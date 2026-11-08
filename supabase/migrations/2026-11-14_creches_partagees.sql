-- Une crèche visible dans plusieurs familles (même crèche, pas une copie).
-- À exécuter une fois dans Supabase (projet des santons) : SQL Editor > New query > Run.
-- Ré-exécutable. Nécessite 2026-11-13_catalogues.sql.

-- ------------------------------------- crèches partagées entre familles
-- Une crèche appartient à sa famille d'origine (listes.famille_id) et peut
-- en plus apparaître dans d'autres familles : c'est la même crèche (pas une
-- copie), ce qu'on coche d'un côté se voit de l'autre. Ses administrateurs
-- choisissent dans quelles familles (dont ils sont membres) elle apparaît.
create table if not exists public.liste_familles (
  liste_id uuid not null references public.listes (id) on delete cascade,
  famille_id uuid not null references public.familles (id) on delete cascade,
  ajoute_par uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (liste_id, famille_id)
);
create index if not exists liste_familles_famille on public.liste_familles (famille_id);

-- toutes les familles d'une crèche : celle d'origine et celles où elle est partagée
create or replace function public.familles_de_liste(l uuid) returns setof uuid
language sql stable security definer set search_path = public as $$
  select famille_id from listes where id = l
  union select famille_id from liste_familles where liste_id = l;
$$;

-- voir : membre d'une des familles de la crèche (ou ancien visiteur avec compte)
create or replace function public.est_membre_de_liste(l uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from membres m where m.user_id = auth.uid()
                 and m.famille_id in (select familles_de_liste(l)));
$$;

-- cocher : administrateur de la crèche ET membre d'une de ses familles
create or replace function public.peut_modifier_liste(l uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from liste_gerants g join membres m on m.user_id = g.user_id
                 where g.liste_id = l and g.user_id = auth.uid()
                   and m.famille_id in (select familles_de_liste(l)));
$$;

-- voir le prénom : en plus, les administrateurs des crèches qu'on voit
create or replace function public.voit_profil(p uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select p = auth.uid()
      or exists (select 1 from membres a join membres b on a.famille_id = b.famille_id
                 where a.user_id = auth.uid() and b.user_id = p)
      or exists (select 1 from liste_visiteurs v join listes li on li.id = v.liste_id
                 join membres m on m.famille_id = li.famille_id
                 where v.user_id = auth.uid() and m.user_id = p)
      or exists (select 1 from liste_visiteurs v join listes li on li.id = v.liste_id
                 join membres m on m.famille_id = li.famille_id
                 where v.user_id = p and m.user_id = auth.uid())
      or exists (select 1 from liste_gerants g where g.user_id = p and peut_voir_liste(g.liste_id));
$$;

alter table public.liste_familles enable row level security;
drop policy if exists partage_lire on public.liste_familles;
create policy partage_lire on public.liste_familles for select to authenticated
  using (peut_voir_liste(liste_id) or est_membre(famille_id));
drop policy if exists partage_ajouter on public.liste_familles;
create policy partage_ajouter on public.liste_familles for insert to authenticated
  with check (peut_gerer_liste(liste_id) and est_membre(famille_id) and ajoute_par = auth.uid()
              and famille_id <> (select li.famille_id from listes li where li.id = liste_id));
drop policy if exists partage_retirer on public.liste_familles;
create policy partage_retirer on public.liste_familles for delete to authenticated
  using (peut_gerer_liste(liste_id) or est_admin(famille_id));
revoke all on public.liste_familles from anon;
grant select, insert, delete on public.liste_familles to authenticated;

-- le nom des familles liées aux crèches qu'on voit (« partagée depuis… »)
drop policy if exists familles_lire on public.familles;
create policy familles_lire on public.familles for select to authenticated
  using (est_membre(id) or exists (select 1 from liste_visiteurs v join listes li on li.id = v.liste_id
                                   where li.famille_id = familles.id and v.user_id = auth.uid())
         or exists (select 1 from listes li where li.famille_id = familles.id and peut_voir_liste(li.id))
         or exists (select 1 from liste_familles lf where lf.famille_id = familles.id and peut_voir_liste(lf.liste_id)));

-- une crèche se modifie (nom, photo, catalogues) sans changer de famille d'origine
drop policy if exists listes_modifier on public.listes;
create policy listes_modifier on public.listes for update to authenticated
  using (peut_gerer_liste(id)) with check (peut_gerer_liste(id));
revoke update on public.listes from authenticated;
grant update (nom, photo, catalogues) on public.listes to authenticated;

-- administrateur : membre d'une des familles de la crèche
drop policy if exists gerants_ajouter on public.liste_gerants;
create policy gerants_ajouter on public.liste_gerants for insert to authenticated
  with check (peut_gerer_liste(liste_id) and exists (
    select 1 from membres m where m.user_id = liste_gerants.user_id
      and m.famille_id in (select familles_de_liste(liste_id))));

-- santons ajoutés : visibles aussi des familles où une crèche de leur famille est partagée ;
-- un administrateur d'une crèche peut en ajouter à sa famille d'origine
drop policy if exists modeles_lire on public.modeles_famille;
create policy modeles_lire on public.modeles_famille for select to authenticated
  using (est_membre(famille_id) or exists (
    select 1 from liste_visiteurs v join listes li on li.id = v.liste_id
    where li.famille_id = modeles_famille.famille_id and v.user_id = auth.uid())
    or exists (select 1 from listes li join liste_familles lf on lf.liste_id = li.id
               where li.famille_id = modeles_famille.famille_id and est_membre(lf.famille_id)));
drop policy if exists modeles_ajouter on public.modeles_famille;
create policy modeles_ajouter on public.modeles_famille for insert to authenticated
  with check (ajoute_par = auth.uid() and (est_membre(famille_id) or exists (
    select 1 from listes li where li.famille_id = modeles_famille.famille_id and peut_modifier_liste(li.id))));

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'storage') then
    -- photos : dans le dossier de la famille d'origine, par ses membres ou les administrateurs de ses crèches
    drop policy if exists "photos : depot par les membres" on storage.objects;
    create policy "photos : depot par les membres" on storage.objects for insert to authenticated
      with check (bucket_id = 'photos'
                  and (storage.foldername(name))[1] ~ '^[0-9a-f-]{36}$'
                  and (public.est_membre(((storage.foldername(name))[1])::uuid)
                       or exists (select 1 from public.listes li
                                  where li.famille_id = ((storage.foldername(name))[1])::uuid
                                    and public.peut_modifier_liste(li.id))));
  end if;
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.liste_familles;
    exception when duplicate_object then null;
    end;
  end if;
end $$;

-- page publique : les administrateurs membres de n'importe quelle famille de la crèche
create or replace function public.voir_liste(p_code text) returns json
language sql stable security definer set search_path = public as $$
  select json_build_object(
    'id', l.id,
    'nom', l.nom,
    'photo', l.photo,
    'catalogues', l.catalogues,
    'gerants', coalesce((select json_agg(distinct jsonb_build_object('id', g.user_id, 'nom', coalesce(p.nom, '')))
                         from liste_gerants g
                         join membres m on m.user_id = g.user_id and m.famille_id in (select familles_de_liste(l.id))
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
