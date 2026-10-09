# Motion Multicharacter (Motion City RP)

A custom character select and creation screen for **ESX Legacy** with **illenium-appearance**, styled
to match the Motion City RP logo: neon magenta, violet and cyan, chrome lettering and graffiti type.

- **Pick a character:** your characters are listed down the left. Click one and it appears standing in
  the scene, wearing its saved outfit, with a big chrome name, job, birthday, cash and bank on the right.
- **Where you stand:** each login picks one of four scenes at random: the Eclipse Towers penthouse,
  Vespucci Beach at sunset, the Maze Bank Tower roof at night, or the yacht. The location shows top right.
- **Make a character:** pick an empty slot, fill in the form (name, date of birth, height, sex), then
  build your face, hair and clothes in illenium-appearance.
- **Delete a character:** you have to type its full name to confirm.
- **Go back:** `/relog` returns to character select without disconnecting.

## Install

1. **Remove the stock `esx_multicharacter`** from your resources.
2. Put this folder in `resources/` and **keep it named `esx_multicharacter`**. es_extended only turns on
   multicharacter mode when a resource with that exact name exists.
3. In `server.cfg`, start it after es_extended and illenium-appearance:
   ```
   ensure oxmysql
   ensure es_extended
   ensure illenium-appearance
   ensure esx_multicharacter
   ```
4. Start the server. There's **no SQL to run**. On first start it creates the `multicharacter_slots`
   table, adds any missing `users` columns (`firstname`, `lastname`, `dateofbirth`, `sex`, `height`,
   `skin`, `disabled`), and widens `identifier`/`owner` columns that are too short for `char1:license...`.

You don't need `esx_identity`, `esx_skin` or `esx_context`. This resource has its own creation form,
and illenium-appearance handles the skin events.

## Settings (`config.lua`)

| Setting | Default | What it does |
| --- | --- | --- |
| `Slots` | `4` | Character slots per player |
| `Prefix` | `char` | Identifier prefix (`char1:license...`). Don't change it once players have characters |
| `CanDelete` | `true` | Players can delete their own characters |
| `Relog` | `true` | Enables `/relog` |
| `Identity` | 2-16 letter names, 18-90 years, 140-210 cm | Creation form rules. These are checked on the server too |
| `Identity.dateFormat` | `DD/MM/YYYY` | How `dateofbirth` is stored. Match what your server used before |
| `SceneMode` | `random` | `random`, or one scene name (`penthouse`, `beach`, `rooftop`, `yacht`) to always use it |
| `Scenes` | 4 scenes | Each scene's position, camera, time of day, weather, and the GTA Online interior it needs |
| `NewCharacterSpawn` | `nil` | Where new characters spawn. `nil` uses es_extended's `DefaultSpawns` |

## Adjusting a scene

The positions are taken from GTA's map data, but you may want to fine-tune where the character stands
or where the camera sits. To do that:

1. Go to the spot in game and stand exactly where the character should stand, facing the way they
   should face.
2. Move your gameplay camera to roughly where the menu camera should be.
3. Run `/mcscene penthouse` (or any name). It prints a ready-made line in the F8 console.
4. Paste that line over the matching scene in `Config.Scenes`, then restart the resource.

You can also add your own scenes this way, and delete any you don't want.

**Penthouse and yacht** are GTA Online interiors. The script loads them itself. If you run
bob74_ipl, they're already loaded.

## Admin commands

| Command | What it does |
| --- | --- |
| `/setslots <license> <slots>` | Give someone more (or fewer) slots |
| `/remslots <license>` | Put someone back on the default number of slots |
| `/disablechar <license> <slot>` | Lock a character so it can't be played |
| `/enablechar <license> <slot>` | Unlock it |

`license` is the player's license identifier without the `license:` part.

## Notes

- **Deleting a character** removes its rows from **every** table with an `identifier` or `owner` column
  (vehicles, properties, and so on), the same as the stock resource does.
- **Each account can only be connected once.** A second connection with the same license is turned away.
- **The logo** is `html/logo.png`. Replace that file to change it.
