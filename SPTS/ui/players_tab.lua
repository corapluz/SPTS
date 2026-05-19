-- Players tab: ESP toggle, kill target dropdown, fireball kill, and punch keybind.

local Tabs    = _G.Tabs
local Toggles = _G.Toggles
local Players = _G.Players
local LP      = _G.LP

-- ── ESP ───────────────────────────────────────────────────────

Tabs.Players:CreateSection("ESP")

Toggles["ESP"] = Tabs.Players:CreateToggle({
    Name         = "Player ESP",
    CurrentValue = false,
    Flag         = "Run_ESP",
    Callback     = function(v)
        _G.espModule.setPlayerEspEnabled(v)
    end,
})

-- ── Kill ──────────────────────────────────────────────────────

Tabs.Players:CreateSection("Kill Players")

local PlayerDropdown = Tabs.Players:CreateDropdown({
    Name            = "Targets",
    Options         = _G.killModule.buildPlayerDropdownOptions(),
    CurrentOption   = { "All" },
    MultipleOptions = true,
    Flag            = "KillTargets",
    Callback        = function(options)
        _G.currentKillSelection = options
    end,
})

-- Keep the dropdown fresh as players join and leave.
local function refreshPlayerDropdown()
    if not PlayerDropdown then return end
    local opts      = _G.killModule.buildPlayerDropdownOptions()
    local preserved = {}
    for _, sel in ipairs(_G.currentKillSelection) do
        if sel == "All" or _G.playerByLabel[sel] then
            table.insert(preserved, sel)
        end
    end
    if #preserved == 0 then preserved = { "All" } end
    PlayerDropdown:Refresh(opts)
    PlayerDropdown:Set(preserved)
    _G.currentKillSelection = preserved
end

Tabs.Players:CreateButton({
    Name     = "Kill Target(s) With Fireball",
    Callback = function() task.spawn(_G.killModule.runKillWithFireball) end,
})

-- ── Punch ─────────────────────────────────────────────────────

Tabs.Players:CreateSection("Normal Punch (C)")

Toggles["Punch"] = Tabs.Players:CreateToggle({
    Name         = "Enable Punch On Keybind",
    CurrentValue = false,
    Flag         = "Run_Punch",
    Callback     = function(v) _G.Settings.AutoPunch = v end,
})

Tabs.Players:CreateKeybind({
    Name           = "Punch Keybind",
    CurrentKeybind = "X",
    HoldToInteract = false,
    Flag           = "PunchKey",
    Callback       = function(state)
        if state == false then return end
        task.spawn(_G.killModule.runKeybindPunch)
    end,
})

-- ── Player list events ────────────────────────────────────────

Players.PlayerAdded:Connect(function(plr)
    if plr == LP then return end
    task.defer(refreshPlayerDropdown)
    task.defer(function() _G.espModule.attachPlayerEsp(plr) end)
end)

Players.PlayerRemoving:Connect(function(plr)
    _G.espModule.removePlayerEsp(plr)
    task.defer(refreshPlayerDropdown)
end)

task.defer(refreshPlayerDropdown)
