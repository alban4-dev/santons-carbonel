#!/usr/bin/env python3
"""Scrape le catalogue complet des Ateliers Marcel Carbonel (marcelcarbonel.com).

Produit ../data/santons.json (puis lancer build_sprites.py et build.py).

Méthode :
  1. toutes les pages de /boutique (liste complète : nom, photo, prix, lien) ;
  2. les mêmes listes filtrées par catégorie, par taille et par collection
     (Tradition, Pastel, Nouveautés, Sélection) pour étiqueter chaque santon ;
  3. le sitemap, pour rattraper les fiches absentes des listes (épuisés...),
     lues une par une.

Uniquement la bibliothèque standard. Une requête toutes les ~0,4 s.
Usage : python3 scrape.py
"""
import html
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

BASE = "https://marcelcarbonel.com"
UA = "Mozilla/5.0 (catalogue familial de santons; usage personnel)"
DELAY = 0.4
OUT = Path(__file__).resolve().parent.parent / "data"

CATEGORIES = {
    1: "Sujets bibliques",
    2: "Maisons et étables",
    3: "Accessoires, arbres, fleurs",
    4: "Animaux",
    5: "Affiches, bougies, livres",
    6: "Provinces de France",
    7: "Sujets hors série",
    8: "Sujets provençaux",
    9: "Sujets spéciaux",
    10: "Pièces détachées",
    12: "Sujets prestiges",
    13: "Coffrets de santons",
}
SIZES = {
    0: "Puce (2,5 cm)",
    1: "N°1 (4 cm)",
    2: "N°2 (7 cm)",
    3: "N°3 (9 cm)",
    4: "N°4 (12 cm)",
    5: "N°5 (15 cm)",
    99: "Divers",
}
COLLECTIONS = {
    "collectionTradition": "tradition",
    "collectionPastel": "pastel",
    "new": "nouveaute",
    "featured": "selection",
}

_last = 0.0


def get(url, tries=4):
    global _last
    for attempt in range(tries):
        wait = DELAY - (time.time() - _last)
        if wait > 0:
            time.sleep(wait)
        _last = time.time()
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.read().decode("utf-8", "replace")
        except Exception as e:  # réseau capricieux : on réessaie
            if attempt == tries - 1:
                raise
            print(f"  ! {e} — nouvel essai", file=sys.stderr)
            time.sleep(2 ** (attempt + 1))


CARD_RE = re.compile(r'<div class="santon-card">(.*?)<div class="overlay">', re.S)


def parse_cards(page):
    out = []
    for block in CARD_RE.findall(page):
        m = re.search(r'href="(https://marcelcarbonel\.com/produit/(\d+)/[^"]+)">(.*?)</a>', block, re.S)
        if not m:
            continue
        img = re.search(r'<img[^>]+src="([^"]+)"', block)
        price = re.search(r'class="price">\s*([\d.,]+)', block)
        out.append({
            "id": int(m.group(2)),
            "url": m.group(1),
            "name": html.unescape(re.sub(r"\s+", " ", m.group(3)).strip()),
            "img": html.unescape(img.group(1)) if img else None,
            "price": float(price.group(1).replace(",", ".")) if price else None,
        })
    return out


def last_page(page):
    nums = [int(n) for n in re.findall(r"(?:[?&]|&amp;)page=(\d+)", page)]
    return max(nums) if nums else 1


def crawl_list(params, label):
    """Toutes les pages d'une liste /boutique filtrée -> liste de cartes."""
    q = urllib.parse.urlencode(params, doseq=True)
    first = get(f"{BASE}/boutique?{q}")
    n = last_page(first)
    cards = parse_cards(first)
    for p in range(2, n + 1):
        sep = "&" if q else ""
        cards += parse_cards(get(f"{BASE}/boutique?{q}{sep}page={p}"))
    print(f"{label:<40} {n:>3} pages  {len(cards):>5} produits")
    return cards


def clean_img(url):
    """URL imgix sans paramètres : l'appli choisit sa propre taille."""
    if not url:
        return None
    # certaines photos pointent vers le stockage brut : imgix sert les mêmes fichiers
    return url.split("?")[0].replace("https://storage.marcelcarbonel.com/", "https://marcelcarbonel.imgix.net/")


def ref_from_url(url):
    # .../santons-de-provence-ane-charge-fagots-n2-2-ANE-001 -> 2-ANE-001
    m = re.search(r"-(\d{1,2}-[A-Z]{2,5}-[0-9A-Z.]+(?:(?:-|%20-)[A-Z0-9.]+)*)$", url)
    return urllib.parse.unquote(m.group(1)).replace(" ", "") if m else None


def parse_detail(url, pid):
    page = get(url)
    name = re.search(r'<h1[^>]*>(.*?)</h1>', page, re.S)
    imgs = re.findall(rf'(https://marcelcarbonel\.imgix\.net/products/{pid}/[^"?\s]+)', page)
    price = re.search(r'class="price[^"]*">\s*([\d.,]+)', page)
    if not name:
        return None
    return {
        "id": pid,
        "url": url,
        "name": html.unescape(re.sub(r"<[^>]+>|\s+", " ", name.group(1))).strip(),
        "img": imgs[0] if imgs else None,
        "price": float(price.group(1).replace(",", ".")) if price else None,
    }


def main():
    products = {}
    for c in crawl_list({}, "Boutique (tout)"):
        products[c["id"]] = {**c, "categories": [], "size": None, "collections": []}

    def tag(cards, fn):
        for c in cards:
            p = products.setdefault(c["id"], {**c, "categories": [], "size": None, "collections": []})
            fn(p)

    for cid, label in CATEGORIES.items():
        tag(crawl_list({"category[]": cid}, f"Catégorie {label}"),
            lambda p, cid=cid: p["categories"].append(cid))
    for sid, label in SIZES.items():
        tag(crawl_list({"size[]": sid}, f"Taille {label}"),
            lambda p, sid=sid: p.__setitem__("size", sid))
    for key, slug in COLLECTIONS.items():
        tag(crawl_list({"collection": key}, f"Collection {slug}"),
            lambda p, slug=slug: p["collections"].append(slug))

    # Fiches du sitemap absentes des listes (épuisées, retirées de la vente...)
    sitemap = get(f"{BASE}/sitemap.xml")
    urls = re.findall(r"<loc>(https?://[^<]*/produit/(\d+)/[^<]*)</loc>", sitemap)
    missing = [(u.replace("://www.", "://"), int(i)) for u, i in urls if int(i) not in products]
    print(f"Sitemap : {len(urls)} fiches, {len(missing)} absentes des listes")
    for u, pid in missing:
        try:
            d = parse_detail(u, pid)
        except Exception as e:
            print(f"  ! {u}: {e}", file=sys.stderr)
            continue
        if d:
            products[pid] = {**d, "categories": [], "size": None, "collections": [], "horsListe": True}

    items = []
    for p in sorted(products.values(), key=lambda p: p["id"]):
        ref = ref_from_url(p["url"])
        size = p["size"]
        if size is None and ref:  # le préfixe de la référence donne la taille
            pre = ref.split("-")[0]
            size = {"0": 0, "1": 1, "2": 2, "3": 3, "4": 4, "5": 5}.get(pre, 99)
        item = {
            "id": p["id"],
            "name": p["name"],
            "ref": ref,
            "size": size,
            "cat": sorted(set(p["categories"])),
            "col": sorted(set(p["collections"])),
            "price": p["price"],
            "img": clean_img(p["img"]),
            "url": p["url"],
        }
        if p.get("horsListe"):
            item["horsListe"] = True
        items.append(item)

    data = {
        "source": BASE,
        "scrapedAt": time.strftime("%Y-%m-%d"),
        "categories": {str(k): v for k, v in CATEGORIES.items()},
        "sizes": {str(k): v for k, v in SIZES.items()},
        "items": items,
    }
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "santons.json").write_text(json.dumps(data, ensure_ascii=False, indent=1))
    print(f"{len(items)} santons écrits dans {OUT}")


if __name__ == "__main__":
    main()
