\set ON_ERROR_STOP 0
\set VERBOSITY terse
\pset tuples_only on
\pset format unaligned
\set papa  '00000000-0000-0000-0000-00000000000a'
\set maman '00000000-0000-0000-0000-00000000000b'
\set mamie '00000000-0000-0000-0000-00000000000c'
\set inconnu '00000000-0000-0000-0000-00000000000d'
insert into auth.users values (:'papa','p'),(:'maman','m'),(:'mamie','mm'),(:'inconnu','i');

-- PAPA : crée la famille, deux listes, coche
select set_config('request.jwt.claim.sub', :'papa', false); set role authenticated;
insert into profils values (:'papa','Papa');
select 'T01 famille créée', creer_famille('Famille Dupont') is not null;
select 'T02 liste Léa', creer_liste((select id from familles), 'Crèche de Léa') is not null;
select 'T03 liste Tom', creer_liste((select id from familles), 'Crèche de Tom') is not null;
insert into liste_items (liste_id, santon_id, statut) select id, 544, 'own' from listes where nom='Crèche de Léa';
select 'T04 papa coche', count(*) = 1 from liste_items;
select 'T05 auteur horodaté', modifie_par = :'papa' from liste_items;
reset role;
select code as fcode from famille_invitations \gset
select l.id as lea, i.code as vcode from listes l join liste_invitations i on i.liste_id = l.id where l.nom = 'Crèche de Léa' \gset
select id as tom from listes where nom = 'Crèche de Tom' \gset

-- INCONNU : ne voit rien, ne peut rien faire
select set_config('request.jwt.claim.sub', :'inconnu', false); set role authenticated;
select 'T10 inconnu: 0 famille', count(*) = 0 from familles;
select 'T11 inconnu: 0 liste', count(*) = 0 from listes;
select 'T12 inconnu: 0 coche', count(*) = 0 from liste_items;
select 'T13 inconnu: 0 profil', count(*) = 0 from profils;
insert into liste_items (liste_id, santon_id, statut) values (:'lea', 1, 'own');
select 'T14 inconnu: creer_liste refusé';
select creer_liste((select :'lea'::uuid), 'x');
reset role;
select 'T15 rien écrit par inconnu', count(*) = 1 from liste_items;

-- MAMAN : rejoint par le lien, voit tout, ne coche pas encore (pas gérante)
select set_config('request.jwt.claim.sub', :'maman', false); set role authenticated;
insert into profils values (:'maman','Maman');
select 'T20 maman rejoint', rejoindre_famille(:'fcode') is not null;
select 'T21 maman voit 2 listes', count(*) = 2 from listes;
select 'T22 maman voit coches', count(*) = 1 from liste_items;
select 'T23 maman voit 2 prénoms', count(*) = 2 from profils;
insert into liste_items (liste_id, santon_id, statut) values (:'lea', 2, 'own');
select 'T24 maman ne voit pas le code visiteur', count(*) = 0 from liste_invitations;
reset role;
select 'T25 maman n''a pas coché', count(*) = 1 from liste_items;

-- PAPA ajoute Maman comme gérante de Léa
select set_config('request.jwt.claim.sub', :'papa', false); set role authenticated;
insert into liste_gerants values (:'lea', :'maman');
select 'T30 papa ajoute maman gérante', count(*) = 2 from liste_gerants where liste_id = :'lea';
insert into liste_gerants values (:'lea', :'mamie');
reset role;
select 'T31 mamie (pas membre) ne peut pas être gérante', count(*) = 2 from liste_gerants where liste_id = :'lea';

select set_config('request.jwt.claim.sub', :'maman', false); set role authenticated;
insert into liste_items (liste_id, santon_id, statut) values (:'lea', 2, 'wish');
update liste_items set statut = 'own' where liste_id = :'lea' and santon_id = 2;
select 'T32 maman coche Léa', count(*) = 2 from liste_items where liste_id = :'lea';
insert into liste_items (liste_id, santon_id, statut) values (:'tom', 3, 'own');
reset role;
select 'T33 maman ne coche pas Tom', count(*) = 0 from liste_items where liste_id = :'tom';

-- MAMIE : visiteuse de Léa seulement
select set_config('request.jwt.claim.sub', :'mamie', false); set role authenticated;
insert into profils values (:'mamie','Mamie');
select 'T40 mamie devient visiteuse', devenir_visiteur(:'vcode') = :'lea';
select 'T41 mamie voit 1 liste (Léa)', count(*) = 1 and min(nom) = 'Crèche de Léa' from listes;
select 'T42 mamie voit les coches de Léa', count(*) = 2 from liste_items;
select 'T43 mamie voit la famille', count(*) = 1 from familles;
select 'T44 mamie voit les prénoms', count(*) = 3 from profils;
select 'T45 mamie ne voit pas le code de la famille', count(*) = 0 from famille_invitations;
select 'T47 mamie ne peut pas rejoindre sans code', count(*) = 0 from membres where user_id = :'mamie';
insert into liste_items (liste_id, santon_id, statut) values (:'lea', 9, 'own');
delete from liste_items where liste_id = :'lea';
update listes set nom = 'piraté';
reset role;
select 'T46 mamie n''a rien modifié', (select count(*) from liste_items where liste_id = :'lea') = 2 and (select count(*) from listes where nom='piraté') = 0;

-- PAPA voit la visiteuse et la retire, change le code
select set_config('request.jwt.claim.sub', :'papa', false); set role authenticated;
select 'T50 papa voit 1 visiteur', count(*) = 1 from liste_visiteurs;
select 'T51 nouveau code', nouveau_code_visite(:'lea') <> :'vcode';
delete from liste_visiteurs where user_id = :'mamie';
reset role;
select set_config('request.jwt.claim.sub', :'mamie', false); set role authenticated;
select 'T52 mamie ne voit plus rien', count(*) = 0 from listes;
select 'T53 ancien code refusé';
select devenir_visiteur(:'vcode');
reset role;

-- MAMAN quitte : plus de droits
select set_config('request.jwt.claim.sub', :'maman', false); set role authenticated;
delete from membres where user_id = :'maman';
insert into liste_items (liste_id, santon_id, statut) values (:'lea', 7, 'own');
select 'T60 maman partie ne voit plus', count(*) = 0 from listes;
reset role;
select 'T61 maman partie n''écrit plus', count(*) = 2 from liste_items where liste_id = :'lea';

-- anon : rien
set role anon;
select 'T70 anon bloqué';
select count(*) from listes;
reset role;

-- PAGE PUBLIQUE : le lien de visite marche sans compte, et rien d'autre
select code as vcode2 from liste_invitations where liste_id = :'lea' \gset
set role anon;
select 'T71 sans compte : la crèche par son lien', (voir_liste(:'vcode2')->>'nom') = 'Crèche de Léa';
select 'T72 sans compte : ses coches', json_array_length(voir_liste(:'vcode2')->'items') = 2;
select 'T73 sans compte : prénoms des gérants', json_array_length(voir_liste(:'vcode2')->'gerants') = 1;
select 'T74 ancien lien (changé) refusé', voir_liste(:'vcode') is null;
select 'T75 code inventé refusé', voir_liste('0123456789abcdef0123456789abcdef') is null;
select 'T76 code trop court refusé', voir_liste('') is null;
reset role;
set role anon;
select 'T77 sans compte : toujours pas de tables';
select count(*) from liste_items;
reset role;

-- SANTONS AJOUTÉS PAR LA FAMILLE (+ photos)
select id as fam from familles \gset
select set_config('request.jwt.claim.sub', :'papa', false); set role authenticated;
insert into modeles_famille (famille_id, nom, photo) values (:'fam', 'Berger ancien 1995', :'fam' || '/berger.jpg');
select 'T80 papa ajoute un santon ancien', count(*) = 1 and min(id) >= 1000000 from modeles_famille;
insert into liste_items (liste_id, santon_id, statut) select :'lea', id, 'own' from modeles_famille;
select 'T81 papa le coche dans Léa', count(*) = 1 from liste_items where santon_id >= 1000000;
insert into storage.objects (bucket_id, name) values ('photos', :'fam' || '/berger.jpg');
reset role;  -- (un membre dépose mais ne liste pas le stockage : on compte en administrateur)
select 'T82 papa dépose la photo dans le dossier de sa famille', count(*) = 1 from storage.objects;
set role authenticated;
insert into storage.objects (bucket_id, name) values ('photos', 'pas-une-famille/x.jpg');
insert into storage.objects (bucket_id, name) values ('photos', '00000000-0000-0000-0000-000000000099/x.jpg');
reset role;
select 'T83 photo refusée hors du dossier de la famille', count(*) = 1 from storage.objects;
select set_config('request.jwt.claim.sub', :'inconnu', false); set role authenticated;
select 'T84 inconnu : ne voit pas les santons ajoutés', count(*) = 0 from modeles_famille;
insert into modeles_famille (famille_id, nom) values (:'fam', 'intrus');
insert into storage.objects (bucket_id, name) values ('photos', :'fam' || '/intrus.jpg');
update modeles_famille set nom = 'piraté';
delete from modeles_famille;
reset role;
select 'T85 inconnu : ni ajout, ni photo, ni modification', (select count(*) from modeles_famille) = 1
  and (select count(*) from storage.objects) = 1 and (select min(nom) from modeles_famille) = 'Berger ancien 1995';
set role anon;
select 'T86 page publique : le santon ajouté et sa photo', (voir_liste(:'vcode2')->'modeles'->0->>'nom') = 'Berger ancien 1995'
  and (voir_liste(:'vcode2')->'modeles'->0->>'photo') like '%/berger.jpg';
reset role;
select set_config('request.jwt.claim.sub', :'papa', false); set role authenticated;
delete from modeles_famille;
reset role;
select 'T87 retiré du catalogue : décoché partout', (select count(*) from liste_items where santon_id >= 1000000) = 0;

-- PHOTO DE LA CRÈCHE INSTALLÉE
insert into membres (famille_id, user_id) values (:'fam', :'maman');  -- Maman revient dans la famille
select set_config('request.jwt.claim.sub', :'papa', false); set role authenticated;
update listes set photo = :'fam' || '/creche-lea.jpg' where id = :'lea';
reset role;
select 'T90 papa (gérant) met la photo de Léa', photo like '%/creche-lea.jpg' from listes where id = :'lea';
select set_config('request.jwt.claim.sub', :'maman', false); set role authenticated;
update listes set photo = 'x/y.jpg' where id = :'tom';
select 'T91 maman voit la photo de Léa', photo like '%/creche-lea.jpg' from listes where id = :'lea';
reset role;
select 'T92 maman (pas gérante de Tom) ne change pas sa photo', photo is null from listes where id = :'tom';
select set_config('request.jwt.claim.sub', :'inconnu', false); set role authenticated;
update listes set photo = null;
reset role;
select 'T93 inconnu ne retire pas la photo', photo is not null from listes where id = :'lea';
set role anon;
select 'T94 page publique : la photo de la crèche', (voir_liste(:'vcode2')->>'photo') like '%/creche-lea.jpg';
reset role;

-- PHOTOS D'UN SANTON AJOUTÉ (face, dos, côté)
select set_config('request.jwt.claim.sub', :'papa', false); set role authenticated;
insert into modeles_famille (famille_id, nom, photo, photos)
  values (:'fam', 'Chasseur a la pipe', :'fam' || '/face.jpg', array[:'fam' || '/face.jpg', null, null]);
reset role;
select id as chasseur from modeles_famille where nom = 'Chasseur a la pipe' \gset
select set_config('request.jwt.claim.sub', :'maman', false); set role authenticated;
update modeles_famille set photos = array[:'fam' || '/face.jpg', :'fam' || '/dos.jpg', null] where id = :chasseur;
update modeles_famille set ajoute_par = :'maman' where id = :chasseur;
update modeles_famille set photos = array['a', 'b', 'c', 'd'] where id = :chasseur;
reset role;
select 'T95 maman (membre) ajoute la photo de dos', photos[2] like '%/dos.jpg' and cardinality(photos) = 3 from modeles_famille where id = :chasseur;
select 'T96 maman ne devient pas autrice du modele', ajoute_par = :'papa' from modeles_famille where id = :chasseur;
select set_config('request.jwt.claim.sub', :'inconnu', false); set role authenticated;
update modeles_famille set photos = null, photo = null;
reset role;
select 'T97 inconnu ne touche pas aux photos', photos[2] is not null and photo is not null from modeles_famille where id = :chasseur;
select set_config('request.jwt.claim.sub', :'papa', false); set role authenticated;
insert into liste_items (liste_id, santon_id, statut) values (:'lea', :chasseur, 'own');
reset role;
set role anon;
select 'T98 page publique : face et dos', (voir_liste(:'vcode2')->'modeles'->0->'photos'->>1) like '%/dos.jpg';
reset role;

-- QUANTITÉS (2 moutons identiques…)
select set_config('request.jwt.claim.sub', :'papa', false); set role authenticated;
update liste_items set quantite = 3 where liste_id = :'lea' and santon_id = 544;
update liste_items set quantite = 0 where liste_id = :'lea' and santon_id = 544;
update liste_items set quantite = 100 where liste_id = :'lea' and santon_id = 544;
reset role;
select 'T100 papa (gerant) en met 3, ni 0 ni 100', quantite = 3 from liste_items where liste_id = :'lea' and santon_id = 544;
select 'T101 nouvelle coche : 1 par defaut', bool_and(quantite = 1) from liste_items where santon_id <> 544;
select set_config('request.jwt.claim.sub', :'inconnu', false); set role authenticated;
update liste_items set quantite = 9;
reset role;
select 'T102 inconnu ne change pas la quantite', quantite = 3 from liste_items where liste_id = :'lea' and santon_id = 544;
set role anon;
select 'T103 page publique : la quantite', (select (x->>'quantite')::int from json_array_elements(voir_liste(:'vcode2')->'items') x where (x->>'santon_id')::int = 544) = 3;
reset role;

-- RÉSERVATIONS « OFFRIR »
insert into liste_items (liste_id, santon_id, statut) values (:'lea', 700, 'wish'), (:'lea', 701, 'wish'), (:'lea', 702, 'wish');
select set_config('request.jwt.claim.sub', '', false);  -- vraiment sans compte
set role anon;
select reserver(null, :'vcode2', 700, 'Mamie', 'jeton-de-mamie-0001');
reset role;
select 'T110 sans compte : Mamie reserve par le lien', nom = 'Mamie' and reserve_par is null from liste_reservations where santon_id = 700;
set role anon;
select reserver(null, :'vcode2', 700, 'Marraine', 'jeton-de-marraine-01');
select reserver(null, :'vcode2', 544, 'Marraine', 'jeton-de-marraine-01');
select reserver(null, '0123456789abcdef0123456789abcdef', 701, 'Pirate', 'jeton-du-pirate-0001');
select reserver(:'lea', null, 701, 'Pirate', 'jeton-du-pirate-0001');
select annuler_reservation(null, :'vcode2', 700, 'jeton-de-marraine-01');
reset role;
select 'T111 deja reserve, pas une envie, mauvais lien, sans lien, mauvais jeton : refuses',
  (select count(*) from liste_reservations) = 1 and (select nom from liste_reservations where santon_id = 700) = 'Mamie';
set role anon;
select 'T112 page publique : la reservation (sans jeton)', (voir_liste(:'vcode2')->'reservations'->0->>'nom') = 'Mamie'
  and (voir_liste(:'vcode2')->'reservations'->0->>'jeton') is null;
select annuler_reservation(null, :'vcode2', 700, 'jeton-de-mamie-0001');
reset role;
select 'T113 Mamie annule avec son jeton', count(*) = 0 from liste_reservations;
select set_config('request.jwt.claim.sub', :'maman', false); set role authenticated;
select reserver(:'lea', null, 701, 'Maman', 'jeton-de-maman-00001');
select 'T114 maman (membre, lecture) voit la reservation', count(*) = 1 from liste_reservations where santon_id = 701;
select jeton from liste_reservations;
reset role;
select 'T115 maman reserve depuis son compte', reserve_par = :'maman' from liste_reservations where santon_id = 701;
select set_config('request.jwt.claim.sub', :'inconnu', false); set role authenticated;
select reserver(:'lea', null, 702, 'Inconnu', 'jeton-inconnu-000001');
select annuler_reservation(:'lea', null, 701, 'jeton-inconnu-000001');
reset role;
select 'T116 inconnu : ni reserver ni annuler', count(*) = 1 from liste_reservations;
select set_config('request.jwt.claim.sub', :'papa', false); set role authenticated;
select annuler_reservation(:'lea', null, 701, 'autre-jeton-000000001');
reset role;
select 'T117 papa (administrateur) annule celle de maman', count(*) = 0 from liste_reservations;
set role anon;
select reserver(null, :'vcode2', 702, 'Mamie', 'jeton-de-mamie-0001');
reset role;
select set_config('request.jwt.claim.sub', :'papa', false); set role authenticated;
update liste_items set statut = 'own' where liste_id = :'lea' and santon_id = 702;
reset role;
select 'T118 cadeau recu (coche J''ai) : reservation liberee', count(*) = 0 from liste_reservations;

-- CATALOGUES D'UNE CRÈCHE
select set_config('request.jwt.claim.sub', :'papa', false); set role authenticated;
update listes set catalogues = array['santons_n3', 'autres'] where id = :'lea';
update listes set catalogues = array['santons', 'inconnu'] where id = :'lea';
update listes set catalogues = array[]::text[] where id = :'lea';
reset role;
select 'T120 papa choisit N°3 + artisans ; catalogue inconnu ou vide refuse', array_to_string(catalogues, ',') = 'santons_n3,autres' from listes where id = :'lea';
select set_config('request.jwt.claim.sub', :'inconnu', false); set role authenticated;
update listes set catalogues = array['santons'];
reset role;
select 'T121 inconnu ne change pas les catalogues', array_to_string(catalogues, ',') = 'santons_n3,autres' from listes where id = :'lea';
select set_config('request.jwt.claim.sub', '', false); set role anon;
select 'T122 page publique : les catalogues', (voir_liste(:'vcode2')->'catalogues'->>0) = 'santons_n3';
reset role;
select set_config('request.jwt.claim.sub', :'papa', false); set role authenticated;
insert into modeles_famille (famille_id, nom, section) values (:'fam', 'Berger N3 inconnu', 'santons_n3');
reset role;
select 'T123 santon inconnu en N°3', count(*) = 1 from modeles_famille where section = 'santons_n3';
