#!/usr/bin/env python3
"""Relève les décors de crèche (bâtiments) des Santons Escoffier (escoffier.fr).

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
        if i["id"] in nouveaux:
            i["nouveaute"] = True
    print(f"Nouveautés : {len(nouveaux)} au total, dont {sum(1 for i in items.values() if i.get('nouveaute'))} décors")
    data = {
        "source": "https://www.escoffier.fr/fr/decors-de-creche.html",
        "scrapedAt": time.strftime("%Y-%m-%d"),
        "items": sorted(items.values(), key=lambda i: i["id"]),
    }
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=1))
    print(f"{len(items)} décors Escoffier écrits dans {OUT}")


if __name__ == "__main__":
    main()
