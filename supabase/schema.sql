-- Santons Carbonel : réseau familial de collections
-- À exécuter une fois dans Supabase : SQL Editor > New query > coller > Run.
-- (Ré-exécutable : tout est créé « if not exists » / « or replace ».)
--
-- Modèle
--   familles        un groupe (« Famille Dupont »)
--   famille_invitations code du lien d'adhésion (lisible par les membres seulement)
--   membres         qui fait partie de la famille (admin ou membre)
--   listes          une crèche au nom de quelqu'un (« Crèche de Léa »)
--   liste_gerants   qui peut cocher dans cette liste (parents, parrain…)
--   liste_visiteurs (ancien) comptes visiteurs : remplacé par la page publique
--   liste_invitations code du lien de visite d'une liste (gérants seulement)
--   liste_items     ce qui est coché : 'own' (je l'ai) ou 'wish' (envie)
--   modeles_famille santons ajoutés à la main par la famille (anciens modèles),
--                   avec photo dans le stockage « photos »
--   profils         le prénom affiché de chaque compte
--
-- Droits (vérifiés par la base, quelle que soit l'appli)
--   - un membre voit toutes les listes de sa famille et tous les membres ;
--   - seuls les gérants d'une liste la modifient ; un admin de la famille
--     peut aussi en gérer les réglages (gérants, visiteurs, suppression) ;
--   - le lien de visite d'une crèche ouvre une page publique en lecture seule,
--     sans compte (fonction voir_liste) ; changer le lien coupe l'ancien.

-- ---------------------------------------------------------------- tables

create table if not exists public.profils (
  id uuid primary key references auth.users (id) on delete cascade,
  nom text not null check (char_length(nom) between 1 and 40),
  created_at timestamptz not null default now()
);

create table if not exists public.familles (
  id uuid primary key default gen_random_uuid(),
  nom text not null check (char_length(nom) between 1 and 60),
  cree_par uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.famille_invitations (
  famille_id uuid primary key references public.familles (id) on delete cascade,
  code text not null unique default replace(gen_random_uuid()::text, '-', '')
);

create table if not exists public.membres (
  famille_id uuid not null references public.familles (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null default 'membre' check (role in ('admin', 'membre')),
  created_at timestamptz not null default now(),
  primary key (famille_id, user_id)
);

create table if not exists public.listes (
  id uuid primary key default gen_random_uuid(),
  famille_id uuid not null references public.familles (id) on delete cascade,
  nom text not null check (char_length(nom) between 1 and 60),
  cree_par uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  photo text check (char_length(photo) <= 300)  -- photo de la crèche installée (stockage « photos »)
);

create table if not exists public.liste_gerants (
  liste_id uuid not null references public.listes (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  primary key (liste_id, user_id)
);

create table if not exists public.liste_visiteurs (
  liste_id uuid not null references public.listes (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (liste_id, user_id)
);

create table if not exists public.liste_invitations (
  liste_id uuid primary key references public.listes (id) on delete cascade,
  code text not null unique default replace(gen_random_uuid()::text, '-', '')
);

create table if not exists public.liste_items (
  liste_id uuid not null references public.listes (id) on delete cascade,
  santon_id integer not null check (santon_id > 0),
  statut text not null check (statut in ('own', 'wish')),
  modifie_par uuid references auth.users (id) on delete set null,
  updated_at timestamptz not null default now(),
  primary key (liste_id, santon_id)
);

create index if not exists listes_famille on public.listes (famille_id);
create index if not exists membres_user on public.membres (user_id);
create index if not exists visiteurs_user on public.liste_visiteurs (user_id);
create index if not exists items_maj on public.liste_items (updated_at desc);

-- ------------------------------------------------- fonctions d'autorisation
-- security definer : elles lisent les tables sans repasser par la RLS,
-- ce qui évite les boucles entre politiques.

create or replace function public.est_membre(f uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from membres where famille_id = f and user_id = auth.uid());
$$;

create or replace function public.est_admin(f uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from membres where famille_id = f and user_id = auth.uid() and role = 'admin');
$$;

create or replace function public.est_membre_de_liste(l uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from listes li join membres m on m.famille_id = li.famille_id
                 where li.id = l and m.user_id = auth.uid());
$$;

create or replace function public.peut_voir_liste(l uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select est_membre_de_liste(l)
      or exists (select 1 from liste_visiteurs where liste_id = l and user_id = auth.uid());
$$;

-- cocher : gérant de la liste ET toujours membre de la famille
create or replace function public.peut_modifier_liste(l uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from liste_gerants g
                 join listes li on li.id = g.liste_id
                 join membres m on m.famille_id = li.famille_id and m.user_id = g.user_id
                 where g.liste_id = l and g.user_id = auth.uid());
$$;

-- réglages : gérant, ou admin de la famille
create or replace function public.peut_gerer_liste(l uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select peut_modifier_liste(l)
      or exists (select 1 from listes li where li.id = l and est_admin(li.famille_id));
$$;

-- voir le prénom de quelqu'un : on partage une famille, ou une liste
create or replace function public.voit_profil(p uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select p = auth.uid()
      or exists (select 1 from membres a join membres b on a.famille_id = b.famille_id
                 where a.user_id = auth.uid() and b.user_id = p)
      -- un visiteur voit les membres de la famille des listes qu'il visite
      or exists (select 1 from liste_visiteurs v join listes li on li.id = v.liste_id
                 join membres m on m.famille_id = li.famille_id
                 where v.user_id = auth.uid() and m.user_id = p)
      -- un membre voit les visiteurs des listes de sa famille
      or exists (select 1 from liste_visiteurs v join listes li on li.id = v.liste_id
                 join membres m on m.famille_id = li.famille_id
                 where v.user_id = p and m.user_id = auth.uid());
$$;

-- ---------------------------------------------------------- actions (RPC)

create or replace function public.creer_famille(p_nom text) returns uuid
language plpgsql security definer set search_path = public as $$
declare f uuid;
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  insert into familles (nom, cree_par) values (trim(p_nom), auth.uid()) returning id into f;
  insert into membres (famille_id, user_id, role) values (f, auth.uid(), 'admin');
  insert into famille_invitations (famille_id) values (f);
  return f;
end $$;

create or replace function public.rejoindre_famille(p_code text) returns uuid
language plpgsql security definer set search_path = public as $$
declare f uuid;
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  select famille_id into f from famille_invitations where code = p_code;
  if f is null then raise exception 'lien d''invitation inconnu ou expiré'; end if;
  insert into membres (famille_id, user_id) values (f, auth.uid()) on conflict do nothing;
  -- devenu membre, il n'a plus besoin d'être visiteur des listes de cette famille
  delete from liste_visiteurs v using listes li
   where v.liste_id = li.id and li.famille_id = f and v.user_id = auth.uid();
  return f;
end $$;

create or replace function public.creer_liste(p_famille uuid, p_nom text) returns uuid
language plpgsql security definer set search_path = public as $$
declare l uuid;
begin
  if not est_membre(p_famille) then raise exception 'réservé aux membres de la famille'; end if;
  insert into listes (famille_id, nom, cree_par) values (p_famille, trim(p_nom), auth.uid()) returning id into l;
  insert into liste_gerants (liste_id, user_id) values (l, auth.uid());
  insert into liste_invitations (liste_id) values (l);
  return l;
end $$;

create or replace function public.devenir_visiteur(p_code text) returns uuid
language plpgsql security definer set search_path = public as $$
declare l uuid;
begin
  if auth.uid() is null then raise exception 'non connecté'; end if;
  select liste_id into l from liste_invitations where code = p_code;
  if l is null then raise exception 'lien de visite inconnu ou expiré'; end if;
  if not est_membre_de_liste(l) then
    insert into liste_visiteurs (liste_id, user_id) values (l, auth.uid()) on conflict do nothing;
  end if;
  return l;
end $$;

create or replace function public.nouveau_code_famille(p_famille uuid) returns text
language plpgsql security definer set search_path = public as $$
declare c text := replace(gen_random_uuid()::text, '-', '');
begin
  if not est_admin(p_famille) then raise exception 'réservé aux administrateurs'; end if;
  insert into famille_invitations (famille_id, code) values (p_famille, c)
    on conflict (famille_id) do update set code = excluded.code;
  return c;
end $$;

create or replace function public.nouveau_code_visite(p_liste uuid) returns text
language plpgsql security definer set search_path = public as $$
declare c text := replace(gen_random_uuid()::text, '-', '');
begin
  if not peut_gerer_liste(p_liste) then raise exception 'réservé aux gérants de la liste'; end if;
  insert into liste_invitations (liste_id, code) values (p_liste, c)
    on conflict (liste_id) do update set code = excluded.code;
  return c;
end $$;

-- horodatage et auteur de chaque coche (pour le fil d'activité)
create or replace function public.items_auteur() returns trigger
language plpgsql set search_path = public as $$
begin
  new.updated_at := now();
  new.modifie_par := auth.uid();
  return new;
end $$;
drop trigger if exists items_auteur on public.liste_items;
create trigger items_auteur before insert or update on public.liste_items
  for each row execute function public.items_auteur();

-- ------------------------------------------------------------------ RLS

alter table public.profils enable row level security;
alter table public.familles enable row level security;
alter table public.famille_invitations enable row level security;
alter table public.membres enable row level security;
alter table public.listes enable row level security;
alter table public.liste_gerants enable row level security;
alter table public.liste_visiteurs enable row level security;
alter table public.liste_invitations enable row level security;
alter table public.liste_items enable row level security;

drop policy if exists profils_lire on public.profils;
create policy profils_lire on public.profils for select to authenticated using (voit_profil(id));
drop policy if exists profils_creer on public.profils;
create policy profils_creer on public.profils for insert to authenticated with check (id = auth.uid());
drop policy if exists profils_modifier on public.profils;
create policy profils_modifier on public.profils for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists familles_lire on public.familles;
create policy familles_lire on public.familles for select to authenticated
  using (est_membre(id) or exists (select 1 from liste_visiteurs v join listes li on li.id = v.liste_id
                                   where li.famille_id = familles.id and v.user_id = auth.uid()));
drop policy if exists familles_modifier on public.familles;
create policy familles_modifier on public.familles for update to authenticated using (est_admin(id)) with check (est_admin(id));
drop policy if exists familles_supprimer on public.familles;
create policy familles_supprimer on public.familles for delete to authenticated using (est_admin(id));

drop policy if exists finvit_lire on public.famille_invitations;
create policy finvit_lire on public.famille_invitations for select to authenticated using (est_membre(famille_id));

drop policy if exists membres_lire on public.membres;
create policy membres_lire on public.membres for select to authenticated
  using (est_membre(famille_id) or voit_profil(user_id) and exists (
    select 1 from liste_visiteurs v join listes li on li.id = v.liste_id
    where li.famille_id = membres.famille_id and v.user_id = auth.uid()));
drop policy if exists membres_role on public.membres;
create policy membres_role on public.membres for update to authenticated
  using (est_admin(famille_id)) with check (est_admin(famille_id));
drop policy if exists membres_quitter on public.membres;
create policy membres_quitter on public.membres for delete to authenticated
  using (user_id = auth.uid() or est_admin(famille_id));

drop policy if exists listes_lire on public.listes;
create policy listes_lire on public.listes for select to authenticated using (peut_voir_liste(id));
drop policy if exists listes_modifier on public.listes;
create policy listes_modifier on public.listes for update to authenticated
  using (peut_gerer_liste(id)) with check (peut_gerer_liste(id) and est_membre(famille_id));
drop policy if exists listes_supprimer on public.listes;
create policy listes_supprimer on public.listes for delete to authenticated using (peut_gerer_liste(id));

drop policy if exists gerants_lire on public.liste_gerants;
create policy gerants_lire on public.liste_gerants for select to authenticated using (peut_voir_liste(liste_id));
drop policy if exists gerants_ajouter on public.liste_gerants;
create policy gerants_ajouter on public.liste_gerants for insert to authenticated
  with check (peut_gerer_liste(liste_id) and exists (
    select 1 from listes li join membres m on m.famille_id = li.famille_id
    where li.id = liste_id and m.user_id = liste_gerants.user_id));
drop policy if exists gerants_retirer on public.liste_gerants;
create policy gerants_retirer on public.liste_gerants for delete to authenticated using (peut_gerer_liste(liste_id));

drop policy if exists visiteurs_lire on public.liste_visiteurs;
create policy visiteurs_lire on public.liste_visiteurs for select to authenticated
  using (est_membre_de_liste(liste_id) or user_id = auth.uid());
drop policy if exists visiteurs_retirer on public.liste_visiteurs;
create policy visiteurs_retirer on public.liste_visiteurs for delete to authenticated
  using (peut_gerer_liste(liste_id) or user_id = auth.uid());

drop policy if exists invitations_lire on public.liste_invitations;
create policy invitations_lire on public.liste_invitations for select to authenticated using (peut_gerer_liste(liste_id));

drop policy if exists items_lire on public.liste_items;
create policy items_lire on public.liste_items for select to authenticated using (peut_voir_liste(liste_id));
drop policy if exists items_ajouter on public.liste_items;
create policy items_ajouter on public.liste_items for insert to authenticated with check (peut_modifier_liste(liste_id));
drop policy if exists items_modifier on public.liste_items;
create policy items_modifier on public.liste_items for update to authenticated
  using (peut_modifier_liste(liste_id)) with check (peut_modifier_liste(liste_id));
drop policy if exists items_retirer on public.liste_items;
create policy items_retirer on public.liste_items for delete to authenticated using (peut_modifier_liste(liste_id));

-- --------------------------------------------------------------- droits

revoke all on all tables in schema public from anon;
revoke execute on all functions in schema public from anon, public;
grant select, insert, update on public.profils to authenticated;
grant select, update, delete on public.familles to authenticated;
grant select on public.famille_invitations to authenticated;
grant select, update, delete on public.membres to authenticated;
grant select, update, delete on public.listes to authenticated;
grant select, insert, delete on public.liste_gerants to authenticated;
grant select, delete on public.liste_visiteurs to authenticated;
grant select on public.liste_invitations to authenticated;
grant select, insert, update, delete on public.liste_items to authenticated;
grant execute on function public.creer_famille(text), public.rejoindre_famille(text),
  public.creer_liste(uuid, text), public.devenir_visiteur(text),
  public.nouveau_code_famille(uuid), public.nouveau_code_visite(uuid),
  public.est_membre(uuid), public.est_admin(uuid), public.est_membre_de_liste(uuid),
  public.peut_voir_liste(uuid), public.peut_modifier_liste(uuid), public.peut_gerer_liste(uuid),
  public.voit_profil(uuid) to authenticated;

-- ------------------------------------------------- temps réel (Supabase)
-- Les changements de coches et de listes arrivent en direct chez les autres.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.liste_items, public.listes,
        public.liste_gerants, public.liste_visiteurs, public.membres;
    exception when duplicate_object then null;
    end;
  end if;
end $$;

-- =====================================================================
-- Santons ajoutés par la famille, page publique, photos
-- (identique à migrations/2026-11-08b_santons_ajoutes.sql)
-- =====================================================================

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
  section text not null default 'santons',
  note text check (char_length(note) <= 200),
  photo text check (char_length(photo) <= 300),  -- chemin dans le stockage « photos » (vignette)
  photos text[] check (photos is null or (cardinality(photos) <= 3      -- [face, dos, côté]
                       and char_length(array_to_string(photos, '')) <= 900)),
  ajoute_par uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists modeles_famille_famille on public.modeles_famille (famille_id);
-- onglet de l'appli : santons Carbonel, santons Escoffier, bâtiments Escoffier, décors Carbonel
alter table public.modeles_famille drop constraint if exists modeles_famille_section_check;
alter table public.modeles_famille add constraint modeles_famille_section_check
  check (section in ('santons', 'santons_escoffier', 'escoffier', 'decor'));

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
  using (est_membre(famille_id)) with check (est_membre(famille_id));  -- tout membre complète les photos
drop policy if exists modeles_retirer on public.modeles_famille;
create policy modeles_retirer on public.modeles_famille for delete to authenticated
  using (ajoute_par = auth.uid() or est_admin(famille_id));

grant select, insert, delete on public.modeles_famille to authenticated;
grant update (nom, note, photo, photos) on public.modeles_famille to authenticated;
grant usage on sequence public.modeles_famille_id_seq to authenticated;
revoke all on public.modeles_famille from anon;
revoke all on sequence public.modeles_famille_id_seq from anon;

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
