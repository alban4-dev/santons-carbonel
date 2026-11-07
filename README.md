# Santons Carbonel en famille

Le catalogue des santons Marcel Carbonel **N°2 (7 cm) au pied vert**, partagé
comme un petit réseau social familial :

- chaque **crèche** est une liste au nom de quelqu'un (« Crèche de Léa »,
  « Crèche de Tom », « Crèche de Mamie ») ;
- les **parents gèrent** les crèches de leurs enfants ou filleuls : on choisit
  pour chaque crèche qui peut cocher ;
- **tous les membres de la famille voient toutes les crèches**, avec le fil
  d'activité (« Maman a coché Berger appuyé · Crèche de Léa ») ;
- un **lien d'invitation** fait entrer quelqu'un dans la famille ;
- chaque crèche a son **lien de visite** : la personne voit cette crèche
  seulement, en lecture seule (un oncle, une marraine…), et on peut la retirer.

Dans chaque crèche : ✓ je l'ai, ♡ envie, trois onglets, photo de la crèche
pour pointer, liste d'envies à copier pour les cadeaux.

| Onglet | Contenu | Nombre |
|---|---|---|
| Santons Carbonel | N°2 pied vert à l'unité, dont 13 anciens modèles hors boutique | 264 |
| Bâtiments Escoffier | Collection 7 cm : maisons et bâtisses, façades, crèches et étables, puits, fontaines et ponts, roulottes et charrettes | 76 |
| Décors Carbonel | Bâtiments et accessoires N°2 | 82 |

## Mise en route (une fois, environ 15 minutes)

### 1. La base de données : Supabase (gratuit)

1. Créer un compte sur [supabase.com](https://supabase.com), puis **New project**
   (région conseillée : Paris, `eu-west-3`).
2. **SQL Editor** > **New query** : coller tout le fichier
   [`supabase/schema.sql`](supabase/schema.sql), puis **Run**.
3. **Authentication** > **Sign In / Providers** > **Email** : désactiver
   **Confirm email**. Sinon chaque inscription attend un e-mail de
   confirmation, et l'envoi d'e-mails du plan gratuit est très limité.
4. **Authentication** > **URL Configuration** : mettre l'adresse du site
   (`https://alban4-dev.github.io/santons-carbonel/`) dans **Site URL** et dans
   **Redirect URLs**. C'est ce qui permet
   au lien « Mot de passe oublié » de revenir sur le site.
5. **Project Settings** > **API** : copier **Project URL** et la clé
   **anon public** dans [`config.js`](config.js), puis relancer `python3 build.py`.
   Cette clé est faite pour être publique : ce sont les règles de la base qui
   protègent les données.

Un projet gratuit se met en pause après une semaine sans visite. On le relance
d'un clic depuis le tableau de bord Supabase, les données sont conservées.

### 2. Le site : GitHub Pages

Le site est publié automatiquement depuis ce dépôt :
**https://alban4-dev.github.io/santons-carbonel/**

- Une seule fois : **Settings** > **Pages** > **Build and deployment** >
  **Source** : « GitHub Actions ».
- Ensuite, chaque modification de `main` republie le dossier [`site/`](site)
  (`index.html`, `config.js`, `sprites/`), via
  [`.github/workflows/pages.yml`](.github/workflows/pages.yml).

Le dossier `site/` peut aussi être déposé tel quel sur un autre hébergeur
statique (par exemple Netlify Drop).

### 3. Optionnel : la reconnaissance des santons sur photo

Sans elle, « Photo de la crèche » garde la photo à l'écran pour cocher à la
main. Avec elle, Claude repère sur la photo les modèles du catalogue et propose
de les cocher (on valide avant).

1. Créer une clé API sur [console.anthropic.com](https://console.anthropic.com)
   (payant à l'usage : quelques centimes par photo).
2. Supabase > **Edge Functions** > **Deploy a new function** > via l'éditeur,
   nom `reconnaitre`, coller
   [`supabase/functions/reconnaitre/index.ts`](supabase/functions/reconnaitre/index.ts).
   Ou en ligne de commande : `supabase functions deploy reconnaitre`.
3. Edge Functions > **Secrets** : ajouter `ANTHROPIC_API_KEY`.
4. Dans `config.js`, mettre `reconnaissance: true`, puis `python3 build.py`
   et republier `site/`.

La fonction n'accepte que les membres connectés d'une famille, pour que la clé
ne serve qu'à vous.

### 4. Premiers pas

1. Ouvrir le site, **Créer un compte** (prénom, e-mail, mot de passe), puis
   **Créer la famille**.
2. **Inviter dans la famille** copie le lien à envoyer (WhatsApp, SMS…). Chacun
   crée son compte en l'ouvrant et devient membre.
3. **+ Nouvelle crèche** : « Crèche de Léa ». Dans la crèche, **Réglages** :
   cocher l'autre parent comme gérant, copier le **lien de visite** pour un
   proche qui doit seulement regarder.

## Qui peut faire quoi

| | Voir les crèches | Cocher | Réglages d'une crèche | Inviter |
|---|---|---|---|---|
| Membre | toutes celles de la famille | celles dont il est gérant | celles dont il est gérant | lien de la famille |
| Admin de la famille (le créateur) | toutes | celles dont il est gérant | toutes, et retirer un membre | lien de la famille |
| Visiteur | seulement celles dont il a reçu le lien | non | non | non |

Ces règles sont vérifiées par la base de données elle-même (Row Level Security
dans `schema.sql`), pas seulement par l'affichage. Un visiteur ne voit pas le
code d'adhésion de la famille. Un membre qui quitte la famille perd aussitôt
ses droits.

## Tests

`supabase/tests/lancer.sh` rejoue tout sans compte Supabase, sur un
PostgreSQL 16 local :

- `droits.sql` : 33 vérifications des règles d'accès (inconnu, membre, gérant,
  visiteur, ancien membre, anonyme) ;
- `parcours.js` : dans un vrai navigateur, Papa crée la famille et la crèche
  de Léa, coche, utilise la photo ; Maman arrive par le lien d'invitation, est
  en lecture seule, puis devient gérante ; Mamie arrive par le lien de visite
  et ne voit que la crèche de Léa.

`faux_supabase.py` imite les routes de Supabase utilisées par l'appli et
exécute chaque requête avec l'identité de l'utilisateur, donc avec les vraies
règles. `auth_factice.sql` crée le schéma `auth` minimal. Le temps réel et
l'appel à Claude ne sont pas couverts : la fonction de reconnaissance est
remplacée par une réponse fixe.

## Le catalogue

- **Boutique** : [marcelcarbonel.com](https://marcelcarbonel.com), relevée en
  entier (1 321 références) par `scraper/scrape.py`.
- **Pied vert** : socle peint en vert, lu sur chaque photo par
  `scraper/socle.py`. Les Provinces de France, la Bonne Mère, les Confrères ou
  le Jésus dans sa paille ont un autre socle et ne sont pas retenus.
- **Anciens modèles** : 13 santons N°2 pied vert du catalogue papier 2024
  absents de la boutique, photos découpées dans le PDF par
  `scraper/anciens.py`.
- **Bâtiments Escoffier** : [escoffier.fr](https://www.escoffier.fr), rubrique
  « Décors de crèche », relevée par `scraper/escoffier.py` (173 décors). Sont
  retenus les bâtiments de la collection 7 cm, l'échelle des santons N°2, et
  ceux sans gamme indiquée (moulins, églises, phare…). Les autres tailles
  (2, 5, 9 cm), les accessoires et les arbres sont écartés.
- **Sélection** : `scraper/selection.py` (N°2 pied vert à l'unité ; bâtiments
  et accessoires Carbonel N°2 ; bâtiments Escoffier 7 cm ; ni coffrets, ni
  lots, ni Pastel).

Pour le mettre à jour :

```sh
cd scraper
python3 scrape.py          # relève la boutique -> data/santons.json
python3 anciens.py         # anciens N°2 du catalogue PDF (pdfplumber)
python3 escoffier.py       # bâtiments Escoffier -> data/escoffier.json
python3 build_sprites.py   # vignettes, pied, sélection -> site/sprites/ (Pillow)
cd .. && python3 build.py  # site/index.html
```

Les identifiants sont ceux des boutiques (5001 et plus pour les anciens
modèles Carbonel, 100000 + l'identifiant Escoffier pour Escoffier), donc les
coches restent valables après une mise à jour.

## Fichiers

| Chemin | Rôle |
|---|---|
| `site/` | Le site à publier (généré) |
| `config.js` | Adresse et clé publique Supabase, option de reconnaissance |
| `src/app.html` | Le code de l'application |
| `supabase/schema.sql` | Tables, règles d'accès, fonctions d'invitation |
| `supabase/functions/reconnaitre/` | Reconnaissance des santons sur photo (Claude) |
| `supabase/tests/` | Tests des droits et du parcours |
| `data/` | Les catalogues relevés (Carbonel, anciens modèles, Escoffier) |
| `scraper/` | Relevé, couleur du pied, anciens modèles, vignettes |

GitHub ne contenait aucun outil de collection de santons ni de catalogue
Carbonel (recherche de novembre 2026). Les seuls dépôts proches,
[Oufti2015/santons](https://github.com/Oufti2015/santons) et
[karim1407/santonniers](https://github.com/karim1407/santonniers), ne
correspondent pas à ce besoin.

Photos et noms © Ateliers Marcel Carbonel et Santons Escoffier. Usage familial et privé.
