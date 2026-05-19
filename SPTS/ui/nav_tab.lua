-- Teleports tab: one button per destination defined in Module.lua.
-- Sections are created automatically from the section field in each entry.

local Z    = _G.Z
local Tabs = _G.Tabs
local LP   = _G.LP

local function tp(pos)
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then root.CFrame = CFrame.new(pos) end
end

local lastSection = ""
for _, t in ipairs(Z.Teleports) do
    if t.section ~= lastSection then
        Tabs.Nav:CreateSection(t.section)
        lastSection = t.section
    end
    local pos = t.pos
    Tabs.Nav:CreateButton({ Name = t.name, Callback = function() tp(pos) end })
end
