-- Shared tool helpers used by all training modules.
-- Equipping, activating, and unequipping tools from the character.

local LP = _G.LP

-- Finds a tool by name in the character or backpack.
local function findStarterTool(names)
    for _, name in ipairs(names) do
        local char = LP.Character
        local t = (char and char:FindFirstChild(name)) or LP.Backpack:FindFirstChild(name)
        if t and t:IsA("Tool") then return t, name end
    end
    return nil, nil
end

-- Fires the tool's Activated signal through every available method.
local function activateTool(tool)
    if not tool then return end
    pcall(function() tool:Activate() end)

    if firesignal then
        local okA, sigA = pcall(function() return tool.Activated end)
        if okA and sigA then pcall(firesignal, sigA) end
        local okM, sigM = pcall(function() return tool.MouseButton1Click end)
        if okM and sigM then pcall(firesignal, sigM) end
    end

    if getconnections then
        local okA, sigA = pcall(function() return tool.Activated end)
        if okA and sigA then
            for _, c in ipairs(getconnections(sigA)) do
                pcall(function() c:Fire() end)
            end
        end
    end
end

-- Equips and activates a starter tool (Push Up etc.) for the given stat.
local function useStarterTraining(statKey)
    local Z     = _G.Z
    local names = Z.STARTER_TOOLS[statKey]
    if not names then return end

    local char = LP.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not hum or hum.Health <= 0 then return end

    local tool, toolName = findStarterTool(names)
    if not tool then return end

    if tool.Parent == LP.Backpack then
        hum:EquipTool(tool)
        tool = char:FindFirstChild(toolName)
    end

    if tool and tool.Parent == char then
        activateTool(tool)
    end
end

-- Equips a zone training tool (e.g. Fist Training) if not already equipped.
local function equipZoneTool(toolName)
    local char = LP.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not hum or hum.Health <= 0 then return end
    if char:FindFirstChild(toolName) then return end
    local tool = LP.Backpack:FindFirstChild(toolName)
    if tool then hum:EquipTool(tool) end
end

-- Unequips whatever tool the character is currently holding.
local function unequipAllTools()
    local char = LP.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum:UnequipTools() end) end
end

-- Expose as globals so every module can call them without require().
_G.unequipAllTools    = unequipAllTools
_G.useStarterTraining = useStarterTraining
_G.equipZoneTool      = equipZoneTool

-- Also store a table for modules that prefer the table style.
_G.trainingTools = {
    findStarterTool    = findStarterTool,
    activateTool       = activateTool,
    useStarterTraining = useStarterTraining,
    equipZoneTool      = equipZoneTool,
    unequipAllTools    = unequipAllTools,
}
