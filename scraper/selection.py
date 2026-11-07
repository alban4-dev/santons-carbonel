"""Ce que montre l'application : N°2 / 7 cm seulement, pièces à l'unité.

- section "santons"   : les santons Carbonel N°2 au pied vert (personnages,
  animaux), boutique + anciens modèles du catalogue papier ;
- section "decor"     : les bâtiments et accessoires Carbonel N°2 (Tradition) ;
- section "escoffier" : les bâtiments Escoffier de la collection 7 cm (maisons,
  crèches et étables, façades, puits, fontaines, ponts, roulottes).
Pas de coffrets ni de lots, pas de pièces sans photo, pas d'autres tailles.
"""
import re
import unicodedata

PACK = re.compile(r"\b(coffret|lot)\b|\+", re.I)
DECOR_CATS = {2, 3}           # Carbonel : maisons et étables ; accessoires, arbres, fleurs
SANTON_ORDER = [1, 8, 9, 6, 4, 12, 7]  # bibliques, provençaux, spéciaux, provinces, animaux…
DECOR_ORDER = [2, 3]
ESCOFFIER_GROUPES = ["Maisons et bâtisses", "Façades", "Crèches et étables",
                     "Puits, fontaines et ponts", "Roulottes et charrettes"]
ESCOFFIER_TAILLE = re.compile(r"Collection (2|5|9) ?cm|^Santon", re.I)


def section(it):
    if it.get("noPhoto") or PACK.search(it["name"]):
        return None
    if it.get("marque") == "escoffier":
        if ESCOFFIER_TAILLE.search(it.get("gamme") or ""):
            return None
        return "escoffier" if set(it.get("groupes", [])) & set(ESCOFFIER_GROUPES) else None
    if 13 in it["cat"] or it["name"].startswith("Pastel"):
        return None
    if set(it["cat"]) & DECOR_CATS:
        n2 = it["size"] == 2 or "N°2" in it["name"]
        return "decor" if n2 else None
    if it["size"] == 2 and it.get("pied") == "vert":
        return "santons"
    return None


GROUPE_PRIORITE = ["Façades", "Crèches et étables", "Puits, fontaines et ponts",
                   "Roulottes et charrettes", "Maisons et bâtisses"]


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
