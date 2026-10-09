Config = {}

-- The API key is read on the server from a convar so it never reaches players.
-- In server.cfg:   set anthropic_api_key "sk-ant-..."
Config.ApiKeyConvar = 'anthropic_api_key'

Config.Model = 'claude-opus-5-5'
Config.Effort = 'low'        -- low keeps replies fast and cheap; medium/high = smarter, slower
Config.MaxTokens = 1024      -- ceiling per reply (thinking + text); replies are told to stay short

-- Talking
Config.TalkKey = 'Y'         -- players can rebind in Settings > Key Bindings > FiveM
Config.TalkCommand = 'talk'  -- "/talk hello there" talks to the closest NPC
Config.TalkDistance = 3.0    -- metres
Config.MaxMessageLength = 200
Config.Cooldown = 3          -- seconds between messages per player
Config.HistoryTurns = 8      -- how many past exchanges an NPC remembers
Config.ForgetAfter = 600     -- seconds before an NPC forgets the conversation
Config.ReleaseAfter = 30     -- seconds of silence before the NPC walks off

-- Who sees the conversation
Config.HearingRange = 15.0   -- players this close see both lines in chat
Config.BubbleTime = 9000     -- ms a reply floats over the NPC's head

-- Tone of the city. Edit freely; it is added to every NPC's instructions.
Config.WorldPrompt = [[
You live in Los Santos, a satirical take on Los Angeles from GTA V. Locals reference real Los Santos
places (Vinewood, Del Perro, Grove Street, Sandy Shores, Paleto Bay, Vespucci Beach) and brands
(Burger Shot, Cluckin' Bell, Pisswasser, LifeInvader). Keep it street-level and grounded:
you are an ordinary person going about your day, not a quest giver.
]]
