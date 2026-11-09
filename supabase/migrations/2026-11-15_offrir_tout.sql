-- « Offrir » : réserver aussi un santon qui n'est pas dans les envies.
-- À exécuter une fois dans Supabase (projet des santons) : SQL Editor > New query > Run.
-- Ré-exécutable. Nécessite 2026-11-12_reservations.sql (déjà fait).

-- Offrir n'importe quel santon que la crèche n'a pas encore (envie ou non)
create or replace function public.reserver(p_liste uuid, p_code text, p_santon integer, p_nom text, p_jeton text)
returns void language plpgsql security definer set search_path = public as $$
declare l uuid := liste_pour_reservation(p_liste, p_code);
begin
  if l is null then raise exception 'crèche introuvable'; end if;
  if char_length(trim(coalesce(p_nom, ''))) not between 1 and 40 then raise exception 'prénom requis'; end if;
  if char_length(coalesce(p_jeton, '')) < 16 then raise exception 'jeton invalide'; end if;
  if coalesce(p_santon, 0) <= 0 then raise exception 'santon inconnu'; end if;
  if exists (select 1 from liste_items where liste_id = l and santon_id = p_santon and statut = 'own') then
    raise exception 'déjà dans la crèche';
  end if;
  insert into liste_reservations (liste_id, santon_id, nom, reserve_par, jeton)
  values (l, p_santon, trim(p_nom), auth.uid(), md5(p_jeton))
  on conflict (liste_id, santon_id) do nothing;
  if not found then raise exception 'déjà réservé'; end if;
end $$;
revoke execute on function public.reserver(uuid, text, integer, text, text) from public;
grant execute on function public.reserver(uuid, text, integer, text, text) to anon, authenticated;

-- la réservation tombe quand le santon est coché « J'ai » (cadeau reçu), pas quand on retire une envie
create or replace function public.reservation_finie() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.statut = 'own' then
    delete from liste_reservations where liste_id = new.liste_id and santon_id = new.santon_id;
  end if;
  return null;
end $$;
revoke execute on function public.reservation_finie() from public, anon;
drop trigger if exists reservation_finie on public.liste_items;
create trigger reservation_finie after insert or update of statut on public.liste_items
  for each row execute function public.reservation_finie();
