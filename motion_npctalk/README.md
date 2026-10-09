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

Walk up to someone and **type in normal chat**. Nothing pops up over anyone's head. The NPC turns to
you, says hi (a GTA voice line), and answers in chat under their own name, just like another player
would. They gesture with their hands and move their mouth while they talk.

- Keep talking and they keep the conversation going. They remember what you said, share things about
  their life, ask you questions back, and warm up or get annoyed depending on how you treat them.
- Once you're talking to someone, they keep listening as long as you stay within about 8 m, even if you
  turn around.
- If they want to end the conversation (you're being rude, or they have somewhere to be), they say a
  last line, say bye, and walk off.
- Leave them alone for 45 seconds and they go back to what they were doing. They remember you for
  30 minutes.
- Players within 15 m see what the NPC says.
- `/talk <message>` does the same thing, for servers whose chat resource doesn't fire the standard
  `chatMessage` event.

Every NPC is a different person: a random name, age, neighbourhood, job, mood, quirk, what they're
doing right now, and something going on in their life. Cops, medics, firefighters, SWAT and soldiers
play their roles.

## Settings (`config.lua`)

| Setting | Default | What it does |
| --- | --- | --- |
| `Model` | `claude-opus-5-5` | Claude model used for replies |
| `Effort` | `low` | `low` is fastest and cheapest; `medium` gives more thoughtful conversations |
| `TalkDistance` / `StayInRange` | `4.0` / `8.0` | How close you have to be to start talking, and to keep talking |
| `MaxMessageLength` | `250` | Longest message a player can send |
| `Cooldown` | `2` | Seconds between messages per player |
| `HistoryTurns` | `20` | How many back-and-forths an NPC remembers |
| `ForgetAfter` / `ReleaseAfter` | `1800` / `45` | Seconds until an NPC forgets you, and until it goes back to what it was doing |
| `HearingRange` | `15.0` | Who else sees the NPC's lines |
| `Subtitles` | `false` | Also show the NPC's line at the bottom of the screen, GTA-dialogue style |
| `NameColor` | white | Chat colour for NPC names |
| `WorldPrompt` | Los Santos flavour | Tone of the whole city. Make it gritty, comedic, serious RP, and so on |

Names, jobs, moods, quirks, neighbourhoods and life situations are listed in `server/personas.lua`.
Add your own to change who lives in your city.

## Cost

Each message is one API request: a short instruction block, the recent conversation (up to 20
exchanges), and a short spoken reply. Longer conversations cost a bit more per message because the
NPC re-reads what was said. With `claude-opus-5-5` ($4 per million input tokens, $20 per million output tokens)
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
- Replies are text in chat. The GTA voice lines are only the hello and bye; the NPC doesn't read its reply out loud.
