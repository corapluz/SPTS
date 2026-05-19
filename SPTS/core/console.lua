-- Custom F9 console output by injecting frames directly into ClientLog.
-- No print() calls — we create our own Frame+TextLabel entries so they
-- never mix with game script output and always have RichText colors.

repeat task.wait(0.1) until game.IsLoaded

local CoreGui = game:GetService("CoreGui")

-- Wait for the DevConsole hierarchy to exist.
local DevConsoleMaster  = CoreGui:WaitForChild("DevConsoleMaster", 15)
local DevConsoleWindow  = DevConsoleMaster and DevConsoleMaster:WaitForChild("DevConsoleWindow", 10)
local DevConsoleUI      = DevConsoleWindow  and DevConsoleWindow:WaitForChild("DevConsoleUI", 10)
local MainView          = DevConsoleUI      and DevConsoleUI:WaitForChild("MainView", 10)
local ClientLog         = MainView          and MainView:WaitForChild("ClientLog", 10)

-- Fallback: if hierarchy isn't found just use plain print.
local function fallback(text)
    print(text)
end

if not ClientLog then
    warn("[SPTS] console.lua: ClientLog not found, falling back to print()")
    _G.cprint       = function(_, t) fallback(t) end
    _G.cprintGreen  = function(t)    fallback(t) end
    _G.cprintRed    = function(t)    fallback(t) end
    _G.cprintYellow = function(t)    fallback(t) end
    _G.cprintGray   = function(t)    fallback(t) end
    return
end

-- Frame counter — we own these names so they won't clash with game prints.
-- Game uses numeric names ("2","3",...). We use "SPTS_1", "SPTS_2", etc.
local frameCount = 0

local COLORS = {
    green  = Color3.fromRGB(0,   220, 80),
    red    = Color3.fromRGB(255, 80,  80),
    yellow = Color3.fromRGB(255, 210, 0),
    gray   = Color3.fromRGB(180, 180, 180),
    white  = Color3.fromRGB(230, 230, 230),
}

local function addEntry(text, color)
    frameCount = frameCount + 1
    local col = COLORS[color] or COLORS.white

    local frame = Instance.new("Frame")
    frame.Name               = "SPTS_" .. frameCount
    frame.Size               = UDim2.new(1, 0, 0, 18)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel    = 0

    local lbl = Instance.new("TextLabel")
    lbl.Name                 = "msg"
    lbl.Parent               = frame
    lbl.Size                 = UDim2.new(1, -6, 1, 0)
    lbl.Position             = UDim2.new(0, 6, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.BorderSizePixel      = 0
    lbl.RichText             = true
    lbl.Text                 = text
    lbl.TextColor3           = col
    lbl.TextSize             = 14
    lbl.Font                 = Enum.Font.Code
    lbl.TextXAlignment       = Enum.TextXAlignment.Left
    lbl.TextYAlignment       = Enum.TextYAlignment.Center
    lbl.TextWrapped          = true

    frame.Parent = ClientLog
end

-- Public API
_G.cprint = function(color, text)
    -- Support both cprint("green","msg") and cprint("msg") with default gray
    if text == nil then text = color; color = "gray" end
    addEntry(text, color)
end

_G.cprintGreen  = function(t) addEntry(t, "green")  end
_G.cprintRed    = function(t) addEntry(t, "red")    end
_G.cprintYellow = function(t) addEntry(t, "yellow") end
_G.cprintGray   = function(t) addEntry(t, "gray")   end
_G.cprintWhite  = function(t) addEntry(t, "white")  end
