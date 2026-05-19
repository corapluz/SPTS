-- Autofarm tab: training toggles, death grinding, quest claim, and Sath Quest section.

local Tabs     = _G.Tabs
local Toggles  = _G.Toggles
local Rayfield = _G.Rayfield
local Z        = _G.Z

local keyMap = {
    FS = "FistStrength",
    BT = "BodyToughness",
    MS = "MovementSpeed",
    JF = "JumpForce",
    PP = "PsychicPower",
}

-- Turns off conflicting toggles when one is switched on.
-- e.g. turning on PP disables BT/MS/JF/DG.
local function cascade(id)
    if _G.cascadeLock or _G.Settings.AutoSathQuest then return end
    _G.cascadeLock = true

    if id == "PP" and _G.Settings.PsychicPower then
        for _, k in ipairs({ "BT", "MS", "JF", "DG" }) do
            local key = keyMap[k] or (k == "DG" and "DeathGrinding")
            if key then _G.Settings[key] = false end
            if Toggles[k] then Toggles[k]:Set(false) end
        end

    elseif id == "DG" and _G.Settings.DeathGrinding then
        if Z.btTrainingMode(_G.RawStats.BT) == "pushup" then
            _G.Settings.DeathGrinding = false
            if Toggles.DG then Toggles.DG:Set(false) end
        end
        _G.Settings.BodyToughness = false
        if Toggles.BT then Toggles.BT:Set(false) end
        _G.Settings.PsychicPower = false
        _G.ppTeleported = false
        if Toggles.PP then Toggles.PP:Set(false) end

    elseif (id == "BT" or id == "MS" or id == "JF") and _G.Settings[keyMap[id]] then
        _G.Settings.PsychicPower = false
        _G.ppTeleported = false
        if Toggles.PP then Toggles.PP:Set(false) end
        _G.Settings.DeathGrinding = false
        if Toggles.DG then Toggles.DG:Set(false) end
    end

    _G.cascadeLock = false
end

-- Disables Auto Sath Quest when the user manually flips a training toggle.
local function disableSathQuestFromTraining()
    if not _G.Settings.AutoSathQuest then return end
    _G.Settings.AutoSathQuest = false
    _G.restoreConflictingFarms()
    _G.syncFarmToggles()
    if Toggles and Toggles.SQ then Toggles.SQ:Set(false) end
    Rayfield:Notify({
        Title    = "Sath",
        Content  = "Disabled — training toggle was turned on.",
        Duration = 4,
        Image    = "alert-circle",
    })
end

-- ── Training toggles ──────────────────────────────────────────

Tabs.Auto:CreateSection("Training")

local matrixDefs = {
    { id = "FS", name = "Auto Fist Strength",  flag = "Run_FS" },
    { id = "BT", name = "Auto Body Toughness", flag = "Run_BT" },
    { id = "MS", name = "Auto Movement Speed", flag = "Run_MS" },
    { id = "JF", name = "Auto Jump Force",     flag = "Run_JF" },
    { id = "PP", name = "Auto Psychic Power",  flag = "Run_PP" },
}

for _, def in ipairs(matrixDefs) do
    local id = def.id
    Toggles[id] = Tabs.Auto:CreateToggle({
        Name         = def.name,
        CurrentValue = false,
        Flag         = def.flag,
        Callback     = function(v)
            if _G.cascadeLock then return end
            if _G.Settings.AutoSathQuest then
                if _G.setToggleVisual then _G.setToggleVisual(id, false) end
                if v then disableSathQuestFromTraining() end
                return
            end
            _G.Settings[keyMap[id]] = v
            if id == "PP" and not v then
                _G.ppTeleported = false
                _G.unequipAllTools()
            end
            cascade(id)
        end,
    })
end

-- ── Anti-AFK ──────────────────────────────────────────────────

Tabs.Auto:CreateSection("Anti-AFK")
Toggles["AA"] = Tabs.Auto:CreateToggle({
    Name         = "Anti-AFK",
    CurrentValue = true,
    Flag         = "Run_AA",
    Callback     = function(v) _G.Settings.AntiAfk = v end,
})

-- ── Death Grinding ────────────────────────────────────────────

Tabs.Auto:CreateSection("Death Grinding")
Toggles["DG"] = Tabs.Auto:CreateToggle({
    Name         = "Death Grinding (BT)",
    CurrentValue = false,
    Flag         = "Run_DG",
    Callback     = function(v)
        if _G.cascadeLock then return end
        if _G.Settings.AutoSathQuest then
            if _G.setToggleVisual then _G.setToggleVisual("DG", false) end
            if v then disableSathQuestFromTraining() end
            return
        end
        if v and not Z.canDeathGrind(_G.RawStats.BT) then
            Rayfield:Notify({
                Title    = "Death Grinding",
                Content  = "Needs 20+ Body Toughness first.",
                Duration = 4,
                Image    = "alert-circle",
            })
            if Toggles.DG then Toggles.DG:Set(false) end
            return
        end
        _G.Settings.DeathGrinding = v
        cascade("DG")
    end,
})

-- ── Quest Auto-Claim ──────────────────────────────────────────

Tabs.Auto:CreateSection("Quest Auto-Claim")
Toggles["AQ"] = Tabs.Auto:CreateToggle({
    Name         = "Auto Quest Claim",
    CurrentValue = false,
    Flag         = "Run_AQ",
    Callback     = function(v) _G.Settings.AutoQuest = v end,
})

-- ── Sath Quest ────────────────────────────────────────────────

Tabs.Auto:CreateSection("Sath Quest")

local SathQuestInfo = Tabs.Auto:CreateLabel("—", "info")

-- Refresh the status line every second.
task.spawn(function()
    while task.wait(1) do
        SathQuestInfo:Set(_G.buildSathInfoText())
    end
end)

Toggles["SQ"] = Tabs.Auto:CreateToggle({
    Name         = "Auto Complete Sath Quest",
    CurrentValue = false,
    Flag         = "Run_SQ",
    Callback     = function(v)
        _G.Settings.AutoSathQuest = v
        if v then
            _G.pauseConflictingFarms()
            if _G.sathScanner.needsQuestPickupFromSath() then
                _G.syncFarmToggles()
            else
                local tasks = _G.sathScanner.scanMainQuestUI()
                if tasks and #tasks > 0 then
                    _G.applySathFarmPhase(_G.sathScanner.enrichTasksFromQuestDef(tasks))
                else
                    _G.syncFarmToggles()
                end
            end
        else
            _G.restoreConflictingFarms()
            _G.syncFarmToggles()
        end
    end,
})
