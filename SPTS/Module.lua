local M = {}

-- ── Helpers ──────────────────────────────────────────────────
local SuffixMul = { K = 1e3, M = 1e6, B = 1e9, T = 1e12, Q = 1e15 }

function M.parseNum(v)
    if type(v) == "number" then return v end
    local s = tostring(v):gsub(",", ""):upper()
    local n, suf = s:match("([%d%.]+)([KMBTQ]?)")
    if not n then return 0 end
    return (tonumber(n) or 0) * (SuffixMul[suf] or 1)
end

function M.fmtCommas(n)
    if type(n) ~= "number" then return tostring(n) end
    local s = tostring(math.floor(n))
    return s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

function M.midPos(p1, p2)
    if not p2 then return p1 end
    return Vector3.new(
        (p1.X + p2.X) / 2,
        (p1.Y + p2.Y) / 2,
        (p1.Z + p2.Z) / 2
    )
end

-- Main quest chapter from UI "X/13" (same as game MainQuest.No while in progress)
M.FS_CHAPTER_ROCK    = 4  -- quest 3 done → Rock FS (4/13+)
M.FS_CHAPTER_CRYSTAL = 10 -- quest 9 done → Crystal+ (10/13+)
M.PP_FLY_CHAPTER     = 10 -- quest 9 done → fly + meditate 10x PP (UI 10/13+)
M.PP_FLY_MIN_JF      = 10000
M.PP_FLY_MIN_PP      = 50
M.BT_DEATH_GRIND_MIN = 20
M.BT_ZONE_MIN        = 20

M.STARTER_TOOLS = {
    FistStrength  = { "Push Up" },
    BodyToughness = { "Push Up" },
}
M.BT_PUSHUP_REMOTE = "+BT1"
M.ZONE_TOOLS = {
    FistStrength = "Fist Training",
}

-- ── Body Toughness Zones ──────────────────────────────────────
M.BT = {
    { req = 4e13, min = 5e8, name = "Red Acid Pool (10T+)",    p1 = Vector3.new(-265, 281, 1001), p2 = Vector3.new(-292, 281, 1013) },
    { req = 4e11, min = 5e7, name = "Green Acid Pool (100B+)", p1 = Vector3.new(-265, 281, 998),  p2 = Vector3.new(-292, 281, 986) },
    { req = 4e9,  min = 5e6, name = "Hellfire Pit (1B+)",      p1 = Vector3.new(-241, 287, 977),  p2 = Vector3.new(-253, 287, 981) },
    { req = 4e7,  min = 5e5, name = "Volcano (10M+)",          p1 = Vector3.new(-1981, 714, -1922) },
    { req = 4e6,  min = 5e4, name = "Tornado (1M+)",           p1 = Vector3.new(-2299, 977, 1071) },
    { req = 4e5,  min = 5e3, name = "Iceberg (100K+)",         p1 = Vector3.new(1625, 262, 2238), p2 = Vector3.new(1646, 261, 2255) },
    { req = 4e4,  min = 500, name = "Lava Bath (10K+)",        p1 = Vector3.new(346, 264, -500),  p2 = Vector3.new(367, 264, -485) },
    { req = 400,  min = 5,   name = "Ice Bath (100+)",         p1 = Vector3.new(360, 250, -450),  p2 = Vector3.new(374, 250, -440) },
    { req = 0,    min = 0,   name = "Safe Zone",               p1 = Vector3.new(420, 249, 878) },
}

-- Crystal listed before Rock so smartTarget picks Crystal when both req=0
M.FS = {
    { req = 1e13, name = "Red Star (10T+)",    p1 = Vector3.new(-367, 15735, -11) },
    { req = 1e11, name = "Green Star (100B+)", p1 = Vector3.new(1380, 9274, 1648) },
    { req = 1e9,  name = "Blue Star (1B+)",   p1 = Vector3.new(1176, 4789, -2293) },
    { req = 0,    name = "Crystal Zone",      p1 = Vector3.new(-2278, 1943, 1052) },
    { req = 0,    name = "Rock Zone",         p1 = Vector3.new(433, 249, 991) },
}

-- ── Psychic Power Zones ───────────────────────────────────────
M.PP = {
    { req = 1e15, name = "Psychic Temple (1Q+)", p1 = Vector3.new(-2545, 5412, -493) },
    { req = 1e12, name = "Psychic Temple (1T+)", p1 = Vector3.new(-2590, 5517, -491), p2 = Vector3.new(-2575, 5516, -511) },
    { req = 1e9,  name = "Psychic Temple (1B+)", p1 = Vector3.new(-2548, 5500, -449), p2 = Vector3.new(-2563, 5501, -441) },
    { req = 1e6,  name = "Psychic Temple (1M+)", p1 = Vector3.new(-2518, 5486, -544), p2 = Vector3.new(-2531, 5487, -536) },
    { req = 0,    name = "Safe Zone",            p1 = Vector3.new(420, 249, 878) },
}

-- ── Manual Teleport Destinations ─────────────────────────────
M.Teleports = {
    { section = "General",        name = "Safe Zone",             pos = Vector3.new(420, 249, 878) },
    { section = "General",        name = "Devil's Training Area", pos = Vector3.new(-244, 291, 942) },
    { section = "General",        name = "City Port",             pos = Vector3.new(392, 264, -412) },

    { section = "Body Toughness", name = "Ice Bath",              pos = Vector3.new(367, 250, -445) },
    { section = "Body Toughness", name = "Lava Bath",             pos = Vector3.new(357, 264, -493) },
    { section = "Body Toughness", name = "Iceberg",               pos = Vector3.new(1538, 250, 2219) },
    { section = "Body Toughness", name = "Tornado",               pos = Vector3.new(-2297, 977, 1071) },
    { section = "Body Toughness", name = "Volcano",               pos = Vector3.new(-2005, 742, -1802) },
    { section = "Body Toughness", name = "Hellfire Pit",          pos = Vector3.new(-247, 287, 979) },
    { section = "Body Toughness", name = "Green Acid Pool",       pos = Vector3.new(-279, 281, 992) },
    { section = "Body Toughness", name = "Red Acid Pool",         pos = Vector3.new(-279, 281, 1007) },

    { section = "Fist Strength",  name = "Rock",                  pos = Vector3.new(409, 271, 981) },
    { section = "Fist Strength",  name = "Crystal",               pos = Vector3.new(-2274, 1943, 1051) },
    { section = "Fist Strength",  name = "Blue Star (1B+)",       pos = Vector3.new(1176, 4789, -2293) },
    { section = "Fist Strength",  name = "Green Star (100B+)",    pos = Vector3.new(1380, 9274, 1648) },
    { section = "Fist Strength",  name = "Red Star (10T+)",       pos = Vector3.new(-367, 15735, -11) },

    { section = "Psychic Temple", name = "1M+ Area",              pos = Vector3.new(-2524.5, 5486.7, -540.4) },
    { section = "Psychic Temple", name = "1B+ Area",              pos = Vector3.new(-2555.9, 5500.9, -445.4) },
    { section = "Psychic Temple", name = "1T+ Area",              pos = Vector3.new(-2582.8, 5516.7, -497.6) },
    { section = "Psychic Temple", name = "1Q+ Area",              pos = Vector3.new(-2545.0, 5412.5, -493.2) },
}

function M.getRockZonePos()
    for _, z in ipairs(M.FS) do
        if z.name == "Rock Zone" then
            return M.midPos(z.p1, z.p2)
        end
    end
    return Vector3.new(409, 271, 981)
end

function M.getCrystalZonePos()
    for _, z in ipairs(M.FS) do
        if z.name == "Crystal Zone" then
            return M.midPos(z.p1, z.p2)
        end
    end
    return Vector3.new(-2274, 1943, 1051)
end

-- chapter: UI "X/13" (nil = unknown, treat as starter-safe)
function M.fsTrainingMode(chapter)
    if not chapter or chapter < M.FS_CHAPTER_ROCK then
        return "starter" -- Push Up, no TP
    end
    if chapter < M.FS_CHAPTER_CRYSTAL then
        return "rock"
    end
    return "zone"
end

-- pushup = Push Up tool (<20 BT) | deathgrind = ice bath zones + respawn (20+ BT)
function M.btTrainingMode(bt)
    bt = bt or 0
    if bt < M.BT_ZONE_MIN then
        return "pushup"
    end
    return "deathgrind"
end

function M.canDeathGrind(bt)
    return (bt or 0) >= M.BT_DEATH_GRIND_MIN
end

function M.canFlyMeditateFarm(chapter, raw)
    if not chapter or chapter < M.PP_FLY_CHAPTER then return false end
    raw = raw or {}
    if (raw.JF or 0) < M.PP_FLY_MIN_JF then return false end
    if (raw.PP or 0) < M.PP_FLY_MIN_PP then return false end
    return true
end

function M.smartTarget(settings, raw, chapter)
    local function pick(zones, stat)
        for _, z in ipairs(zones) do
            if stat >= z.req then
                return M.midPos(z.p1, z.p2)
            end
        end
    end

    if settings.PsychicPower then return pick(M.PP, raw.PP) end
    if settings.FistStrength then
        local mode = M.fsTrainingMode(chapter)
        if mode == "rock" then
            return M.getRockZonePos()
        end
        if mode == "zone" then
            for _, z in ipairs(M.FS) do
                if z.name ~= "Rock Zone" and raw.FS >= z.req then
                    return M.midPos(z.p1, z.p2)
                end
            end
        end
    end

    return nil
end

-- Teleport target for autofarm loops (nil = stay in place / use starter tool)
function M.farmTarget(settings, raw, chapter)
    if settings.FistStrength and M.fsTrainingMode(chapter) == "starter" then
        return nil
    end
    if settings.BodyToughness then
        return nil
    end
    return M.smartTarget(settings, raw, chapter)
end

function M.deathGrindTarget(raw)
    if not M.canDeathGrind(raw.BT) then
        return nil
    end
    local bt = raw.BT
    for i, zone in ipairs(M.BT) do
        if bt >= zone.req then
            local upZone = (i > 1) and M.BT[i - 1] or zone
            return M.midPos(upZone.p1, upZone.p2)
        end
    end
    return M.midPos(M.BT[#M.BT].p1, M.BT[#M.BT].p2)
end

return M
