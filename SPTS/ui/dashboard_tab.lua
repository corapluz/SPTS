-- Dashboard tab: live stat labels that refresh every 0.5 s.

local Tabs = _G.Tabs

Tabs.Dash:CreateSection("Live Stats")

local LabelFS = Tabs.Dash:CreateLabel("Fist Strength: --",   2197020684)
local LabelBT = Tabs.Dash:CreateLabel("Body Toughness: --",  2197021260)
local LabelMS = Tabs.Dash:CreateLabel("Movement Speed: --",  2197021644)
local LabelJF = Tabs.Dash:CreateLabel("Jump Force: --",      2197021850)
local LabelPP = Tabs.Dash:CreateLabel("Psychic Power: --",   2197021455)

task.spawn(function()
    while task.wait(0.5) do
        LabelFS:Set("Fist Strength: "  .. _G.Stats.FS)
        LabelBT:Set("Body Toughness: " .. _G.Stats.BT)
        LabelMS:Set("Movement Speed: " .. _G.Stats.MS)
        LabelJF:Set("Jump Force: "     .. _G.Stats.JF)
        LabelPP:Set("Psychic Power: "  .. _G.Stats.PP)
    end
end)
