-- Low-level GUI helpers: finding buttons, firing signals, clicking positions.
-- Nothing game-logic specific lives here — just plumbing.

local LP = _G.LP

local function getScreenGui()
    local gui = LP:FindFirstChild("PlayerGui")
    return gui and gui:FindFirstChild("ScreenGui")
end

local function getMainQuestFrame()
    local sg = getScreenGui()
    return sg and sg:FindFirstChild("MainQuestFrame")
end

-- Walks up the GUI tree to find the actual clickable button inside a frame.
local function resolveClickable(gui)
    if not gui then return nil end
    if gui:IsA("TextButton") or gui:IsA("ImageButton") then return gui end
    local inner = gui:FindFirstChildWhichIsA("TextButton", true)
        or gui:FindFirstChildWhichIsA("ImageButton", true)
    return inner or gui:FindFirstChild("Btn") or gui
end

-- Collects the relevant click signals from a button so we can fire them directly.
local function collectGuiSignals(gui)
    local signals = {}
    if not gui then return signals end

    local function tryAdd(eventName)
        local ok, sig = pcall(function() return gui[eventName] end)
        if ok and sig then table.insert(signals, sig) end
    end

    if gui:IsA("GuiButton") then tryAdd("Activated") end
    tryAdd("MouseButton1Click")
    tryAdd("MouseButton1Down")
    return signals
end

-- Simulates a mouse click at the center of the viewport as a last resort.
local function clickScreenCenter()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local x, y = vp.X * 0.5, vp.Y * 0.5
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendMouseButtonEvent(x, y, 0, true,  game, 0)
        task.wait(0.1)
        vim:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
end

-- Clicks the center of a specific GUI element, falling back to screen center.
local function clickGuiCenter(btn)
    btn = resolveClickable(btn)
    if not btn then clickScreenCenter() return end

    if btn:IsA("GuiObject") and btn.AbsoluteSize.X > 0 and btn.AbsoluteSize.Y > 0 then
        local pos  = btn.AbsolutePosition
        local size = btn.AbsoluteSize
        local x = pos.X + size.X * 0.5
        local y = pos.Y + size.Y * 0.5
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendMouseButtonEvent(x, y, 0, true,  game, 0)
            task.wait(0.1)
            vim:SendMouseButtonEvent(x, y, 0, false, game, 0)
        end)
        return
    end

    clickScreenCenter()
end

-- Tries firesignal → getconnections → clickGuiCenter in that order.
local function fireGuiSignal(btn)
    btn = resolveClickable(btn)
    if not btn then return false end

    local signals = collectGuiSignals(btn)

    if firesignal then
        for _, sig in ipairs(signals) do
            if pcall(firesignal, sig) then return true end
        end
    end

    if getconnections then
        local fired = false
        for _, sig in ipairs(signals) do
            for _, c in ipairs(getconnections(sig)) do
                pcall(function() c:Fire() end)
                fired = true
            end
        end
        if fired then return true end
    end

    clickGuiCenter(btn)
    return true
end

-- Store in _G so every other module can reach these without require().
_G.guiUtils = {
    getScreenGui      = getScreenGui,
    getMainQuestFrame = getMainQuestFrame,
    resolveClickable  = resolveClickable,
    collectGuiSignals = collectGuiSignals,
    clickScreenCenter = clickScreenCenter,
    clickGuiCenter    = clickGuiCenter,
    fireGuiSignal     = fireGuiSignal,
}
