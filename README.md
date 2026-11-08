# Santons Carbonel en famille

Le catalogue des santons Marcel Carbonel **N°2 (7 cm)** et **N°3 (9 cm)**,
des santons et bâtiments **Escoffier** (collection 7 cm), partagé
comme un petit réseau social familial :

- chaque **crèche** est une liste au nom de quelqu'un (« Crèche de Léa »,
  « Crèche de Tom », « Crèche de Mamie ») ;
- les **parents gèrent** les crèches de leurs enfants ou filleuls : on choisit
  pour chaque crèche qui peut cocher ;
- **tous les membres de la famille voient toutes les crèches**, avec le fil
  d'activité (« Maman a coché Berger appuyé · Crèche de Léa ») ;
- un **lien d'invitation** fait entrer quelqu'un dans la famille ;
- chaque crèche a son **lien public** : une page en lecture seule, **sans
  compte**, qui ne montre que cette crèche (pour un oncle, une marraine…).
  « Changer » le lien coupe l'ancien.

Dans chaque crèche : ✓ je l'ai (avec le nombre d'exemplaires dans la fiche :
2 moutons identiques…), ♡ envie, un **menu « Catalogue »** (chaque crèche choisit ses catalogues dans
ses réglages : N°2, N°3, Escoffier, artisans…), une grande **photo
de la crèche installée** (mise par ses gérants, en tête de la crèche, sur
l'accueil et sur la page publique), un bouton **Partager** qui envoie le lien de la crèche (lecture seule, sans
compte, envies comprises), un bouton **Offrir** sur les envies (une grand-mère, la marraine… note
qu'elle l'offre, même sans compte, pour que personne n'achète le même), et
**« + Santon inconnu »** pour créer un santon qu'on a devant les yeux mais
qu'on ne retrouve dans aucun catalogue (trop ancien…), pour les modèles qu'aucun catalogue ne montre (crèches commencées
il y a 30 ans) : nom, marque, note, et jusqu'à trois photos (face, dos,
côté), que tout membre de la famille peut compléter ou changer dans sa fiche. Le modèle entre
dans le catalogue de toute la famille, dans le bon onglet, sous « Ajoutés par
la famille », et se coche comme les autres. Les nouveautés de
l'année (rubrique « Nouveautés » des deux boutiques) portent un badge
« Nouveau 2026 » et ont leur filtre.

| Catalogue (menu) | Contenu | Nombre |
|---|---|---|
| Carbonel N°2 · Santons | Toute la gamme du catalogue papier N°2 Tradition 2024 (283 modèles, dont 20 absents de la boutique en ligne), la Colombe du dépliant N°2 de 2010, plus les autres santons N°2 au pied vert de la boutique | 303 |
| Escoffier 7 cm · Santons | Collection 7 cm (l'échelle des N°2 Carbonel), classés Nativité (17), Personnages (287) et Animaux (67, dont le flamant rose) d'après leur nom ; « Nouveau 2026 » pour les créations de la saison 2026-2027 | 371 |
| Escoffier 7 cm · Bâtiments | Collection 7 cm : maisons et bâtisses, façades, crèches et étables, puits, fontaines et ponts, roulottes et charrettes (76) ; accessoires : murs, escaliers, rivières, quais, pointus, champs… (53) ; arbres et buissons rangés par Escoffier dans les accessoires (24) | 153 |
| Carbonel N°2 · Bâtiments et décors | Bâtiments et accessoires N°2 | 82 |
| Carbonel N°3 · Santons et bâtiments | Tous les modèles N°3 (9 cm) de la boutique à l'unité, quel que soit le socle : santons, animaux, bâtiments, accessoires (sans coffrets ni pièces détachées) ; 7 anciens modèles relevés dans le catalogue N°3 2024 et le dépliant N°3 de 2009 (Mireille à la cruche orange, Femme sur l'âne, Femme à la chèvre marron et grise, Ange bleu et rose, Chameau couché tapis jaune) ; plus les 16 accessoires « N°2 & N°3 » (fleurs, lavande) | 211 + 16 |
| Artisans sans marques | Ce que la famille ajoute elle-même | — |

Par défaut une crèche montre tout sauf Carbonel N°3 ; ses administrateurs
cochent ses catalogues dans **Réglages** (ou à sa création).

## Mise en route (une fois, environ 15 minutes)

### 1. La base de données : Supabase (gratuit)

1. Créer un compte sur [supabase.com](https://supabase.com), puis **New project**
   (région conseillée : Paris, `eu-west-3`).
2. **SQL Editor** > **New query** : coller tout le fichier
   [`supabase/schema.sql`](supabase/schema.sql), puis **Run**.
3. **Authentication** > **Sign In / Providers** > **Email** : désactiver
   **Confirm email**. Sinon chaque inscription attend un e-mail de
   confirmation, et l'envoi d'e-mails du plan gratuit est très limité.
4. **Authentication** > **URL Configuration** : mettre l'adresse du site
   (`https://alban4-dev.github.io/santons-carbonel/`) dans **Site URL** et dans
   **Redirect URLs**. C'est ce qui permet
   au lien « Mot de passe oublié » de revenir sur le site.
5. **Project Settings** > **API** : copier **Project URL** et la clé
   **anon public** dans [`config.js`](config.js), puis relancer `python3 build.py`.
   Cette clé est faite pour être publique : ce sont les règles de la base qui
   protègent les données.

Un projet gratuit se met en pause après une semaine sans visite. On le relance
d'un clic depuis le tableau de bord Supabase, les données sont conservées.

### Mises à jour de la base

Une base déjà installée reçoit les nouveautés par les fichiers de
[`supabase/migrations/`](supabase/migrations), à exécuter une fois chacun dans
le SQL Editor (`schema.sql` les contient déjà pour une nouvelle installation) :

- `2026-11-08b_santons_ajoutes.sql` : santons ajoutés par la famille, espace
  « photos » pour leurs photos, et page publique d'une crèche (contient aussi
  `2026-11-08_page_publique.sql`, qu'il n'est donc pas utile de lancer) ;
- `2026-11-10_photos_santons.sql` : photo de la crèche installée, et trois
  photos par santon ajouté (contient aussi `2026-11-09_photo_creche.sql`) ;
- `2026-11-11_quantites.sql` : nombre d'exemplaires d'un santon (2 moutons…) ;
- `2026-11-12_reservations.sql` : réservations « Offrir » sur les envies ;
- `2026-11-13_catalogues.sql` : catalogues de chaque crèche, santons inconnus en N°3.

### 2. Le site : GitHub Pages

Le site est publié automatiquement depuis ce dépôt :
**https://alban4-dev.github.io/santons-carbonel/**

- Une seule fois : **Settings** > **Pages** > **Build and deployment** >
  **Source** : « GitHub Actions ».
- Ensuite, chaque modification de `main` republie le dossier [`site/`](site)
  (`index.html`, `config.js`, `sprites/`), via
  [`.github/workflows/pages.yml`](.github/workflows/pages.yml).

Le dossier `site/` peut aussi être déposé tel quel sur un autre hébergeur
statique (par exemple Netlify Drop).

### 3. Premiers pas

1. Ouvrir le site, **Créer un compte** (prénom, e-mail, mot de passe), puis
   **Créer la famille**.
2. **Inviter dans la famille** copie le lien à envoyer (WhatsApp, SMS…). Chacun
   crée son compte en l'ouvrant et devient membre.
3. **+ Nouvelle crèche** : « Crèche de Léa ». Dans la crèche, **Réglages** :
   cocher l'autre parent parmi les **administrateurs de la crèche**.
   **Partager** envoie le lien de la crèche à un proche qui doit seulement
   regarder (il n'a pas de compte à créer).

**Onglet « Artisans »** (« Artisans sans marques ») : les santons et
bâtiments d'artisans sans marque (achetés sur un marché…), créés par la
famille avec la marque « Artisan, sans marque », rangés en « Santons » et
« Bâtiments et décors », à part des gammes Carbonel et Escoffier.

**Les ajouts restent dans leur famille** : un santon créé dans une famille
(santon inconnu, sans marque) n'est visible que de ses membres, et seulement
dans ses crèches ; quelqu'un qui est dans deux familles ne voit, dans chaque
crèche, que les ajouts de la famille de cette crèche (vérifié par la base et
par `familles.js`).

**Plusieurs familles** : « + Créer une autre famille » en bas de l'accueil
(côté du conjoint, côté de ses parents…) ; quand on est dans plusieurs
familles, un menu « Famille » en haut de l'accueil choisit celle qu'on voit
(le téléphone s'en souvient). Chaque famille a ses crèches, ses
membres et son lien d'invitation ; une même personne peut être dans
plusieurs familles et les voit toutes, les autres ne voient que la leur.
L'admin d'une famille peut la renommer.

## Qui peut faire quoi

| | Voir les crèches | Cocher | Réglages d'une crèche | Inviter |
|---|---|---|---|---|
| Membre | toutes celles de la famille | celles dont il est administrateur | celles dont il est administrateur | lien de la famille |
| Admin de la famille (le créateur) | toutes | celles dont il est administrateur | toutes, et retirer un membre | lien de la famille |
| Personne avec le lien public d'une crèche (sans compte) | cette crèche seulement | non | non | non |

**Offrir** : toute personne qui voit une crèche (membre de la famille ou lien
de partage, sans compte) peut réserver un santon de ses envies en notant son
prénom ; un administrateur peut aussi la noter pour quelqu'un. La réservation s'annule par la personne qui l'a faite (même téléphone
ou même compte) ou par un administrateur de la crèche, et disparaît quand le
santon est coché « J'ai ».

Ces règles sont vérifiées par la base de données elle-même (Row Level Security
dans `schema.sql`), pas seulement par l'affichage. Sans compte, la seule chose
accessible est la fonction `voir_liste`, qui renvoie une crèche (nom, prénoms
des gérants, coches) à qui fournit son code de visite, et rien d'autre : ni la
famille, ni son code d'adhésion, ni les autres crèches. Un membre qui quitte la famille perd aussitôt
ses droits.

## Tests

`supabase/tests/lancer.sh` rejoue tout sans compte Supabase, sur un
PostgreSQL 16 local :

- `droits.sql` : 73 vérifications des règles d'accès (inconnu, membre, gérant,
  visiteur, ancien membre, anonyme, page publique, santons ajoutés, photos
  photo de la crèche, photos face, dos, côté, quantités et réservations) ;
- `parcours.js` : dans un vrai navigateur, Papa crée la famille et la crèche
  de Léa, coche, met la photo de la crèche ; Maman arrive par le lien d'invitation, est
  en lecture seule, puis devient gérante ; Mamie ouvre le lien public sans
  compte et ne voit que la crèche de Léa ; après « Changer », l'ancien lien
  ne marche plus ;
- `familles.js` : une personne dans deux familles, chacun ne voit que les siennes,
  et les santons ajoutés restent dans leur famille ;
- `ajout.js` : Papa ajoute un santon ancien avec sa photo, coché dans la
  crèche, puis ajoute le dos et change la face ; Maman ajoute le côté ; Maman le voit dans le catalogue, la page publique l'affiche ; Papa
  le retire et il disparaît de toutes les crèches.

`faux_supabase.py` imite les routes de Supabase utilisées par l'appli et
exécute chaque requête avec l'identité de l'utilisateur, donc avec les vraies
règles. `auth_factice.sql` crée le schéma `auth` minimal. Le temps réel n'est
pas couvert ; le stockage des photos est imité (dépôt soumis aux mêmes règles,
fichiers sur le disque).

## Le catalogue

- **Boutique** : [marcelcarbonel.com](https://marcelcarbonel.com), relevée en
  entier (1 321 références) par `scraper/scrape.py`.
- **Catalogue N°2 Tradition 2024** (le PDF de marcelcarbonel.com/catalogue) :
  `scraper/catalogue_n2.py` lit les 283 modèles du catalogue (variantes de
  couleur comprises) et retrouve chacun dans la boutique ou parmi les anciens
  modèles → `data/catalogue_n2_2024.json`. **Toute cette gamme est dans
  l'appli**, quel que soit le socle (Provinces de France, Marins, Catalans…) ;
  `build.py` refuse de construire le site s'il en manque un.
- **Anciens modèles** : 21 santons des catalogues papier absents de la
  boutique (Mireille, Ravi coupé, Bastidanes, Pont-Aven, Fileuse au rouet… et
  la Colombe du dépliant N°2 de 2010, dont la photo ne fait que 36 × 18 pixels),
  photos découpées dans les PDF par `scraper/anciens.py`.
- **Anciens N°3** : catalogues N°3 Tradition 2023 et 2024 (marcelcarbonel.com) et
  dépliant N°3 de 2009 (chez un revendeur), comparés à la boutique nom par nom
  puis photo par photo ; aucun catalogue N°3 plus ancien n'est en ligne. Pour
  les couleurs annoncées sans photo, la fiche le précise (« photo de l'ange
  blanc »).
- **Autres catalogues vérifiés** : N°2 Tradition 2023 (site Carbonel), liste
  N°2 « Crèche 2022 » (publiée par une paroisse) et dépliant N°2 de 2010 : tous
  leurs modèles sont dans l'appli. Aucun catalogue plus ancien n'est en ligne ;
  les modèles d'il y a 30 ans se créent avec « + Santon inconnu ».
- **Pied vert** : en plus du catalogue, les santons N°2 de la boutique au socle
  peint en vert (lu sur chaque photo par `scraper/socle.py`), et ceux sans socle
  (Jésus et le Berceau dans leur paille, Canard nageant, Cigogne :
  `SANS_SOCLE` dans `scraper/selection.py`). Restent écartés, hors catalogue et
  au socle d'une autre couleur : la Bonne Mère, les Confrères, le Comte de
  Monte-Cristo, le Carabinier de Monaco.
- **Bâtiments Escoffier** : [escoffier.fr](https://www.escoffier.fr), rubrique
  « Décors de crèche », relevée par `scraper/escoffier.py` (173 décors). Sont
  retenus les bâtiments et les accessoires de la collection 7 cm, l'échelle des
  santons N°2, et ceux sans gamme indiquée (moulins, églises, phare…). Les
  autres tailles (2, 5, 9 cm) et les arbres absents de la rubrique
  « Accessoires » sont écartés.
- **Santons Escoffier** : la « Collection 7 cm » d'escoffier.fr (371 santons
  peints ; la version « brut » n'est pas retenue), relevée par
  `scraper/escoffier.py` avec l'année de création de chaque modèle (filtre du
  site). Le site ne les classe pas : Nativité / Animaux / Personnages est
  déduit du nom dans `scraper/selection.py`.
- **Sélection** : `scraper/selection.py` (gamme du catalogue N°2 et N°2 pied vert, à l'unité ; bâtiments
  et accessoires Carbonel N°2 ; bâtiments et accessoires Escoffier 7 cm ; ni coffrets, ni
  lots, ni Pastel).

Pour le mettre à jour :

```sh
cd scraper
python3 scrape.py          # relève la boutique -> data/santons.json
python3 anciens.py         # anciens N°2 du catalogue PDF (pdfplumber)
python3 catalogue_n2.py    # liste de la gamme du catalogue N°2 Tradition
python3 escoffier.py       # bâtiments, accessoires et santons 7 cm Escoffier -> data/escoffier.json
python3 build_sprites.py   # vignettes, pied, sélection -> site/sprites/ (Pillow)
cd .. && python3 build.py  # site/index.html
```

Les identifiants sont ceux des boutiques (5001 et plus pour les anciens
modèles Carbonel, 100000 + l'identifiant Escoffier pour Escoffier), donc les
coches restent valables après une mise à jour.

## Fichiers

| Chemin | Rôle |
|---|---|
| `site/` | Le site à publier (généré) |
| `config.js` | Adresse et clé publique Supabase |
| `src/app.html` | Le code de l'application |
| `supabase/schema.sql` | Tables, règles d'accès, fonctions d'invitation |
| `supabase/tests/` | Tests des droits et du parcours |
| `data/` | Les catalogues relevés (Carbonel, anciens modèles, Escoffier) |
| `scraper/` | Relevé, couleur du pied, anciens modèles, vignettes |

GitHub ne contenait aucun outil de collection de santons ni de catalogue
Carbonel (recherche de novembre 2026). Les seuls dépôts proches,
[Oufti2015/santons](https://github.com/Oufti2015/santons) et
[karim1407/santonniers](https://github.com/karim1407/santonniers), ne
correspondent pas à ce besoin.

Photos et noms © Ateliers Marcel Carbonel et Santons Escoffier. Usage familial et privé.
