# Fivem-stuff

| Resource | What it is |
| --- | --- |
| [`motion_guns`](#motion-guns) | Mega add-on weapon pack (33 guns) |
| [`motion_testbot`](motion_testbot/README.md) | Admin menu (F7): spawn and dress any GTA ped, give bots tasks, free cam and photo tours |
| [`motion_npctalk`](motion_npctalk/README.md) | Type in chat next to any NPC and have a real conversation with them (Claude API) |

# Motion Guns

A mega add-on weapon pack for FiveM. 33 real-world guns as **add-on** weapons
(they don't replace any vanilla GTA guns), with weapon wheel names, a give
command, and ready-made item entries for ox_inventory, qb-core and ESX.

| Category | Weapons |
| --- | --- |
| Pistols | Glock 17, Glock 19X, Glock 18C, SIG P226, Beretta M9, FN Five-seveN, Colt 1911, SIG P365, Desert Eagle, Colt Python |
| SMGs | MP5A3, SIG MPX, KRISS Vector, MP7, Micro Uzi, TEC-9, Scorpion Evo |
| Rifles | M4A1, HK416, SIG MCX, AK-47, AKS-74U, SCAR-L, G36C, AUG A3 |
| Shotguns | Remington 870, Benelli M4, Saiga-12 |
| Snipers / DMR | SR-25, M24, Barrett M82A1 |
| LMGs | M249 SAW, PKM |

Each gun clones a vanilla base weapon's handling, animations, audio and ammo
type (for example, the Glock 17 handles like the Combat Pistol), with its own
magazine size and stat tweaks.

## What's in the repo, and what you add

The **weapon models are not included**. Free gun models from gta5-mods.com and
the Cfx.re forum are made by individual modders, and most of their licences
don't allow re-uploading them in someone else's pack. This repo has
everything else, so the pack works as soon as you drop the models in.

```
motion_guns/            <- the FiveM resource (copy into resources/)
  fxmanifest.lua
  config.lua
  meta/                 <- generated weapons/archetypes/animations/personality metas
  stream/<category>/    <- put the .ydr / .ytd model files here
  integrations/         <- copy-paste entries for ox_inventory, qb-core, ESX
tools/
  weapons.json          <- the roster: names, labels, base weapon, model, stats
  build.py              <- regenerates meta/ and the Lua tables from weapons.json
  templates/            <- vanilla base-weapon metas used by build.py
CREDITS.md              <- fill in which modder each model came from
```

## Setup

1. **Get the models.** For each gun, download a free model (search the gun's
   name on gta5-mods.com → Weapons, or the Cfx.re forum Releases section).
   Check the download's readme: make sure the author allows use on a FiveM
   server, and note them in `CREDITS.md`.
2. **Find the model files.** Most packs ship either loose `.ydr`/`.ytd`
   files or a `.oiv`/`.rpf`. Open the `.rpf` with OpenIV or CodeWalker and
   export the weapon's `.ydr` and `.ytd` (and `_hi.ydr` if there is one).
3. **Rename them to the Motion Guns model name**, then put them in the
   matching `motion_guns/stream/<category>/` folder. For example, a Glock 17
   replacing the vanilla pistol (`w_pi_pistol.ydr`, `w_pi_pistol.ytd`,
   `w_pi_pistol_hi.ydr`) becomes:
   ```
   stream/pistols/w_pi_motion_glock17.ydr
   stream/pistols/w_pi_motion_glock17.ytd
   stream/pistols/w_pi_motion_glock17_hi.ydr
   ```
   The model name for each gun is in `tools/weapons.json` (`"model"`).
4. **Check nothing is missing:**
   ```
   python3 tools/build.py --check
   ```
   It lists every gun that has no model yet. A gun without a model still
   works, but it's invisible.
5. **Install:** copy the `motion_guns` folder into your server's
   `resources/` and add to `server.cfg`:
   ```
   ensure motion_guns
   add_ace group.admin command.motionguns allow
   ```
6. **Test in game:** `/motionguns` lists the pack, `/motionguns glock17`
   gives one gun, `/motionguns all` gives everything, and
   `/motionguns m4a1 12` gives a gun to player ID 12.

## Inventory / framework items

`build.py` writes copy-paste entries to `motion_guns/integrations/`:

- `ox_inventory.lua` → paste into `ox_inventory/data/weapons.lua`, inside
  `Weapons = { }`. Inventory images go in `ox_inventory/web/images/`, named
  after the weapon (e.g. `WEAPON_MOTION_GLOCK17.png`).
- `qb-core.lua` → the first block goes in `qb-core/shared/weapons.lua`, the
  second in `qb-core/shared/items.lua`. Images go in
  `qb-inventory/html/images/` (e.g. `weapon_motion_glock17.png`).
- `esx.lua` → paste into `Config.Weapons` in `es_extended/config.weapons.lua`.

Ammo uses the vanilla pools (AMMO_PISTOL, AMMO_RIFLE, and so on), so existing
ammo items keep working.

## Changing the pack

Everything comes from `tools/weapons.json`. After editing it, run:

```
python3 tools/build.py
```

and restart the resource. Per gun you can set:

| Field | Meaning |
| --- | --- |
| `name` | Spawn name, e.g. `WEAPON_MOTION_GLOCK17` (keep the `WEAPON_` prefix) |
| `label` | Name shown on the weapon wheel and in inventories |
| `category` | `pistol`, `smg`, `rifle`, `shotgun`, `sniper` or `mg` |
| `base` | Vanilla weapon to clone; any folder name in `tools/templates/` |
| `model` | `.ydr`/`.ytd` file name without the extension |
| `clip` | Magazine size |
| `damage` | Damage per bullet (optional) |
| `fireRate` | Seconds between shots, lower is faster (optional) |
| `range` | Max range in metres (optional) |
| `scope` | Vanilla scope component for snipers (optional) |

**To add a gun,** add a line to `weapons.json`, put its model in `stream/`,
and rebuild. **To use a model under its original file name,** set `model` to
that name instead of renaming the file.

## Notes and limitations

- **Attachments:** vanilla magazine, suppressor and flashlight components are
  left out because free models have their magazine built in and their bones
  don't line up with vanilla parts.
- **Snipers** get a vanilla scope so they can zoom. The scope attaches to the
  model's `WAPScop` bone; if a model doesn't have that bone, the scope won't
  show up.
- **Skins / tints** use the default tint palette. Models with their own
  liveries may ignore weapon tints.
- **Sounds** come from the base weapon. Custom gunshot audio is outside the
  scope of this pack.
