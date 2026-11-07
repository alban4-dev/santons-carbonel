#!/usr/bin/env python3
"""Liste des modèles du catalogue papier « N°2 Collection Tradition » (2024).

Lit les libellés du PDF (verticaux à côté des photos, horizontaux pour les
animaux et les présents), déplie les variantes de couleur (« Chameau bleu,
rouge, vert ou violet » = 4 modèles), puis retrouve chaque modèle dans la
boutique (data/santons.json) ou parmi les anciens modèles (data/anciens.json).

Écrit ../data/catalogue_n2_2024.json : [{page, libelle, ids, noms}]. Tout
modèle de ce catalogue est montré par l'appli, quel que soit son socle
(voir selection.py). Le script s'arrête si un modèle n'est pas retrouvé.

Nécessite pdfplumber. Usage : python3 catalogue_n2.py
"""
import io
import json
import re
import sys
import unicodedata
import urllib.request
from pathlib import Path

import pdfplumber

HERE = Path(__file__).resolve().parent
DATA = HERE.parent / "data"
PDF_URL = "https://storage.marcelcarbonel.com/catalogues/n2_tradition_2024.pdf"
# ligatures « fi » inversées par la lecture du texte vertical
LIGATURES = {"iflle": "fille", "iflet": "filet", "Inifrmière": "Infirmière", "ifls": "fils", "orilfamme": "oriflamme"}
COULEURS = ("rouge|bleu|bleue|violet|violette|vert|verte|orange|blanc|blanche|gris|grise|marron|noir|noire|"
            "roux|rousse|jaune|ocre|rose|lavande|pourpre")
# libellés que le rapprochement automatique ne peut pas trancher : motif sur le nom en boutique
A_LA_MAIN = {
    "Tourettane": r"^Tourrettane N°2$",
    "Couple au parapluie": r"^Couple au parapluie N°2$",
    "Fileuse au rouet": r"^Fileuse au rouet N°2$",
    "Arlésiennes": r"^Arlésienne (bleue|jaune|pourpre|violette) N°2$",
    "Arlésiennes à la cape": r"^Arlésienne à la cape ",
    "Cheval": r"^Cheval noir N°2$",
    "Oie droite": r"^Oie N°2$",
}
SEUIL = 0.5  # en dessous, le rapprochement est refusé


def libelles(pdf):
    out = []
    for pi, pg in enumerate(pdf.pages[:14]):
        for w in pg.extract_words(extra_attrs=["upright"], keep_blank_chars=True):
            if w["upright"]:
                continue
            t = w["text"][::-1].strip()
            for a, b in LIGATURES.items():
                t = t.replace(a, b)
            if len(t) > 2 and not t.startswith("Les ") and t != "N°":
                out.append((pi + 1, t))
        mots = [w for w in pg.extract_words(extra_attrs=["upright", "size"], keep_blank_chars=True)
                if w["upright"] and round(w["size"], 1) == 5.0]
        for k, w in enumerate(mots):
            t = w["text"].strip()
            if t == "picorant":
                continue
            if t == "Poussin" and k + 1 < len(mots) and mots[k + 1]["text"].strip() == "picorant":
                t = "Poussin picorant"
            out.append((pi + 1, t))
    vus = set()
    return [x for x in out if not (x[1] in vus or vus.add(x[1]))]


def deplier(page, t):
    m = re.match(rf"^(.*?)\s+((?:{COULEURS})(?:\s*,\s*(?:{COULEURS}))*\s+ou\s+(?:{COULEURS}))$", t)
    if not m:
        return [(page, t)]
    return [(page, f"{m.group(1)} {c}") for c in re.split(r"\s*,\s*|\s+ou\s+", m.group(2))]


def mots(s):
    s = unicodedata.normalize("NFD", s.lower())
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    s = re.sub(r"[’'“”\"&,.()–/-]", " ", s)
    s = re.sub(r"n°\s*2", "", s)
    vides = {"le", "la", "les", "l", "de", "du", "des", "d", "a", "au", "aux", "et", "avec", "mr", "monsieur", "n",
             "2", "mage", "marie", "st", "saint", "li", "ou", "sur", "en", "chemise", "robe", "gilet", "pantalon",
             "couple", "mariees", "maries", "debout", "modele"}
    genre = {"bleue": "bleu", "verte": "vert", "violette": "violet", "noire": "noir", "grise": "gris",
             "rousse": "roux", "blanche": "blanc"}
    out = set()
    for t in s.split():
        if t in vides:
            continue
        t = t.rstrip("s") if len(t) > 3 else t
        out.add(genre.get(t, t))
    return out


def main():
    req = urllib.request.Request(PDF_URL, headers={"User-Agent": "Mozilla/5.0"})
    with pdfplumber.open(io.BytesIO(urllib.request.urlopen(req, timeout=120).read())) as pdf:
        modeles = [m for p, t in libelles(pdf) for m in deplier(p, t)]
    boutique = json.loads((DATA / "santons.json").read_text())["items"]
    anciens = json.loads((DATA / "anciens.json").read_text())["items"]
    pool = [i for i in boutique + anciens
            if (i["size"] == 2 or "N°2" in i["name"]) and not i["name"].startswith("Pastel") and 13 not in i["cat"]]
    sortie, manquants = [], []
    for page, libelle in modeles:
        if libelle in A_LA_MAIN:
            trouves = [i for i in pool if re.search(A_LA_MAIN[libelle], i["name"])]
        else:
            m = mots(libelle)
            score = lambda i: len(m & mots(i["name"])) / len(m | mots(i["name"]))  # noqa: E731
            best = max(pool, key=lambda i: (score(i), -len(i["name"])))
            trouves = [best] if score(best) >= SEUIL else []
        if not trouves:
            manquants.append(f"p{page} {libelle}")
        sortie.append({"page": page, "libelle": libelle, "ids": [i["id"] for i in trouves],
                       "noms": [i["name"] for i in trouves]})
    if manquants:
        sys.exit("Modèles du catalogue introuvables : " + ", ".join(manquants))
    (DATA / "catalogue_n2_2024.json").write_text(json.dumps(
        {"source": PDF_URL, "modeles": sortie}, ensure_ascii=False, indent=1))
    ids = {i for s in sortie for i in s["ids"]}
    print(f"{len(modeles)} modèles au catalogue, {len(ids)} références retrouvées")


if __name__ == "__main__":
    main()
