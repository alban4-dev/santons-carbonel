"""Ce que montre l'application : N°2 / 7 cm seulement, pièces à l'unité.

- section "santons"   : toute la gamme du catalogue papier « N°2 Collection
  Tradition » 2024 (quel que soit le socle), plus les santons Carbonel N°2 au
  pied vert de la boutique (personnages, animaux) ;
- section "decor"     : les bâtiments et accessoires Carbonel N°2 (Tradition) ;
- section "escoffier" : les bâtiments et accessoires Escoffier de la collection
  7 cm (maisons, façades, crèches et étables, puits, fontaines, ponts,
  roulottes, et la rubrique « Accessoires » : murs, escaliers, rivières,
  quais, arbres…).
Pas de coffrets ni de lots, pas de pièces sans photo, pas d'autres tailles.
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
ESCOFFIER_TAILLE = re.compile(r"Collection (2|5|9) ?cm|^Santon", re.I)


def section(it):
    if it.get("noPhoto") or PACK.search(it["name"]):
        return None
    if it.get("marque") == "escoffier":
        if ESCOFFIER_TAILLE.search(it.get("gamme") or ""):
            return None
        return "escoffier" if set(it.get("groupes", [])) & ESCOFFIER_RETENUS else None
    if 13 in it["cat"] or it["name"].startswith("Pastel"):
        return None
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


def groupe(it):
    """Groupe d'affichage d'un bâtiment Escoffier. Une façade est aussi rangée
    par Escoffier dans « Maisons et bâtisses » : la rubrique la plus précise gagne."""
    return next((g for g in GROUPE_PRIORITE if g in it.get("groupes", [])), "Autres")


def sort_key(it):
    sec = it.get("section")
    name = unicodedata.normalize("NFD", it["name"].lower())
    name = "".join(c for c in name if unicodedata.category(c) != "Mn")
    if sec == "escoffier":
        return (2, False, ESCOFFIER_GROUPES.index(groupe(it)) if groupe(it) in ESCOFFIER_GROUPES else 99, name)
    order = SANTON_ORDER if sec == "santons" else DECOR_ORDER
    cat = next((order.index(c) for c in it["cat"] if c in order), 99)
    ancien = "ancien" in it.get("col", [])
    return (0 if sec == "santons" else 1, ancien, cat, name)
