-- Roblox service references and the main remote event.
-- Loaded once at startup; everything else imports from here via _G.

local Players          = game:GetService("Players")
local RepStorage       = game:GetService("ReplicatedStorage")
local VirtualUser      = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")

local LP     = Players.LocalPlayer
local Remote = RepStorage:WaitForChild("RemoteEvent")

-- Expose globally so every module can reach them without re-requiring.
_G.LP              = LP
_G.Remote          = Remote
_G.Players         = Players
_G.RepStorage      = RepStorage
_G.VirtualUser     = VirtualUser
_G.UserInputService = UserInputService

-- Anti-AFK: fires whenever Roblox would normally kick the player for idling.
LP.Idled:Connect(function()
    if _G.Settings.AntiAfk then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)
