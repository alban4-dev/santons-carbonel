"""Ce que montre l'application : N°2 / 7 cm seulement, pièces à l'unité.

- section "santons"   : toute la gamme du catalogue papier « N°2 Collection
  Tradition » 2024 (quel que soit le socle), plus les santons Carbonel N°2 au
  pied vert de la boutique (personnages, animaux) ;
- section "decor"     : les bâtiments et accessoires Carbonel N°2 (Tradition) ;
- section "santons_escoffier" : les santons Escoffier de la collection 7 cm
  (l'échelle des N°2 Carbonel), classés Nativité / Personnages / Animaux ;
- section "escoffier" : les bâtiments et accessoires Escoffier de la collection
  7 cm (maisons, façades, crèches et étables, puits, fontaines, ponts,
  roulottes, et la rubrique « Accessoires » : murs, escaliers, rivières,
  quais, arbres…).
- section "santons_n3" : les santons Carbonel N°3 (9 cm) à l'unité, quel que
  soit le socle, et les bâtiments et accessoires N°3, pour les crèches montées
  en taille 3 (chaque crèche choisit ses catalogues dans l'appli).
Pas de coffrets ni de lots, pas de pièces détachées, pas de pièces sans photo,
pas d'autres tailles.
"""
import json
import re
import unicodedata
from pathlib import Path

_CAT = Path(__file__).resolve().parent.parent / "data" / "catalogue_n2_2024.json"
# tous les modèles du catalogue papier N°2 Tradition (voir catalogue_n2.py)
CATALOGUE_N2 = ({i for m in json.loads(_CAT.read_text())["modeles"] for i in m["ids"]}
                if _CAT.exists() else set())

PACK = re.compile(r"\b(coffret|lot)\b|\+", re.I)
DECOR_CATS = {2, 3}           # Carbonel : maisons et étables ; accessoires, arbres, fleurs
SANTON_ORDER = [1, 8, 9, 6, 4, 12, 7]  # bibliques, provençaux, spéciaux, provinces, animaux…
DECOR_ORDER = [2, 3]
# ordre d'affichage des groupes
ESCOFFIER_GROUPES = ["Maisons et bâtisses", "Façades", "Crèches et étables",
                     "Puits, fontaines et ponts", "Roulottes et charrettes",
                     "Accessoires", "Arbres et végétation"]
# rubriques du site qui font entrer un décor dans l'appli (les arbres seulement
# s'ils sont aussi rangés dans « Accessoires »)
ESCOFFIER_RETENUS = set(ESCOFFIER_GROUPES) - {"Arbres et végétation"}
# Santons Tradition N°2 sans socle du tout (la lecture du « pied » ne peut pas
# les retenir) : la Nativité dans sa paille, et des animaux posés sans terrasse.
SANS_SOCLE = {
    543: "Jésus N°2",
    568: "Jésus seul N°2",
    569: "Berceau de Jésus N°2",
    354: "Canard nageant N°2",
    1484: "Cigogne N°2",
}
# santons Escoffier : classement d'après le nom (le site ne les range pas)
NATIVITE_ESC = re.compile(r"^(Enfant Jésus|Vierge Marie|Vierge à l'enfant|Marie de l'avent|Marie enceinte|"
                          r"Saint Joseph|Ange\b|Roi Mage|Pages à genoux|Chamelier|Cornac)", re.I)
ANIMAL_ESC = re.compile(r"^(Âne|Ane|Bougre d'âne|Aigle|Brebis|Bélier|Bœuf|Canard|Chameau|Chat\b|Chaton|Cheval|"
                        r"Chien|Chiot|Chèvre|Cigogne|Cochon|Colombe|Coq|Couple d'agneaux|Cygne|Dindon|Dromadaire|"
                        r"Éléphant|Eléphant|Flamant|Hibou|Laie|Lapin|Loup|Mouton|Oie|Ours|Pigeon|Poule|Poussin|"
                        r"Renard|Sanglier|Taureau|Vache)", re.I)
SANTONS_ESC_ORDRE = ["Nativité", "Personnages", "Animaux"]
ESCOFFIER_TAILLE = re.compile(r"Collection (2|5|9) ?cm|^Santon", re.I)


def section(it):
    if it.get("noPhoto") or PACK.search(it["name"]):
        return None
    if it.get("marque") == "escoffier":
        if it.get("type") == "santon":
            return "santons_escoffier" if re.search(r"Santon Collection 7 ?cm$", it.get("gamme") or "") else None
        if ESCOFFIER_TAILLE.search(it.get("gamme") or ""):
            return None
        return "escoffier" if set(it.get("groupes", [])) & ESCOFFIER_RETENUS else None
    if 13 in it["cat"] or it["name"].startswith("Pastel"):
        return None
    if it["size"] == 3 or (re.search(r"N°3\b", it["name"]) and "N°2" not in it["name"]):
        return "santons_n3" if 10 not in it["cat"] else None  # santons et bâtiments N°3, sans pièces détachées
    if set(it["cat"]) & DECOR_CATS:
        n2 = it["size"] == 2 or "N°2" in it["name"]
        return "decor" if n2 else None
    if it["id"] in CATALOGUE_N2 or "ancien" in it.get("col", []):  # gamme du catalogue, anciens modèles
        return "santons"
    if it["size"] == 2 and (it.get("pied") == "vert" or it["id"] in SANS_SOCLE):
        return "santons"
    return None


GROUPE_PRIORITE = ["Façades", "Crèches et étables", "Puits, fontaines et ponts",
                   "Roulottes et charrettes", "Maisons et bâtisses",
                   "Arbres et végétation", "Accessoires"]


def aussi(it):
    """Autres rubriques où un modèle apparaît aussi : les accessoires « N°2 & N°3 »
    (fleurs, lavande) servent aux deux tailles."""
    if it.get("section") == "decor" and re.search(r"N°2 (&|et) N°3", it["name"]):
        return ["santons_n3"]
    return None


def groupe(it):
    """Groupe d'affichage d'un modèle Escoffier : pour un santon, Nativité /
    Personnages / Animaux d'après son nom ; pour un bâtiment, voir groupe_decor."""
    if it.get("type") == "santon":
        nom = it["name"]
        return "Nativité" if NATIVITE_ESC.search(nom) else "Animaux" if ANIMAL_ESC.search(nom) else "Personnages"
    return groupe_decor(it)


def groupe_decor(it):
    """Groupe d'affichage d'un bâtiment Escoffier. Une façade est aussi rangée
    par Escoffier dans « Maisons et bâtisses » : la rubrique la plus précise gagne."""
    return next((g for g in GROUPE_PRIORITE if g in it.get("groupes", [])), "Autres")


def sort_key(it):
    sec = it.get("section")
    name = unicodedata.normalize("NFD", it["name"].lower())
    name = "".join(c for c in name if unicodedata.category(c) != "Mn")
    if sec == "santons_escoffier":
        return (1, False, SANTONS_ESC_ORDRE.index(groupe(it)), name)
    if sec == "escoffier":
        return (2, False, ESCOFFIER_GROUPES.index(groupe(it)) if groupe(it) in ESCOFFIER_GROUPES else 99, name)
    # l'appli range les sujets prestiges et hors série avec les sujets spéciaux (9) : même place
    cats = [9 if c in (12, 7) else c for c in it["cat"]]
    if sec == "santons_n3":  # santons d'abord, puis bâtiments et accessoires
        order = SANTON_ORDER + DECOR_ORDER
        return (4, "ancien" in it.get("col", []), next((order.index(c) for c in cats if c in order), 99), name)
    order = SANTON_ORDER if sec == "santons" else DECOR_ORDER
    cat = next((order.index(c) for c in cats if c in order), 99)
    ancien = "ancien" in it.get("col", [])
    return (0 if sec == "santons" else 3, ancien, cat, name)
