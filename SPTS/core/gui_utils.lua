-- Low-level GUI helpers: finding buttons, firing signals, clicking positions.
-- Uses _G.ExploitCaps (set by exploit_check.lua) to pick the best method.

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

-- Collects the relevant click signals from a button.
local function collectGuiSignals(gui)
    local signals = {}
    if not gui then return signals end
    local function tryAdd(name)
        local ok, sig = pcall(function() return gui[name] end)
        if ok and sig then table.insert(signals, sig) end
    end
    tryAdd("MouseButton1Click")
    tryAdd("MouseButton1Down")
    return signals
end

-- Sends a real mouse click at screen coordinates via VirtualInputManager.
-- AbsolutePosition doesn't account for the GUI inset (top bar), so we
-- add the inset offset to get the correct screen position.
local function sendVirtualClick(x, y)
    pcall(function()
        local inset = game:GetService("GuiService"):GetGuiInset()
        local vim   = game:GetService("VirtualInputManager")
        vim:SendMouseButtonEvent(x + inset.X, y + inset.Y, 0, true,  game, 0)
        task.wait(0.08)
        vim:SendMouseButtonEvent(x + inset.X, y + inset.Y, 0, false, game, 0)
    end)
end

-- Clicks the center of the viewport as a last resort.
local function clickScreenCenter()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    sendVirtualClick(vp.X * 0.5, vp.Y * 0.5)
end

-- Clicks the center of a GUI element using VirtualInputManager.
local function clickGuiCenter(btn)
    btn = resolveClickable(btn)
    if not btn then clickScreenCenter(); return end
    if btn:IsA("GuiObject") and btn.AbsoluteSize.X > 0 and btn.AbsoluteSize.Y > 0 then
        local pos  = btn.AbsolutePosition
        local size = btn.AbsoluteSize
        sendVirtualClick(pos.X + size.X * 0.5, pos.Y + size.Y * 0.5)
        return
    end
    clickScreenCenter()
end

-- Fires a GUI button using the best available method:
--   1. firesignal  (fastest, most reliable on supported executors)
--   2. getconnections + Fire()  (fallback if firesignal missing)
--   3. VirtualInputManager click  (universal fallback)
local function fireGuiSignal(btn)
    btn = resolveClickable(btn)
    if not btn then return false end

    local caps    = _G.ExploitCaps or {}
    local signals = collectGuiSignals(btn)

    -- Method 1: firesignal
    if caps.firesignal and firesignal then
        for _, sig in ipairs(signals) do
            if pcall(firesignal, sig) then return true end
        end
    end

    -- Method 2: getconnections
    if caps.getconnections and getconnections then
        local fired = false
        for _, sig in ipairs(signals) do
            local ok2, conns = pcall(getconnections, sig)
            if ok2 and conns then
                for _, c in ipairs(conns) do
                    pcall(function() c:Fire() end)
                    fired = true
                end
            end
        end
        if fired then return true end
    end

    -- Method 3: VirtualInputManager click
    clickGuiCenter(btn)
    return true
end

_G.guiUtils = {
    getScreenGui      = getScreenGui,
    getMainQuestFrame = getMainQuestFrame,
    resolveClickable  = resolveClickable,
    collectGuiSignals = collectGuiSignals,
    clickScreenCenter = clickScreenCenter,
    clickGuiCenter    = clickGuiCenter,
    fireGuiSignal     = fireGuiSignal,
}
