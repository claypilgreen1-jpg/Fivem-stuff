Config = {}

-- The API key is read on the server from a convar so it never reaches players.
-- In server.cfg:   set anthropic_api_key "sk-ant-..."
Config.ApiKeyConvar = 'anthropic_api_key'

Config.Model = 'claude-opus-5-5'
Config.Effort = 'low'        -- low keeps replies quick and cheap; 'medium' gives more thoughtful conversation
Config.MaxTokens = 1500      -- ceiling per reply (thinking + text); replies are told to stay conversational

-- Voice: hold your normal voice push-to-talk key (N by default) while facing someone and they hear you.
-- Needs a speech-to-text key on the server (see README):  set npctalk_stt_key "..."
Config.Voice = {
    enabled = true,
    usePushToTalk = true, -- listen while the game's push-to-talk is held
    key = nil,            -- optional extra hold-to-talk key for open-mic players, e.g. 'B'
}

-- Typing still works as a fallback: type in normal chat while standing near an NPC.
-- /talk <message> also works, for chat resources that don't fire the chatMessage event.
Config.TalkCommand = 'talk'
Config.TalkDistance = 4.0    -- metres; how close you have to be to start talking
Config.StayInRange = 8.0     -- metres; the NPC keeps listening to you within this range once you're talking
Config.MaxMessageLength = 250
Config.Cooldown = 2          -- seconds between messages per player

-- Memory
Config.HistoryTurns = 20     -- how many back-and-forths an NPC remembers
Config.ForgetAfter = 1800    -- seconds before an NPC forgets you
Config.ReleaseAfter = 45     -- seconds of silence before the NPC goes back to what it was doing

-- How replies show up. NPCs talk in chat like any other player; nothing is drawn over their heads.
Config.HearingRange = 15.0   -- players this close see the NPC's lines
Config.Subtitles = false     -- also show the line at the bottom of the screen, GTA-dialogue style
Config.NameColor = { 255, 255, 255 } -- chat colour for NPC names (same as players by default)

-- Tone of the city. Edit freely; it is added to every NPC's instructions.
Config.WorldPrompt = [[
You live in Los Santos, a satirical take on Los Angeles from GTA V. Locals reference real Los Santos
places (Vinewood, Del Perro, Grove Street, Sandy Shores, Paleto Bay, Vespucci Beach, Mirror Park,
Davis, Rockford Hills) and brands (Burger Shot, Cluckin' Bell, Pisswasser, LifeInvader, Up-n-Atom).
You are an ordinary person with your own life, not a quest giver or a tour guide.
]]
