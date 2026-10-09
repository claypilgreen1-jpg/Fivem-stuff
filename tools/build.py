#!/usr/bin/env python3
"""Motion Guns meta builder.

Reads tools/weapons.json, clones the vanilla base weapon templates in
tools/templates/<BASE>/ for every entry, and writes merged add-on metas plus
Lua tables into motion_guns/.

    python3 tools/build.py            # build
    python3 tools/build.py --check    # build into memory, report missing models
"""
import copy
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOLS = ROOT / "tools"
TEMPLATES = TOOLS / "templates"
RESOURCE = ROOT / "motion_guns"
META = RESOURCE / "meta"

# ox_inventory ammo items, keyed by the vanilla AmmoInfo the base weapon uses.
OX_AMMO = {
    "AMMO_PISTOL": "ammo-9",
    "AMMO_SMG": "ammo-9",
    "AMMO_RIFLE": "ammo-rifle",
    "AMMO_SHOTGUN": "ammo-shotgun",
    "AMMO_SNIPER": "ammo-sniper",
    "AMMO_SNIPER_REMOTE": "ammo-sniper",
    "AMMO_MG": "ammo-rifle2",
}
# Per-weapon ox ammo where the real-world calibre differs from the vanilla pool.
OX_AMMO_OVERRIDE = {
    "WEAPON_MOTION_1911": "ammo-45",
    "WEAPON_MOTION_DEAGLE": "ammo-50",
    "WEAPON_MOTION_PYTHON": "ammo-44",
    "WEAPON_MOTION_VECTOR": "ammo-45",
    "WEAPON_MOTION_UZI": "ammo-9",
    "WEAPON_MOTION_AK47": "ammo-rifle2",
    "WEAPON_MOTION_AK74U": "ammo-rifle2",
    "WEAPON_MOTION_M82": "ammo-heavysniper",
}
QB_TYPE = {
    "pistol": "Pistol",
    "smg": "Submachine Gun",
    "rifle": "Assault Rifle",
    "shotgun": "Shotgun",
    "sniper": "Sniper Rifle",
    "mg": "Light Machine Gun",
}
WEIGHT = {"pistol": 1000, "smg": 2500, "rifle": 3500, "shotgun": 3500, "sniper": 5000, "mg": 8000}
LOD_DIST = 500


def load(path):
    return ET.fromstring(path.read_text(encoding="utf-8-sig").encode("utf-8"))


def set_value(info, tag, value):
    el = info.find(tag)
    if el is None:
        raise KeyError(f"{info.findtext('Name')}: no <{tag}> in template")
    el.set("value", f"{value:.6f}" if isinstance(value, float) else str(value))


def build_weapon_info(w, slot_order):
    blob = load(TEMPLATES / w["base"] / "weapons.meta")
    info = blob.find(".//Item[@type='CWeaponInfo']")
    base_slot = info.findtext("Slot")
    slot = "SLOT_" + w["name"][len("WEAPON_"):]

    info.find("Name").text = w["name"]
    info.find("Model").text = w["model"]
    info.find("Slot").text = slot
    info.find("HumanNameHash").text = "WT_" + w["name"][len("WEAPON_"):]
    pickup = info.find("PickupHash")
    if pickup is not None:
        pickup.text = None  # vanilla pickups would spawn the vanilla gun

    if "clip" in w:
        set_value(info, "ClipSize", int(w["clip"]))
    if "damage" in w:
        set_value(info, "Damage", float(w["damage"]))
        set_value(info, "HudDamage", int(w["damage"]))
    if "fireRate" in w:
        set_value(info, "TimeBetweenShots", float(w["fireRate"]))
    if "range" in w:
        set_value(info, "WeaponRange", float(w["range"]))

    # Free-pack models bake their magazine into the gun, so vanilla clip
    # components would float next to it. Snipers get a scope so they can zoom.
    attach = info.find("AttachPoints")
    for child in list(attach):
        attach.remove(child)
    if w.get("scope"):
        point = ET.SubElement(attach, "Item")
        ET.SubElement(point, "AttachBone").text = "WAPScop"
        comps = ET.SubElement(point, "Components")
        comp = ET.SubElement(comps, "Item")
        ET.SubElement(comp, "Name").text = w["scope"]
        ET.SubElement(comp, "Default", value="true")

    order = None
    for entry in blob.iter("Item"):
        if entry.findtext("Entry") == base_slot:
            order = int(entry.find("OrderNumber").get("value"))
    slot_order.append((slot, (order or 300) * 10 + len(slot_order)))
    return info, info.find("AmmoInfo").get("ref")


def merge_animations(sets, w):
    root = load(TEMPLATES / w["base"] / "weaponanimations.meta")
    for anim_set in root.find("WeaponAnimationsSets"):
        key = anim_set.get("key")
        target = sets.setdefault(key, {"fallback": anim_set.findtext("Fallback"), "items": []})
        for item in anim_set.find("WeaponAnimations"):
            if item.get("key") == w["base"]:
                item = copy.deepcopy(item)
                item.set("key", w["name"])
                target["items"].append(item)


def rename_weapons(root, base, name):
    """Point the template's entries at the new weapon. Some templates share an
    entry with other vanilla guns; those names are dropped so we never patch
    vanilla weapons, along with any entry left with no weapons at all."""
    parents = {child: parent for parent in root.iter() for child in parent}
    for weapons in list(root.iter("Weapons")):
        for item in list(weapons):
            if item.text == base:
                item.text = name
            else:
                weapons.remove(item)
        if len(weapons) == 0:
            entry = parents[weapons]
            parents[entry].remove(entry)


def merge_personality(merged, w):
    root = load(TEMPLATES / w["base"] / "pedpersonality.meta")
    rename_weapons(root, w["base"], w["name"])
    if merged is None:
        return root

    unholster = {i.findtext("Name"): i for i in merged.find("MovementModeUnholsterData")}
    for item in root.find("MovementModeUnholsterData"):
        name = item.findtext("Name")
        if name in unholster:
            unholster[name].find("UnholsterClips").extend(list(item.find("UnholsterClips")))
        else:
            merged.find("MovementModeUnholsterData").append(item)

    modes = {i.findtext("Name"): i for i in merged.find("MovementModes")}
    for item in root.find("MovementModes"):
        name = item.findtext("Name")
        if name not in modes:
            merged.find("MovementModes").append(item)
            continue
        dest = list(modes[name].find("MovementModes"))
        for idx, group in enumerate(item.find("MovementModes")):
            if idx < len(dest):
                dest[idx].extend(list(group))
            else:
                modes[name].find("MovementModes").append(group)
    return merged


def write_xml(path, root):
    ET.indent(root, space="  ")
    data = ET.tostring(root, encoding="unicode")
    path.write_text('<?xml version="1.0" encoding="UTF-8"?>\n' + data + "\n", encoding="utf-8")


def lua_str(s):
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"


def build(weapons):
    names = [w["name"] for w in weapons]
    dupes = {n for n in names if names.count(n) > 1}
    if dupes:
        sys.exit(f"duplicate weapon names: {', '.join(sorted(dupes))}")
    for w in weapons:
        if not (TEMPLATES / w["base"]).is_dir():
            sys.exit(f"{w['name']}: no template for base {w['base']}")

    blob = ET.Element("CWeaponInfoBlob")
    slot_nav = ET.SubElement(blob, "SlotNavigateOrder")
    infos_outer = ET.SubElement(blob, "Infos")
    infos = ET.SubElement(ET.SubElement(infos_outer, "Item"), "Infos")
    ET.SubElement(blob, "Name").text = "MOTION_GUNS"

    archetypes = ET.Element("CWeaponModelInfo__InitDataList")
    init_datas = ET.SubElement(archetypes, "InitDatas")

    anim_sets = {}
    personality = None
    slot_order = []

    for w in weapons:
        info, ammo = build_weapon_info(w, slot_order)
        w["_ammo"] = ammo
        infos.append(info)

        arch = ET.SubElement(init_datas, "Item")
        ET.SubElement(arch, "modelName").text = w["model"]
        ET.SubElement(arch, "txdName").text = w["model"]
        ET.SubElement(arch, "ptfxAssetName").text = "NULL"
        ET.SubElement(arch, "lodDist", value=str(w.get("lodDist", LOD_DIST)))

        merge_animations(anim_sets, w)
        personality = merge_personality(personality, w)

    # Same layout the game uses: one navigate entry holding every slot.
    slots = ET.SubElement(ET.SubElement(slot_nav, "Item"), "WeaponSlots")
    for slot, order in slot_order:
        item = ET.SubElement(slots, "Item")
        ET.SubElement(item, "OrderNumber", value=str(order))
        ET.SubElement(item, "Entry").text = slot

    anims = ET.Element("CWeaponAnimationsSets")
    sets_el = ET.SubElement(anims, "WeaponAnimationsSets")
    for key, data in anim_sets.items():
        set_el = ET.SubElement(sets_el, "Item", key=key)
        if data["fallback"]:
            ET.SubElement(set_el, "Fallback").text = data["fallback"]
        ET.SubElement(set_el, "WeaponAnimations").extend(data["items"])

    return blob, archetypes, anims, personality


def write_lua(weapons):
    lines = [
        "-- Generated by tools/build.py from tools/weapons.json. Do not edit by hand.",
        "MotionGuns = MotionGuns or {}",
        "MotionGuns.Weapons = {",
    ]
    for w in weapons:
        lines.append(
            f"    {{ name = {lua_str(w['name'])}, label = {lua_str(w['label'])}, "
            f"category = {lua_str(w['category'])}, ammo = {lua_str(w['_ammo'])}, "
            f"clip = {int(w.get('clip', 0))} }},"
        )
    lines.append("}")
    (RESOURCE / "shared" / "weapons.lua").write_text("\n".join(lines) + "\n", encoding="utf-8")

    ox = ["-- Paste into ox_inventory/data/weapons.lua inside the Weapons = { ... } table.", ""]
    for w in weapons:
        ammo = OX_AMMO_OVERRIDE.get(w["name"], OX_AMMO.get(w["_ammo"], "ammo-9"))
        ox.append(
            f"['{w['name']}'] = {{ label = {lua_str(w['label'])}, weight = {WEIGHT[w['category']]}, "
            f"durability = 0.1, ammoname = '{ammo}' }},"
        )
    (RESOURCE / "integrations" / "ox_inventory.lua").write_text("\n".join(ox) + "\n", encoding="utf-8")

    qbw = ["-- Paste into qb-core/shared/weapons.lua (QBShared.Weapons).", ""]
    qbi = ["-- Paste into qb-core/shared/items.lua (QBShared.Items).", ""]
    for w in weapons:
        low = w["name"].lower()
        qbw.append(
            f"[`{low}`] = {{ name = '{low}', label = {lua_str(w['label'])}, "
            f"weapontype = '{QB_TYPE[w['category']]}', ammotype = '{w['_ammo']}', "
            f"damagereason = 'Shot by a {w['label']}' }},"
        )
        qbi.append(
            f"['{low}'] = {{ name = '{low}', label = {lua_str(w['label'])}, weight = {WEIGHT[w['category']]}, "
            f"type = 'weapon', ammotype = '{w['_ammo']}', image = '{low}.png', unique = true, "
            f"useable = false, description = {lua_str('Motion Guns - ' + w['label'])} }},"
        )
    (RESOURCE / "integrations" / "qb-core.lua").write_text(
        "\n".join(qbw) + "\n\n" + "\n".join(qbi) + "\n", encoding="utf-8"
    )

    esx = ["-- Paste into es_extended/config.weapons.lua (Config.Weapons).", ""]
    for w in weapons:
        esx.append(
            f"{{ name = '{w['name']}', label = {lua_str(w['label'])}, components = {{}}, "
            f"ammo = {{ label = 'rounds', hash = `{w['_ammo']}` }} }},"
        )
    (RESOURCE / "integrations" / "esx.lua").write_text("\n".join(esx) + "\n", encoding="utf-8")


def missing_models(weapons):
    streamed = {p.stem.lower() for p in (RESOURCE / "stream").rglob("*") if p.suffix.lower() in (".ydr", ".ytd")}
    return [w for w in weapons if w["model"].lower() not in streamed]


def main():
    weapons = json.loads((TOOLS / "weapons.json").read_text(encoding="utf-8"))["weapons"]
    blob, archetypes, anims, personality = build(weapons)

    if "--check" not in sys.argv:
        META.mkdir(parents=True, exist_ok=True)
        write_xml(META / "weapons.meta", blob)
        write_xml(META / "weaponarchetypes.meta", archetypes)
        write_xml(META / "weaponanimations.meta", anims)
        write_xml(META / "pedpersonality.meta", personality)
        write_lua(weapons)
        print(f"built {len(weapons)} weapons into {RESOURCE.relative_to(ROOT)}/")

    missing = missing_models(weapons)
    if missing:
        print(f"{len(missing)} weapon(s) have no model in motion_guns/stream yet:")
        for w in missing:
            print(f"  {w['name']:<26} needs {w['model']}.ydr + {w['model']}.ytd")


if __name__ == "__main__":
    main()
