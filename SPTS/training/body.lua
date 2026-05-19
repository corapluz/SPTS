-- Body Toughness training loop.
-- Below BT 20: Push Up tool + remote BT increment.
-- BT 20+: death grinding (teleport to damage zone, respawn on death).

local Z      = _G.Z
local LP     = _G.LP
local Remote = _G.Remote

local lastPushUpBt = 0

-- Fires the Push Up tool and sends the BT increment remote at most once per second.
local function usePushUpBodyToughness()
    _G.useStarterTraining("BodyToughness")

    -- Click the screen so the tool animation plays.
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

-- Returns true when BT is high enough to use death grinding instead of Push Up.
local function shouldBtDeathGrindFarm()
    return _G.sathAllowsToolFarm("BodyToughness")
        and Z.btTrainingMode(_G.RawStats.BT) == "deathgrind"
end

-- Returns true when the respawn loop should be active.
local function shouldRespawnForBtFarm()
    if _G.Settings.InstantRespawn then return true end
    if _G.Settings.DeathGrinding and Z.canDeathGrind(_G.RawStats.BT) then return true end
    if shouldBtDeathGrindFarm() then return true end
    return false
end

-- Teleport loop: keeps the character in the right BT damage zone.
task.spawn(function()
    while true do
        if _G.sathAutofarmBlocked() then
            task.wait(0.15)
            continue
        end

        if (_G.Settings.DeathGrinding and Z.canDeathGrind(_G.RawStats.BT))
            or shouldBtDeathGrindFarm()
        then
            local target = Z.deathGrindTarget(_G.RawStats)
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

-- Tool loop: runs Push Up when BT is still in pushup mode.
task.spawn(function()
    while true do
        if _G.sathAutofarmBlocked() then
            task.wait(0.15)
            continue
        end

        if _G.sathAllowsToolFarm("BodyToughness")
            and Z.btTrainingMode(_G.RawStats.BT) == "pushup"
        then
            usePushUpBodyToughness()
        end

        task.wait(0.35)
    end
end)

-- Character event binding: triggers respawn when health hits zero.
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

-- Store in _G so main.lua can wire up CharacterAdded.
_G.bodyModule = {
    bindCharacterEvents    = bindCharacterEvents,
    shouldRespawnForBtFarm = shouldRespawnForBtFarm,
}
