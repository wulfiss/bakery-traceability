#!/usr/bin/env python3
"""V6.6 source extraction (spec §55): PEDIDOS DE PANADERÍA (1).xlsx -> review CSVs.

Outputs (this directory):
  production_suggestions.csv           one row per sheet x code (§42)
  production_suggestion_items.csv      one row per non-empty source cell (§43)
  production_suggestion_ambiguities.csv one row per ambiguous item

Rules (spec §44-47):
- source_text keeps the EXACT cell text (trailing spaces included).
- Fractions 1/2 and 1 1/2 are parsed numerically (unambiguous structure, §44);
  the original text is preserved in source_text.
- Product matching is EXACT (casefold + whitespace collapse) against the
  current products master only. No silent merging of spelling variants (§45).
  Master snapshot (read-only query, 2026-09-16):
    baguette   -> ddf2c5c2-7ab6-4532-93b9-824d84ab59c2 (morning)
    pan mignon -> 35ae09e7-8e14-431a-9482-13324e348cef (night)
- shift_candidate comes ONLY from a reliably matched product's default
  shift (§46). Rows under the "PARA LA TARDE:" label get
  status=review_required, shift_candidate=null, no inference.
- status: ready = matched product + valid quantity + unit + shift (§47);
  review_required = anything unresolved.
- No Supabase access in this script (read-only master snapshot above).

Re-run: python3 extract_v6.py   (idempotent, regenerates all three CSVs)
"""

import csv
import os
import re
import zipfile
from xml.etree import ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "source", "PEDIDOS DE PANADERÍA (1).xlsx")

M = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
R = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"

# weekday per sheet (1=Mon .. 6=Sat). Sheet names come from the workbook;
# SÁBADO has a trailing space in its name.
WEEKDAYS = {
    "LUNES": 1,
    "MARTES": 2,
    "MIÉRCOLES": 3,
    "JUEVES": 4,
    "VIERNES": 5,
    "SÁBADO ": 6,
}

# products master snapshot (read-only query, 2026-09-16): normalized name -> (id, default shift)
PRODUCTS = {
    "baguette": ("ddf2c5c2-7ab6-4532-93b9-824d84ab59c2", "morning"),
    "pan mignon": ("35ae09e7-8e14-431a-9482-13324e348cef", "night"),
}

# §45 spelling-variant families present in THIS workbook (surfaced for review,
# never merged). Most specific family wins per product text.
VARIANT_GROUPS = [
    ("palmerita family", ["palmerita", "palmeritas"]),
    ("trencitas/trenzas family", ["trencitas saborizadas", "trenzas saborizadas", "trencitas"]),
    ("pan lactal family", ["pan lactal salvado", "pan lactal integral", "pan lactal de salvado", "pan lactal"]),
    ("hamburguesa family", ["pan hamburguesa", "hamburguesas"]),
    ("miga family", ["miga entero", "miga"]),
    ("hojaldre family", ["hojaldré (membrillo y crema)", "hojaldre (membrillo y crema)", "hojaldre membrillo y crema"]),
    ("medialunas kind", ["medialunas"]),  # bare "medialunas" = which kind?
]

UNITS = ["lata", "latas", "bolsa", "bolsas", "carro", "carros", "kg"]

Q_WORD = re.compile(r"^un\b", re.I)
Q_MIXED = re.compile(r"^(\d+)\s+(\d+)/(\d+)\b")
Q_FRAC = re.compile(r"^(\d+)/(\d+)\b")
Q_INT = re.compile(r"^(\d+)(?=\s*$|\s|kg|latas?|bolsas?|carros?|miga\b)")


def read_workbook(path):
    """Return {sheet_name: {row: {col: value}}} for all non-empty cells."""
    z = zipfile.ZipFile(path)
    shared = []
    if "xl/sharedStrings.xml" in z.namelist():
        root = ET.fromstring(z.read("xl/sharedStrings.xml"))
        for si in root.iter(M + "si"):
            shared.append("".join(t.text or "" for t in si.iter(M + "t")))
    wb = ET.fromstring(z.read("xl/workbook.xml"))
    rels = ET.fromstring(z.read("xl/_rels/workbook.xml.rels"))
    relmap = {r.get("Id"): r.get("Target") for r in rels}
    out = {}
    for sh in wb.find(M + "sheets"):
        target = relmap[sh.get(R)]
        if not target.startswith("xl/"):
            target = "xl/" + target
        root = ET.fromstring(z.read(target))
        rows = {}
        for c in root.iter(M + "c"):
            ref, t = c.get("r"), c.get("t")
            v = c.find(M + "v")
            is_node = c.find(M + "is")
            val = None
            if t == "s" and v is not None:
                val = shared[int(v.text)]
            elif t == "inlineStr" and is_node is not None:
                val = "".join(x.text or "" for x in is_node.iter(M + "t"))
            elif v is not None:
                val = v.text
            if val is None:
                continue
            m = re.match(r"([A-Z]+)(\d+)", ref)
            rows.setdefault(int(m.group(2)), {})[m.group(1)] = val
        out[sh.get("name")] = rows
    return out


def norm(s):
    return re.sub(r"\s+", " ", s.casefold()).strip()


def parse_item(raw):
    """Parse one source cell. Returns candidates + ambiguity categories."""
    text = raw.strip()
    categories, notes = [], []
    quantity, unit, product = None, "", ""

    # --- quantity ---
    m = Q_WORD.match(text)
    if m:
        quantity = 1
        text = text[m.end():].strip()
        categories.append("word_quantity")
        notes.append("quantity is the word 'Un' (parsed as 1; confirm)")
    else:
        m = Q_MIXED.match(text)
        if m:
            quantity = int(m.group(1)) + int(m.group(2)) / int(m.group(3))
            text = text[m.end():].strip()
            notes.append(f"mixed fraction '{m.group(0)}' parsed as {quantity:g} (§44 unambiguous)")
        else:
            m = Q_FRAC.match(text)
            if m:
                quantity = int(m.group(1)) / int(m.group(2))
                text = text[m.end():].strip()
                notes.append(f"fraction '{m.group(0)}' parsed as {quantity:g} (§44 unambiguous)")
            else:
                m = Q_INT.match(text)
                if m:
                    quantity = int(m.group(1))
                    text = text[m.end():].strip()
                else:
                    categories.append("missing_quantity")
                    notes.append("no numeric quantity in source text")

    # --- unit + product ---
    if quantity is not None:
        if re.fullmatch(r"miga\b", text, re.I):
            # "1 miga": the word is both unit and product (whole miga) - §44 review example
            unit, text, product = "miga", "", "miga"
            categories.append("miga_unit_variant")
            notes.append("'1 miga': 'miga' acts as both unit and product; product = Pan miga (to be created) - §44 review example")
        else:
            for u in UNITS:
                mm = re.match(rf"^{u}\b(\s+de\b)?\s*", text, re.I)
                if mm:
                    unit = u
                    text = text[mm.end():].strip()
                    break
            else:
                categories.append("missing_unit")
                notes.append("no recognizable unit after quantity")
            product = text
    else:
        # no quantity: the whole text is the product candidate; unit unknown too
        categories.append("missing_unit")
        notes.append("no unit in source text (no quantity found either)")
        product = text

    if not product:
        categories.append("product_missing")
        notes.append("no product text left after quantity/unit")
    product = norm(product)

    if product:
        for label, forms in VARIANT_GROUPS:
            if product in forms:
                categories.append(f"name_variant:{label}")
                break
        if product == "pan":
            categories.append("generic_product")
            notes.append("'pan' alone is too generic to match a product")

    # --- product match (exact normalized only, §45) ---
    matched_id, shift = "", ""
    if product and product in PRODUCTS:
        matched_id, shift = PRODUCTS[product]
    elif product:
        categories.append("unknown_product")

    return {
        "quantity": quantity,
        "unit": unit,
        "product": product,
        "matched_id": matched_id,
        "shift": shift,
        "categories": categories,
        "notes": notes,
    }


def fmt_q(q):
    return "" if q is None else f"{q:g}"


def main():
    sheets = read_workbook(SRC)
    items, ambiguities, sug_rows = [], [], []
    per_suggestion = {}  # (sheet, code) -> [item dict] (headers excluded)
    afternoon_span = {}  # sheet -> (first, last afternoon row)

    for sheet, rows in sheets.items():
        if sheet not in WEEKDAYS:
            raise SystemExit(f"unexpected sheet {sheet!r}")
        weekday = WEEKDAYS[sheet]
        header_codes = sorted(rows.get(1, {}), key=lambda c: (len(c), c))
        afternoon_from = None

        for row in sorted(rows):
            rowcells = rows[row]
            for col in sorted(rowcells, key=lambda c: (len(c), c)):
                raw = rowcells[col]
                if row == 1:  # code header row (A, B, C, ...)
                    continue
                if "para la tarde" in raw.strip().casefold():
                    afternoon_from = row  # section header; not an item
                    continue
                afternoon = afternoon_from is not None and row > afternoon_from
                p = parse_item(raw)
                if afternoon:
                    p["categories"].insert(0, "saturday_afternoon")
                    p["shift"] = ""
                    p["notes"].append("PARA LA TARDE source section: shift_candidate=null, do not infer (§46)")
                    span = afternoon_span.setdefault(sheet, [row, row])
                    span[0], span[1] = min(span[0], row), max(span[1], row)
                ready = bool(p["matched_id"] and p["quantity"] is not None and p["unit"] and p["shift"] and p["product"])
                item = {
                    "source_sheet": sheet.strip(),
                    "suggestion_code": col,
                    "source_row": row,
                    "source_text": raw,
                    "quantity_candidate": fmt_q(p["quantity"]),
                    "unit_candidate": p["unit"],
                    "product_candidate": p["product"],
                    "matched_product_id": p["matched_id"],
                    "shift_candidate": p["shift"],
                    "status": "ready" if ready else "review_required",
                    "notes": "; ".join(dict.fromkeys(p["notes"])),
                }
                items.append(item)
                per_suggestion.setdefault((sheet, col), []).append(item)
                if p["categories"]:
                    ambiguities.append(
                        {
                            "source_sheet": sheet.strip(),
                            "suggestion_code": col,
                            "source_row": row,
                            "source_text": raw,
                            "categories": ";".join(dict.fromkeys(p["categories"])),
                            "notes": item["notes"],
                        }
                    )

        for col in header_codes:
            it = per_suggestion.get((sheet, col), [])
            n_ready = sum(1 for x in it if x["status"] == "ready")
            n = len(it)
            notes = f"{n} item cells; {n_ready} ready; {n - n_ready} review_required"
            if sheet in afternoon_span:
                a, b = afternoon_span[sheet]
                notes += f"; rows {a}-{b} are under PARA LA TARDE (not inferable, §46)"
            sug_rows.append(
                {
                    "source_sheet": sheet.strip(),
                    "weekday": weekday,
                    "suggestion_code": col,
                    "status": "ready" if (n and n_ready == n) else "review_required",
                    "notes": notes,
                }
            )

    with open(os.path.join(HERE, "production_suggestions.csv"), "w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=["source_sheet", "weekday", "suggestion_code", "status", "notes"])
        w.writeheader()
        w.writerows(sug_rows)
    with open(os.path.join(HERE, "production_suggestion_items.csv"), "w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(
            f,
            fieldnames=[
                "source_sheet",
                "suggestion_code",
                "source_row",
                "source_text",
                "quantity_candidate",
                "unit_candidate",
                "product_candidate",
                "matched_product_id",
                "shift_candidate",
                "status",
                "notes",
            ],
        )
        w.writeheader()
        w.writerows(items)
    with open(os.path.join(HERE, "production_suggestion_ambiguities.csv"), "w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(
            f, fieldnames=["source_sheet", "suggestion_code", "source_row", "source_text", "categories", "notes"]
        )
        w.writeheader()
        w.writerows(ambiguities)

    print(f"suggestions rows: {len(sug_rows)}")
    print(
        "item rows: "
        f"{len(items)} (ready={sum(1 for i in items if i['status'] == 'ready')}, "
        f"review_required={sum(1 for i in items if i['status'] == 'review_required')})"
    )
    print(f"ambiguity rows: {len(ambiguities)}")


if __name__ == "__main__":
    main()
