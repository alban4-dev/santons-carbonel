#!/usr/bin/env python3
"""Modèles N°2 des catalogues papier absents de la boutique en ligne.

Le catalogue « N°2 Collection Tradition » (édition 2024, PDF sur
marcelcarbonel.com/catalogue) montre des santons que la boutique en ligne ne
propose pas. La liste ci-dessous a été établie en comparant les deux, nom par
nom. Le script télécharge le PDF, découpe la photo de chacun et écrit
../data/anciens.json + ./anciens/<id>.png.

Nécessite pdfplumber et Pillow (pip install pdfplumber pillow).
Usage : python3 anciens.py
"""
import io
import json
import urllib.request
from pathlib import Path

import pdfplumber
from PIL import Image

HERE = Path(__file__).resolve().parent
# catalogues papier utilisés : clé -> (adresse du PDF, nom affiché dans la fiche)
SOURCES = {
    "2024": ("https://storage.marcelcarbonel.com/catalogues/n2_tradition_2024.pdf", "Catalogue N°2 Tradition 2024"),
    "2010": ("https://cdn.shopify.com/s/files/1/0253/1419/files/N2-2015.pdf", "Dépliant N°2 (2010)"),
}
PDF_URL = SOURCES["2024"][0]

# id, nom affiché, catégorie (voir scrape.CATEGORIES), page du PDF,
# libellé exact dans le PDF (texte vertical à droite de la photo),
# ou cadre de la photo en points PDF quand le libellé déborde dessus,
# et en option la source (clé de SOURCES, "2024" par défaut).
MODELES = [
    (5001, "Mireille à la cruche jaune N°2", 8, 6, "Mireille à la cruche jaune", None),
    (5002, "Mireille à la cruche orange N°2", 8, 6, "Mireille à la cruche orange", None),
    (5003, "Ravi coupé blanc N°2", 8, 6, "Ravi coupé blanc", None),
    (5004, "Ravi coupé bleu N°2", 8, 6, "Ravi coupé bleu", None),
    (5005, "Gitane verte N°2", 8, 5, "Gitane rouge ou verte", None),
    (5006, "Victorine violette N°2", 9, 8, "Victorine violette", None),
    (5007, "Femme sur l'âne N°2", 9, 9, "Femme sur l’âne", None),
    (5008, "Homme à l'aïoli N°2", 9, 9, "Homme à l’aïoli", None),
    (5009, "Maraîcher N°2", 9, 10, "Maraîcher", None),
    (5010, "Étalage de la Poissonnière N°2", 9, 10, "Etalage de la Poissonnière", None),
    (5011, "Étalage de la Maraîchère N°2", 9, 10, None, (164, 467, 256, 560)),
    (5012, "Couple de Bastidanes rose N°2", 9, 10, "Couple de Bastidanes rose", None),
    (5013, "Couple de Bastidanes vert N°2", 9, 10, "Couple de Bastidanes vert", None),
    (5014, "Arlésiennes rose et bleue sur le banc N°2", 9, 10, None, (98, 34, 176, 118)),
    (5015, "Arlésiennes verte et orange sur le banc N°2", 9, 10, None, (198, 34, 272, 117)),
    (5016, "Pont-Aven bleue N°2", 6, 11, "Pont-Aven bleue", None),
    (5017, "Pont-Aven rose N°2", 6, 11, "Pont-Aven rose", None),
    (5018, "Pont-Aven blanche N°2", 6, 11, "Pont-Aven blanche", None),
    (5019, "Pont-Aven verte N°2", 6, 11, "Pont-Aven verte", None),
    (5020, "Fileuse au rouet N°2", 9, 9, None, (300, 141, 372, 229)),  # fileuse + rouet : deux images
    # dépliant N°2 de 2010 : la colombe blanche, photo minuscule (36 × 18 px) sur fond jaune
    (5021, "Colombe N°2", 4, 2, None, (986, 546, 1016, 563), "2010"),
]


def find_box(page, label):
    for w in page.extract_words(extra_attrs=["upright"], keep_blank_chars=True):
        if w["upright"] or w["text"][::-1].strip() != label:
            continue
        cands = [im for im in page.images
                 if im["x1"] <= w["x0"] + 4 and w["x0"] - im["x1"] < 70
                 and not (im["bottom"] < w["top"] - 10 or im["top"] > w["bottom"] + 10)]
        if cands:
            im = max(cands, key=lambda i: i["x1"])
            return (im["x0"], im["top"], im["x1"], im["bottom"])
    raise SystemExit(f"Photo introuvable pour « {label} »")


def main_blob(im):
    """Recadre sur le plus gros sujet (écarte les bouts de photos voisines)."""
    small = im.convert("L").resize((im.width // 4 or 1, im.height // 4 or 1))
    W, H = small.size
    px = small.load()
    mask = [[px[x, y] < 235 for x in range(W)] for y in range(H)]
    seen = [[False] * W for _ in range(H)]
    best = None
    for y0 in range(H):
        for x0 in range(W):
            if not mask[y0][x0] or seen[y0][x0]:
                continue
            stack, n, box = [(x0, y0)], 0, [x0, y0, x0, y0]
            seen[y0][x0] = True
            while stack:
                x, y = stack.pop()
                n += 1
                box = [min(box[0], x), min(box[1], y), max(box[2], x), max(box[3], y)]
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < W and 0 <= ny < H and mask[ny][nx] and not seen[ny][nx]:
                        seen[ny][nx] = True
                        stack.append((nx, ny))
            if not best or n > best[0]:
                best = (n, box)
    if not best:
        return im
    b = best[1]
    pad = 2
    return im.crop((max(0, (b[0] - pad) * 4), max(0, (b[1] - pad) * 4),
                    min(im.width, (b[2] + pad + 1) * 4), min(im.height, (b[3] + pad + 1) * 4)))


def main():
    pdfs = {}
    for key, (url, _) in SOURCES.items():
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        pdfs[key] = pdfplumber.open(io.BytesIO(urllib.request.urlopen(req, timeout=120).read()))
    out_dir = HERE / "anciens"
    out_dir.mkdir(exist_ok=True)
    items = []
    try:
        for pid, name, cat, page_no, label, box, *rest in MODELES:
            src = rest[0] if rest else "2024"
            page = pdfs[src].pages[page_no - 1]
            img = page.crop(box or find_box(page, label)).to_image(resolution=300).original.convert("RGB")
            # cadre trouvé d'après le libellé : on écarte les bouts d'images voisines ;
            # cadre donné à la main : on le garde tel quel (il peut réunir deux images)
            img = img if box else main_blob(img)
            if img.width < 150:  # photo minuscule : on l'agrandit pour la vignette
                k = 170 / img.width
                img = img.resize((170, round(img.height * k)), Image.LANCZOS)
            img.save(out_dir / f"{pid}.png")
            items.append({
                "id": pid, "name": name, "ref": None, "size": 2, "cat": [cat],
                "col": ["tradition", "ancien"], "price": None, "img": None,
                "url": "https://marcelcarbonel.com/catalogue",
                "source": f"{SOURCES[src][1]}, page {page_no}",
            })
            print(f"{pid} {name}")
    finally:
        for pdf in pdfs.values():
            pdf.close()
    (HERE.parent / "data" / "anciens.json").write_text(json.dumps(
        {"sources": [u for u, _ in SOURCES.values()], "note": "Modèles des catalogues papier absents de la boutique en ligne",
         "items": items}, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
