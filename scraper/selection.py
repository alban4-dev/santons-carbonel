"""Ce que montre l'application : N°2 seulement, pièces à l'unité.

- section "santons" : les santons N°2 au pied vert (personnages, animaux),
  boutique + anciens modèles du catalogue papier ;
- section "decor" : les bâtiments et accessoires N°2 (gamme Tradition).
Pas de coffrets ni de lots, pas de pièces sans photo.
"""
import re
import unicodedata

PACK = re.compile(r"\b(coffret|lot)\b|\+", re.I)
DECOR_CATS = {2, 3}           # maisons et étables ; accessoires, arbres, fleurs
SANTON_ORDER = [1, 8, 9, 6, 4, 12, 7]  # bibliques, provençaux, spéciaux, provinces, animaux…
DECOR_ORDER = [2, 3]


def section(it):
    if it.get("noPhoto") or 13 in it["cat"] or PACK.search(it["name"]):
        return None
    if it["name"].startswith("Pastel"):
        return None
    if set(it["cat"]) & DECOR_CATS:
        n2 = it["size"] == 2 or "N°2" in it["name"]
        return "decor" if n2 else None
    if it["size"] == 2 and it.get("pied") == "vert":
        return "santons"
    return None


def sort_key(it):
    sec = it.get("section")
    order = SANTON_ORDER if sec == "santons" else DECOR_ORDER
    cat = next((order.index(c) for c in it["cat"] if c in order), 99)
    ancien = "ancien" in it.get("col", [])
    name = unicodedata.normalize("NFD", it["name"].lower())
    name = "".join(c for c in name if unicodedata.category(c) != "Mn")
    return (0 if sec == "santons" else 1, ancien, cat, name)
