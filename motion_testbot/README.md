# Motion TestBot

An admin tool for testing things live on your FiveM server:

- **Free cam:** fly a camera anywhere and take screenshots.
- **Photo tour:** the camera flies to a list of city spots and photographs each one by itself.
- **Test bots:** spawn peds and give them tasks, or a queue of tasks, such as following you, driving to your waypoint, robbing someone, or acting as a robbery victim. Use them to test robbery, police, EMS and similar scripts.
- **Event trigger:** fire any client or server event with arguments to test a script without playing through it.

Everything is in one admin-only menu. Press **F7** (or type `/bot`) to open it. The typed commands
below still work if you prefer them.

## Install

1. Install [screenshot-basic](https://github.com/citizenfx/screenshot-basic). You only need it for screenshots.
2. Copy `motion_testbot` into `resources/` and add this to `server.cfg`:
   ```
   ensure screenshot-basic
   ensure motion_testbot
   add_ace group.admin command.bot allow
   ```
3. Screenshots are saved on the server in `resources/motion_testbot/screenshots/`.

## The menu

| Tab | What's in it |
| --- | --- |
| **Peds** | Search and browse every GTA V ped (1,100+, grouped by ambient, gangs, service and jobs, story, cutscene, animals and more). Double-click to spawn, or swap the selected bot's model in place. You can type any model name for add-on peds. |
| **Outfit** | Dress the selected bot: hair, top, undershirt, pants, shoes, mask, bag, armor, hat, glasses, watch and more, each with style and colour arrows. Has random and default outfit buttons, and saved outfits per model. Online character models (`mp_m_freemode_01` / `mp_f_freemode_01`) get a proper face. |
| **Tasks** | One click per task: follow, walk or run to, teleport, wander, spawn a car, drive (normal or fast), get in or out, robbery victim (calm or flee), rob, aim, shoot, attack, hands up, flee, kneel, ragdoll, kill, revive, stop, give a weapon, play a scenario or animation. Pick a target (you, nearest ped, your waypoint, another bot). Turn on **Build a queue** to chain tasks in order, and **All bots** to command every bot at once. |
| **Bots** | Every bot with its current task. Select, god mode, freeze, bring to me, go to it, dismiss. |
| **Camera** | Free cam, take a photo, run the whole photo tour or shoot one spot, save new spots. |
| **Events** | Fire any client or server event with JSON args to test a script. |

Players who can open it are set by the same ACE as the command (`command.bot`). Rebind the key in
Settings → Key Bindings → FiveM.

## Free cam and photos

| Command | What it does |
| --- | --- |
| `/bot cam` | Toggle the free cam |
| `/bot photo [label]` | Screenshot right now, with the HUD hidden |
| `/bot tour` | Visit every spot in `Config.PhotoSpots` and photograph it |
| `/bot tour legion_square chiliad` | Photograph only those spots |
| `/bot tour stop` | Stop a running tour |
| `/bot spot <name>` | Print a `Config.PhotoSpots` line for what the free cam is looking at |

Free cam controls: **WASD** move, **Q/E** down/up, **SHIFT** fast, **CTRL** slow, **mouse wheel** zoom, **left click** screenshot, **H** hide the help text, **BACKSPACE** exit.

To add your own photo spots: open the free cam, frame the shot, run `/bot spot my_spot`, and paste the printed line into `Config.PhotoSpots`. You can also add `hour = 20` to a spot to shoot it at night.

## Test bots

```
/bot spawn                    spawn a bot (default model) and select it
/bot spawn s_m_y_cop_01       spawn a specific ped model
/bot list                     list bots and what they're doing
/bot select 2                 command bot 2 from now on
/bot dismiss [id|all]         delete bots
/bot tasks                    list every task
```

Give the selected bot a task, or chain several with `;`. A new command cancels whatever the bot was doing.

```
/bot follow
/bot goto waypoint ; handsup 5 ; flee
/bot car sultan ; drive waypoint fast ; leave ; wander
/bot on 2 attack me           give one specific bot a task
/bot all rob ped              every bot robs the nearest ped
```

Targets: `me`, `ped` (nearest normal ped), `waypoint`, `bot:<id>`, `player:<server id>`, or `x y z` coordinates.

| Task | What it does |
| --- | --- |
| `follow [target]` | Follow you or a target |
| `stay` | Stand still |
| `goto <target> [walk]` | Walk or run somewhere; the next task starts when it arrives |
| `tp <target>` | Teleport the bot |
| `car [model]` | Spawn a car and get in the driver's seat |
| `enter [driver\|passenger]` | Get into your vehicle or the nearest one |
| `leave` | Get out of the vehicle |
| `drive <target> [fast]` | Drive somewhere, using its own car or the nearest free one |
| `weapon <name\|none>` | Give the bot a weapon, e.g. `pistol` or `motion_glock17` |
| `aim [target]` | Hold a target at gunpoint |
| `shoot [target] [sec]` | Shoot at a target |
| `attack [target]` | Fight a target |
| `rob [target]` | Go to the nearest ped (or a target), pull a gun, and make the ped put their hands up |
| `victim [stay\|flee] [sec]` | Put hands up while any player aims at it, then calm down or flee after N seconds |
| `handsup [sec]` | Hands up |
| `kneel` | Kneel with hands on head |
| `flee [target]` | Run away |
| `wander` | Walk around like a normal ped |
| `anim <dict> <name> [upper]` | Loop any animation |
| `scenario <name>` | Play a scenario, e.g. `WORLD_HUMAN_SMOKING` |
| `ragdoll [sec]` | Fall over |
| `kill` / `revive` | Kill or revive the bot, for testing death, loot or EMS scripts |
| `wait <sec>` | Pause the queue |
| `stop` | Stop everything |

## Testing a robbery script

- **You're the robber:** run `/bot spawn mp_m_shopkeep_01`, then `/bot tp me ; victim flee 10`. Stand behind the counter, aim at it, and check that your robbery script triggers. The bot puts its hands up while you aim and runs off 10 seconds after you stop.
- **Watch a robbery:** run `/bot spawn ; rob ped`. The bot holds up the nearest NPC, for example a store clerk, while you watch from `/bot cam`.
- **Skip straight to a step:** fire the robbery script's own events (find their names in its `RegisterNetEvent` lines), for example
  `/bot event server my_robbery:server:payout ["store_1"]` or
  `/bot event client my_robbery:start [{"store":"ltd_grove"}]`.
  The arguments must be a JSON array.

## Limits

- **Bots are NPCs, not players.** They don't have an inventory, job or server ID, and they can't press keys or trigger a script's events themselves. Anything a script only lets a player do has to be done by you or with `/bot event`. Bots are for being the *other side*: victims, clerks, attackers, drivers, crowds.
- **Bots belong to the admin who spawned them.** They're removed when the resource stops.
- **`/bot event` fires events as you.** Server scripts see your player as `source`.
