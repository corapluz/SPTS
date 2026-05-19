-- Controls which stats are being farmed at any given moment during a Sath quest.
-- One stat trains at a time, in the order defined by quest_defs.
-- When a stat finishes, this module switches to the next one automatically.

local Z = _G.Z

-- Shorthand accessors — read from _G so load order doesn't matter.
local function DEFS()           return _G.SATH_QUEST_DEFS     end
local function FARM_FLAGS()     return _G.SATH_FARM_FLAGS     end
local function PHYSICAL_FLAGS() return _G.SATH_PHYSICAL_FLAGS end
local function FLAG_LABELS()    return _G.SATH_FLAG_LABELS    end
local function scanner()        return _G.sathScanner         end

-- Saved copies of the user's training toggles before Sath mode took over.
local savedSathFarmFlags = {}

-- State globals read by dialog.lua, loop.lua, and the training loops.
_G.sathFarmLock     = false
_G.sathDialogBusy   = false
_G.sathTalkMode     = false
_G.sathWeightLock   = false
_G.ppTeleported     = false
_G.ppUseFlyMode     = false
_G.lastSathFarmFlag = nil

-- Returns true when the farm loop should pause and let the dialog run.
local function sathAutofarmBlocked()
    return _G.sathDialogBusy or _G.sathTalkMode
end

-- Checks whether a task's stat target has been reached.
-- Checks t.complete first (set by the UI scan), then falls back to RawStats.
local function farmTaskSatisfied(t)
    if t.isKill or not t.flag or t.target <= 0 then return false end
    if t.complete then return true end
    local rawKey  = _G.STAT_TO_RAW[t.flag]
    local statVal = rawKey and (_G.RawStats[rawKey] or 0) or 0
    local best    = math.max(t.current or 0, statVal)
    return best >= t.target
end

-- Returns only the tasks that still need farming.
local function getIncompleteFarmTasks(tasks)
    local list = {}
    for _, t in ipairs(tasks) do
        if t.flag and not t.isKill and not farmTaskSatisfied(t) then
            table.insert(list, t)
        end
    end
    return list
end

-- Returns incomplete tasks sorted by the definition order for the current quest.
local function getOrderedIncompleteTasks(tasks)
    local incomplete = getIncompleteFarmTasks(tasks)
    if #incomplete == 0 then return incomplete end

    local no = scanner().getMainQuestNo() or scanner().detectQuestId(tasks)
    if not (no and DEFS()[no]) then
        table.sort(incomplete, function(a, b) return (a.index or 0) < (b.index or 0) end)
        return incomplete
    end

    local ordered = {}
    for _, dt in ipairs(DEFS()[no].tasks) do
        if dt.key ~= "KILLS" and dt.farm ~= false then
            for _, t in ipairs(incomplete) do
                if t.key == dt.key then
                    table.insert(ordered, t); break
                end
            end
        end
    end
    return ordered
end

-- Saves the current training flags and turns them all off so Sath mode
-- has full control. Safe to call multiple times — won't overwrite the save.
local function pauseConflictingFarms()
    if _G.sathFarmLock then return end
    _G.sathFarmLock = true
    savedSathFarmFlags = {}
    for _, k in ipairs(FARM_FLAGS()) do
        savedSathFarmFlags[k] = _G.Settings[k]
        _G.Settings[k] = false
    end
    savedSathFarmFlags.ActiveWeight = _G.Settings.ActiveWeight
    _G.ppTeleported = false
end

-- Restores the flags saved by pauseConflictingFarms.
-- Only called when the user manually turns off Auto Sath Quest.
local function restoreConflictingFarms()
    if not _G.sathFarmLock then return end
    local savedWeight = savedSathFarmFlags.ActiveWeight
    for k, v in pairs(savedSathFarmFlags) do
        _G.Settings[k] = v
    end
    savedSathFarmFlags = {}
    _G.sathFarmLock = false
    if not _G.Settings.AutoSathQuest and savedWeight ~= nil and _G.setSathEquipWeight then
        _G.setSathEquipWeight(savedWeight or 0)
    end
end

-- Zeroes out all training flags without touching the saved snapshot.
-- Called at the start of each farm phase so we start from a clean slate.
local function clearSathFarmFlagsOnly()
    _G.Settings.FistStrength  = false
    _G.Settings.BodyToughness = false
    _G.Settings.MovementSpeed = false
    _G.Settings.JumpForce     = false
    _G.Settings.PsychicPower  = false
    _G.Settings.DeathGrinding = false
    _G.ppTeleported = false
end

-- Picks the best weight tier for the current MS/JF values.
local function maxWeightTierForStat(val, statKey)
    local field = statKey == "MS" and "MS" or "JF"
    local best  = 0
    for tier = 1, 4 do
        if val >= _G.WEIGHT_REQS[tier][field] then best = tier end
    end
    return best
end

local function getMobilityWeightTier(incomplete)
    local needMS, needJF = false, false
    for _, t in ipairs(incomplete) do
        if t.flag == "MovementSpeed" and not t.complete then needMS = true end
        if t.flag == "JumpForce"     and not t.complete then needJF = true end
    end
    if not needMS and not needJF then return 0 end

    local ms, jf = _G.RawStats.MS, _G.RawStats.JF

    if needMS and needJF then
        for tier = 4, 1, -1 do
            if ms >= _G.WEIGHT_REQS[tier].MS and jf >= _G.WEIGHT_REQS[tier].JF then
                return tier
            end
        end
        for tier = 4, 1, -1 do
            if ms >= _G.WEIGHT_REQS[tier].MS then return tier end
        end
        return 0
    elseif needMS then
        return maxWeightTierForStat(ms, "MS")
    else
        return maxWeightTierForStat(jf, "JF")
    end
end

-- The main phase switcher. Figures out which stat to train next and flips
-- the right Settings flags. One stat at a time, in definition order.
-- MS+JF run together only when both are needed in the same quest.
local function applySathFarmPhase(tasks)
    if not _G.sathFarmLock then pauseConflictingFarms() end
    clearSathFarmFlagsOnly()

    tasks = scanner().enrichTasksFromQuestDef(tasks)
    local incomplete = getOrderedIncompleteTasks(tasks)

    if #incomplete == 0 then
        _G.lastSathFarmFlag = nil
        _G.unequipAllTools()
        _G.syncFarmToggles()
        return nil
    end

    local activeFlags  = {}
    local activeLabels = {}
    local hasMS, hasJF = false, false
    local physicalIncomplete = {}

    for _, t in ipairs(incomplete) do
        if t.flag == "MovementSpeed"       then hasMS = true end
        if t.flag == "JumpForce"           then hasJF = true end
        if PHYSICAL_FLAGS()[t.flag]        then table.insert(physicalIncomplete, t) end
    end

    local mobilityPair = hasMS and hasJF
    local primary      = physicalIncomplete[1]

    if primary then
        table.insert(activeFlags,  primary.flag)
        table.insert(activeLabels, FLAG_LABELS()[primary.flag] or primary.flag)

        if (primary.flag == "FistStrength" or primary.flag == "BodyToughness") and mobilityPair then
            -- Run MS+JF alongside the physical stat so weights stay active.
            table.insert(activeFlags,  "MovementSpeed")
            table.insert(activeFlags,  "JumpForce")
            table.insert(activeLabels, "Movement Speed")
            table.insert(activeLabels, "Jump Force")
        elseif (primary.flag == "MovementSpeed" or primary.flag == "JumpForce") and mobilityPair then
            activeFlags  = { "MovementSpeed", "JumpForce" }
            activeLabels = { "Movement Speed", "Jump Force" }
        end
    elseif incomplete[1].flag == "PsychicPower" then
        table.insert(activeFlags,  "PsychicPower")
        table.insert(activeLabels, "Psychic Power")
    end

    if #activeFlags == 0 then
        _G.syncFarmToggles()
        return nil
    end

    _G.Settings.DeathGrinding = false
    for _, flag in ipairs(activeFlags) do
        _G.Settings[flag] = true
    end

    -- Enable death grinding automatically when BT is high enough.
    if activeFlags[1] == "BodyToughness" and Z.btTrainingMode(_G.RawStats.BT) == "deathgrind" then
        _G.Settings.DeathGrinding = true
    end

    -- Unequip the old tool when switching stats so the new one gets equipped cleanly.
    local primaryFlag = activeFlags[1]
    if primaryFlag ~= _G.lastSathFarmFlag then
        _G.unequipAllTools()
        _G.lastSathFarmFlag = primaryFlag
    end

    -- Equip the right weight tier for mobility stats.
    local needWeight = false
    for _, f in ipairs(activeFlags) do
        if f == "MovementSpeed" or f == "JumpForce" then needWeight = true; break end
    end

    if needWeight and _G.setSathEquipWeight then
        local mobilityTasks = {}
        for _, t in ipairs(incomplete) do
            if t.flag == "MovementSpeed" or t.flag == "JumpForce" then
                table.insert(mobilityTasks, t)
            end
        end
        _G.setSathEquipWeight(getMobilityWeightTier(mobilityTasks))
    elseif activeFlags[1] == "PsychicPower" and _G.setSathEquipWeight then
        _G.setSathEquipWeight(0)
    end

    _G.syncFarmToggles()
    return primaryFlag, activeLabels, nil, physicalIncomplete
end

-- Returns true if the tool farm loop is allowed to use a given training flag.
-- In Sath mode, only the currently active stat's flag returns true.
-- The double-check on Settings[flag] prevents a race where lastSathFarmFlag
-- hasn't updated yet but the flag was already cleared by clearSathFarmFlagsOnly.
local function sathAllowsToolFarm(flag)
    if not _G.Settings.AutoSathQuest then return _G.Settings[flag] == true end
    if not _G.Settings[flag] then return false end
    if not _G.lastSathFarmFlag then return false end
    if flag == "FistStrength" or flag == "BodyToughness" then
        return _G.lastSathFarmFlag == flag
    end
    return _G.Settings[flag] == true
end

local function hasPendingKillTask(tasks)
    for _, t in ipairs(tasks) do
        if t.isKill and t.target > 0 and t.current < t.target then return true end
    end
    return false
end

local function allAutoFarmTasksDone(tasks)
    local any = false
    for _, t in ipairs(tasks) do
        if t.flag and not t.isKill then
            any = true
            if not farmTaskSatisfied(t) then return false end
        end
    end
    return any
end

-- Returns true when every farmable task is done and it's safe to talk to Sath.
local function isReadyForSathTalk(tasks, talkBtn)
    if not tasks or #tasks == 0 then return false end
    tasks = scanner().enrichTasksFromQuestDef(tasks)
    if hasPendingKillTask(tasks) then return false end
    if not allAutoFarmTasksDone(tasks) then return false end
    if talkBtn and talkBtn.Visible then return true end
    return true
end

local function needsSathFarm(tasks)
    return #getIncompleteFarmTasks(scanner().enrichTasksFromQuestDef(tasks)) > 0
end

-- Builds the one-line status string shown in the Sath Quest dashboard label.
local function buildSathInfoText()
    if scanner().needsQuestPickupFromSath() then
        return "Quest 0/13 — 0/0 ready | Go to Sath"
    end

    local tasks = scanner().scanMainQuestUI()
    if not tasks or #tasks == 0 then return "—" end
    tasks = scanner().enrichTasksFromQuestDef(tasks)

    local no    = scanner().getMainQuestNo()
    local qid   = scanner().detectQuestId(tasks)
    local idStr = (no and no > 0 and tostring(no)) or (qid and tostring(qid)) or "?"

    local ready, farmTotal = 0, 0
    local lines = {}

    for _, t in ipairs(tasks) do
        if t.flag and not t.isKill then
            farmTotal = farmTotal + 1
            if farmTaskSatisfied(t) then ready = ready + 1 end
            local label = FLAG_LABELS()[t.flag]
            if label and t.progTxt and t.progTxt ~= "" then
                table.insert(lines, label .. ": " .. t.progTxt)
            end
        end
    end

    local head = string.format("Quest %s/13 — %d/%d ready", idStr, ready, farmTotal)
    if #lines == 0 then return head end
    return head .. " | " .. table.concat(lines, " · ")
end

-- Stops all training and gets ready for the Sath dialog.
local function prepareForSathTalk()
    _G.sathTalkMode = true
    clearSathFarmFlagsOnly()
    _G.ppUseFlyMode = false
    if _G.stopFlyMode then _G.stopFlyMode() end
    _G.unequipAllTools()
    _G.syncFarmToggles()
end

-- Expose everything as globals so dialog.lua, loop.lua, and UI tabs
-- can call them without require().
_G.pauseConflictingFarms   = pauseConflictingFarms
_G.restoreConflictingFarms = restoreConflictingFarms
_G.clearSathFarmFlagsOnly  = clearSathFarmFlagsOnly
_G.applySathFarmPhase      = applySathFarmPhase
_G.sathAutofarmBlocked     = sathAutofarmBlocked
_G.prepareForSathTalk      = prepareForSathTalk
_G.sathAllowsToolFarm      = sathAllowsToolFarm
_G.buildSathInfoText       = buildSathInfoText
_G.isReadyForSathTalk      = isReadyForSathTalk
_G.needsSathFarm           = needsSathFarm
_G.hasPendingKillTask      = hasPendingKillTask
_G.farmTaskSatisfied       = farmTaskSatisfied
