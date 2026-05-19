-- SPTS main entry point.
-- All modules are fetched from GitHub and executed via loadstring.
-- No script.Parent / require() calls — everything shares state through _G.

local BASE = "https://raw.githubusercontent.com/corapluz/SPTS/refs/heads/main/SPTS/"

-- Fetches and runs a file from the repo. Errors loudly so bad URLs are obvious.
local function load(path)
    local src = game:HttpGet(BASE .. path)
    local fn, err = loadstring(src, "@" .. path)
    assert(fn, "[SPTS] loadstring failed for " .. path .. ": " .. tostring(err))
    return fn()
end

-- ── Module.lua ────────────────────────────────────────────────

_G.Z = load("Module.lua")

-- ── Rayfield ──────────────────────────────────────────────────

getgenv().RAYFIELD_ASSET_ID = 10804731440
_G.Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

-- ── Core ──────────────────────────────────────────────────────

load("core/state.lua")    -- _G.Settings, _G.Stats, _G.RawStats, constants
load("core/services.lua") -- _G.LP, _G.Remote, service refs, anti-AFK

-- Respawn helper: body.lua and util_tab.lua both call _G.doRespawn.
local Remote          = _G.Remote
local LP              = _G.LP
local RESPAWN_PAYLOAD = { [1] = "Respawn" }
local savedRespawnPos = nil

_G.doRespawn = function()
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then savedRespawnPos = root.Position end
    Remote:FireServer(RESPAWN_PAYLOAD)
end

load("core/stats.lua")     -- stat sniffer loop
load("core/exploit_check.lua") -- _G.ExploitCaps + colored F9 console output
load("core/gui_utils.lua") -- fireGuiSignal, clickGuiCenter, etc. → _G.guiUtils

-- ── Shared toggle table ───────────────────────────────────────

_G.Toggles     = {}
_G.cascadeLock = false

-- ── Rayfield window ───────────────────────────────────────────

load("ui/window.lua")      -- creates _G.Tabs and _G.RayfieldWindow

-- ── Toggle sync ───────────────────────────────────────────────

load("ui/toggle_sync.lua") -- _G.syncFarmToggles, _G.setToggleVisual, _G.setTrainingUiLocked

-- ── Sath ──────────────────────────────────────────────────────

-- Load farm first so its _G globals exist before any training loop runs.
load("sath/quest_defs.lua") -- _G.SATH_QUEST_DEFS (used by scanner + farm)
load("sath/scanner.lua")    -- _G.sathScanner
load("sath/farm.lua")       -- _G.pauseConflictingFarms, _G.applySathFarmPhase, etc.
load("sath/dialog.lua")     -- _G.tryAdvanceSathQuest

-- ── Training ──────────────────────────────────────────────────

load("training/tools.lua")   -- _G.unequipAllTools, _G.useStarterTraining, etc.
load("training/fist.lua")
load("training/body.lua")    -- also sets _G.bodyModule
load("training/mobility.lua")
load("training/psychic.lua") -- _G.stopFlyMode, _G.isFlying, _G.hasMeditateEquipped

-- ── Character events ──────────────────────────────────────────

-- After every respawn, click the IntroGui "SPAWN" button automatically
-- so the death screen doesn't block the Sath quest loop.
local function dismissIntroGui()
    local playerGui = LP:FindFirstChild("PlayerGui")
    if not playerGui then return end
    local introGui = playerGui:FindFirstChild("IntroGui")
    if not introGui or not introGui.Enabled then return end

    local playBtn = introGui:FindFirstChild("PlayBtn")
    if not playBtn then return end

    -- Wait for the button to be ready ("SPAWN" or "PLAY").
    local deadline = tick() + 12
    while tick() < deadline do
        local t = playBtn.Text
        if t == " SPAWN " or t == "SPAWN" or t == "PLAY" or t == " PLAY " then break end
        task.wait(0.2)
    end

    -- Try every available method to click the button.
    local caps = _G.ExploitCaps or {}

    -- Method 1: firesignal on MouseButton1Click
    if caps.firesignal and firesignal then
        local ok2, sig2 = pcall(function() return playBtn.MouseButton1Click end)
        if ok2 and sig2 then pcall(firesignal, sig2) end
    end

    -- Method 2: getconnections + Fire on MouseButton1Click
    if caps.getconnections and getconnections then
        for _, evName in ipairs({ "MouseButton1Click", "MouseButton1Down" }) do
            local ok3, sig3 = pcall(function() return playBtn[evName] end)
            if ok3 and sig3 then
                local ok4, conns = pcall(getconnections, sig3)
                if ok4 and conns then
                    for _, c in ipairs(conns) do pcall(function() c:Fire() end) end
                end
            end
        end
    end

    -- Method 3: VirtualInputManager click at button center (always attempted)
    pcall(function()
        local pos  = playBtn.AbsolutePosition
        local size = playBtn.AbsoluteSize
        local x = pos.X + size.X * 0.5
        local y = pos.Y + size.Y * 0.5
        local vim = game:GetService("VirtualInputManager")
        vim:SendMouseButtonEvent(x, y, 0, true,  game, 0)
        task.wait(0.1)
        vim:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)

    -- Wait for the GUI to disappear.
    deadline = tick() + 8
    while tick() < deadline and introGui.Enabled do
        task.wait(0.2)
    end
end

LP.CharacterAdded:Connect(function(char)
    _G.ppTeleported = false

    -- Dismiss the death/spawn screen first so loops aren't blocked.
    task.spawn(dismissIntroGui)

    if savedRespawnPos then
        local pos = savedRespawnPos
        savedRespawnPos = nil
        task.spawn(function()
            local root = char:WaitForChild("HumanoidRootPart", 6)
            if root then
                task.wait(0.4)
                root.CFrame = CFrame.new(pos)
            end
        end)
    end

    if _G.bodyModule then
        _G.bodyModule.bindCharacterEvents(char)
    end
end)

if LP.Character and _G.bodyModule then
    _G.bodyModule.bindCharacterEvents(LP.Character)
end

-- ── UI tabs ───────────────────────────────────────────────────

load("players/esp.lua")  -- _G.espModule
load("players/kill.lua") -- _G.killModule

load("ui/dashboard_tab.lua")
load("ui/autofarm_tab.lua")
load("ui/nav_tab.lua")
load("ui/equip_tab.lua")    -- defines _G.setSathEquipWeight
load("ui/util_tab.lua")
load("ui/theme_tab.lua")
load("ui/players_tab.lua")

-- ── Sath automation loop ──────────────────────────────────────

-- Loaded last so every function it calls is already defined.
load("sath/loop.lua")

-- ── Saved config ──────────────────────────────────────────────

_G.Rayfield:LoadConfiguration()

if _G.Settings.PlayerEsp and _G.Toggles["ESP"] then
    _G.Toggles["ESP"]:Set(true)
end

if _G.Settings.AutoSathQuest and _G.setTrainingUiLocked then
    _G.setTrainingUiLocked(true)
end
