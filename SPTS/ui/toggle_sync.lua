-- Keeps the Rayfield toggle visuals in sync with _G.Settings.
-- Also handles locking/unlocking the training UI when Sath mode is active.

-- NOTE: Do NOT cache _G.Toggles into a local at load time.
-- Toggles are added after this file runs, so we always read _G.Toggles fresh.

-- Guard flag: prevents Set() -> callback -> setToggleVisual -> Set() loops.
local visualLock = false

local function getToggles()
    return _G.Toggles
end

-- Sets a toggle's visual state without triggering its callback.
_G.setToggleVisual = function(id, value)
    if visualLock then return end
    local Toggles = getToggles()
    local tog = Toggles and Toggles[id]
    if not tog then return end

    visualLock = true
    pcall(function() tog:Set(value == true) end)
    visualLock = false
end

-- Pushes the current Settings state to all toggle visuals.
-- In Sath mode, training toggles are forced off and weight shows the active tier.
_G.syncFarmToggles = function()
    local Toggles = getToggles()
    if not Toggles then return end
    if visualLock then return end

    local map = {
        FistStrength  = "FS",
        BodyToughness = "BT",
        MovementSpeed = "MS",
        JumpForce     = "JF",
        PsychicPower  = "PP",
        DeathGrinding = "DG",
    }

    _G.cascadeLock = true
    visualLock     = true

    if _G.Settings.AutoSathQuest then
        for _, id in pairs(map) do
            local tog = Toggles[id]
            if tog then pcall(function() tog:Set(false) end) end
        end

        local aw = _G.Settings.ActiveWeight or 0
        _G.sathWeightLock = true
        for i = 1, 4 do
            local tog = Toggles["W" .. i]
            if tog then pcall(function() tog:Set(i == aw) end) end
        end
        _G.sathWeightLock = false
    else
        for flag, id in pairs(map) do
            local tog = Toggles[id]
            if tog then pcall(function() tog:Set(_G.Settings[flag] == true) end) end
        end
    end

    visualLock     = false
    _G.cascadeLock = false

    if _G.setTrainingUiLocked then
        _G.setTrainingUiLocked(_G.Settings.AutoSathQuest)
    end
end

-- Locks or unlocks the training and weight toggles in the Rayfield UI.
-- Only touches interactability — never calls Set() to avoid re-triggering callbacks.
_G.setTrainingUiLocked = function(locked)
    local Toggles = getToggles()
    if not Toggles then return end

    local function lockGuiTree(root, on)
        if typeof(root) ~= "Instance" then return end
        if root:IsA("GuiObject") then root.Interactable = not on end
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("GuiObject") then d.Interactable = not on end
        end
    end

    local function lockOne(tog)
        if not tog then return end
        if tog.Lock          then pcall(function() tog:Lock(locked)               end) end
        if tog.SetInteraction then pcall(function() tog:SetInteraction(not locked) end) end
        if tog.SetLocked     then pcall(function() tog:SetLocked(locked)          end) end

        local root
        for _, key in ipairs({ "Toggle", "ToggleFrame", "Object", "Container", "Frame", "Holder" }) do
            if typeof(tog[key]) == "Instance" then root = tog[key]; break end
        end
        lockGuiTree(root, locked)
    end

    for _, id in ipairs({ "FS", "BT", "MS", "JF", "PP", "DG" }) do
        lockOne(Toggles[id])
    end
    for i = 1, 4 do
        lockOne(Toggles["W" .. i])
    end
end
