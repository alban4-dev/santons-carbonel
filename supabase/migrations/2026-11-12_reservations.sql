-- Réservations de cadeaux (« Offrir ») sur les envies d'une crèche.
-- À exécuter une fois dans Supabase (projet des santons) : SQL Editor > New query > Run.
-- Ré-exécutable. Nécessite 2026-11-11_quantites.sql (déjà fait).

-- ------------------------------------------------ réservations de cadeaux
-- « Offrir » : sur un santon de la liste d'envies, une grand-mère, une
-- marraine… note qu'elle l'offre, pour que personne n'achète le même.
-- Possible avec le lien de partage (sans compte) comme pour tout membre de
-- la famille. Annulable par qui a réservé (même navigateur, ou même compte)
-- et par les administrateurs de la crèche.
create table if not exists public.liste_reservations (
  liste_id uuid not null references public.listes (id) on delete cascade,
  santon_id integer not null check (santon_id > 0),
  nom text not null check (char_length(nom) between 1 and 40),
  reserve_par uuid references auth.users (id) on delete set null,
  jeton text,  -- empreinte du jeton secret du navigateur qui a réservé
  created_at timestamptz not null default now(),
  primary key (liste_id, santon_id)
);
alter table public.liste_reservations enable row level security;
drop policy if exists resa_lire on public.liste_reservations;
create policy resa_lire on public.liste_reservations for select to authenticated using (peut_voir_liste(liste_id));
revoke all on public.liste_reservations from anon, authenticated;
grant select (liste_id, santon_id, nom, reserve_par, created_at) on public.liste_reservations to authenticated;

-- la crèche visée : par le code du lien de partage, ou par son id pour qui la voit déjà
create or replace function public.liste_pour_reservation(p_liste uuid, p_code text) returns uuid
language sql stable security definer set search_path = public as $$
  select case
    when char_length(coalesce(p_code, '')) >= 16 then (select liste_id from liste_invitations where code = p_code)
    when auth.uid() is not null and peut_voir_liste(p_liste) then p_liste
  end;
$$;
revoke execute on function public.liste_pour_reservation(uuid, text) from public, anon, authenticated;

create or replace function public.reserver(p_liste uuid, p_code text, p_santon integer, p_nom text, p_jeton text)
returns void language plpgsql security definer set search_path = public as $$
declare l uuid := liste_pour_reservation(p_liste, p_code);
begin
  if l is null then raise exception 'crèche introuvable'; end if;
  if char_length(trim(coalesce(p_nom, ''))) not between 1 and 40 then raise exception 'prénom requis'; end if;
  if char_length(coalesce(p_jeton, '')) < 16 then raise exception 'jeton invalide'; end if;
  if not exists (select 1 from liste_items where liste_id = l and santon_id = p_santon and statut = 'wish') then
    raise exception 'pas dans les envies';
  end if;
  insert into liste_reservations (liste_id, santon_id, nom, reserve_par, jeton)
  values (l, p_santon, trim(p_nom), auth.uid(), md5(p_jeton))
  on conflict (liste_id, santon_id) do nothing;
  if not found then raise exception 'déjà réservé'; end if;
end $$;
revoke execute on function public.reserver(uuid, text, integer, text, text) from public;
grant execute on function public.reserver(uuid, text, integer, text, text) to anon, authenticated;

create or replace function public.annuler_reservation(p_liste uuid, p_code text, p_santon integer, p_jeton text)
returns void language plpgsql security definer set search_path = public as $$
declare l uuid := liste_pour_reservation(p_liste, p_code); n integer;
begin
  if l is null then raise exception 'crèche introuvable'; end if;
  delete from liste_reservations r
   where r.liste_id = l and r.santon_id = p_santon
     and (r.jeton = md5(coalesce(p_jeton, ''))
          or (auth.uid() is not null and (r.reserve_par = auth.uid() or peut_gerer_liste(l))));
  get diagnostics n = row_count;
  if n = 0 then raise exception 'réservation d''une autre personne'; end if;
end $$;
revoke execute on function public.annuler_reservation(uuid, text, integer, text) from public;
grant execute on function public.annuler_reservation(uuid, text, integer, text) to anon, authenticated;

-- un santon reçu (coché « J'ai ») ou retiré des envies libère sa réservation
create or replace function public.reservation_finie() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' or new.statut <> 'wish' then
    delete from liste_reservations where liste_id = old.liste_id and santon_id = old.santon_id;
  end if;
  return null;
end $$;
revoke execute on function public.reservation_finie() from public, anon;
drop trigger if exists reservation_finie on public.liste_items;
create trigger reservation_finie after delete or update of statut on public.liste_items
  for each row execute function public.reservation_finie();

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.liste_reservations;
    exception when duplicate_object then null;
    end;
  end if;
end $$;

-- page publique : les réservations en plus
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
