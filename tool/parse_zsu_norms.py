# One-off parser: zakononline dump of Order 232 → assets/zsu_norms.json
import json
import re
from pathlib import Path

SRC = Path(r"C:\Users\ep000\.cursor\projects\e-W-Node\agent-tools\292111fe-dfea-4245-88f5-ff8bc36296a2.txt")
OUT = Path(r"E:\W-Node\assets\zsu_norms.json")

SKIP_PREFIXES = ("{", "__________", "Примітки:")
UNIT_RE = re.compile(
    r"^(штука|комплект|пара|пари|шт\.?|к-т|к-та|пар\.?|набір|одиниця|компл\.?)$",
    re.I,
)
ITEM_N_RE = re.compile(r"^\d+(?:\.\d+)?$")
LETTERS_RE = re.compile(r"[А-Яа-яІіЇїЄєҐґA-Za-z]")
SECTIONS = {
    "головні убори",
    "головні убори та шарфи",
    "обмундирування",
    "спорядження",
    "взуття",
    "білизна",
    "інші предмети",
    "засоби захисту",
    "екіпірування",
}


def cells_of(text: str) -> list[str]:
    out = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith(SKIP_PREFIXES):
            continue
        out.append(line)
    return out


def is_n(s: str) -> bool:
    return bool(ITEM_N_RE.match(s)) and float(s) < 200


def is_section(s: str) -> bool:
    t = s.lower().rstrip("*").strip()
    if t in SECTIONS:
        return True
    if t.startswith("1. ") or t.startswith("2. "):
        return True
    return False


def looks_term(s: str) -> bool:
    if s in ("-", "—"):
        return True
    if "строк служби" in s.lower() or "зносу" in s.lower():
        return True
    return bool(re.fullmatch(r"\d+(?:[.,]\d+)?", s))


def looks_qty(s: str) -> bool:
    return s in ("-", "—") or bool(re.fullmatch(r"\d+(?:[.,]\d+)?", s))


def term(s: str) -> str:
    if s in ("-", "—", ""):
        return "—"
    if "строк служби" in s.lower() or "зносу" in s.lower():
        return "до зносу"
    if re.fullmatch(r"\d+(?:[.,]\d+)?", s):
        return f"{s.replace(',', '.')} р."
    return s


def qty(s: str) -> str:
    return "—" if s in ("-", "—") else s


def is_new_row(cells: list[str], i: int) -> bool:
    if i >= len(cells):
        return True
    if cells[i].startswith("НОРМА №"):
        return True
    if is_section(cells[i]):
        return True
    if is_n(cells[i]):
        return True
    return False


def take(cells, i, n=1):
    vals = cells[i:i + n]
    if len(vals) < n:
        return None, i
    return vals, i + n


def finish_item(n, name, unit, q, tp, tw):
    if is_section(name) or name.lower() == "строк служби":
        return None
    if not LETTERS_RE.search(name) or len(name) < 3:
        return None
    if not looks_term(tp if " р." not in str(tp) else tp.replace(" р.", "")) and not looks_term(tp):
        # tp already formatted later; check raw before term()
        pass
    return {
        "n": n,
        "name": name,
        "unit": unit,
        "qtyPeace": qty(q),
        "qtyWar": qty(q),
        "termPeace": term(tp),
        "termWar": term(tw),
    }


def parse_bek(cells, i):
    n = cells[i]
    if i + 3 >= len(cells) or not UNIT_RE.match(cells[i + 2]):
        return None, i + 1
    name, unit = cells[i + 1], cells[i + 2]
    i += 3
    vals, i = take(cells, i, 6)
    if not vals:
        return None, i
    q, t1, t2, t3, t4, t5 = vals
    if not looks_qty(q) or not looks_term(t1):
        return None, i
    # notes
    if not is_new_row(cells, i):
        i += 1
    # optional inventory
    if not is_new_row(cells, i):
        i += 1
    item = finish_item(n, name, unit, q, t1, t5)
    return item, i


def parse_bsk(cells, i):
    n = cells[i]
    if i + 3 >= len(cells) or not UNIT_RE.match(cells[i + 2]):
        return None, i + 1
    name, unit = cells[i + 1], cells[i + 2]
    i += 3
    vals, i = take(cells, i, 3)
    if not vals:
        return None, i
    q, tp, tw = vals
    if not looks_qty(q) or not looks_term(tp):
        return None, i
    if not is_new_row(cells, i):
        i += 1
    return finish_item(n, name, unit, q, tp, tw), i


def parse_sso(cells, i):
    n = cells[i]
    if i + 3 >= len(cells) or not UNIT_RE.match(cells[i + 2]):
        return None, i + 1
    name, unit = cells[i + 1], cells[i + 2]
    i += 3
    vals, i = take(cells, i, 2)
    if not vals:
        return None, i
    q, t = vals
    if not looks_qty(q) or not looks_term(t):
        return None, i
    if not is_new_row(cells, i):
        i += 1
    return finish_item(n, name, unit, q, t, t), i


def parse_named_qty_terms(cells, i, terms, peace_i, war_i):
    n = cells[i]
    if i + 2 >= len(cells):
        return None, i + 1
    name = cells[i + 1]
    if is_section(name) or is_n(name):
        return None, i + 1
    i += 2
    need = 1 + terms
    vals, i = take(cells, i, need)
    if not vals:
        return None, i
    q, *ts = vals
    if not looks_qty(q) or not looks_term(ts[0]):
        return None, i
    if not is_new_row(cells, i):
        i += 1
    tp = ts[peace_i] if peace_i < len(ts) else ts[0]
    tw = ts[war_i] if war_i < len(ts) else ts[-1]
    return finish_item(n, name, "", q, tp, tw), i


def parse_block(all_cells, start_title, end_title, kind):
    a = next(i for i, c in enumerate(all_cells) if c.startswith(start_title))
    b = next(i for i, c in enumerate(all_cells) if i > a and c.startswith(end_title))
    block = all_cells[a:b]
    # start at first real item: n + name + (unit or qty)
    i = 0
    try:
        h = next(k for k, c in enumerate(block) if c == "Назва предмета")
        i = h + 1
    except StopIteration:
        i = 1
    items = []
    steps = 0
    while i < len(block) and steps < 8000:
        steps += 1
        if block[i].startswith("НОРМА №"):
            break
        if not is_n(block[i]):
            i += 1
            continue
        if kind == "bek":
            item, i = parse_bek(block, i)
        elif kind == "bsk":
            item, i = parse_bsk(block, i)
        elif kind == "sso":
            item, i = parse_sso(block, i)
        elif kind == "everyday":
            item, i = parse_named_qty_terms(block, i, 3, 1, 2)
        elif kind == "vms8":
            item, i = parse_named_qty_terms(block, i, 2, 0, 1)
        elif kind == "simple":
            item, i = parse_named_qty_terms(block, i, 1, 0, 0)
        elif kind == "flight":
            item, i = parse_named_qty_terms(block, i, 2, 1, 0)
        else:
            i += 1
            continue
        if item:
            items.append(item)
    return items


def main():
    cells = cells_of(SRC.read_text(encoding="utf-8"))
    tables = {
        "1": {
            "code": "1",
            "title": "Бойовий єдиний комплект (БЄК)",
            "hint": "Усі сили. Кількість одна; строк кат. 1 = мирний, кат. 5 = воєнний стан",
            "items": parse_block(cells, "НОРМА № 1 забезпечення предметами бойового", "НОРМА № 2 забезпечення", "bek"),
        },
        "2": {
            "code": "2",
            "title": "Бойовий спеціальний комплект (БСК)",
            "hint": "Строки окремо для мирного часу і особливого періоду",
            "items": parse_block(cells, "НОРМА № 2 забезпечення предметами бойового", "НОРМА № 3 забезпечення", "bsk"),
        },
        "4": {
            "code": "4",
            "title": "Повсякденна форма",
            "hint": "Строк: 1 група забезпечення / 2 група забезпечення",
            "items": parse_block(cells, "НОРМА № 4 забезпечення повсякденною формою", "НОРМА № 5 забезпечення", "everyday"),
        },
        "8": {
            "code": "8",
            "title": "Корабельний склад ВМС",
            "hint": "Контракт / строкова служба",
            "items": parse_block(cells, "НОРМА № 8 забезпечення повсякденною формою одягу військовослужбовців за контрактом", "НОРМА № 9 забезпечення", "vms8"),
        },
        "12": {
            "code": "12",
            "title": "Спецодяг Повітряних Сил",
            "hint": "Радіотехнічні частини поза приміщенням",
            "items": parse_block(cells, "НОРМА № 12 забезпечення спецодягом військовослужбовців Повітряних Сил", "НОРМА № 13 забезпечення", "simple"),
        },
        "13": {
            "code": "13",
            "title": "Льотний одяг",
            "hint": "Строк: помірний клімат / жаркий клімат",
            "items": parse_block(cells, "НОРМА № 13 забезпечення льотним одягом", "НОРМА № 14 забезпечення", "flight"),
        },
        "18": {
            "code": "18",
            "title": "Десантний і льотний одяг ДШВ",
            "hint": "Інвентарне майно",
            "items": parse_block(cells, "НОРМА № 18 забезпечення десантним", "НОРМА № 19 забезпечення", "simple"),
        },
        "19": {
            "code": "19",
            "title": "Спецодяг ССО",
            "hint": "Тип С. Інвентарне майно",
            "items": parse_block(cells, "НОРМА № 19 забезпечення спеціальним одягом військовослужбовців Сил спеціальних операцій", "НОРМА № 20 забезпечення", "sso"),
        },
        "21": {
            "code": "21",
            "title": "Надводні кораблі ВМС",
            "hint": "Спецодяг у морі",
            "items": parse_block(cells, "НОРМА № 21 забезпечення спецодягом військовослужбовців надводних кораблів", "НОРМА № 22 забезпечення", "simple"),
        },
    }

    data = {
        "source": "Наказ МОУ № 232 від 29.04.2016 (z0767-16), редакція від 09.05.2025",
        "sourceUrl": "https://zakon.rada.gov.ua/laws/show/z0767-16#Text",
        "tables": tables,
        "forces": [
            {
                "id": "sv",
                "name": "Сухопутні війська",
                "short": "СВ",
                "hint": "БЄК, БСК і повсякденна форма",
                "tableIds": ["1", "2", "4"],
            },
            {
                "id": "vms",
                "name": "Військово-Морські Сили",
                "short": "ВМС",
                "hint": "БЄК, корабельний склад, надводні кораблі",
                "tableIds": ["1", "8", "21"],
            },
            {
                "id": "ps",
                "name": "Повітряні Сили",
                "short": "ПС",
                "hint": "БЄК, спецодяг ПС, льотний одяг",
                "tableIds": ["1", "12", "13"],
            },
            {
                "id": "dshv",
                "name": "Десантно-штурмові війська",
                "short": "ДШВ",
                "hint": "БЄК і десантний одяг",
                "tableIds": ["1", "18"],
            },
            {
                "id": "sso",
                "name": "Сили спеціальних операцій",
                "short": "ССО",
                "hint": "БЄК і спецодяг тип С",
                "tableIds": ["1", "19"],
            },
        ],
    }

    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    for k, t in tables.items():
        names = [x["name"] for x in t["items"][:3]]
        print(f"Norm {k}: {len(t['items']):3d}  {names}")


if __name__ == "__main__":
    main()
