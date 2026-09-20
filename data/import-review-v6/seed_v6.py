#!/usr/bin/env python3
"""V6.7 seed driver (spec §56): review CSV -> seed_v6_suggestion_templates payload.

Reads production_suggestion_items.csv (V6.6 output) and keeps ONLY rows that are
fully resolved:

  1. not a SÁBADO "PARA LA TARDE" row (rows 15-20; spec §46: never seeded);
  2. quantity: numeric, or missing -> 1 (user decision 2026-09-16: template
     quantities are provisional); word "Un" parsed as 1;
  3. recognized unit present (lata/latas/bolsa/bolsas/carro/carros/kg; "1 miga"
     has no standard unit - spec §44 review example, stays out); rows whose
     quantity defaulted to 1 may use an agreed unit (PROVISIONAL_UNITS, user
     confirmed: "1 carro" for "Pan salvado para hacer tostada");
  4. product candidate maps to the locked master list (RESOLUTION below).

Everything else is excluded and reported in seed_summary.txt with the reason.

The payload is ordered by (weekday, code), and within each group by source_row
ascending = source order preserved (spec §56).

Usage:
  python3 seed_v6.py                 # writes seed_payload.json + seed_summary.txt
  python3 seed_v6.py --execute       # additionally calls the RPC as the admin user
  python3 seed_v6.py --execute --reseed
      # dev-time master re-seed: first clears the previously seeded
      # production_suggestion_items + production_suggestions (refusing if any
      # daily selection exists), products are kept and reused

No database access without --execute. With --execute it needs the local
Supabase docker container (supabase_db_bakery-traceability) and runs:
  set_config('request.jwt.claims', sub=<ADMIN_USER_ID>) + the RPC in one
  transaction.
"""

import csv
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ITEMS_CSV = os.path.join(HERE, "production_suggestion_items.csv")
PAYLOAD = os.path.join(HERE, "seed_payload.json")
SUMMARY = os.path.join(HERE, "seed_summary.txt")

ADMIN_USER_ID = "8a271366-4b41-4d2f-813c-4d553c83b968"  # local admin profile
DB_CONTAINER = "supabase_db_bakery-traceability"

WEEKDAY_OF_SHEET = {
    "LUNES": 1,
    "MARTES": 2,
    "MIÉRCOLES": 3,
    "JUEVES": 4,
    "VIERNES": 5,
    "SÁBADO": 6,
}
CODES_BY_WEEKDAY = {1: "ABCD", 2: "ABCDE", 3: "ABCD", 4: "ABCD", 5: "ABCD", 6: "ABCD"}

# SÁBADO "PARA LA TARDE:" header is row 14; afternoon rows are 15..20.
SATURDAY_AFTERNOON_FIRST_ROW = 15

# Locked master decisions (user-confirmed in an earlier session):
# workbook product candidate -> (master product name, default shift, decision note).
RESOLUTION = {
    "baguette": ("Baguette", "morning", "existing master product (V5 seed)"),
    "cara sucia": ("Cara sucia", "morning", "locked MAÑANA list"),
    "chip": ("Chip", "morning", "locked MAÑANA list"),
    "pan pebete": ("Pan pebete", "morning", "locked MAÑANA list"),
    "chipacitos": ("Chipacitos", "night", "locked NOCHE list"),
    "palmerita": ("Palmeritas", "night", "locked NOCHE list (spelling variant: singular)"),
    "palmeritas": ("Palmeritas", "night", "locked NOCHE list"),
    "trencitas": ("Trencitas dulces", "night", "locked TARDE->NOCHE list (bare 'trencitas')"),
    "trencitas saborizadas": ("Trencitas dulces", "night", "locked list ('saborizadas' -> locked name 'dulces')"),
    "trenzas saborizadas": ("Trencitas dulces", "night", "locked list ('trenzas' -> locked name 'trencitas')"),
    "medialunas rellenas": ("Medialunas rellenas", "night", "locked TARDE->NOCHE list"),
    "medialunas dulces": ("Medialunas dulces", "night", "locked TARDE->NOCHE list (rows lack a unit)"),
    "medialunas saladas": ("Medialunas saladas", "morning", "locked MAÑANA list (rows lack a unit)"),
    "pan lactal": ("Pan lactal", "night", "locked NOCHE list"),
    "pan lactal salvado": ("Pan lactal", "night", "locked list ('salvado' form -> locked name)"),
    "pan lactal de salvado": ("Pan lactal", "night", "locked list ('de salvado' form -> locked name)"),
    "pan lactal integral": ("Pan integral", "night", "locked list ('pan lactal integral' is the workbook's only integral form)"),
    "pan salvado para hacer tostadas": ("Pan salvado", "morning", "locked MAÑANA list (long form -> locked name)"),
    "pan salvado para hacer tostada": (
        "Pan salvado",
        "morning",
        "locked MAÑANA list (singular 'tostada' form; provisional qty 1 / unit carro per user decision 2026-09-16)",
    ),
    "prepizzas": ("Prepizza", "night", "locked NOCHE list (plural -> locked name)"),
    "hamburguesas": ("Hamburguesa", "night", "locked NOCHE list (plural -> locked name)"),
    "pan hamburguesa": ("Hamburguesa", "night", "locked NOCHE list"),
    "pan pernil": ("Pan pernil", "night", "locked NOCHE list"),
    "pan árabe": ("Pan árabe", "night", "locked NOCHE list"),
    "miga entero": ("Pan miga", "night", "locked NOCHE list ('miga entero' -> locked name)"),
    "miga": ("Pan miga", "night", "locked NOCHE list ('1 miga' has no standard unit)"),
}

UNIT_OK = {"lata", "latas", "bolsa", "bolsas", "carro", "carros", "kg"}

# User decision 2026-09-16: template quantities are provisional. A row
# without a numeric quantity gets suggested_quantity 1; the affected rows
# ("Pan salvado para hacer tostada": MARTES E R14, MIÉRCOLES B R13,
# JUEVES B R16) also lack a unit and use the confirmed unit "carro"
# (i.e. "1 carro"). "Un carro de pan para hacer tostadas" (JUEVES A R15)
# is a DIFFERENT product (user: "sin salvado"), not in the locked list.
PROVISIONAL_QTY = "1"
PROVISIONAL_UNITS = {"pan salvado para hacer tostada": "carro"}


def build_payload():
    items = list(csv.DictReader(open(ITEMS_CSV, encoding="utf-8-sig")))
    selected, excluded = [], []
    for r in items:
        sheet = r["source_sheet"]
        row = int(r["source_row"])
        code = r["suggestion_code"]
        product = r["product_candidate"]
        unit = r["unit_candidate"]
        qty = r["quantity_candidate"]
        text = r["source_text"]

        if sheet == "SÁBADO" and row >= SATURDAY_AFTERNOON_FIRST_ROW:
            excluded.append((r, "saturday_para_la_tarde: shift not inferable (spec §46) - never seeded"))
            continue
        provisional = qty == ""
        if provisional:
            qty = PROVISIONAL_QTY  # user decision 2026-09-16: provisional quantity 1
        # The old word_quantity gate ('Un' -> 1 unconfirmed) is superseded by
        # the same decision: quantities are provisional. That row (JUEVES A
        # R15) now falls out on product_not_resolved ('pan para hacer
        # tostadas' is "sin salvado", user-confirmed different product).
        if unit == "miga":
            excluded.append((r, "miga_unit: '1 miga' - unit/product split unresolved (spec §44 review example)"))
            continue
        if unit not in UNIT_OK:
            if provisional and unit == "" and product in PROVISIONAL_UNITS:
                unit = PROVISIONAL_UNITS[product]  # user-confirmed provisional unit
            else:
                excluded.append((r, "missing_unit: no recognized unit after quantity"))
                continue
        if product not in RESOLUTION:
            excluded.append((r, f"product_not_resolved: '{product}' is not in the locked master list"))
            continue

        name, shift, note = RESOLUTION[product]
        selected.append(
            {
                "weekday": WEEKDAY_OF_SHEET[sheet],
                "code": code,
                "source_sheet": sheet,
                "source_row": row,
                "source_text": text,
                "product_name": name,
                "default_shift": shift,
                "suggested_quantity": qty,
                "unit": unit,
                "_note": note,
            }
        )

    # order: (weekday, code) groups, source_row ascending within group
    selected.sort(key=lambda x: (x["weekday"], x["code"], x["source_row"]))
    # safety: code allowed per weekday
    for s in selected:
        assert s["code"] in CODES_BY_WEEKDAY[s["weekday"]], f"code {s['code']} not allowed for weekday {s['weekday']}"
    payload = [{k: v for k, v in s.items() if k != "_note"} for s in selected]
    return payload, selected, excluded


def summarize(payload, selected, excluded):
    lines = []
    lines.append(f"payload items: {len(payload)} (of {len(payload) + len(excluded)} review rows)")
    lines.append("")
    lines.append("counts by weekday / suggestion (source_row order preserved):")
    by = {}
    for s in selected:
        by.setdefault((s["weekday"], s["code"]), []).append(s)
    for (w, c) in sorted(by):
        rows = by[(w, c)]
        lines.append(f"  weekday {w} code {c}: {len(rows)} items  (rows {', '.join(str(x['source_row']) for x in rows)})")
    lines.append("")
    lines.append("products in payload:")
    prods = {}
    for s in selected:
        prods.setdefault((s["product_name"], s["default_shift"]), []).append(s)
    for (name, shift), rows in sorted(prods.items()):
        lines.append(f"  {name} ({shift}): {len(rows)} items")
    lines.append("")
    lines.append("excluded rows by reason:")
    ex_by_reason = {}
    for r, reason in excluded:
        ex_by_reason.setdefault(reason.split(":")[0], []).append((r, reason))
    for reason in sorted(ex_by_reason):
        rows = ex_by_reason[reason]
        lines.append(f"  {reason} x{len(rows)}")
        for r, full in rows[:60]:
            lines.append(f"      {r['source_sheet']} {r['suggestion_code']} R{r['source_row']}: {r['source_text']!r}")
    lines.append("")
    lines.append("resolution notes (workbook form -> locked master name):")
    notes = {}
    for r in csv.DictReader(open(ITEMS_CSV, encoding="utf-8-sig")):
        p = r["product_candidate"]
        if p in RESOLUTION and p not in notes:
            name, shift, note = RESOLUTION[p]
            notes[p] = (name, shift, note)
    for p in sorted(notes):
        name, shift, note = notes[p]
        lines.append(f"  {p!r} -> {name!r} ({shift}) - {note}")
    text = "\n".join(lines) + "\n"
    with open(SUMMARY, "w", encoding="utf-8") as f:
        f.write(text)
    return text


def _psql(stdin, extra_args=()):
    args = ["docker", "exec", "-i", DB_CONTAINER, "psql", "-U", "postgres", "-d", "postgres", "-v", "ON_ERROR_STOP=1"]
    args += list(extra_args)
    res = subprocess.run(args, input=stdin, capture_output=True, text=True)
    print(res.stdout, end="")
    if res.returncode != 0:
        print(res.stderr, file=sys.stderr)
        raise SystemExit(res.returncode)
    return res


def reseed_clear():
    """Wipe the previously-seeded master suggestion data before re-seeding.

    The two tables are master/config data (spec §69 master layer), not
    production history. Refuse unless no downstream layer depends on them:
    no daily selections, and no selection item referencing a suggestion
    item. Products are intentionally left untouched (reused, not recreated).
    """
    check = (
        "select "
        "(select count(*) from public.daily_production_selections), "
        "(select count(*) from public.daily_production_selection_items "
        " where source_suggestion_item_id is not null);"
    )
    res = subprocess.run(
        ["docker", "exec", "-i", DB_CONTAINER, "psql", "-U", "postgres", "-d", "postgres", "-t", "-A", "-F", "|", "-c", check],
        capture_output=True,
        text=True,
    )
    parts = [p for p in res.stdout.strip().split("|")]
    sel = int(parts[0]) if len(parts) > 0 and parts[0].strip() else 0
    refs = int(parts[1]) if len(parts) > 1 and parts[1].strip() else 0
    if sel or refs:
        raise SystemExit(f"reseed refused: downstream dependents exist (selections={sel}, refs={refs}); not a clean master re-seed")
    _psql(
        stdin=(
            "begin;\n"
            "delete from public.production_suggestion_items;\n"
            "delete from public.production_suggestions;\n"
            "commit;\n"
        )
    )
    print("reseed: cleared production_suggestion_items + production_suggestions (master layer, no downstream dependents)")


def execute(payload):
    body = json.dumps(payload, ensure_ascii=False)
    assert "$seed$" not in body
    _psql(
        stdin=(
            "begin;\n"
            f"select set_config('request.jwt.claims', '{{\"sub\": \"{ADMIN_USER_ID}\"}}', false);\n"
            f"select public.seed_v6_suggestion_templates($seed${body}$seed$::jsonb);\n"
            "commit;\n"
        )
    )


if __name__ == "__main__":
    payload, selected, excluded = build_payload()
    with open(PAYLOAD, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=1)
    text = summarize(payload, selected, excluded)
    print(text)
    if "--execute" in sys.argv:
        if "--reseed" in sys.argv:
            reseed_clear()
        execute(payload)
