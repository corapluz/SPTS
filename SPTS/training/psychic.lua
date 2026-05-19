-- Psychic Power training loop.
-- Fly detection: listens to Update_Flying_Status remote event fired by the game.
-- To enter fly: jump, wait for freefall, jump again (double jump activates fly).
-- Once flying: equip Meditate tool for 10x PP gains.

local Z              = _G.Z
local LP             = _G.LP
local Remote         = _G.Remote
local UserInputService = _G.UserInputService

-- ── Fly state — driven by the game's own remote event ─────────

local isCurrentlyFlying = false

-- Hook into the remote event the game fires to track fly state.
-- Update_Flying_Status true = flying, false = not flying.
Remote.OnClientEvent:Connect(function(args)
    if type(args) == "table" and args[1] == "Update_Flying_Status" then
        isCurrentlyFlying = args[2] == true
        _G.Flying = isCurrentlyFlying
    end
end)

_G.isFlying = function()
    return isCurrentlyFlying
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

-- ── Input helpers ─────────────────────────────────────────────

local function doJump()
    pcall(function() UserInputService:JumpRequest() end)
end

local function isOnGround(hum)
    return hum.FloorMaterial ~= Enum.Material.Air
end

local function isFalling(hum, root)
    if hum:GetState() == Enum.HumanoidStateType.Freefall then return true end
    if root and root.AssemblyLinearVelocity.Y < -1 then return true end
    return false
end

local function waitUntilFalling(hum, root, maxSec)
    local t0 = os.clock()
    while os.clock() - t0 < (maxSec or 1.5) do
        if isFalling(hum, root) then return true end
        task.wait(0.05)
    end
    return isFalling(hum, root)
end

-- ── Fly entry ─────────────────────────────────────────────────

-- Double jump: if on ground, jump first to get airborne, then jump again in freefall.
-- If already in freefall, just jump once more — that activates fly.
local function tryEnterFlyMode()
    if _G.isFlying() then return true end

    local chapter = _G.sathScanner.readMainQuestChapterFromUI()
    if not Z.canFlyMeditateFarm(chapter, _G.RawStats) then return false end

    local char = LP.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then return false end

    -- If on ground, jump to get airborne first.
    if isOnGround(hum) then
        doJump()
        waitUntilFalling(hum, root, 1.5)
    end

    -- Now in freefall — second jump activates fly.
    if isFalling(hum, root) then
        doJump()
        task.wait(0.5)
        if _G.isFlying() then return true end
    end

    -- Still not flying — teleport to open air and try once more.
    local fallback = Vector3.new(420, 299, 878)
    root.CFrame = CFrame.new(fallback)
    task.wait(0.3)
    hum  = char:FindFirstChildOfClass("Humanoid")
    root = char and char:FindFirstChild("HumanoidRootPart")
    if hum and root then
        waitUntilFalling(hum, root, 2)
        if isFalling(hum, root) then
            doJump()
            task.wait(0.5)
        end
    end

    return _G.isFlying()
end

-- Stop fly: jump once more while flying to exit, then unequip meditate.
_G.stopFlyMode = function()
    if not _G.isFlying() and not _G.hasMeditateEquipped() then return end

    unequipMeditateTool()
    waitUntilMeditateGone(2)

    if _G.isFlying() then
        doJump()
        task.wait(0.4)
    end

    isCurrentlyFlying = false
    _G.Flying = false
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
                if _G.isFlying() then
                    -- Already flying — just keep meditate equipped.
                    equipMeditateTool()
                else
                    -- Try to enter fly mode. If it fails, wait before retrying.
                    if tryEnterFlyMode() then
                        task.wait(0.3)
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
