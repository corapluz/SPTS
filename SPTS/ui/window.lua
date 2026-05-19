-- Creates the Rayfield window and all tabs.
-- Returns the tab references so other UI modules can add their sections.

local Rayfield = _G.Rayfield

local Window = Rayfield:CreateWindow({
    Name            = "SPTS",
    Icon            = "shield",
    LoadingTitle    = "Syncing Engine Arrays...",
    LoadingSubtitle = "SPTS Premium Module",
    ShowText        = "Toggle Window",
    Theme           = "Default",
    ToggleUIKeybind = Enum.KeyCode.K,
    ConfigurationSaving = {
        Enabled    = true,
        FolderName = "SPTS_CoreSuite",
        FileName   = "Profiles",
    },
})

local Tabs = {
    Dash    = Window:CreateTab("Dashboard", "layout-dashboard"),
    Auto    = Window:CreateTab("Autofarm",  "cpu"),
    Nav     = Window:CreateTab("Teleports", "compass"),
    Equip   = Window:CreateTab("Equipment", "dumbbell"),
    Util    = Window:CreateTab("Utilities", "wrench"),
    Theme   = Window:CreateTab("Themes",    "palette"),
    Players = Window:CreateTab("Players",   "users"),
}

_G.RayfieldWindow = Window
_G.Tabs           = Tabs

return Tabs
