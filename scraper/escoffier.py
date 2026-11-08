#!/usr/bin/env python3
"""Relève les décors de crèche (bâtiments, accessoires) et les santons des
collections 7 cm et 9 cm des Santons Escoffier (escoffier.fr).

Écrit ../data/escoffier.json : un élément par modèle (nom, photo, référence,
prix, gamme, catégorie, lien, et "nouveaute": true pour ceux de la rubrique
Nouveautés du site). Les identifiants valent 100000 + l'identifiant
de la boutique Escoffier, pour ne jamais croiser ceux de Carbonel.

Uniquement la bibliothèque standard. Une requête toutes les ~0,5 s.
Usage : python3 escoffier.py
"""
import html
import json
import re
import sys
import time
import urllib.request
from pathlib import Path

BASE = "https://www.escoffier.fr/fr/decors-de-creche/"
# santons peints à l'échelle des N°2 Carbonel (7 cm) et des N°3 (9 cm) ; la version « brut » n'est pas retenue
SANTONS_7CM = "https://www.escoffier.fr/fr/santons-de-creche/collection-7-cm.html"
SANTONS_9CM = "https://www.escoffier.fr/fr/santons-de-creche/collection-9-cm.html"
COLLECTIONS = {SANTONS_7CM: "Santons 7 cm", SANTONS_9CM: "Santons 9 cm"}
# codes du filtre « Création » du site -> saison
ANNEES_CREATION = {67: "2026-2027", 65: "2025-2026", 64: "2024-2025", 63: "2023-2024", 62: "2022-2023"}
SAISON = "2026-2027"
UA = "Mozilla/5.0 (catalogue familial de santons; usage personnel)"
OUT = Path(__file__).resolve().parent.parent / "data" / "escoffier.json"
ID_OFFSET = 100000
CATEGORIES = {  # slug -> libellé affiché
    "maisons-batisses": "Maisons et bâtisses",
    "creches-etables": "Crèches et étables",
    "facades": "Façades",
    "puits-fontaines-ponts": "Puits, fontaines et ponts",
    "roulottes-charettes": "Roulottes et charrettes",
    "autres-decors": "Autres décors",
    "accessoires": "Accessoires",
    "arbres-vegetations": "Arbres et végétation",
}
_last = 0.0


def get(url):
    global _last
    for attempt in range(4):
        wait = 0.5 - (time.time() - _last)
        if wait > 0:
            time.sleep(wait)
        _last = time.time()
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.read().decode("utf-8", "replace")
        except Exception as e:
            if attempt == 3:
                raise
            print(f"  ! {e} — nouvel essai", file=sys.stderr)
            time.sleep(2 ** (attempt + 1))


ITEM_RE = re.compile(r'id="product-item-info_(\d+)"(.*?)</li>', re.S)


def field(block, cls):
    m = re.search(rf'<div class="{cls}">(.*?)</div>', block, re.S)
    return html.unescape(re.sub(r"<[^>]+>|\s+", " ", m.group(1))).strip() if m else ""


def parse(page):
    out = []
    for pid, block in ITEM_RE.findall(page):
        link = re.search(r'class="product-item-link"\s+href="([^"]+)">\s*(.*?)\s*</a>', block, re.S)
        img = re.search(r'<img class="product-image-photo"\s+src="([^"]+)"', block)
        price = re.search(r'data-price-amount="([\d.]+)"', block)
        if not link:
            continue
        src = img.group(1) if img else None
        if src:  # image d'origine plutôt que la vignette mise en cache
            src = re.sub(r"/cache/[0-9a-f]+/", "/", src)
        out.append({
            "id": ID_OFFSET + int(pid),
            "name": html.unescape(re.sub(r"\s+", " ", link.group(2))).strip(),
            "ref": field(block, "ref").replace("Ref :", "").strip() or None,
            "gamme": field(block, "categorie"),
            "price": float(price.group(1)) if price else None,
            "img": src,
            "url": link.group(1),
        })
    return out


def main():
    items = {}
    for slug, label in CATEGORIES.items():
        n = 0
        for p in range(1, 30):
            page = get(f"{BASE}{slug}.html?product_list_limit=36&p={p}")
            found = parse(page)
            new = [f for f in found if f["id"] not in items or label not in items[f["id"]]["groupes"]]
            for f in found:
                items.setdefault(f["id"], {**f, "groupes": []})
                if label not in items[f["id"]]["groupes"]:
                    items[f["id"]]["groupes"].append(label)
            n += len(new)
            if not found or not new:  # au-delà de la dernière page, le site renvoie la dernière
                break
        print(f"{label:<28} {n:>4} modèles")
    for it in items.values():
        it["type"] = "decor"
    # Santons des collections 7 cm et 9 cm
    for url, label in COLLECTIONS.items():
        n = 0
        for p in range(1, 40):
            found = parse(get(f"{url}?product_list_limit=36&p={p}"))
            new = [f for f in found if f["id"] not in items]
            for f in new:
                items[f["id"]] = {**f, "groupes": [label], "type": "santon"}
            n += len(new)
            if not found or not new:
                break
        print(f"{label:<28} {n:>4} modèles")
        # Année de création des santons (filtre du site) : seuls ceux de la saison
        # en cours portent le badge « Nouveau »
        for code, annee in ANNEES_CREATION.items():
            vus = set()
            for p in range(1, 10):
                found = [f for f in parse(get(f"{url}?annee_creation={code}&product_list_limit=36&p={p}"))
                         if f["id"] not in vus]
                if not found:
                    break
                for f in found:
                    vus.add(f["id"])
                    if f["id"] in items:
                        items[f["id"]]["creation"] = annee
            print(f"  créés en {annee} : {len(vus)}")
    # Rubrique « Nouveautés » : surtout des santons, parfois un décor
    nouveaux = set()
    for p in range(1, 30):
        found = parse(get(f"https://www.escoffier.fr/fr/nouveautes.html?product_list_limit=36&p={p}"))
        fresh = {f["id"] for f in found} - nouveaux
        if not fresh:
            break
        nouveaux |= fresh
    for i in items.values():
        i.pop("nouveaute", None)
        # santon : la saison de création fait foi ; décor : la rubrique Nouveautés
        if (i.get("creation") == SAISON) if i.get("type") == "santon" else (i["id"] in nouveaux):
            i["nouveaute"] = True
    print(f"Nouveautés retenues : {sum(1 for i in items.values() if i.get('nouveaute'))}")
    data = {
        "source": "https://www.escoffier.fr/fr/decors-de-creche.html",
        "scrapedAt": time.strftime("%Y-%m-%d"),
        "items": sorted(items.values(), key=lambda i: i["id"]),
    }
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=1))
    print(f"{len(items)} modèles Escoffier écrits dans {OUT}")


if __name__ == "__main__":
    main()
