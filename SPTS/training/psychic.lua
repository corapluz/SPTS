-- Psychic Power training loop.
--
-- Fly mode requires ToggleFlight setting to be ON in the game's own settings.
-- We cannot set that — only the player can toggle it in-game.
-- So we detect if the player is already flying via _G.Flying (set by the game's LocalScript).
-- If flying: equip Meditate for 10x gains.
-- If not flying: just equip Meditate on the ground in the right PP zone.

local Z  = _G.Z
local LP = _G.LP

_G.isFlying = function()
    return _G.Flying == true
end

_G.hasMeditateEquipped = function()
    local char = LP.Character
    return char and char:FindFirstChild("Meditate") ~= nil
end

local function unequipMeditateTool()
    if not _G.hasMeditateEquipped() then return end
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum:UnequipTools() end) end
end

local function waitUntilMeditateGone(maxSec)
    local t0 = os.clock()
    while _G.hasMeditateEquipped() and os.clock() - t0 < (maxSec or 2) do
        unequipMeditateTool()
        task.wait(0.1)
    end
end

-- Stop fly: unequip Meditate so the game allows fly to be cancelled on next jump.
_G.stopFlyMode = function()
    unequipMeditateTool()
    waitUntilMeditateGone(2)
    -- _G.Flying will be set to false by the game's own LocalScript when fly ends.
end

-- Equip Meditate tool — works both on ground and while flying.
local function equipMeditateTool()
    if _G.sathAutofarmBlocked() then return end
    local char = LP.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not hum or hum.Health <= 0 then return end
    if char:FindFirstChild("Meditate") then return end
    local tool = LP.Backpack:FindFirstChild("Meditate")
    if tool then hum:EquipTool(tool) end
end

-- ── Main PP loop ──────────────────────────────────────────────

task.spawn(function()
    while true do
        if _G.sathAutofarmBlocked() then
            if not _G.Settings.PsychicPower then
                _G.unequipAllTools()
            end
            task.wait(0.15)
            continue
        end

        if _G.Settings.PsychicPower then
            local chapter = _G.sathScanner.readMainQuestChapterFromUI()

            -- Teleport to the right PP zone once per activation.
            if not _G.ppTeleported then
                local target = Z.smartTarget({ PsychicPower = true }, _G.RawStats, chapter)
                if target then
                    local char = LP.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if root then
                        root.CFrame = CFrame.new(target)
                        _G.ppTeleported = true
                        task.wait(0.5)
                    end
                else
                    _G.ppTeleported = true
                end
            end

            -- Whether flying or on ground, just keep Meditate equipped.
            -- If the player has ToggleFlight on and is flying, Meditate gives 10x.
            -- If on ground, Meditate still gives normal gains.
            equipMeditateTool()

        else
            if _G.ppTeleported then
                _G.unequipAllTools()
            end
            _G.ppTeleported  = false
            _G.ppUseFlyMode  = false
        end

        task.wait(0.4)
    end
end)
