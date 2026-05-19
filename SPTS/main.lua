-- SPTS main entry point.
-- All modules are fetched from GitHub and executed via loadstring.

repeat task.wait(0.5) until game.IsLoaded

local BASE = "https://raw.githubusercontent.com/corapluz/SPTS/refs/heads/main/SPTS/"

-- ── Executor detection ────────────────────────────────────────

local executorName = "Unknown"
if identifyexecutor then
    local ok, name = pcall(identifyexecutor)
    if ok and name then executorName = tostring(name) end
elseif getexecutorname then
    local ok, name = pcall(getexecutorname)
    if ok and name then executorName = tostring(name) end
end

executorName = executorName:match("^(%a[%a%d]*)") or executorName
_G.ExecutorName = executorName

-- ── Module loader ─────────────────────────────────────────────

local function load(path)
    local ok1, src = pcall(function() return game:HttpGet(BASE .. path) end)
    if not ok1 then
        if _G.Loader then _G.Loader.error("HttpGet failed: " .. path) end
        error("[SPTS] HttpGet failed for " .. path .. ": " .. tostring(src))
    end
    local fn, err = loadstring(src, "@" .. path)
    if not fn then
        if _G.Loader then _G.Loader.error("Parse error: " .. path) end
        error("[SPTS] loadstring failed for " .. path .. ": " .. tostring(err))
    end
    local ok2, result = pcall(fn)
    if not ok2 then
        if _G.Loader then _G.Loader.error(path .. ": " .. tostring(result):sub(1,50)) end
        error("[SPTS] runtime error in " .. path .. ": " .. tostring(result))
    end
    return result
end

-- ── Loader UI ─────────────────────────────────────────────────

load("core/loader.lua")  -- creates _G.Loader with .step() and .finish()

local function step(label)
    if _G.Loader then _G.Loader.step(label) end
end

-- ── Boot sequence ─────────────────────────────────────────────

_G.Loader.status("Loading modules...")

_G.Z = load("Module.lua");     step("Module.lua")

getgenv().RAYFIELD_ASSET_ID = 10804731440
_G.Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
step("Rayfield UI")

load("core/state.lua");        step("State")
load("core/services.lua");     step("Services")

-- Redefine helpers to plain print until a custom console is provided.
cprint = function(msg) print(msg) end
cwarn  = function(msg) warn(msg)  end
cinfo  = function(msg) print(msg) end

local LP              = _G.LP
local RESPAWN_PAYLOAD = { [1] = "Respawn" }
local savedRespawnPos = nil

_G.doRespawn = function()
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then savedRespawnPos = root.Position end
    Remote:FireServer(RESPAWN_PAYLOAD)
end

load("core/stats.lua");         step("Stats sniffer")
load("core/exploit_check.lua"); step("Exploit check")
load("core/gui_utils.lua");    step("GUI utils")

_G.Toggles     = {}
_G.cascadeLock = false

load("ui/window.lua");         step("Window")
load("ui/toggle_sync.lua");    step("Toggle sync")

load("sath/quest_defs.lua");   step("Quest defs")
load("sath/scanner.lua");      step("Scanner")
load("sath/farm.lua");         step("Farm")
load("sath/dialog.lua");       step("Dialog")

load("training/tools.lua");    step("Tools")
load("training/fist.lua")
load("training/body.lua")
load("training/mobility.lua")
load("training/psychic.lua");  step("Training loops")

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

load("players/esp.lua");       step("ESP")
load("players/kill.lua")

load("ui/dashboard_tab.lua")
load("ui/autofarm_tab.lua")
load("ui/nav_tab.lua")
load("ui/equip_tab.lua")
load("ui/util_tab.lua")
load("ui/theme_tab.lua")
load("ui/players_tab.lua");    step("UI tabs")

load("sath/loop.lua");         step("Sath loop")

_G.Rayfield:LoadConfiguration()

if _G.Settings.PlayerEsp and _G.Toggles["ESP"] then
    _G.Toggles["ESP"]:Set(true)
end

if _G.Settings.AutoSathQuest and _G.setTrainingUiLocked then
    _G.setTrainingUiLocked(true)
end

_G.Loader.finish()