"""Generates the 30 fictional receipts of the OCR bench (Testing Protocol).

Every supplier, ICE and amount is invented. Each receipt is drawn as a
thermal ticket or an invoice, then degraded the way real receipts are
(blur, fading, crumpling, shadow, tilt, low resolution, handwriting).

Writes assets/bench/rNN.jpg and assets/bench/manifest.json with, for each
receipt, the lines printed and the values a reader should find.

Run from the repository root:  python3 tool/bench/generate_receipts.py
Needs Pillow with libraqm (Arabic shaping) and the fonts listed below.
"""
import json
import math
import os
import random

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

OUT = "assets/bench"
FONTS = {
    "mono": "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
    "mono_bold": "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf",
    "sans": "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "hand": "/usr/share/fonts/opentype/tlwg/Purisa-Oblique.otf",
    "arabic": "/usr/share/fonts/truetype/noto/NotoSansArabic-Regular.ttf",
}

random.seed(2026)


def mad(cents, sep=","):
    return f"{cents // 100}{sep}{cents % 100:02d}"


def vat_of(total, rate):
    return round(total * rate / (100 + rate))


# id, kind, quality, supplier, ice, date, total, rate (None: no VAT line),
# currency, category, language, items
SPECS = [
    (1, "ticket", "clean", "CAFE ATLAS", "001234567000089", "2026-11-10", 24000, 10, "MAD", "Repas", "fr"),
    (2, "ticket", "clean", "PETIT TAXI CASA", None, "2026-11-11", 4500, None, "MAD", "Transport", "fr"),
    (3, "invoice", "clean", "LIBRAIRIE NATIONALE", "002345678000012", "2026-11-09", 18000, 20, "MAD", "Fournitures", "fr"),
    (4, "ticket", "clean", "STATION AFRIQUIA MAARIF", "003456789000034", "2026-11-08", 49875, 14, "MAD", "Transport", "fr"),
    (5, "invoice", "clean", "HOTEL FARAH TANGER", "004567890000056", "2026-11-05", 95000, 10, "MAD", "Hébergement", "fr"),
    (6, "ticket", "blur", "RESTAURANT LE JARDIN", "005678901000078", "2026-11-06", 32000, 10, "MAD", "Repas", "fr"),
    (7, "ticket", "blur", "PATISSERIE BENNIS", None, "2026-11-12", 3500, None, "MAD", "Repas", "fr"),
    (8, "invoice", "blur", "PAPETERIE AGDAL", "006789012000090", "2026-11-04", 26400, 20, "MAD", "Fournitures", "fr"),
    (9, "ticket", "faded", "SNACK EL BAHJA", None, "2026-11-07", 6800, None, "MAD", "Repas", "fr"),
    (10, "ticket", "faded", "ONCF GARE CASA PORT", "007890123000012", "2026-11-03", 24900, 14, "MAD", "Transport", "fr"),
    (11, "ticket", "faded", "MARJANE CALIFORNIE", "008901234000034", "2026-11-02", 15640, 20, "MAD", "Fournitures", "fr"),
    (12, "ticket", "tilt", "CAFE DE FRANCE", None, "2026-11-13", 4200, None, "MAD", "Repas", "fr"),
    (13, "invoice", "tilt", "RIAD SALAM MARRAKECH", "009012345000056", "2026-10-30", 128000, 10, "MAD", "Hébergement", "fr"),
    (14, "ticket", "tilt", "PARKING TWIN CENTER", None, "2026-11-14", 2000, None, "MAD", "Transport", "fr"),
    (15, "ticket", "crumpled", "PIZZERIA VENEZIA", "001122334000045", "2026-11-01", 21500, 10, "MAD", "Repas", "fr"),
    (16, "ticket", "crumpled", "STATION SHELL AIN SEBAA", "002233445000067", "2026-10-29", 60000, 14, "MAD", "Transport", "fr"),
    (17, "ticket", "crumpled", "BIM HAY RIAD", None, "2026-11-15", 8930, None, "MAD", "Fournitures", "fr"),
    (18, "ticket", "shadow", "BRASSERIE DU PORT", "003344556000089", "2026-10-28", 45000, 10, "MAD", "Repas", "fr"),
    (19, "invoice", "shadow", "IMPRIMERIE ATLAS", "004455667000001", "2026-10-27", 72000, 20, "MAD", "Fournitures", "fr"),
    (20, "ticket", "shadow", "AUTOROUTES DU MAROC", None, "2026-11-16", 2300, None, "MAD", "Transport", "fr"),
    (21, "ticket", "lowres", "GLACIER OLIVERI", None, "2026-11-17", 5600, None, "MAD", "Repas", "fr"),
    (22, "invoice", "lowres", "IBIS RABAT AGDAL", "005566778000023", "2026-10-26", 71000, 10, "MAD", "Hébergement", "fr"),
    (23, "ticket", "lowres", "CTM GARE ROUTIERE", None, "2026-11-18", 13000, None, "MAD", "Transport", "fr"),
    (24, "hand", "hand", "Petit taxi n 1234", None, "2026-11-12", 3000, None, "MAD", "Transport", "fr"),
    (25, "hand", "hand", "Snack Chez Ali", None, "2026-11-09", 7500, None, "MAD", "Repas", "fr"),
    (26, "hand", "hand", "Souk Fournitures", None, "2026-11-06", 12000, None, "MAD", "Fournitures", "fr"),
    (27, "ticket", "clean", "مطعم الأندلس", "006677889000045", "2026-11-11", 18500, 10, "MAD", "Repas", "ar"),
    (28, "ticket", "faded", "مكتبة الوحدة", None, "2026-11-04", 9600, None, "MAD", "Fournitures", "ar"),
    (29, "ticket", "clean", "CAFE DE FLORE PARIS", None, "2026-10-25", 1850, 10, "EUR", "Repas", "fr"),
    (30, "invoice", "clean", "UBER LONDON", None, "2026-10-24", 2240, 20, "GBP", "Transport", "fr"),
]

ITEMS = {
    "Repas": [("Tajine poulet", 0.45), ("Eau minérale", 0.1), ("Thé à la menthe", 0.2), ("Salade marocaine", 0.25)],
    "Transport": [("Course", 1.0)],
    "Fournitures": [("Cahiers A4", 0.4), ("Stylos", 0.2), ("Classeurs", 0.4)],
    "Hébergement": [("Nuitée chambre double", 0.9), ("Taxe de séjour", 0.1)],
}
CURRENCY_WORD = {"MAD": "DH", "EUR": "€", "GBP": "GBP"}


def lines_for(spec):
    n, kind, quality, supplier, ice, date, total, rate, currency, category, lang = spec
    y, m, d = date.split("-")
    day = f"{d}/{m}/{y}"
    cur = CURRENCY_WORD[currency]
    if lang == "ar":
        # Bilingual, as many Moroccan tickets: the date stays in Latin digits.
        rows = [supplier, "الدار البيضاء", f"Date : {day}"]
        if ice:
            rows.append(f"ICE {ice}")
        if rate is not None:
            rows.append(f"TVA {rate}% {mad(vat_of(total, rate))}")
        rows.append(f"المجموع {mad(total)} درهم")
        rows.append("شكرا لزيارتكم")
        return rows
    if kind == "hand":
        return [supplier, f"Le {day}", f"Total {mad(total)} DH", "Merci"]
    rows = [supplier, "Casablanca" if currency == "MAD" else "", ]
    if ice:
        rows.append(f"ICE : {ice}")
    rows.append(f"{'Facture' if kind == 'invoice' else 'Ticket'} N° {random.randint(100, 9999)}")
    rows.append(f"Date : {day} {random.randint(8, 21):02d}:{random.randint(0, 59):02d}")
    items = ITEMS[category]
    left = total
    for i, (label, share) in enumerate(items):
        price = left if i == len(items) - 1 else round(total * share)
        left -= price
        rows.append(f"{label:<22}{mad(price):>10}")
    if rate is not None:
        vat = vat_of(total, rate)
        rows.append(f"{'TOTAL HT':<22}{mad(total - vat):>10}")
        rows.append(f"{f'TVA {rate}%':<22}{mad(vat):>10}")
    rows.append(f"{'TOTAL TTC':<16}{mad(total):>10} {cur}")
    if kind == "ticket" and currency == "MAD" and total < 50000:
        paid = ((total // 10000) + 1) * 10000
        rows.append(f"{'Espèces':<22}{mad(paid):>10}")
        rows.append(f"{'Rendu':<22}{mad(paid - total):>10}")
    rows.append("Merci de votre visite")
    return [r for r in rows if r != ""]


def draw(rows, kind, lang):
    width = 640 if kind != "invoice" else 900
    font_name = {"hand": "hand", "invoice": "sans"}.get(kind, "mono")
    size = 30 if kind == "hand" else 24
    font = ImageFont.truetype(FONTS[font_name], size)
    bold = ImageFont.truetype(FONTS["mono_bold"] if kind != "hand" else FONTS["hand"], size + 4)
    arabic = ImageFont.truetype(FONTS["arabic"], size + 2, layout_engine=ImageFont.Layout.RAQM)
    line_h = int(size * 1.6)
    height = 120 + line_h * len(rows) + 80
    paper = (252, 251, 246) if kind != "hand" else (250, 247, 232)
    img = Image.new("RGB", (width, height), paper)
    dr = ImageDraw.Draw(img)
    y = 60
    for i, row in enumerate(rows):
        has_ar = any("؀" <= c <= "ۿ" for c in row)
        f = arabic if has_ar else (bold if i == 0 else font)
        if has_ar or i == 0:
            w = dr.textlength(row, font=f)
            x = (width - w) / 2
        else:
            x = 50
        ink = (25, 25, 30) if kind != "hand" else (20, 40, 120)
        if has_ar:
            dr.text((x, y), row, font=f, fill=ink, language="ar")
        else:
            dr.text((x, y), row, font=f, fill=ink)
        y += line_h
    return img


def wave(img, amp=6, period=180):
    w, h = img.size
    out = Image.new("RGB", (w, h), (235, 233, 226))
    src = img.load()
    dst = out.load()
    for yy in range(h):
        dx = int(amp * math.sin(2 * math.pi * yy / period))
        for xx in range(w):
            sx = xx + dx
            if 0 <= sx < w:
                dst[xx, yy] = src[sx, yy]
    return out


def degrade(img, quality):
    if quality == "blur":
        img = img.filter(ImageFilter.GaussianBlur(1.6))
    elif quality == "faded":
        img = ImageEnhance.Contrast(img).enhance(0.35)
        img = ImageEnhance.Brightness(img).enhance(1.15)
    elif quality == "tilt":
        img = img.rotate(random.choice([-5, -3.5, 4, 6]), expand=True, fillcolor=(205, 200, 190))
    elif quality == "crumpled":
        img = wave(img, amp=7, period=random.choice([140, 170, 210]))
        img = img.filter(ImageFilter.GaussianBlur(0.6))
    elif quality == "shadow":
        w, h = img.size
        shade = Image.new("L", (w, h))
        sd = ImageDraw.Draw(shade)
        for xx in range(w):
            sd.line([(xx, 0), (xx, h)], fill=int(150 * xx / w))
        dark = ImageEnhance.Brightness(img).enhance(0.45)
        img = Image.composite(dark, img, shade)
    elif quality == "lowres":
        w, h = img.size
        img = img.resize((int(w * 0.38), int(h * 0.38)), Image.BILINEAR).resize((w, h), Image.NEAREST)
    elif quality == "hand":
        img = img.rotate(-2, expand=True, fillcolor=(210, 205, 190))
    # A light sensor noise on every photo.
    noise = Image.effect_noise(img.size, 10).convert("RGB")
    img = Image.blend(img, noise, 0.06)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    manifest = []
    for spec in SPECS:
        n, kind, quality, supplier, ice, date, total, rate, currency, category, lang = spec
        rows = lines_for(spec)
        img = degrade(draw(rows, kind, lang), quality)
        img.thumbnail((1000, 1600))
        name = f"r{n:02d}.jpg"
        img.save(os.path.join(OUT, name), quality=80)
        printed_vat = rate is not None
        manifest.append({
            "file": name,
            "quality": quality,
            "language": lang,
            "lines": rows,
            "expected": {
                "supplier": supplier,
                "ice": ice,
                "date": date,
                "amount": total,
                "vat": vat_of(total, rate) if printed_vat else None,
                "rate": rate if printed_vat else None,
                "currency": currency,
                "category": category,
            },
        })
    with open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump({"version": 1, "receipts": manifest}, f, ensure_ascii=False, indent=1)
    print(f"{len(manifest)} receipts written to {OUT}")


if __name__ == "__main__":
    main()
