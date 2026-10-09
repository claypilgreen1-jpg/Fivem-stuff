# Motion Multicharacter (Motion City RP)

A custom character select and creation screen for **ESX Legacy** with **illenium-appearance**, styled
to match the Motion City RP logo: neon magenta, violet and cyan, chrome lettering and graffiti type.

- **Pick a character:** your characters are listed down the left, each showing its job. Click one to
  see it standing in the scene, with its name, date of birth, height, job, cash and bank on the right.
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
| `Scene` | Vinewood Hills overlook, 7 pm | Where the character stands, the camera angle, and the time of day |
| `NewCharacterSpawn` | `nil` | Where new characters spawn. `nil` uses es_extended's `DefaultSpawns` |

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
