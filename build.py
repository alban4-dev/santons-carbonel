#!/usr/bin/env python3
"""Assemble le site à publier (dossier site/) : src/app.html + la sélection du catalogue.

site/ se dépose tel quel sur n'importe quel hébergement statique (GitHub Pages,
Netlify, Cloudflare Pages…). Les réglages Supabase sont dans config.js.
Usage : python3 build.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
data = json.loads((ROOT / "data" / "santons.json").read_text())
anciens = ROOT / "data" / "anciens.json"
if anciens.exists():  # modèles du catalogue papier absents de la boutique
    data["items"] += json.loads(anciens.read_text())["items"]
# l'appli ne montre que la sélection (N°2 pied vert + bâtiments N°2), dans l'ordre des planches
import sys
sys.path.insert(0, str(ROOT / "scraper"))
from selection import sort_key  # noqa: E402
keep = ("id", "name", "ref", "cat", "col", "price", "img", "url", "source", "sp", "section")
data["items"] = [{k: it[k] for k in keep if it.get(k) is not None}
                 for it in sorted((i for i in data["items"] if i.get("section")), key=sort_key)]
blob = json.dumps(data, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
src = (ROOT / "src" / "app.html").read_text()
assert "/*__DATA__*/null" in src
body = src.replace("/*__DATA__*/null", blob)

# Le site à publier : site/index.html + site/config.js (+ site/sprites/, écrit par build_sprites.py)
import shutil  # noqa: E402
site = ROOT / "site"
site.mkdir(exist_ok=True)
page = ("<!doctype html>\n<html lang=\"fr\">\n<head>\n<meta charset=\"utf-8\">\n"
        "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1,viewport-fit=cover\">\n"
        + body + "\n</html>\n")
(site / "index.html").write_text(page)
shutil.copy(ROOT / "config.js", site / "config.js")
print(f"site/ : index.html {len(page) // 1024} Ko, {len(data['items'])} santons, "
      f"{len(list((site / 'sprites').iterdir()))} planches")
