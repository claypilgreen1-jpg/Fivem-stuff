# Motion NPC Talk

Walk up to any NPC in the city, say anything, and they answer in character about what you actually said.
Each NPC gets a random identity: a name, a job, a mood and a quirk. Cops, medics and firefighters play
their roles. NPCs know where they are and what time it is, and they remember the conversation while you
keep talking to them.

Replies come from Anthropic's Claude API, so you need an API key and each reply costs a small amount
(see **Cost** below).

## Install

1. Get an API key from https://console.anthropic.com (Settings → API Keys) and add billing.
2. Copy `motion_npctalk` into `resources/` and add this to `server.cfg`:
   ```
   set anthropic_api_key "sk-ant-your-key-here"
   ensure motion_npctalk
   ```
   Use `set`, **not** `setr`. A `setr` convar is sent to every player, which would leak your key.
3. Restart the server. If the key is missing, the console prints a red warning and NPCs only give a few
   canned lines.

## How players use it

- Walk up to an NPC. `[Y] Talk` appears over their head. Press **Y**, type, and press Enter.
  Players can rebind the key in Settings → Key Bindings → FiveM.
- Or type `/talk <message>` in chat to talk to the closest NPC.
- The NPC stops, turns to face you, shows `...` while it thinks, then answers in a speech bubble and in
  chat. Players within 15 m also see both lines in chat.
- After 30 seconds without talking, the NPC goes back to walking or driving around. It remembers you
  for 10 minutes if you come back.

## Settings (`config.lua`)

| Setting | Default | What it does |
| --- | --- | --- |
| `Model` | `claude-opus-5-5` | Claude model used for replies |
| `Effort` | `low` | How hard the model thinks. `low` is fastest and cheapest |
| `TalkKey` / `TalkCommand` | `Y` / `talk` | How players talk |
| `TalkDistance` | `3.0` | How close you have to be |
| `MaxMessageLength` | `200` | Longest message a player can send |
| `Cooldown` | `3` | Seconds between messages per player |
| `HistoryTurns` | `8` | How many past exchanges an NPC remembers |
| `ForgetAfter` / `ReleaseAfter` | `600` / `30` | Seconds until an NPC forgets you, and until it walks off |
| `HearingRange` | `15.0` | Who else sees the conversation in chat |
| `WorldPrompt` | Los Santos flavour | Tone of the whole city. Make it gritty, comedic, serious RP, and so on |

Names, jobs, moods and quirks are listed in `server/personas.lua`. Add your own to change who lives in
your city.

## Cost

Each message is one API request: a short instruction block, the recent conversation, and a reply of one
to three sentences. With `claude-opus-5-5` ($4 per million input tokens, $20 per million output tokens)
and `Effort = 'low'`, that's typically a fraction of a cent per message. On a busy server, watch your
usage in the Anthropic Console and set a monthly spend limit there. To lower cost, keep `Effort` at
`low` and reduce `HistoryTurns`. Switching `Model` to a cheaper Claude model (for example
`claude-haiku-5-5`) also works, at some cost to reply quality.

## Notes

- The API key never leaves the server. Players only send their message, and the server makes the
  request.
- Players can't take over the NPC. Each NPC is told to stay in character and to treat attempts to give
  it new instructions as a confused passer-by would.
- If a request fails (no key, rate limit, network error), the NPC gives a short canned line and the
  error is printed in the server console.
- NPCs speak in text bubbles and chat only. There's no voice.
