-- Psychic Power training loop.
-- Fly detection: _G.Flying is set by the game's own LocalScript.
-- To enter fly: double jump (jump → freefall → jump again).
-- CanFly global is set to true by the game when in Freefall state.
-- Once flying: equip Meditate for 10x PP gains.
-- Below 1M PP or quest 9 not done: just equip Meditate on the ground.

local Z              = _G.Z
local LP             = _G.LP
local UserInputService = _G.UserInputService

_G.isFlying = function()
    -- _G.Flying is set by the game's own LocalScript (not ClientPlrData).
    -- Also check for fly animations as a fallback.
    if _G.Flying == true then return true end
    -- Check if fly animation is playing on the character
    local char = LP.Character
    if not char then return false end
    local animTracks = _G.AnimTracks
    if animTracks then
        for _, track in pairs(animTracks) do
            if track and track.IsPlaying then
                local name = track.Animation and track.Animation.Name or ""
                if name:find("Fly") then return true end
            end
        end
    end
    -- Fallback: check HumanoidRootPart for BodyVelocity/BodyGyro (added during fly)
    local root = char:FindFirstChild("HumanoidRootPart")
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

-- Unequip Meditate so the game allows fly to be cancelled on next jump.
_G.stopFlyMode = function()
    unequipMeditateTool()
    waitUntilMeditateGone(2)
end

local function doJump()
    pcall(function() UserInputService:JumpRequest() end)
end

local function isFalling()
    local char = LP.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    return hum:GetState() == Enum.HumanoidStateType.Freefall
end

local function isOnGround()
    local char = LP.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    return hum.FloorMaterial ~= Enum.Material.Air
end

-- Double jump to enter fly mode.
-- The game sets CanFly=true when in Freefall, then onJumpRequest activates fly.
-- Returns true if flying after the attempt.
local function tryEnterFlyMode()
    if _G.isFlying() then return true end

    local char = LP.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then return false end

    -- Step 1: get airborne if on ground
    if isOnGround() then
        doJump()
        -- Wait for freefall state (CanFly becomes true)
        local t0 = tick()
        while tick() - t0 < 1.5 do
            if isFalling() then break end
            task.wait(0.05)
        end
    end

    -- Step 2: in freefall, jump again to activate fly
    if isFalling() then
        task.wait(0.05) -- tiny wait so CanFly is set
        doJump()
        -- Wait for _G.Flying to become true
        local t0 = tick()
        while tick() - t0 < 1 do
            if _G.isFlying() then return true end
            task.wait(0.05)
        end
    end

    return _G.isFlying()
end

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
                -- Don't stop fly — player controls that via ToggleFlight setting
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
                    -- Already flying — keep Meditate equipped.
                    equipMeditateTool()
                else
                    -- Try double jump to enter fly.
                    if tryEnterFlyMode() then
                        task.wait(0.2)
                        equipMeditateTool()
                    else
                        -- Fly didn't activate — wait before retrying.
                        task.wait(2)
                    end
                end
            else
                -- Ground mode: just equip Meditate in the zone.
                if _G.ppUseFlyMode then
                    _G.ppUseFlyMode = false
                end
                equipMeditateTool()
            end

        else
            if _G.ppTeleported or _G.ppUseFlyMode then
                _G.unequipAllTools()
            end
            _G.ppTeleported = false
            _G.ppUseFlyMode = false
        end

        task.wait(0.4)
    end
end)
