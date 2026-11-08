-- Photo de la crèche installée : une grande photo par crèche, choisie par ses
-- gérants, affichée en haut de la crèche, sur l'accueil et sur la page publique.
-- À exécuter une fois dans Supabase (projet des santons) : SQL Editor > New query > Run.
-- Ré-exécutable. Nécessite 2026-11-08b_santons_ajoutes.sql (déjà fait).

alter table public.listes add column if not exists photo text;
alter table public.listes drop constraint if exists listes_photo_check;
alter table public.listes add constraint listes_photo_check check (char_length(photo) <= 300);
-- (les gérants et l'admin modifient déjà leur crèche : politique listes_modifier)

-- page publique : la photo de la crèche en plus
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
                                                           'section', f.section, 'note', f.note, 'photo', f.photo))
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
