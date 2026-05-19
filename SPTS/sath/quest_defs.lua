-- All 13 Sath main quest definitions in order.
-- Each entry lists the stat targets the script needs to hit before talking to Sath.
-- Tasks with farm=false are skipped by the autofarm (e.g. kill quests).

local SATH_QUEST_DEFS = {
    [1]  = { name = "Starter Training", tasks = {
        { key = "FS", flag = "FistStrength",  target = 20 },
        { key = "BT", flag = "BodyToughness", target = 20 },
    }},
    [2]  = { name = "Mobility Basics", tasks = {
        { key = "MS", flag = "MovementSpeed", target = 20 },
        { key = "JF", flag = "JumpForce",     target = 20 },
    }},
    [3]  = { name = "Psychic Power Training", tasks = {
        { key = "PP", flag = "PsychicPower", target = 100 },
    }},
    [4]  = { name = "Fist Milestone", tasks = {
        { key = "FS", flag = "FistStrength", target = 1000 },
    }},
    [5]  = { name = "Body Milestone", tasks = {
        { key = "BT", flag = "BodyToughness", target = 1000 },
    }},
    [6]  = { name = "Movement Speed & Psychic Power", tasks = {
        { key = "MS", flag = "MovementSpeed", target = 1000 },
        { key = "PP", flag = "PsychicPower",  target = 1000 },
    }},
    [7]  = { name = "Jump Milestone", tasks = {
        { key = "JF", flag = "JumpForce", target = 1000 },
    }},
    [8]  = { name = "Speed Surge", tasks = {
        { key = "MS", flag = "MovementSpeed", target = 10000 },
    }},
    [9]  = { name = "Jump Force & Psychic Power", tasks = {
        { key = "JF", flag = "JumpForce",    target = 10000 },
        { key = "PP", flag = "PsychicPower", target = 10000 },
    }},
    [10] = { name = "Fist Master", tasks = {
        { key = "FS", flag = "FistStrength", target = 100000 },
    }},
    [11] = { name = "Psychic Power 100K", tasks = {
        { key = "PP", flag = "PsychicPower", target = 100000 },
    }},
    [12] = { name = "Triple Mastery", tasks = {
        { key = "FS", flag = "FistStrength",  target = 1000000 },
        { key = "BT", flag = "BodyToughness", target = 1000000 },
        { key = "PP", flag = "PsychicPower",  target = 1000000 },
    }},
    [13] = { name = "Psychic Power 100M (kills manual)", tasks = {
        { key = "PP",    flag = "PsychicPower", target = 100000000 },
        { key = "KILLS", flag = nil, farm = false, target = 1000 },
    }},
}

-- Flags that the Sath loop is allowed to toggle on/off.
local SATH_FARM_FLAGS = {
    "FistStrength", "BodyToughness", "MovementSpeed",
    "JumpForce", "PsychicPower", "DeathGrinding",
}

-- Stats that use a physical training tool (as opposed to PP meditation).
local PHYSICAL_FLAGS = {
    FistStrength  = true,
    BodyToughness = true,
    MovementSpeed = true,
    JumpForce     = true,
}

-- Display names shown in notifications and the dashboard label.
local FLAG_LABELS = {
    FistStrength  = "Fist Strength",
    BodyToughness = "Body Toughness",
    MovementSpeed = "Movement Speed",
    JumpForce     = "Jump Force",
    PsychicPower  = "Psychic Power",
    KILLS         = "Kills",
}

-- Store in _G so scanner.lua and farm.lua can read without require().
_G.SATH_QUEST_DEFS  = SATH_QUEST_DEFS
_G.SATH_FARM_FLAGS  = SATH_FARM_FLAGS
_G.SATH_PHYSICAL_FLAGS = PHYSICAL_FLAGS
_G.SATH_FLAG_LABELS = FLAG_LABELS
