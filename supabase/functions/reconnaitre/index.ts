// Fonction Supabase « reconnaitre » : repère, sur une photo de crèche, les
// santons du catalogue Carbonel, à l'aide de Claude.
//
// Entrée (POST JSON, utilisateur connecté et membre d'une famille) :
//   { photo: "<jpeg base64>", planches: ["<jpeg base64>", ...], liste: "1 = Ange\n2 = Bœuf\n..." }
//   - photo    : la photo de la crèche
//   - planches : 1 à 6 planches de référence, chaque case numérotée
//   - liste    : la correspondance numéro = nom
// Sortie : { trouves: [{ n: 12, sur: true }, ...] }
//
// Déploiement (voir le README) :
//   supabase secrets set ANTHROPIC_API_KEY=...
//   supabase functions deploy reconnaitre
import Anthropic from "npm:@anthropic-ai/sdk";
import { createClient } from "npm:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });

const SCHEMA = {
  type: "object",
  properties: {
    trouves: {
      type: "array",
      items: {
        type: "object",
        properties: { n: { type: "integer" }, sur: { type: "boolean" } },
        required: ["n", "sur"],
        additionalProperties: false,
      },
    },
  },
  required: ["trouves"],
  additionalProperties: false,
};

const anthropic = new Anthropic(); // lit ANTHROPIC_API_KEY

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "POST attendu" }, 405);

  // Réservé aux membres d'une famille : la clé Anthropic est payante.
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });
  const { data: { user } } = await sb.auth.getUser();
  if (!user) return json({ error: "connexion requise" }, 401);
  const { count } = await sb.from("membres").select("user_id", { count: "exact", head: true }).eq("user_id", user.id);
  if (!count) return json({ error: "réservé aux membres d'une famille" }, 403);

  let body: { photo?: unknown; planches?: unknown; liste?: unknown };
  try { body = await req.json(); } catch { return json({ error: "JSON invalide" }, 400); }
  const { photo, planches, liste } = body;
  const b64 = (v: unknown) => typeof v === "string" && v.length > 100 && v.length < 4_000_000 && /^[A-Za-z0-9+/=]+$/.test(v);
  if (!b64(photo) || !Array.isArray(planches) || planches.length < 1 || planches.length > 6 || !planches.every(b64) ||
      typeof liste !== "string" || liste.length > 30_000) {
    return json({ error: "photo, planches (1 à 6) et liste attendues" }, 400);
  }

  const image = (data: string) => ({ type: "image" as const, source: { type: "base64" as const, media_type: "image/jpeg" as const, data } });
  const content = [
    { type: "text" as const, text: "Image 1 : la photo de la crèche de la famille." },
    image(photo as string),
    ...(planches as string[]).flatMap((p, i) => [
      { type: "text" as const, text: `Planche de référence ${i + 1} du catalogue Carbonel (chaque case porte un numéro en haut à gauche).` },
      image(p),
    ]),
    {
      type: "text" as const,
      text: `Tu aides une famille à inventorier sa crèche provençale de santons Marcel Carbonel (taille N°2, 7 cm).
Correspondance des numéros des planches :
${liste}

Pour chaque objet visible sur la photo de la crèche, trouve la case de référence qui lui correspond : même personnage, même posture, mêmes couleurs, même accessoire. Ignore ce qui ne figure dans aucune planche. Plusieurs modèles ne diffèrent que par la couleur : choisis la bonne couleur. Ne retiens que ce que tu vois vraiment sur la photo.
Réponds avec la liste "trouves" : un élément par modèle reconnu, avec son numéro "n" et "sur" à false si tu hésites.`,
    },
  ];

  try {
    const response = await anthropic.beta.messages.create({
      model: "claude-opus-5-5",
      max_tokens: 16000,
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
      output_config: { effort: "high", format: { type: "json_schema", schema: SCHEMA } },
      messages: [{ role: "user", content }],
    });
    if (response.stop_reason === "refusal") return json({ error: "demande refusée par le modèle", trouves: [] }, 422);
    const text = response.content.find((b) => b.type === "text");
    if (!text || text.type !== "text") return json({ error: "réponse vide", trouves: [] }, 502);
    const parsed = JSON.parse(text.text) as { trouves?: { n: number; sur: boolean }[] };
    return json({ trouves: Array.isArray(parsed.trouves) ? parsed.trouves : [] });
  } catch (e) {
    if (e instanceof Anthropic.RateLimitError) return json({ error: "trop de demandes, réessayez plus tard" }, 429);
    if (e instanceof Anthropic.AuthenticationError) return json({ error: "clé Anthropic invalide (ANTHROPIC_API_KEY)" }, 500);
    if (e instanceof Anthropic.APIError) return json({ error: `erreur du service (${e.status})` }, 502);
    return json({ error: "erreur inattendue" }, 500);
  }
});
