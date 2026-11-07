-- Santons ajoutés par la famille (anciens modèles, pièces hors catalogue)
-- et page publique d'une crèche.
-- À exécuter une fois dans Supabase : SQL Editor > New query > coller > Run.
-- Ré-exécutable. Contient aussi 2026-11-08_page_publique.sql : inutile de
-- lancer celui-là en plus.

-- ------------------------------------------------- modèles ajoutés à la main
-- Un modèle ajouté par un membre entre dans le catalogue de toute sa famille :
-- il apparaît dans toutes ses crèches et se coche comme les autres
-- (liste_items.santon_id = son id, à partir de 1 000 000).
create sequence if not exists public.modeles_famille_id_seq start 1000000;

create table if not exists public.modeles_famille (
  id integer primary key default nextval('public.modeles_famille_id_seq'),
  famille_id uuid not null references public.familles (id) on delete cascade,
  nom text not null check (char_length(nom) between 1 and 80),
  marque text not null default 'Carbonel' check (marque in ('Carbonel', 'Escoffier', 'Autre')),
  section text not null default 'santons' check (section in ('santons', 'escoffier', 'decor')),
  note text check (char_length(note) <= 200),
  photo text check (char_length(photo) <= 300),  -- chemin dans le stockage « photos »
  ajoute_par uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists modeles_famille_famille on public.modeles_famille (famille_id);

alter table public.modeles_famille enable row level security;
drop policy if exists modeles_lire on public.modeles_famille;
create policy modeles_lire on public.modeles_famille for select to authenticated
  using (est_membre(famille_id) or exists (
    select 1 from liste_visiteurs v join listes li on li.id = v.liste_id
    where li.famille_id = modeles_famille.famille_id and v.user_id = auth.uid()));
drop policy if exists modeles_ajouter on public.modeles_famille;
create policy modeles_ajouter on public.modeles_famille for insert to authenticated
  with check (est_membre(famille_id) and ajoute_par = auth.uid());
drop policy if exists modeles_modifier on public.modeles_famille;
create policy modeles_modifier on public.modeles_famille for update to authenticated
  using (ajoute_par = auth.uid() or est_admin(famille_id))
  with check (est_membre(famille_id));
drop policy if exists modeles_retirer on public.modeles_famille;
create policy modeles_retirer on public.modeles_famille for delete to authenticated
  using (ajoute_par = auth.uid() or est_admin(famille_id));

grant select, insert, update, delete on public.modeles_famille to authenticated;
grant usage on sequence public.modeles_famille_id_seq to authenticated;

-- un modèle retiré disparaît aussi des crèches de la famille
create or replace function public.modele_retire() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  delete from liste_items i using listes l
   where i.liste_id = l.id and l.famille_id = old.famille_id and i.santon_id = old.id;
  return old;
end $$;
revoke execute on function public.modele_retire() from public, anon;
drop trigger if exists modele_retire on public.modeles_famille;
create trigger modele_retire after delete on public.modeles_famille
  for each row execute function public.modele_retire();

-- --------------------------------------------- page publique d'une crèche
-- Renvoie la crèche dont le code de visite est donné : son nom, ses gérants
-- encore membres de la famille (prénoms), ses coches, et les modèles ajoutés
-- par la famille qui y sont cochés. Rien d'autre. Code inconnu ou changé : null.
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

-- ------------------------------------------------------ photos (Storage)
-- Espace « photos » : lisible par tous (les liens sont introuvables sans les
-- connaître), seuls les membres d'une famille déposent dans son dossier
-- (<famille_id>/<fichier>.jpg), 5 Mo au plus, images seulement.
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'storage') then
    insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    values ('photos', 'photos', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
    on conflict (id) do update set public = true, file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;
    drop policy if exists "photos : depot par les membres" on storage.objects;
    create policy "photos : depot par les membres" on storage.objects for insert to authenticated
      with check (bucket_id = 'photos'
                  and (storage.foldername(name))[1] ~ '^[0-9a-f-]{36}$'
                  and public.est_membre(((storage.foldername(name))[1])::uuid));
    drop policy if exists "photos : retrait par l'auteur" on storage.objects;
    create policy "photos : retrait par l'auteur" on storage.objects for delete to authenticated
      using (bucket_id = 'photos' and owner = auth.uid());
  end if;
end $$;

-- ------------------------------------------------------------ temps réel
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.modeles_famille;
    exception when duplicate_object then null;
    end;
  end if;
end $$;
