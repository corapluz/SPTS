-- Utilities tab: instant respawn toggle and manual respawn button.

local Tabs    = _G.Tabs
local Toggles = _G.Toggles

Tabs.Util:CreateSection("Respawn")

Toggles["IR"] = Tabs.Util:CreateToggle({
    Name         = "Instant Respawn",
    CurrentValue = false,
    Flag         = "Run_IR",
    Callback     = function(v) _G.Settings.InstantRespawn = v end,
})

Tabs.Util:CreateSection("Manual")

Tabs.Util:CreateButton({
    Name     = "Respawn Here",
    Callback = function() _G.doRespawn() end,
})
