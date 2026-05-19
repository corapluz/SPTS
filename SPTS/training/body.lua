-- Body Toughness training loop.
--
-- Two modes:
--   pushup      — BT < 20: equip Push Up, click screen, fire +BT1 remote.
--   deathgrind  — BT >= 20: teleport to a damage zone and respawn on death.
--
-- Zone selection rules (from Module.lua M.BT table):
--   Normal BT farm  → needs bt >= zone.req  (you survive there)
--   Death Grinding  → needs bt >= zone.min  (you die there, that's the point)
--
-- Death Grinding toggle works standalone too — it just needs BT >= 5 (Ice Bath min).

local Z      = _G.Z
local LP     = _G.LP
local Remote = _G.Remote

local BT_DEATH_GRIND_ABSOLUTE_MIN = 5  -- Ice Bath min from Module.lua

local lastPushUpBt = 0

-- ── Zone pickers ──────────────────────────────────────────────

-- Best zone where bt >= zone.req (normal farm — you survive).
local function normalBtTarget(bt)
    for _, zone in ipairs(Z.BT) do
        if bt >= zone.req and zone.req > 0 then
            return Z.midPos(zone.p1, zone.p2)
        end
    end
    return nil
end

-- Best zone where bt >= zone.min (death grind — you die there).
local function deathGrindTarget(bt)
    for _, zone in ipairs(Z.BT) do
        if bt >= zone.min and zone.min > 0 then
            return Z.midPos(zone.p1, zone.p2)
        end
    end
    return nil
end

-- ── State checks ──────────────────────────────────────────────

local function canDeathGrind()
    return (_G.RawStats.BT or 0) >= BT_DEATH_GRIND_ABSOLUTE_MIN
end

-- True when death grinding should be active (standalone toggle or Sath BT phase).
local function deathGrindActive()
    if _G.Settings.DeathGrinding and canDeathGrind() then return true end
    if _G.sathAllowsToolFarm("BodyToughness")
        and Z.btTrainingMode(_G.RawStats.BT) == "deathgrind"
    then return true end
    return false
end

local function shouldRespawnForBtFarm()
    if _G.Settings.InstantRespawn then return true end
    if deathGrindActive() then return true end
    return false
end

-- ── Push Up ───────────────────────────────────────────────────

local function usePushUpBodyToughness()
    _G.useStarterTraining("BodyToughness")

    local cam = workspace.CurrentCamera
    if cam then
        local vp = cam.ViewportSize
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendMouseButtonEvent(vp.X * 0.5, vp.Y * 0.5, 0, true,  game, 0)
            task.wait(0.1)
            vim:SendMouseButtonEvent(vp.X * 0.5, vp.Y * 0.5, 0, false, game, 0)
        end)
    end

    local now = tick()
    if now - lastPushUpBt >= 1.05 then
        lastPushUpBt = now
        Remote:FireServer({ Z.BT_PUSHUP_REMOTE or "+BT1" })
    end
end

-- ── Teleport loop ─────────────────────────────────────────────

task.spawn(function()
    while true do
        if _G.sathAutofarmBlocked() then task.wait(0.15); continue end

        local bt = _G.RawStats.BT or 0

        if deathGrindActive() then
            -- Death grind: go to the hardest zone we can die in.
            local target = deathGrindTarget(bt)
            if target then
                local char = LP.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root and (root.Position - target).Magnitude > 8 then
                    root.CFrame = CFrame.new(target)
                end
            end
        elseif _G.sathAllowsToolFarm("BodyToughness")
            and Z.btTrainingMode(bt) ~= "pushup"
        then
            -- Normal BT farm: go to the best zone we can survive in.
            local target = normalBtTarget(bt)
            if target then
                local char = LP.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root and (root.Position - target).Magnitude > 8 then
                    root.CFrame = CFrame.new(target)
                end
            end
        end

        task.wait(0.1)
    end
end)

-- ── Push Up loop ──────────────────────────────────────────────

task.spawn(function()
    while true do
        if _G.sathAutofarmBlocked() then task.wait(0.15); continue end

        if _G.sathAllowsToolFarm("BodyToughness")
            and Z.btTrainingMode(_G.RawStats.BT) == "pushup"
        then
            usePushUpBodyToughness()
        end

        task.wait(0.35)
    end
end)

-- ── Character events ──────────────────────────────────────────

local function bindCharacterEvents(char)
    local hum = char:WaitForChild("Humanoid", 8)
    if not hum then return end

    local prevHP  = hum.Health
    local lastDmg = 0

    hum:GetPropertyChangedSignal("Health"):Connect(function()
        local cur   = hum.Health
        local delta = prevHP - cur
        if delta > 0 then
            lastDmg = delta
            if shouldRespawnForBtFarm() and (cur - lastDmg) <= 0 then
                _G.doRespawn()
            end
        end
        prevHP = cur
    end)

    hum.Died:Connect(function()
        if shouldRespawnForBtFarm() then
            task.wait(0.1)
            _G.doRespawn()
        end
    end)
end

_G.bodyModule = {
    bindCharacterEvents    = bindCharacterEvents,
    shouldRespawnForBtFarm = shouldRespawnForBtFarm,
}
