-- Psychic Power training loop.
-- Low chapter / low stats: equip Meditate tool on the ground.
-- High chapter (10+) with enough JF and PP: fly + meditate for faster gains.
-- Uses Module.lua's canFlyMeditateFarm to decide which mode to use.

local Z              = _G.Z
local LP             = _G.LP
local Remote         = _G.Remote
local UserInputService = _G.UserInputService

local flyStatusSynced = false

-- ── Fly state helpers ─────────────────────────────────────────

local function setFlyStatus(on)
    flyStatusSynced = on == true
    pcall(function()
        Remote:FireServer({ "Update_Flying_Status", flyStatusSynced })
    end)
end

_G.isFlying = function()
    return _G.Flying == true or flyStatusSynced
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
    return not _G.hasMeditateEquipped()
end

-- ── Input helpers ─────────────────────────────────────────────

local function pressSpace()
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true,  Enum.KeyCode.Space, false, game)
        task.wait(0.04)
        vim:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
    end)
end

local function doPhysicalJump()
    pcall(function() UserInputService:JumpRequest() end)
end

-- ── Fly entry logic ───────────────────────────────────────────

local function isOnGround(hum)
    return hum.FloorMaterial ~= Enum.Material.Air
end

local function isFalling(hum, root)
    local st = hum:GetState()
    if st == Enum.HumanoidStateType.Freefall then return true end
    if root then
        local vy = root.AssemblyLinearVelocity.Y
        if vy < -1.5 then return true end
    end
    return false
end

local function waitUntilFalling(hum, root, maxSec)
    local t0 = os.clock()
    while os.clock() - t0 < (maxSec or 1.2) do
        if isFalling(hum, root) then return true end
        task.wait(0.05)
    end
    return isFalling(hum, root)
end

-- Finds a clear spot above the character to jump from without hitting a ceiling.
local function findOpenFlyPosition()
    local char     = LP.Character
    local root     = char and char:FindFirstChild("HumanoidRootPart")
    local fallback = Vector3.new(420, 299, 878)
    if not root then return fallback end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { char }

    local offsets = {
        Vector3.zero,
        Vector3.new( 25, 0,  0),
        Vector3.new(-25, 0,  0),
        Vector3.new(  0, 0, 25),
        Vector3.new(  0, 0,-25),
    }

    for _, off in ipairs(offsets) do
        local base = root.Position + off
        for lift = 35, 100, 15 do
            local pos        = Vector3.new(base.X, base.Y + lift, base.Z)
            local clearAbove = not workspace:Raycast(pos, Vector3.new(0, 20, 0), params)
            local clearHead  = not workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, 8, 0), params)
            if clearAbove and clearHead then return pos end
        end
    end

    return fallback
end

local function activateFlyJump(hum, root)
    if _G.isFlying() then setFlyStatus(true); return true end

    if isFalling(hum, root) then
        pressSpace()
        task.wait(0.4)
        if _G.isFlying() then setFlyStatus(true); return true end
        return false
    end

    if isOnGround(hum) then
        doPhysicalJump()
        task.wait(0.12)
        waitUntilFalling(hum, root, 1.2)
    end

    if isFalling(hum, root) then
        pressSpace()
        task.wait(0.4)
        if _G.isFlying() then setFlyStatus(true); return true end
    end

    return false
end

-- Stops flying and unequips the Meditate tool.
_G.stopFlyMode = function()
    if not _G.isFlying() and not _G.hasMeditateEquipped() then
        flyStatusSynced = false
        return
    end

    unequipMeditateTool()
    waitUntilMeditateGone(2)

    if _G.isFlying() then
        pressSpace()
        task.wait(0.25)
    end

    setFlyStatus(false)
    _G.Flying = false
end

local function tryEnterFlyMode()
    if _G.isFlying() then setFlyStatus(true); return true end

    local chapter = _G.sathScanner.readMainQuestChapterFromUI()
    if not Z.canFlyMeditateFarm(chapter, _G.RawStats) then return false end

    pcall(function() Remote:FireServer({ "Setting", "ToggleFlight", true }) end)

    local char = LP.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then return false end

    if activateFlyJump(hum, root) then return true end

    -- Couldn't get airborne from current position — try a clear spot nearby.
    root.CFrame = CFrame.new(findOpenFlyPosition())
    task.wait(0.3)
    hum  = char:FindFirstChildOfClass("Humanoid")
    root = char and char:FindFirstChild("HumanoidRootPart")
    if hum and root then
        waitUntilFalling(hum, root, 1.5)
        activateFlyJump(hum, root)
    end

    return _G.isFlying()
end

local function equipMeditateTool()
    if _G.sathAutofarmBlocked() or not _G.isFlying() then return end
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
            -- Stop flying if PP isn't active so we don't float around doing nothing.
            if not _G.Settings.PsychicPower then
                _G.stopFlyMode()
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
                if tryEnterFlyMode() and _G.isFlying() then
                    equipMeditateTool()
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
