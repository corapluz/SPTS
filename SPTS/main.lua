-- SPTS main entry point.
-- All modules are fetched from GitHub and executed via loadstring.

local BASE = "https://raw.githubusercontent.com/corapluz/SPTS/refs/heads/main/SPTS/"

-- ── Console helpers ───────────────────────────────────────────
-- Roblox F9 doesn't support ANSI colors, but warn() = yellow, print() = white.
-- We prefix with colored tags using Unicode blocks for visual separation.

local function cprint(msg)  print("\27[32m" .. msg .. "\27[0m") end  -- green (some executors support ANSI)
local function cwarn(msg)   warn(msg) end                             -- yellow via warn()
local function cinfo(msg)   print(msg) end                            -- white

-- Loading bar: prints ONE line per step, no spam.
-- steps = total number of steps, current = which step just finished.
local LOAD_STEPS = 18
local loadStep   = 0

local function loadBar(label)
    loadStep = loadStep + 1
    local filled = math.floor((loadStep / LOAD_STEPS) * 10)
    local empty  = 10 - filled
    local bar    = "[" .. string.rep("=", filled) .. string.rep(" ", empty) .. "]"
    local pct    = math.floor((loadStep / LOAD_STEPS) * 100)
    cinfo(string.format("[SPTS] %s %d%%  %s", bar, pct, label))
end

-- ── Executor detection ────────────────────────────────────────

local executorName = "Unknown"
if identifyexecutor then
    local ok, name = pcall(identifyexecutor)
    if ok and name then executorName = tostring(name) end
elseif getexecutorname then
    local ok, name = pcall(getexecutorname)
    if ok and name then executorName = tostring(name) end
end

_G.ExecutorName = executorName

local execLower = executorName:lower()
if execLower:find("solara") or execLower:find("xeno") then
    cprint("[SPTS] " .. executorName .. " detected — loading VirtualInput mode")
end

-- ── Module loader ─────────────────────────────────────────────

local function load(path)
    local src = game:HttpGet(BASE .. path)
    local fn, err = loadstring(src, "@" .. path)
    assert(fn, "[SPTS] loadstring failed for " .. path .. ": " .. tostring(err))
    return fn()
end

-- ── Boot sequence ─────────────────────────────────────────────

cinfo("[SPTS] ── Starting SPTS ──────────────────────────")

_G.Z = load("Module.lua");    loadBar("Module.lua")

getgenv().RAYFIELD_ASSET_ID = 10804731440
_G.Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
loadBar("Rayfield UI")

load("core/state.lua");        loadBar("State")
load("core/services.lua");     loadBar("Services")

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

load("core/stats.lua");        loadBar("Stats sniffer")
load("core/exploit_check.lua"); loadBar("Exploit check")
load("core/gui_utils.lua");    loadBar("GUI utils")

_G.Toggles     = {}
_G.cascadeLock = false

load("ui/window.lua");         loadBar("Window")
load("ui/toggle_sync.lua");    loadBar("Toggle sync")

load("sath/quest_defs.lua");   loadBar("Quest defs")
load("sath/scanner.lua");      loadBar("Scanner")
load("sath/farm.lua");         loadBar("Farm")
load("sath/dialog.lua");       loadBar("Dialog")

load("training/tools.lua");    loadBar("Tools")
load("training/fist.lua")
load("training/body.lua")
load("training/mobility.lua")
load("training/psychic.lua");  loadBar("Training loops")

-- ── Character events ──────────────────────────────────────────

local function dismissIntroGui()
    local playerGui = LP:FindFirstChild("PlayerGui")
    if not playerGui then return end
    local introGui = playerGui:FindFirstChild("IntroGui")
    if not introGui or not introGui.Enabled then return end

    local playBtn = introGui:FindFirstChild("PlayBtn")
    if not playBtn then return end

    local deadline = tick() + 12
    while tick() < deadline do
        local t = playBtn.Text
        if t == " SPAWN " or t == "SPAWN" or t == "PLAY" or t == " PLAY " then break end
        task.wait(0.2)
    end

    local caps = _G.ExploitCaps or {}

    if caps.firesignal and firesignal then
        local ok, sig = pcall(function() return playBtn.MouseButton1Click end)
        if ok and sig then pcall(firesignal, sig) end
    end

    if caps.getconnections and getconnections then
        for _, evName in ipairs({ "MouseButton1Click", "MouseButton1Down" }) do
            local ok, sig = pcall(function() return playBtn[evName] end)
            if ok and sig then
                local ok2, conns = pcall(getconnections, sig)
                if ok2 and conns then
                    for _, c in ipairs(conns) do pcall(function() c:Fire() end) end
                end
            end
        end
    end

    pcall(function()
        local pos   = playBtn.AbsolutePosition
        local size  = playBtn.AbsoluteSize
        local inset = game:GetService("GuiService"):GetGuiInset()
        local vim   = game:GetService("VirtualInputManager")
        vim:SendMouseButtonEvent(pos.X + size.X * 0.5 + inset.X, pos.Y + size.Y * 0.5 + inset.Y, 0, true,  game, 0)
        task.wait(0.1)
        vim:SendMouseButtonEvent(pos.X + size.X * 0.5 + inset.X, pos.Y + size.Y * 0.5 + inset.Y, 0, false, game, 0)
    end)

    deadline = tick() + 8
    while tick() < deadline and introGui.Enabled do
        task.wait(0.2)
    end
end

LP.CharacterAdded:Connect(function(char)
    _G.ppTeleported = false
    task.spawn(dismissIntroGui)

    if savedRespawnPos then
        local pos = savedRespawnPos
        savedRespawnPos = nil
        task.spawn(function()
            local root = char:WaitForChild("HumanoidRootPart", 6)
            if root then task.wait(0.4); root.CFrame = CFrame.new(pos) end
        end)
    end

    if _G.bodyModule then _G.bodyModule.bindCharacterEvents(char) end
end)

if LP.Character and _G.bodyModule then
    _G.bodyModule.bindCharacterEvents(LP.Character)
end

load("players/esp.lua");       loadBar("ESP")
load("players/kill.lua")

load("ui/dashboard_tab.lua")
load("ui/autofarm_tab.lua")
load("ui/nav_tab.lua")
load("ui/equip_tab.lua")
load("ui/util_tab.lua")
load("ui/theme_tab.lua")
load("ui/players_tab.lua");    loadBar("UI tabs")

load("sath/loop.lua");         loadBar("Sath loop")

_G.Rayfield:LoadConfiguration()

if _G.Settings.PlayerEsp and _G.Toggles["ESP"] then
    _G.Toggles["ESP"]:Set(true)
end

if _G.Settings.AutoSathQuest and _G.setTrainingUiLocked then
    _G.setTrainingUiLocked(true)
end

cprint("[SPTS] ══ Loaded successfully ══════════════════")
