-- Page publique d'une crèche : le lien de visite (#voir=…) s'ouvre sans compte.
-- À exécuter une fois sur une base déjà installée (SQL Editor > New query > Run).
-- Déjà inclus dans schema.sql pour une nouvelle installation.

-- Renvoie la crèche dont le code de visite est donné : son nom, ses gérants
-- encore membres de la famille (prénoms) et ses coches. Rien d'autre (ni la famille, ni les autres crèches,
-- ni les membres). Code inconnu ou changé : renvoie null.
create or replace function public.voir_liste(p_code text) returns json
language sql stable security definer set search_path = public as $$
  select json_build_object(
    'id', l.id,
    'nom', l.nom,
    'gerants', coalesce((select json_agg(json_build_object('id', g.user_id, 'nom', coalesce(p.nom, '')))
                         from liste_gerants g
                         join membres m on m.user_id = g.user_id and m.famille_id = l.famille_id
                         left join profils p on p.id = g.user_id
                         where g.liste_id = l.id), '[]'::json),
    'items', coalesce((select json_agg(json_build_object('santon_id', i.santon_id, 'statut', i.statut,
                                                         'updated_at', i.updated_at))
                       from liste_items i where i.liste_id = l.id), '[]'::json))
  from liste_invitations v join listes l on l.id = v.liste_id
  where v.code = p_code and char_length(p_code) >= 16;
$$;
revoke execute on function public.voir_liste(text) from public;
grant execute on function public.voir_liste(text) to anon, authenticated;
