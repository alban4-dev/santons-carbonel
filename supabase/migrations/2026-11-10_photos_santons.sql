-- Jusqu'à 3 photos par santon ajouté par la famille (face, dos, côté),
-- modifiables ensuite dans sa fiche par tout membre de la famille.
-- À exécuter une fois dans Supabase (projet des santons) : SQL Editor > New query > Run.
-- Ré-exécutable. Contient aussi 2026-11-09_photo_creche.sql (photo de la
-- crèche installée) : inutile de lancer celui-là en plus.

-- ------------------------------------------- photo de la crèche installée
alter table public.listes add column if not exists photo text;
alter table public.listes drop constraint if exists listes_photo_check;
alter table public.listes add constraint listes_photo_check check (char_length(photo) <= 300);

-- -------------------------------------------- photos des santons ajoutés
-- photos = [face, dos, côté] (une case vide = null) ; photo = la première
-- présente, pour la vignette.
alter table public.modeles_famille add column if not exists photos text[];
alter table public.modeles_famille drop constraint if exists modeles_famille_photos_check;
alter table public.modeles_famille add constraint modeles_famille_photos_check
  check (photos is null or (cardinality(photos) <= 3 and char_length(array_to_string(photos, '')) <= 900));
update public.modeles_famille set photos = array[photo, null, null] where photos is null and photo is not null;

-- tout membre de la famille peut compléter les photos, le nom et la note ;
-- retirer un modèle reste réservé à qui l'a ajouté et à l'admin
drop policy if exists modeles_modifier on public.modeles_famille;
create policy modeles_modifier on public.modeles_famille for update to authenticated
  using (est_membre(famille_id)) with check (est_membre(famille_id));
revoke update on public.modeles_famille from authenticated;
grant update (nom, note, photo, photos) on public.modeles_famille to authenticated;

-- ----------------------------------------------------------- page publique
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
                                                         'updated_at', i.updated_at))
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

-- hygiène : Supabase ouvre par défaut les nouvelles tables au rôle anonyme ;
-- les règles d'accès le bloquaient déjà, on retire aussi le droit lui-même
revoke all on public.modeles_famille from anon;
revoke all on sequence public.modeles_famille_id_seq from anon;
