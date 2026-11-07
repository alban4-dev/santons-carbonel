#!/usr/bin/env python3
"""Télécharge une vignette de chaque santon et les assemble en planches.

Lit ../data/santons.json (boutique Carbonel), ../data/anciens.json (modèles du
catalogue papier, photos dans ./anciens/) et ../data/escoffier.json (bâtiments
Escoffier), écrit ../site/sprites/planche-NN.webp
et ajoute à chaque santon :
  "sp"   : sa position dans les planches [planche, case] ;
  "pied" : la couleur de son socle lue sur la photo ("vert" ou "autre"),
           pour les personnages, animaux et coffrets (pas pour les décors) ;
  "noPhoto": true quand le site n'affiche que son logo à la place de la photo ;
  "section": "santons", "decor" ou "escoffier" pour ce que montre l'appli
             (voir selection.py).
Seule cette sélection est mise en planches.
Les vignettes téléchargées restent en cache dans ./cache/ (non versionné),
une relance ne retélécharge que les nouveautés.

Pourquoi des planches : l'appli s'affiche aussi dans un cadre qui n'autorise
que les images publiées avec la page (pas de lien direct vers le site
Carbonel), et 1 300 fichiers séparés seraient trop nombreux.

Nécessite Pillow (pip install pillow).
Usage : python3 build_sprites.py
"""
import collections
import concurrent.futures as cf
import hashlib
import io
import json
import time
import urllib.request

from PIL import ImageChops
from pathlib import Path

from PIL import Image

from selection import section, sort_key
from socle import socle

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
DATA = ROOT / "data" / "santons.json"
ANCIENS = ROOT / "data" / "anciens.json"
ESCOFFIER = ROOT / "data" / "escoffier.json"
DECOR = {2, 3, 5, 10}  # maisons, accessoires, affiches, pièces détachées : pas de « pied »
SPRITES = ROOT / "site" / "sprites"
CACHE = HERE / "cache"
CELL_W, CELL_H = 180, 240  # vignette (px), affichée à ~120×160 à l'écran
COLS, ROWS = 10, 10        # 100 vignettes par planche
UA = "Mozilla/5.0 (catalogue familial de santons; usage personnel)"


def thumb_url(img):
    # imgix redimensionne, détoure le fond (trim) et recentre sur fond blanc
    return (f"{img}?auto=format&fm=jpg&q=80&trim=auto&trim-pad=8&fit=fill"
            f"&fill=solid&fill-color=ffffff&bg=ffffff&w={CELL_W}&h={CELL_H}")


def to_cell(src, dst):
    """Photo quelconque -> vignette CELL_W×CELL_H centrée sur fond blanc."""
    im = Image.open(src)
    if im.mode in ("RGBA", "LA", "P"):  # fond transparent -> blanc
        im = im.convert("RGBA")
        bg = Image.new("RGBA", im.size, "white")
        bg.alpha_composite(im)
        im = bg
    im = im.convert("RGB")
    box = ImageChops.difference(im, Image.new("RGB", im.size, "white")).point(lambda v: 255 if v > 18 else 0).getbbox()
    if box:  # rogne les marges blanches
        pad = 8
        im = im.crop((max(0, box[0] - pad), max(0, box[1] - pad), min(im.width, box[2] + pad), min(im.height, box[3] + pad)))
    im.thumbnail((CELL_W - 12, CELL_H - 12))
    bg = Image.new("RGB", (CELL_W, CELL_H), "white")
    bg.paste(im, ((CELL_W - im.width) // 2, (CELL_H - im.height) // 2))
    bg.save(dst, quality=90)


def fetch(item):
    path = CACHE / f"{item['id']}.jpg"
    local = HERE / "anciens" / f"{item['id']}.png"
    if local.exists():
        if not path.exists() or path.stat().st_mtime < local.stat().st_mtime:
            to_cell(local, path)
        return item["id"], path
    if path.exists() and path.stat().st_size > 0:
        return item["id"], path
    if item.get("marque") == "escoffier" and item.get("img"):  # photo d'origine, pas d'imgix
        raw = CACHE / f"{item['id']}.orig"
        try:
            req = urllib.request.Request(item["img"], headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as r:
                raw.write_bytes(r.read())
            to_cell(raw, path)
            raw.unlink()
            return item["id"], path
        except Exception as e:
            print(f"  ! {item['id']} {item['name']}: {e}")
            return item["id"], None
    if not item.get("img"):
        return item["id"], None
    for attempt in range(4):
        try:
            req = urllib.request.Request(thumb_url(item["img"]), headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as r:
                path.write_bytes(r.read())
            return item["id"], path
        except Exception as e:
            if attempt == 3:
                print(f"  ! {item['id']} {item['name']}: {e}")
                return item["id"], None
            time.sleep(2 ** attempt)


def main():
    data = json.loads(DATA.read_text())
    anciens = json.loads(ANCIENS.read_text()) if ANCIENS.exists() else {"items": []}
    escoffier = json.loads(ESCOFFIER.read_text()) if ESCOFFIER.exists() else {"items": []}
    for it in escoffier["items"]:
        it.update(marque="escoffier", cat=it.get("cat", []), size=it.get("size"))
    items = data["items"] + anciens["items"] + escoffier["items"]
    CACHE.mkdir(exist_ok=True)
    SPRITES.mkdir(exist_ok=True)

    with cf.ThreadPoolExecutor(6) as ex:
        paths = dict(ex.map(fetch, items))

    # Le site remplace les photos manquantes par son logo : même fichier partout
    digests = {i: hashlib.md5(p.read_bytes()).hexdigest() for i, p in paths.items() if p}
    common = {h for h, n in collections.Counter(digests.values()).items() if n >= 5}
    for it in items:
        it.pop("noPhoto", None)
        it.pop("pied", None)
        if digests.get(it["id"]) in common:
            it["noPhoto"] = True
            paths[it["id"]] = None
        elif paths.get(it["id"]) and it.get("marque") != "escoffier" and not (set(it["cat"]) & DECOR):
            lab = socle(paths[it["id"]])[0]
            it["pied"] = "vert" if lab == "vert" else "autre"

    # Seule la sélection de l'appli (N°2 pied vert + bâtiments N°2) va en planches
    for it in items:
        it.pop("section", None)
        sec = section(it) if paths.get(it["id"]) else None
        if sec:
            it["section"] = sec
    ordered = sorted((it for it in items if it.get("section")), key=sort_key)
    per = COLS * ROWS
    for old in SPRITES.glob("planche-*.webp"):
        old.unlink()
    for it in items:
        it.pop("sp", None)
    for n in range(0, len(ordered), per):
        sheet_no = n // per
        chunk = ordered[n:n + per]
        rows = (len(chunk) + COLS - 1) // COLS
        sheet = Image.new("RGB", (COLS * CELL_W, rows * CELL_H), "white")
        for i, it in enumerate(chunk):
            try:
                im = Image.open(io.BytesIO(paths[it["id"]].read_bytes())).convert("RGB")
            except Exception as e:
                print(f"  ! image illisible {it['id']}: {e}")
                continue
            if im.size != (CELL_W, CELL_H):
                im.thumbnail((CELL_W, CELL_H))
                bg = Image.new("RGB", (CELL_W, CELL_H), "white")
                bg.paste(im, ((CELL_W - im.width) // 2, (CELL_H - im.height) // 2))
                im = bg
            sheet.paste(im, ((i % COLS) * CELL_W, (i // COLS) * CELL_H))
            it["sp"] = [sheet_no, i]
        out = SPRITES / f"planche-{sheet_no:02d}.webp"
        sheet.save(out, "WEBP", quality=72, method=6)
        print(f"{out.name}: {len(chunk)} vignettes, {out.stat().st_size // 1024} Ko")

    data["sprite"] = {"cellW": CELL_W, "cellH": CELL_H, "cols": COLS,
                      "sheets": (len(ordered) + per - 1) // per}
    DATA.write_text(json.dumps(data, ensure_ascii=False, indent=1))
    if anciens["items"]:
        ANCIENS.write_text(json.dumps(anciens, ensure_ascii=False, indent=1))
    if escoffier["items"]:
        ESCOFFIER.write_text(json.dumps(escoffier, ensure_ascii=False, indent=1))
    count = collections.Counter(it["section"] for it in ordered)
    print(f"{count['santons']} santons N°2 pied vert, {count['decor']} bâtiments et accessoires N°2, "
          f"{count["escoffier"]} bâtiments et accessoires Escoffier")


if __name__ == "__main__":
    main()
