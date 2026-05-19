-- Global settings and stat tables shared across all modules.
-- Everything that needs to persist between loops lives here.

_G.Settings = {
    FistStrength   = false,
    BodyToughness  = false,
    MovementSpeed  = false,
    JumpForce      = false,
    PsychicPower   = false,
    DeathGrinding  = false,
    InstantRespawn = false,
    AutoQuest      = false,
    AutoSathQuest  = false,
    AntiAfk        = true,
    ActiveWeight   = 0,
    PlayerEsp      = false,
    AutoPunch      = false,
}

-- Human-readable stat strings shown in the dashboard labels.
_G.Stats = { FS = "0", BT = "0", MS = "0", JF = "0", PP = "0" }

-- Raw numeric values used for all threshold checks.
_G.RawStats = { FS = 0, BT = 0, MS = 0, JF = 0, PP = 0 }

-- Maps a training flag name to its RawStats key.
_G.STAT_TO_RAW = {
    FistStrength  = "FS",
    BodyToughness = "BT",
    MovementSpeed = "MS",
    JumpForce     = "JF",
    PsychicPower  = "PP",
}

-- Weight tier thresholds. Tier index matches the in-game weight item number.
_G.WEIGHT_REQS = {
    { MS = 100,      JF = 5000 },
    { MS = 5000,     JF = 210000 },
    { MS = 567000,   JF = 2100000 },
    { MS = 10000000, JF = 10000000 },
}
