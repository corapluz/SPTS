-- Psychic Power training loop.
--
-- Three modes depending on chapter and stats:
--   ground      — always works: teleport to PP zone, equip Meditate tool, stay put.
--   fly+meditate — quest 9 done (chapter 10+), JF >= 10K, PP >= 50:
--                  enter fly mode then equip Meditate for 10x gains.
--   high zone   — PP >= 1M: just stand in the 1M+ area with Meditate equipped.
--
-- Remote events are NOT used for PP — only the Meditate tool matters.
-- The tool must stay equipped; unequipping it stops the gain.

local Z              = _G.Z
local LP             = _G.LP
local Remote         = _G.Remote
local UserInputService = _G.UserInputService

local flyStatusSynced = false

-- ── Fly helpers ───────────────────────────────────────────────

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

local function isOnGround(hum)
    return hum.FloorMaterial ~= Enum.Material.Air
end

local function isFalling(hum, root)
    if hum:GetState() == Enum.HumanoidStateType.Freefall then return true end
    if root and root.AssemblyLinearVelocity.Y < -1.5 then return true end
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

local function findOpenFlyPosition()
    local char     = LP.Character
    local root     = char and char:FindFirstChild("HumanoidRootPart")
    local fallback = Vector3.new(420, 299, 878)
    if not root then return fallback end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { char }

    for _, off in ipairs({
        Vector3.zero,
        Vector3.new( 25,0,0), Vector3.new(-25,0,0),
        Vector3.new(0,0, 25), Vector3.new(0,0,-25),
    }) do
        local base = root.Position + off
        for lift = 35, 100, 15 do
            local pos = Vector3.new(base.X, base.Y + lift, base.Z)
            if not workspace:Raycast(pos, Vector3.new(0,20,0), params)
            and not workspace:Raycast(pos + Vector3.new(0,2,0), Vector3.new(0,8,0), params)
            then
                return pos
            end
        end
    end
    return fallback
end

local function activateFlyJump(hum, root)
    if _G.isFlying() then setFlyStatus(true); return true end

    -- Must be falling/freefall to trigger fly mode via jump request.
    if isFalling(hum, root) then
        -- Use JumpRequest (not Space key) — this is what triggers onJumpRequest in the game.
        pcall(function() UserInputService:JumpRequest() end)
        task.wait(0.5)
        if _G.isFlying() then setFlyStatus(true); return true end
        return false
    end

    if isOnGround(hum) then
        doPhysicalJump()
        task.wait(0.15)
        waitUntilFalling(hum, root, 1.5)
    end

    if isFalling(hum, root) then
        pcall(function() UserInputService:JumpRequest() end)
        task.wait(0.5)
        if _G.isFlying() then setFlyStatus(true); return true end
    end
    return false
end

_G.stopFlyMode = function()
    if not _G.isFlying() and not _G.hasMeditateEquipped() then
        flyStatusSynced = false
        return
    end
    unequipMeditateTool()
    waitUntilMeditateGone(2)
    if _G.isFlying() then pressSpace(); task.wait(0.25) end
    setFlyStatus(false)
    _G.Flying = false
end

local function tryEnterFlyMode()
    if _G.isFlying() then setFlyStatus(true); return true end

    local chapter = _G.sathScanner.readMainQuestChapterFromUI()
    if not Z.canFlyMeditateFarm(chapter, _G.RawStats) then return false end

    -- Enable flight setting on the server and wait for it to propagate.
    pcall(function() Remote:FireServer({ "Setting", "ToggleFlight", true }) end)
    task.wait(0.3)

    local char = LP.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then return false end

    -- First attempt from current position.
    if activateFlyJump(hum, root) then return true end

    -- If still not flying, teleport to an open spot and try once more.
    root.CFrame = CFrame.new(findOpenFlyPosition())
    task.wait(0.4)
    hum  = char:FindFirstChildOfClass("Humanoid")
    root = char and char:FindFirstChild("HumanoidRootPart")
    if hum and root then
        waitUntilFalling(hum, root, 2)
        activateFlyJump(hum, root)
    end

    return _G.isFlying()
end

-- ── Meditate tool equip ───────────────────────────────────────

-- Equips the Meditate tool. In fly mode we need to be airborne first.
-- On the ground (high PP zone or pre-fly) we just equip directly.
local function equipMeditateTool()
    if _G.sathAutofarmBlocked() then return end
    local char = LP.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not hum or hum.Health <= 0 then return end
    if char:FindFirstChild("Meditate") then return end  -- already equipped
    local tool = LP.Backpack:FindFirstChild("Meditate")
    if tool then hum:EquipTool(tool) end
end

-- ── Main PP loop ──────────────────────────────────────────────

task.spawn(function()
    while true do
        if _G.sathAutofarmBlocked() then
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
                -- Quest 9 done + enough JF/PP: fly and meditate for 10x gains.
                _G.ppUseFlyMode = true
                local flying = _G.isFlying() or tryEnterFlyMode()
                if flying and _G.isFlying() then
                    equipMeditateTool()
                else
                    -- Not flying yet — wait before retrying to avoid spam loop.
                    task.wait(1.5)
                end
            else
                -- Ground mode: just keep Meditate equipped in the right zone.
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
