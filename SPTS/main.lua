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

LP.CharacterAdded:Connect(function(char)
    _G.ppTeleported = false

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
