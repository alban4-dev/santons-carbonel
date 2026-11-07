# Santons Carbonel en famille

Le catalogue des santons Marcel Carbonel **N°2 (7 cm)** et des bâtiments
**Escoffier** (collection 7 cm), partagé
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

Dans chaque crèche : ✓ je l'ai, ♡ envie, trois onglets, photo de la crèche
pour pointer, liste d'envies à copier pour les cadeaux, et **« + Santon
ancien »** pour les modèles qu'aucun catalogue ne montre (crèches commencées
il y a 30 ans) : nom, marque, note, photo prise au téléphone. Le modèle entre
dans le catalogue de toute la famille, dans le bon onglet, sous « Ajoutés par
la famille », et se coche comme les autres. Les nouveautés de
l'année (rubrique « Nouveautés » des deux boutiques) portent un badge
« Nouveau 2026 » et ont leur filtre.

| Onglet | Contenu | Nombre |
|---|---|---|
| Santons Carbonel | Toute la gamme du catalogue papier N°2 Tradition 2024 (283 modèles, dont 20 absents de la boutique en ligne), plus les autres santons N°2 au pied vert de la boutique | 302 |
| Escoffier | Collection 7 cm : maisons et bâtisses, façades, crèches et étables, puits, fontaines et ponts, roulottes et charrettes (76) ; accessoires : murs, escaliers, rivières, quais, pointus, champs… (53) ; arbres et buissons rangés par Escoffier dans les accessoires (24) | 153 |
| Décors Carbonel | Bâtiments et accessoires N°2 | 82 |

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
  `2026-11-08_page_publique.sql`, qu'il n'est donc pas utile de lancer).

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

### 3. Optionnel : la reconnaissance des santons sur photo

Sans elle, « Photo de la crèche » garde la photo à l'écran pour cocher à la
main. Avec elle, Claude repère sur la photo les modèles du catalogue et propose
de les cocher (on valide avant).

1. Créer une clé API sur [console.anthropic.com](https://console.anthropic.com)
   (payant à l'usage : quelques centimes par photo).
2. Supabase > **Edge Functions** > **Deploy a new function** > via l'éditeur,
   nom `reconnaitre`, coller
   [`supabase/functions/reconnaitre/index.ts`](supabase/functions/reconnaitre/index.ts).
   Ou en ligne de commande : `supabase functions deploy reconnaitre`.
3. Edge Functions > **Secrets** : ajouter `ANTHROPIC_API_KEY`.
4. Dans `config.js`, mettre `reconnaissance: true`, puis `python3 build.py`
   et republier `site/`.

La fonction n'accepte que les membres connectés d'une famille, pour que la clé
ne serve qu'à vous.

### 4. Premiers pas

1. Ouvrir le site, **Créer un compte** (prénom, e-mail, mot de passe), puis
   **Créer la famille**.
2. **Inviter dans la famille** copie le lien à envoyer (WhatsApp, SMS…). Chacun
   crée son compte en l'ouvrant et devient membre.
3. **+ Nouvelle crèche** : « Crèche de Léa ». Dans la crèche, **Réglages** :
   cocher l'autre parent comme gérant, copier le **lien public** pour un
   proche qui doit seulement regarder (il n'a pas de compte à créer).

## Qui peut faire quoi

| | Voir les crèches | Cocher | Réglages d'une crèche | Inviter |
|---|---|---|---|---|
| Membre | toutes celles de la famille | celles dont il est gérant | celles dont il est gérant | lien de la famille |
| Admin de la famille (le créateur) | toutes | celles dont il est gérant | toutes, et retirer un membre | lien de la famille |
| Personne avec le lien public d'une crèche (sans compte) | cette crèche seulement | non | non | non |

Ces règles sont vérifiées par la base de données elle-même (Row Level Security
dans `schema.sql`), pas seulement par l'affichage. Sans compte, la seule chose
accessible est la fonction `voir_liste`, qui renvoie une crèche (nom, prénoms
des gérants, coches) à qui fournit son code de visite, et rien d'autre : ni la
famille, ni son code d'adhésion, ni les autres crèches. Un membre qui quitte la famille perd aussitôt
ses droits.

## Tests

`supabase/tests/lancer.sh` rejoue tout sans compte Supabase, sur un
PostgreSQL 16 local :

- `droits.sql` : 47 vérifications des règles d'accès (inconnu, membre, gérant,
  visiteur, ancien membre, anonyme, page publique, santons ajoutés et photos) ;
- `parcours.js` : dans un vrai navigateur, Papa crée la famille et la crèche
  de Léa, coche, utilise la photo ; Maman arrive par le lien d'invitation, est
  en lecture seule, puis devient gérante ; Mamie ouvre le lien public sans
  compte et ne voit que la crèche de Léa ; après « Changer », l'ancien lien
  ne marche plus ;
- `ajout.js` : Papa ajoute un santon ancien avec sa photo, coché dans la
  crèche ; Maman le voit dans le catalogue, la page publique l'affiche ; Papa
  le retire et il disparaît de toutes les crèches.

`faux_supabase.py` imite les routes de Supabase utilisées par l'appli et
exécute chaque requête avec l'identité de l'utilisateur, donc avec les vraies
règles. `auth_factice.sql` crée le schéma `auth` minimal. Le temps réel et
l'appel à Claude ne sont pas couverts ; le stockage des photos est imité
(dépôt soumis aux mêmes règles, fichiers sur le disque) : la fonction de reconnaissance est
remplacée par une réponse fixe.

## Le catalogue

- **Boutique** : [marcelcarbonel.com](https://marcelcarbonel.com), relevée en
  entier (1 321 références) par `scraper/scrape.py`.
- **Catalogue N°2 Tradition 2024** (le PDF de marcelcarbonel.com/catalogue) :
  `scraper/catalogue_n2.py` lit les 283 modèles du catalogue (variantes de
  couleur comprises) et retrouve chacun dans la boutique ou parmi les anciens
  modèles → `data/catalogue_n2_2024.json`. **Toute cette gamme est dans
  l'appli**, quel que soit le socle (Provinces de France, Marins, Catalans…) ;
  `build.py` refuse de construire le site s'il en manque un.
- **Anciens modèles** : 20 santons du catalogue papier absents de la boutique
  (Mireille, Ravi coupé, Bastidanes, Pont-Aven, Fileuse au rouet…), photos
  découpées dans le PDF par `scraper/anciens.py`.
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
- **Sélection** : `scraper/selection.py` (gamme du catalogue N°2 et N°2 pied vert, à l'unité ; bâtiments
  et accessoires Carbonel N°2 ; bâtiments et accessoires Escoffier 7 cm ; ni coffrets, ni
  lots, ni Pastel).

Pour le mettre à jour :

```sh
cd scraper
python3 scrape.py          # relève la boutique -> data/santons.json
python3 anciens.py         # anciens N°2 du catalogue PDF (pdfplumber)
python3 catalogue_n2.py    # liste de la gamme du catalogue N°2 Tradition
python3 escoffier.py       # bâtiments Escoffier -> data/escoffier.json
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
| `config.js` | Adresse et clé publique Supabase, option de reconnaissance |
| `src/app.html` | Le code de l'application |
| `supabase/schema.sql` | Tables, règles d'accès, fonctions d'invitation |
| `supabase/functions/reconnaitre/` | Reconnaissance des santons sur photo (Claude) |
| `supabase/tests/` | Tests des droits et du parcours |
| `data/` | Les catalogues relevés (Carbonel, anciens modèles, Escoffier) |
| `scraper/` | Relevé, couleur du pied, anciens modèles, vignettes |

GitHub ne contenait aucun outil de collection de santons ni de catalogue
Carbonel (recherche de novembre 2026). Les seuls dépôts proches,
[Oufti2015/santons](https://github.com/Oufti2015/santons) et
[karim1407/santonniers](https://github.com/karim1407/santonniers), ne
correspondent pas à ce besoin.

Photos et noms © Ateliers Marcel Carbonel et Santons Escoffier. Usage familial et privé.
