"""Couleur du socle (« pied ») d'un santon, lue sur sa vignette.

On isole le sujet (pixels non blancs), puis on regarde la bande du bas
(les 10 % inférieurs de sa hauteur) : c'est le socle. Renvoie "vert",
"terre" (terre cuite / ocre, gamme Pastel), "autre" ou None si pas d'image.
"""
from PIL import Image


def socle(path):
    im = Image.open(path).convert("RGB")
    W, H = im.size
    px = im.load()
    rows = [y for y in range(H) if any(min(px[x, y]) < 225 for x in range(0, W, 3))]
    if not rows:
        return None, 0, 0
    top, bot = rows[0], rows[-1]
    band = max(3, int((bot - top) * 0.10))
    g = o = t = 0
    for y in range(bot - band, bot + 1):
        for x in range(W):
            r, gg, b = px[x, y]
            if min(r, gg, b) > 225:
                continue
            t += 1
            if gg > r + 8 and gg > b:
                g += 1
            elif r > gg + 25 and r > b + 40:
                o += 1
    if not t:
        return None, 0, 0
    g, o = g / t, o / t
    if g >= 0.35 and g > o:
        lab = "vert"
    elif o >= 0.35:
        lab = "terre"
    else:
        lab = "autre"
    return lab, round(g, 2), round(o, 2)
