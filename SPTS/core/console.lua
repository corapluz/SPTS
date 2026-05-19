-- Colored F9 console output using RichText font tags.
-- Patches DevConsoleMaster TextLabels to enable RichText on every heartbeat.
-- Usage: _G.cprint("green", "hello")  |  _G.cwarn("red", "error!")

local RunService = game:GetService("RunService")
local CoreGui    = game:GetService("CoreGui")

-- Enable RichText on all DevConsole labels so color tags render.
RunService.Heartbeat:Connect(function()
    local dcm = CoreGui:FindFirstChild("DevConsoleMaster")
    if not dcm then return end
    for _, v in ipairs(dcm:GetDescendants()) do
        if v:IsA("TextLabel") and not v.RichText then
            v.RichText = true
        end
    end
end)

local COLORS = {
    green  = "0,220,80",
    red    = "255,80,80",
    yellow = "255,210,0",
    cyan   = "33,161,163",
    white  = "255,255,255",
    gray   = "160,160,160",
}

local function colorPrint(color, text)
    local rgb = COLORS[color] or COLORS.white
    print('<font color="rgb(' .. rgb .. ')">' .. tostring(text) .. '</font>')
end

-- Expose globally
_G.cprint = colorPrint

-- Shortcuts used across the codebase
_G.cprintGreen  = function(t) colorPrint("green",  t) end
_G.cprintRed    = function(t) colorPrint("red",    t) end
_G.cprintYellow = function(t) colorPrint("yellow", t) end
_G.cprintGray   = function(t) colorPrint("gray",   t) end
