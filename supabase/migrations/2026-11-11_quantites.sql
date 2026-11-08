-- Quantité possédée (2 moutons identiques…) : 1 par défaut, réglable dans la
-- fiche du santon. À exécuter une fois dans Supabase (projet des santons) :
-- SQL Editor > New query > Run. Ré-exécutable.
-- Nécessite 2026-11-10_photos_santons.sql (déjà fait).

alter table public.liste_items add column if not exists quantite smallint not null default 1;
alter table public.liste_items drop constraint if exists liste_items_quantite_check;
alter table public.liste_items add constraint liste_items_quantite_check check (quantite between 1 and 99);

-- page publique : la quantité en plus
create or replace function public.voir_liste(p_code text) returns json
language sql stable security definer set search_path = public as $$
  select json_build_object(
    'id', l.id,
    'nom', l.nom,
    'photo', l.photo,
    'gerants', coalesce((select json_agg(json_build_object('id', g.user_id, 'nom', coalesce(p.nom, '')))
                         from liste_gerants g
                         join membres m on m.user_id = g.user_id and m.famille_id = l.famille_id
                         left join profils p on p.id = g.user_id
                         where g.liste_id = l.id), '[]'::json),
    'items', coalesce((select json_agg(json_build_object('santon_id', i.santon_id, 'statut', i.statut,
                                                         'quantite', i.quantite, 'updated_at', i.updated_at))
                       from liste_items i where i.liste_id = l.id), '[]'::json),
    'modeles', coalesce((select json_agg(json_build_object('id', f.id, 'nom', f.nom, 'marque', f.marque,
                                                           'section', f.section, 'note', f.note, 'photo', f.photo,
                                                           'photos', f.photos))
                         from modeles_famille f
                         where f.famille_id = l.famille_id
                           and exists (select 1 from liste_items i where i.liste_id = l.id and i.santon_id = f.id)),
                        '[]'::json))
  from liste_invitations v join listes l on l.id = v.liste_id
  where v.code = p_code and char_length(p_code) >= 16;
$$;
revoke execute on function public.voir_liste(text) from public;
grant execute on function public.voir_liste(text) to anon, authenticated;
