-- Psychic Power training loop.
-- Fly detection: _G.Flying is set by the game's LocalScript (accessible).
-- CanFly global is also set by the game (true when in Freefall).
-- To enter fly: jump → wait for Freefall (CanFly=true) → jump again.
-- Once flying: equip Meditate for 10x PP gains.
-- When PP target reached: unequip Meditate → stop fly via jump.

local Z              = _G.Z
local LP             = _G.LP
local UserInputService = _G.UserInputService

-- ── Fly state ─────────────────────────────────────────────────

_G.isFlying = function()
    -- _G.Flying is set by the game's own LocalScript, not ClientPlrData.
    if _G.Flying == true then return true end
    -- Also check BodyVelocity/BodyGyro added to root during fly.
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        if root:FindFirstChildOfClass("BodyVelocity") or root:FindFirstChildOfClass("BodyGyro") then
            return true
        end
    end
    return false
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

-- Stop fly: unequip Meditate first (required by game to allow fly cancel),
-- then jump to exit fly mode.
_G.stopFlyMode = function()
    if not _G.isFlying() and not _G.hasMeditateEquipped() then return end
    unequipMeditateTool()
    waitUntilMeditateGone(2)
    if _G.isFlying() then
        pcall(function() UserInputService:JumpRequest() end)
        task.wait(0.5)
    end
end

-- ── Double jump to enter fly ──────────────────────────────────

local function doJump()
    local vim = game:GetService("VirtualInputManager")
    vim:SendKeyEvent(true,  Enum.KeyCode.Space, false, game)
    task.wait(0.05)
    vim:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
end

local function getHumAndRoot()
    local char = LP.Character
    if not char then return nil, nil end
    return char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart")
end

local function tryEnterFlyMode()
    if _G.isFlying() then return true end

    local hum, root = getHumAndRoot()
    if not hum or not root or hum.Health <= 0 then return false end

    -- First Space press — jump
    doJump()
    task.wait(0.8)
    -- Second Space press — activates fly while in freefall
    doJump()

    -- Wait for _G.Flying to become true
    local t0 = tick()
    while tick() - t0 < 1.5 do
        if _G.isFlying() then return true end
        task.wait(0.05)
    end

    return _G.isFlying()
end

-- ── Meditate equip ────────────────────────────────────────────

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
            local useFly  = Z.canFlyMeditateFarm(chapter, _G.RawStats)

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

            if useFly then
                _G.ppUseFlyMode = true
                if _G.isFlying() then
                    equipMeditateTool()
                else
                    if tryEnterFlyMode() then
                        task.wait(0.2)
                        equipMeditateTool()
                    else
                        task.wait(2)
                    end
                end
            else
                if _G.ppUseFlyMode then
                    _G.stopFlyMode()
                    _G.ppUseFlyMode = false
                end
                equipMeditateTool()
            end

        else
            if _G.ppTeleported or _G.ppUseFlyMode then
                _G.unequipAllTools()
                _G.stopFlyMode()
            end
            _G.ppTeleported = false
            _G.ppUseFlyMode = false
        end

        task.wait(0.4)
    end
end)
