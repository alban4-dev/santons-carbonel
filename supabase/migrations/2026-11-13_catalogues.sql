-- Catalogues de chaque crèche (Carbonel N°2, Carbonel N°3, Escoffier, artisans…)
-- et santons ajoutés en taille N°3.
-- À exécuter une fois dans Supabase (projet des santons) : SQL Editor > New query > Run.
-- Ré-exécutable. Nécessite 2026-11-12_reservations.sql (déjà fait).

-- null = les catalogues par défaut (tous sauf Carbonel N°3)
alter table public.listes add column if not exists catalogues text[];
alter table public.listes drop constraint if exists listes_catalogues_check;
alter table public.listes add constraint listes_catalogues_check check (catalogues is null or (
  cardinality(catalogues) between 1 and 10
  and catalogues <@ array['santons', 'decor', 'santons_n3', 'santons_escoffier', 'escoffier', 'autres']));
-- (les administrateurs modifient déjà leur crèche : politique listes_modifier)

-- un santon inconnu peut être ajouté au catalogue Carbonel N°3
alter table public.modeles_famille drop constraint if exists modeles_famille_section_check;
alter table public.modeles_famille add constraint modeles_famille_section_check
  check (section in ('santons', 'santons_n3', 'santons_escoffier', 'escoffier', 'decor'));

-- page publique : les catalogues de la crèche en plus
create or replace function public.voir_liste(p_code text) returns json
language sql stable security definer set search_path = public as $$
  select json_build_object(
    'id', l.id,
    'nom', l.nom,
    'photo', l.photo,
    'catalogues', l.catalogues,
    'gerants', coalesce((select json_agg(json_build_object('id', g.user_id, 'nom', coalesce(p.nom, '')))
                         from liste_gerants g
                         join membres m on m.user_id = g.user_id and m.famille_id = l.famille_id
                         left join profils p on p.id = g.user_id
                         where g.liste_id = l.id), '[]'::json),
    'items', coalesce((select json_agg(json_build_object('santon_id', i.santon_id, 'statut', i.statut,
                                                         'quantite', i.quantite, 'updated_at', i.updated_at))
                       from liste_items i where i.liste_id = l.id), '[]'::json),
    'reservations', coalesce((select json_agg(json_build_object('santon_id', r.santon_id, 'nom', r.nom,
                                                                'created_at', r.created_at))
                              from liste_reservations r where r.liste_id = l.id), '[]'::json),
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
