local MODULE_URL = "https://raw.githubusercontent.com/corapluz/SPTS/refs/heads/main/Module.lua"

local function loadZModule()
    if readfile and isfile then
        local paths = {
            "scripts/Module.lua",
            "SPTS/scripts/Module.lua",
            "Module.lua",
        }
        for _, path in ipairs(paths) do
            if isfile(path) then
                local src = readfile(path)
                local fn, err = loadstring(src, "@" .. path)
                if fn then
                    local ok, mod = pcall(fn)
                    if ok and mod then return mod end
                end
                warn("[SPTS] Module load failed:", err)
            end
        end
    end
    return loadstring(game:HttpGet(MODULE_URL))()
end

local Z = loadZModule()

getgenv().RAYFIELD_ASSET_ID = 10804731440
local Rayfield    = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Players           = game:GetService("Players")
local RepStorage        = game:GetService("ReplicatedStorage")
local VirtualUser       = game:GetService("VirtualUser")
local UserInputService  = game:GetService("UserInputService")

local LP     = Players.LocalPlayer
local Remote = RepStorage:WaitForChild("RemoteEvent")

local RESPAWN_PAYLOAD = {[1] = "Respawn"}

-- ── Global State ──────────────────────────────────────────────
_G.Settings = {
    FistStrength   = false,
    BodyToughness  = false,
    MovementSpeed  = false,
    JumpForce      = false,
    PsychicPower   = false,
    DeathGrinding  = false,
    InstantRespawn = false,
    AutoQuest      = false,
    AutoSathQuest  = false,
    AntiAfk        = true,
    ActiveWeight   = 0,
    PlayerEsp      = false,
    AutoPunch      = false,
}

LP.Idled:Connect(function()
    if _G.Settings.AntiAfk then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

_G.Stats    = { FS="0", BT="0", MS="0", JF="0", PP="0" }
_G.RawStats = { FS=0,   BT=0,   MS=0,   JF=0,   PP=0 }

-- ── Sath Quest: UI-driven (MainQuestFrame) ───────────────────
local SATH_QUEST_DEFS = {
    [1]  = { name = "Starter Training", tasks = {
        { key = "FS", flag = "FistStrength",  target = 20 },
        { key = "BT", flag = "BodyToughness", target = 20 },
    }},
    [2]  = { name = "Mobility Basics", tasks = {
        { key = "MS", flag = "MovementSpeed", target = 20 },
        { key = "JF", flag = "JumpForce",     target = 20 },
    }},
    [3]  = { name = "Psychic Power Training", tasks = {
        { key = "PP", flag = "PsychicPower", target = 100 },
    }},
    [4]  = { name = "Fist Milestone", tasks = {
        { key = "FS", flag = "FistStrength", target = 1000 },
    }},
    [5]  = { name = "Body Milestone", tasks = {
        { key = "BT", flag = "BodyToughness", target = 1000 },
    }},
    [6]  = { name = "Movement Speed & Psychic Power", tasks = {
        { key = "MS", flag = "MovementSpeed", target = 1000 },
        { key = "PP", flag = "PsychicPower",  target = 1000 },
    }},
    [7]  = { name = "Jump Milestone", tasks = {
        { key = "JF", flag = "JumpForce", target = 1000 },
    }},
    [8]  = { name = "Speed Surge", tasks = {
        { key = "MS", flag = "MovementSpeed", target = 10000 },
    }},
    [9]  = { name = "Jump Force & Psychic Power", tasks = {
        { key = "JF", flag = "JumpForce",    target = 10000 },
        { key = "PP", flag = "PsychicPower", target = 10000 },
    }},
    [10] = { name = "Fist Master", tasks = {
        { key = "FS", flag = "FistStrength", target = 100000 },
    }},
    [11] = { name = "Psychic Power 100K", tasks = {
        { key = "PP", flag = "PsychicPower", target = 100000 },
    }},
    [12] = { name = "Triple Mastery", tasks = {
        { key = "FS", flag = "FistStrength",  target = 1000000 },
        { key = "BT", flag = "BodyToughness", target = 1000000 },
        { key = "PP", flag = "PsychicPower",  target = 1000000 },
    }},
    [13] = { name = "Psychic Power 100M (kills manual)", tasks = {
        { key = "PP", flag = "PsychicPower", target = 100000000 },
        { key = "KILLS", flag = nil, farm = false, target = 1000 },
    }},
}

local SATH_FARM_FLAGS = { "FistStrength", "BodyToughness", "MovementSpeed", "JumpForce", "PsychicPower", "DeathGrinding" }
local PHYSICAL_FLAGS = {
    FistStrength = true,
    BodyToughness = true,
    MovementSpeed = true,
    JumpForce = true,
}
local FLAG_LABELS = {
    FistStrength  = "Fist Strength",
    BodyToughness = "Body Toughness",
    MovementSpeed = "Movement Speed",
    JumpForce     = "Jump Force",
    PsychicPower  = "Psychic Power",
    KILLS         = "Kills",
}
local savedSathFarmFlags = {}
local sathFarmLock = false
local sathDialogBusy = false
local sathTalkMode = false
local sathWeightLock = false
local ppTeleported = false
local ppUseFlyMode = false
local lastSathFarmFlag = nil

local STAT_TO_RAW = {
    FistStrength  = "FS",
    BodyToughness = "BT",
    MovementSpeed = "MS",
    JumpForce     = "JF",
    PsychicPower  = "PP",
}
local setTrainingUiLocked -- forward; defined after UI toggles exist
local setToggleVisual -- forward; unlock Rayfield toggle before Set while Sath locks UI
local cascadeLock = false
local setSathEquipWeight  -- forward; defined in Equipment section
local stopFlyMode         -- forward; defined in fly section (used by Sath talk)
local isFlying
local hasMeditateEquipped

-- Weight tier requirements (MS / JF)
local WEIGHT_REQS = {
    { MS = 100,       JF = 5000 },
    { MS = 5000,      JF = 210000 },
    { MS = 567000,    JF = 2100000 },
    { MS = 10000000,  JF = 10000000 },
}

local function getScreenGui()
    local gui = LP:FindFirstChild("PlayerGui")
    return gui and gui:FindFirstChild("ScreenGui")
end

local function getMainQuestFrame()
    local sg = getScreenGui()
    return sg and sg:FindFirstChild("MainQuestFrame")
end

local function parseProgTxt(text)
    if not text or text == "" then return 0, 0 end
    local left, right = text:match("^%s*(.-)%s*/%s*(.+)%s*$")
    if not left then return 0, 0 end
    return Z.parseNum(left), Z.parseNum(right)
end

local function questTxtToMeta(questTxt)
    local t = string.lower(questTxt or "")
    if t:find("villain") or t:find("hero") or t:find("killed") then
        return nil, "KILLS", true
    end
    if t:find("fist") then return "FistStrength", "FS", false end
    if t:find("body") then return "BodyToughness", "BT", false end
    if t:find("movement") then return "MovementSpeed", "MS", false end
    if t:find("jump") then return "JumpForce", "JF", false end
    if t:find("psychic") then return "PsychicPower", "PP", false end
    return nil, nil, false
end

local function getMainQuestNo()
    if _G.ClientPlrData and _G.ClientPlrData.QuestData and _G.ClientPlrData.QuestData.MainQuest then
        return _G.ClientPlrData.QuestData.MainQuest.No
    end
    return nil
end

local function taskMatchesQuestDef(t, dt)
    if t.isKill then return dt.key == "KILLS" end
    return t.key == dt.key and t.target == dt.target
end

local function detectQuestId(tasks)
    if not tasks or #tasks == 0 then return nil end

    local sig = {}
    for _, t in ipairs(tasks) do
        if t.key and not t.isKill then
            table.insert(sig, { key = t.key, target = t.target })
        end
    end
    table.sort(sig, function(a, b) return a.key < b.key end)

    for id = 1, 13 do
        local def = SATH_QUEST_DEFS[id]
        local defSig = {}
        for _, dt in ipairs(def.tasks) do
            if dt.key ~= "KILLS" and dt.farm ~= false then
                table.insert(defSig, { key = dt.key, target = dt.target })
            end
        end
        table.sort(defSig, function(a, b) return a.key < b.key end)

        if #sig == #defSig then
            local ok = true
            for i = 1, #sig do
                if sig[i].key ~= defSig[i].key or sig[i].target ~= defSig[i].target then
                    ok = false
                    break
                end
            end
            if ok then return id end
        end
    end

    local hasKill, hasPP = false, false
    for _, t in ipairs(tasks) do
        if t.isKill then hasKill = true end
        if t.key == "PP" then hasPP = true end
    end
    if hasKill and hasPP then return 13 end
    return nil
end

local function normalizeQuestTasks(tasks)
    if not tasks or #tasks == 0 then return tasks end

    local no = getMainQuestNo()
    if no and no > 0 and SATH_QUEST_DEFS[no] then
        local filtered = {}
        for _, t in ipairs(tasks) do
            for _, dt in ipairs(SATH_QUEST_DEFS[no].tasks) do
                if taskMatchesQuestDef(t, dt) then
                    table.insert(filtered, t)
                    break
                end
            end
        end
        table.sort(filtered, function(a, b) return (a.index or 0) < (b.index or 0) end)
        return filtered
    end

    local qid = detectQuestId(tasks)
    if qid and SATH_QUEST_DEFS[qid] then
        local filtered = {}
        for _, t in ipairs(tasks) do
            for _, dt in ipairs(SATH_QUEST_DEFS[qid].tasks) do
                if taskMatchesQuestDef(t, dt) then
                    table.insert(filtered, t)
                    break
                end
            end
        end
        table.sort(filtered, function(a, b) return (a.index or 0) < (b.index or 0) end)
        return filtered
    end

    local filtered = {}
    for _, t in ipairs(tasks) do
        if t.isKill or (t.flag and t.target > 0) then
            table.insert(filtered, t)
        end
    end
    table.sort(filtered, function(a, b) return (a.index or 0) < (b.index or 0) end)
    return filtered
end

local function scanMainQuestUI()
    if getMainQuestNo() == 0 then return {} end

    local mqf = getMainQuestFrame()
    if not mqf then return nil end

    local tasks = {}
    for i = 1, 5 do
        local frame = mqf:FindFirstChild("MaxFrame" .. i)
        if frame and frame.Visible == true then
            local questLbl = frame:FindFirstChild("QuestTxt")
            local progLbl  = frame:FindFirstChild("ProgTxt")
            local claimBtn = frame:FindFirstChild("ClaimBtn")
            local qt = questLbl and questLbl.Text or ""
            local pt = progLbl and progLbl.Text or ""
            if qt == "" then
                -- skip empty slots
            else
                local flag, key, isKill = questTxtToMeta(qt)
                if flag or isKill then
                    local cur, tgt = parseProgTxt(pt)
                    if tgt > 0 then
                        local claimable = claimBtn and claimBtn.Visible == true
                        local complete = cur >= tgt
                        table.insert(tasks, {
                            index = i,
                            questTxt = qt,
                            progTxt = pt,
                            current = cur,
                            target = tgt,
                            flag = flag,
                            key = key,
                            isKill = isKill,
                            claimable = claimable,
                            complete = complete,
                        })
                    end
                end
            end
        end
    end
    return normalizeQuestTasks(tasks)
end

-- UI bazen tek satır gösterir; SATH_QUEST_DEFS ile tüm hedefleri tamamla (sıra def'ten gelir).
local function enrichTasksFromQuestDef(tasks)
    if not tasks then return tasks end
    local no = getMainQuestNo()
    local qid = (no and no > 0) and no or detectQuestId(tasks)
    if not qid or not SATH_QUEST_DEFS[qid] then return tasks end

    local byKey = {}
    for _, t in ipairs(tasks) do
        if t.key then byKey[t.key] = t end
    end

    local enriched = {}
    for _, dt in ipairs(SATH_QUEST_DEFS[qid].tasks) do
        if dt.farm == false or dt.key == "KILLS" then
            if byKey[dt.key] then
                table.insert(enriched, byKey[dt.key])
            end
        else
            local raw = _G.RawStats[dt.key] or 0
            local t = byKey[dt.key]
            if t then
                t.flag = t.flag or dt.flag
                t.target = t.target or dt.target
                t.current = math.max(t.current or 0, raw)
                table.insert(enriched, t)
            else
                table.insert(enriched, {
                    key = dt.key,
                    flag = dt.flag,
                    target = dt.target,
                    current = raw,
                    isKill = false,
                    questTxt = FLAG_LABELS[dt.flag] or dt.flag,
                    progTxt = tostring(raw) .. " / " .. tostring(dt.target),
                })
            end
        end
    end
    return enriched
end

local function needsQuestPickupFromSath()
    local no = getMainQuestNo()
    if no == 0 then return true end
    if no ~= nil and no > 0 then return false end
    local tasks = scanMainQuestUI()
    return not tasks or #tasks == 0
end

local function getCRCModule()
    local ls = LP.PlayerScripts:FindFirstChild("LocalScript")
    local mod = ls and ls:FindFirstChild("ClientRemoteController_Module")
    if mod then
        local ok, m = pcall(require, mod)
        if ok then return m end
    end
    return nil
end

local function resolveClickable(gui)
    if not gui then return nil end
    if gui:IsA("TextButton") or gui:IsA("ImageButton") then return gui end
    local inner = gui:FindFirstChildWhichIsA("TextButton", true)
        or gui:FindFirstChildWhichIsA("ImageButton", true)
    return inner or gui:FindFirstChild("Btn") or gui
end

local function collectGuiSignals(gui)
    local signals = {}
    if not gui then return signals end

    local function tryAdd(eventName)
        local ok, sig = pcall(function()
            return gui[eventName]
        end)
        if ok and sig then
            table.insert(signals, sig)
        end
    end

    if gui:IsA("GuiButton") then
        tryAdd("Activated")
    end
    tryAdd("MouseButton1Click")
    tryAdd("MouseButton1Down")
    return signals
end

local function clickScreenCenter()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local x, y = vp.X * 0.5, vp.Y * 0.5
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.1)
        vim:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
end

local function clickGuiCenter(btn)
    btn = resolveClickable(btn)
    if not btn then
        clickScreenCenter()
        return
    end
    if btn:IsA("GuiObject") and btn.AbsoluteSize.X > 0 and btn.AbsoluteSize.Y > 0 then
        local pos = btn.AbsolutePosition
        local size = btn.AbsoluteSize
        local x = pos.X + size.X * 0.5
        local y = pos.Y + size.Y * 0.5
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendMouseButtonEvent(x, y, 0, true, game, 0)
            task.wait(0.1)
            vim:SendMouseButtonEvent(x, y, 0, false, game, 0)
        end)
        return
    end
    clickScreenCenter()
end

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

local function teleportToSath()
    local pos
    local sathPart = RepStorage:FindFirstChild("SathPart")
    if sathPart and sathPart:IsA("BasePart") then
        pos = sathPart.Position
    else
        local map = workspace:FindFirstChild("Map")
        local sath = map and map:FindFirstChild("QuestNPC") and map.QuestNPC:FindFirstChild("Sathopian")
        local part = sath and (sath:FindFirstChild("UpperTorso") or sath:FindFirstChild("HumanoidRootPart"))
        if part then pos = part.Position end
    end
    if not pos then return false end

    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    root.CFrame = CFrame.new(pos + Vector3.new(0, 3.5, 0))
    task.wait(0.7)

    local crc = getCRCModule()
    if crc and crc.Storage then
        crc.Storage.TouchingQuestPart = true
    end
    return true
end

local function runSathDialog()
    if sathDialogBusy then return false end
    sathDialogBusy = true

    local sg = getScreenGui()
    if not sg then sathDialogBusy = false return false end

    local talkBtn  = sg:FindFirstChild("QuestTalkBtn")
    local msgFrame = sg:FindFirstChild("QuestMsgFrame")
    if not talkBtn or not msgFrame then sathDialogBusy = false return false end

    teleportToSath()

    local npcVal = talkBtn:FindFirstChild("Npc")
    if npcVal then npcVal.Value = "Sath" end

    for _ = 1, 40 do
        if talkBtn.Visible then break end
        task.wait(0.25)
    end

    if not talkBtn.Visible then
        sathDialogBusy = false
        return false
    end

    fireGuiSignal(talkBtn)
    task.wait(0.9)

    for _ = 1, 40 do
        if msgFrame.Visible then break end
        task.wait(0.25)
    end

    local page = msgFrame:FindFirstChild("Page") or msgFrame:WaitForChild("Page", 5)
    local btn  = resolveClickable(msgFrame:FindFirstChild("Btn") or msgFrame:WaitForChild("Btn", 5))

    for _ = 1, 80 do
        if not msgFrame.Visible then break end
        if page and page.Value <= 0 then break end
        if btn then fireGuiSignal(btn) end
        task.wait(0.35)
    end

    local crc = getCRCModule()
    if crc and crc.Storage then
        crc.Storage.TouchingQuestPart = false
    end

    sathDialogBusy = false
    return page and page.Value <= 0
end

local function maxWeightTierForStat(val, statKey)
    local field = statKey == "MS" and "MS" or "JF"
    local best = 0
    for tier = 1, 4 do
        if val >= WEIGHT_REQS[tier][field] then best = tier end
    end
    return best
end

local function getMobilityWeightTier(incomplete)
    local needMS, needJF = false, false
    for _, t in ipairs(incomplete) do
        if t.flag == "MovementSpeed" and not t.complete then needMS = true end
        if t.flag == "JumpForce" and not t.complete then needJF = true end
    end
    if not needMS and not needJF then return 0 end

    local ms, jf = _G.RawStats.MS, _G.RawStats.JF

    if needMS and needJF then
        for tier = 4, 1, -1 do
            if ms >= WEIGHT_REQS[tier].MS and jf >= WEIGHT_REQS[tier].JF then
                return tier
            end
        end
        for tier = 4, 1, -1 do
            if ms >= WEIGHT_REQS[tier].MS then return tier end
        end
        return 0
    elseif needMS then
        return maxWeightTierForStat(ms, "MS")
    elseif needJF then
        return maxWeightTierForStat(jf, "JF")
    end
    return 0
end

-- Chapter: ClientPlrData first; UI text fallback (never force MainQuestFrame.Visible).
local function readMainQuestChapterFromUI()
    local no = getMainQuestNo()
    if no ~= nil then return no end

    local mqf = getMainQuestFrame()
    if mqf then
        for _, d in ipairs(mqf:GetDescendants()) do
            if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text then
                local cur = d.Text:match("(%d+)%s*/%s*13")
                if cur then return tonumber(cur) end
            end
        end
    end

    local sg = getScreenGui()
    local menu = sg and sg:FindFirstChild("MenuFrame")
    if menu then
        for _, d in ipairs(menu:GetDescendants()) do
            if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text then
                local cur = d.Text:match("(%d+)%s*/%s*13")
                if cur then return tonumber(cur) end
            end
        end
    end

    local tasks = scanMainQuestUI()
    return tasks and detectQuestId(tasks) or nil
end

local function pauseConflictingFarms()
    if sathFarmLock then return end
    sathFarmLock = true
    savedSathFarmFlags = {}
    for _, k in ipairs(SATH_FARM_FLAGS) do
        savedSathFarmFlags[k] = _G.Settings[k]
        _G.Settings[k] = false
    end
    savedSathFarmFlags.ActiveWeight = _G.Settings.ActiveWeight
    ppTeleported = false
end

local function restoreConflictingFarms()
    if not sathFarmLock then return end
    local savedWeight = savedSathFarmFlags.ActiveWeight
    for k, v in pairs(savedSathFarmFlags) do
        _G.Settings[k] = v
    end
    savedSathFarmFlags = {}
    sathFarmLock = false
    if not _G.Settings.AutoSathQuest and savedWeight ~= nil and setSathEquipWeight then
        setSathEquipWeight(savedWeight or 0)
    end
end

local function syncFarmToggles()
    if not Toggles then return end
    local map = { FistStrength = "FS", BodyToughness = "BT", MovementSpeed = "MS", JumpForce = "JF", PsychicPower = "PP", DeathGrinding = "DG" }
    cascadeLock = true
    if _G.Settings.AutoSathQuest then
        for _, id in pairs(map) do
            if setToggleVisual then
                setToggleVisual(id, false)
            elseif Toggles[id] then
                Toggles[id]:Set(false)
            end
        end
        local aw = _G.Settings.ActiveWeight or 0
        sathWeightLock = true
        for i = 1, 4 do
            local wid = "W" .. i
            if setToggleVisual then
                setToggleVisual(wid, i == aw)
            elseif Toggles[wid] then
                Toggles[wid]:Set(i == aw)
            end
        end
        sathWeightLock = false
    else
        for flag, id in pairs(map) do
            if setToggleVisual then
                setToggleVisual(id, _G.Settings[flag] == true)
            elseif Toggles[id] then
                Toggles[id]:Set(_G.Settings[flag] == true)
            end
        end
    end
    cascadeLock = false
    if setTrainingUiLocked then
        setTrainingUiLocked(_G.Settings.AutoSathQuest)
    end
end

local function disableSathQuestFromTraining()
    if not _G.Settings.AutoSathQuest then return end
    _G.Settings.AutoSathQuest = false
    restoreConflictingFarms()
    syncFarmToggles()
    if Toggles and Toggles.SQ then Toggles.SQ:Set(false) end
    Rayfield:Notify({
        Title = "Sath",
        Content = "Disabled — training toggle was turned on.",
        Duration = 4,
        Image = "alert-circle",
    })
end

local function clearSathFarmFlagsOnly()
    _G.Settings.FistStrength = false
    _G.Settings.BodyToughness = false
    _G.Settings.MovementSpeed = false
    _G.Settings.JumpForce = false
    _G.Settings.PsychicPower = false
    _G.Settings.DeathGrinding = false
    ppTeleported = false
end

local function unequipAllTools()
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function() hum:UnequipTools() end)
    end
end

local function farmTaskSatisfied(t)
    if t.isKill or not t.flag or t.target <= 0 then return false end
    local rawKey = STAT_TO_RAW[t.flag]
    local statVal = rawKey and (_G.RawStats[rawKey] or 0) or 0
    local best = math.max(t.current or 0, statVal)
    return best >= t.target
end

local function sathAutofarmBlocked()
    return sathDialogBusy or sathTalkMode
end

local function getIncompleteFarmTasks(tasks)
    local list = {}
    for _, t in ipairs(tasks) do
        if t.flag and not t.isKill and not farmTaskSatisfied(t) then
            table.insert(list, t)
        end
    end
    return list
end

local function getOrderedIncompleteTasks(tasks)
    local incomplete = getIncompleteFarmTasks(tasks)
    if #incomplete == 0 then return incomplete end

    local no = getMainQuestNo() or detectQuestId(tasks)
    if not (no and SATH_QUEST_DEFS[no]) then
        table.sort(incomplete, function(a, b) return (a.index or 0) < (b.index or 0) end)
        return incomplete
    end

    local ordered = {}
    for _, dt in ipairs(SATH_QUEST_DEFS[no].tasks) do
        if dt.key ~= "KILLS" and dt.farm ~= false then
            for _, t in ipairs(incomplete) do
                if t.key == dt.key then
                    table.insert(ordered, t)
                    break
                end
            end
        end
    end
    return ordered
end

-- Sıra: SATH_QUEST_DEFS (quest 1 = FS sonra BT). Tek aktif stat; bitince sonraki.
-- MS+JF birlikte sadece FS/BT adımındayken veya sadece MS+JF quest'inde.
local function applySathFarmPhase(tasks)
    if not sathFarmLock then pauseConflictingFarms() end
    clearSathFarmFlagsOnly()

    tasks = enrichTasksFromQuestDef(tasks)
    local incomplete = getOrderedIncompleteTasks(tasks)
    if #incomplete == 0 then
        lastSathFarmFlag = nil
        unequipAllTools()
        syncFarmToggles()
        return nil
    end

    local activeFlags = {}
    local activeLabels = {}
    local hasMS, hasJF = false, false
    local physicalIncomplete = {}

    for _, t in ipairs(incomplete) do
        if t.flag == "MovementSpeed" then hasMS = true end
        if t.flag == "JumpForce" then hasJF = true end
        if PHYSICAL_FLAGS[t.flag] then
            table.insert(physicalIncomplete, t)
        end
    end

    local mobilityPair = hasMS and hasJF
    local primary = physicalIncomplete[1]

    if primary then
        table.insert(activeFlags, primary.flag)
        table.insert(activeLabels, FLAG_LABELS[primary.flag] or primary.flag)
        if (primary.flag == "FistStrength" or primary.flag == "BodyToughness") and mobilityPair then
            table.insert(activeFlags, "MovementSpeed")
            table.insert(activeFlags, "JumpForce")
            table.insert(activeLabels, "Movement Speed")
            table.insert(activeLabels, "Jump Force")
        elseif (primary.flag == "MovementSpeed" or primary.flag == "JumpForce") and mobilityPair then
            activeFlags = { "MovementSpeed", "JumpForce" }
            activeLabels = { "Movement Speed", "Jump Force" }
        end
    elseif incomplete[1].flag == "PsychicPower" then
        table.insert(activeFlags, "PsychicPower")
        table.insert(activeLabels, "Psychic Power")
    end

    if #activeFlags == 0 then
        syncFarmToggles()
        return nil
    end

    _G.Settings.DeathGrinding = false
    for _, flag in ipairs(activeFlags) do
        _G.Settings[flag] = true
    end

    if activeFlags[1] == "BodyToughness" and Z.btTrainingMode(_G.RawStats.BT) == "deathgrind" then
        _G.Settings.DeathGrinding = true
    end

    local primaryFlag = activeFlags[1]
    if primaryFlag ~= lastSathFarmFlag then
        unequipAllTools()
        lastSathFarmFlag = primaryFlag
    end

    local needWeight = false
    for _, f in ipairs(activeFlags) do
        if f == "MovementSpeed" or f == "JumpForce" then
            needWeight = true
            break
        end
    end
    if needWeight and setSathEquipWeight then
        local mobilityTasks = {}
        for _, t in ipairs(incomplete) do
            if t.flag == "MovementSpeed" or t.flag == "JumpForce" then
                table.insert(mobilityTasks, t)
            end
        end
        setSathEquipWeight(getMobilityWeightTier(mobilityTasks))
    elseif activeFlags[1] == "PsychicPower" and setSathEquipWeight then
        setSathEquipWeight(0)
    end

    syncFarmToggles()
    return primaryFlag, activeLabels, nil, physicalIncomplete
end

local function hasPendingKillTask(tasks)
    for _, t in ipairs(tasks) do
        if t.isKill and t.target > 0 and t.current < t.target then
            return true
        end
    end
    return false
end

local function allAutoFarmTasksDone(tasks)
    local any = false
    for _, t in ipairs(tasks) do
        if t.flag and not t.isKill then
            any = true
            if not farmTaskSatisfied(t) then return false end
        end
    end
    return any
end

local function isReadyForSathTalk(tasks, talkBtn)
    if not tasks or #tasks == 0 then return false end
    tasks = enrichTasksFromQuestDef(tasks)
    if hasPendingKillTask(tasks) then return false end
    if not allAutoFarmTasksDone(tasks) then return false end
    if talkBtn and talkBtn.Visible then return true end
    return true
end

local function prepareForSathTalk()
    sathTalkMode = true
    clearSathFarmFlagsOnly()
    ppUseFlyMode = false
    if stopFlyMode then stopFlyMode() end
    unequipAllTools()
    syncFarmToggles()
end

local function buildSathInfoText()
    if needsQuestPickupFromSath() then
        return "Quest 0/13 — 0/0 ready | Go to Sath"
    end

    local tasks = scanMainQuestUI()
    if not tasks or #tasks == 0 then
        return "—"
    end
    tasks = enrichTasksFromQuestDef(tasks)

    local no = getMainQuestNo()
    local qid = detectQuestId(tasks)
    local idStr = (no and no > 0 and tostring(no)) or (qid and tostring(qid)) or "?"

    local ready, farmTotal = 0, 0
    local lines = {}
    for _, t in ipairs(tasks) do
        if t.flag and not t.isKill then
            farmTotal = farmTotal + 1
            if farmTaskSatisfied(t) then
                ready = ready + 1
            end
            local label = FLAG_LABELS[t.flag]
            if label and t.progTxt and t.progTxt ~= "" then
                table.insert(lines, label .. ": " .. t.progTxt)
            end
        end
    end

    local head = string.format("Quest %s/13 — %d/%d ready", idStr, ready, farmTotal)
    if #lines == 0 then
        return head
    end
    return head .. " | " .. table.concat(lines, " · ")
end

local function needsSathFarm(tasks)
    return #getIncompleteFarmTasks(enrichTasksFromQuestDef(tasks)) > 0
end

local function sathAllowsToolFarm(flag)
    if not _G.Settings.AutoSathQuest then return _G.Settings[flag] == true end
    -- Sath modunda: hem Settings hem lastSathFarmFlag eşleşmeli
    if not _G.Settings[flag] then return false end
    if not lastSathFarmFlag then return false end
    if flag == "FistStrength" or flag == "BodyToughness" then
        return lastSathFarmFlag == flag
    end
    return _G.Settings[flag] == true
end

local function tryAdvanceSathQuest()
    if sathDialogBusy then return false end
    local sg = getScreenGui()
    if not sg then return false end

    local function runTalkFlow()
        prepareForSathTalk()
        pauseConflictingFarms()
        unequipAllTools()
        local ok = runSathDialog()
        -- restoreConflictingFarms() burada ÇAĞRILMIYOR:
        -- Sath döngüsü bittikten sonra applySathFarmPhase yeni fazı set eder.
        -- Restore çağrılırsa eski BT/FS toggle'ları geri gelir ve push-up kesilmez.
        sathFarmLock = false  -- kilidi aç; döngü yeni fazı belirlesin
        syncFarmToggles()
        sathTalkMode = false
        return ok
    end

    local talkBtn = sg:FindFirstChild("QuestTalkBtn")
    if talkBtn and talkBtn.Visible then
        return runTalkFlow()
    end

    prepareForSathTalk()
    teleportToSath()
    for _ = 1, 50 do
        if (isFlying and isFlying()) or (hasMeditateEquipped and hasMeditateEquipped()) then
            if stopFlyMode then stopFlyMode() end
        end
        unequipAllTools()
        talkBtn = sg:FindFirstChild("QuestTalkBtn")
        if talkBtn and talkBtn.Visible then
            return runTalkFlow()
        end
        task.wait(0.25)
    end
    sathTalkMode = false
    return false
end

-- ── Respawn with position restore ────────────────────────────
local savedRespawnPos = nil

local function doRespawn()
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then savedRespawnPos = root.Position end
    Remote:FireServer(RESPAWN_PAYLOAD)
end

-- ── Stat Sniffer ──────────────────────────────────────────────
task.spawn(function()
    while true do
        local gui   = LP:FindFirstChild("PlayerGui")
        local frame = gui
            and gui:FindFirstChild("ScreenGui")
            and gui.ScreenGui:FindFirstChild("MenuFrame")
            and gui.ScreenGui.MenuFrame:FindFirstChild("InfoFrame")

        if frame then
            local function txt(key)
                local o = frame:FindFirstChild(key)
                return o and o.Text:match(":%s*(.+)") or "0"
            end
            local fs,bt,ms,jf,pp = txt("FSTxt"),txt("BTTxt"),txt("MSTxt"),txt("JFTxt"),txt("PPTxt")
            _G.RawStats.FS=Z.parseNum(fs); _G.Stats.FS=fs
            _G.RawStats.BT=Z.parseNum(bt); _G.Stats.BT=bt
            _G.RawStats.MS=Z.parseNum(ms); _G.Stats.MS=ms
            _G.RawStats.JF=Z.parseNum(jf); _G.Stats.JF=jf
            _G.RawStats.PP=Z.parseNum(pp); _G.Stats.PP=pp
        end
        task.wait(0.8)
    end
end)

local function findStarterTool(names)
    for _, name in ipairs(names) do
        local char = LP.Character
        local t = (char and char:FindFirstChild(name)) or LP.Backpack:FindFirstChild(name)
        if t and t:IsA("Tool") then return t, name end
    end
    return nil, nil
end

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

local lastPushUpBt = 0

local function usePushUpBodyToughness()
    useStarterTraining("BodyToughness")
    clickScreenCenter()
    local now = tick()
    if now - lastPushUpBt >= 1.05 then
        lastPushUpBt = now
        Remote:FireServer({ Z.BT_PUSHUP_REMOTE or "+BT1" })
    end
end

local function shouldBtDeathGrindFarm()
    return sathAllowsToolFarm("BodyToughness")
        and Z.btTrainingMode(_G.RawStats.BT) == "deathgrind"
end

local function shouldRespawnForBtFarm()
    if _G.Settings.InstantRespawn then return true end
    if _G.Settings.DeathGrinding and Z.canDeathGrind(_G.RawStats.BT) then return true end
    if shouldBtDeathGrindFarm() then return true end
    return false
end

local function useStarterTraining(statKey)
    local names = Z.STARTER_TOOLS[statKey]
    if not names then return end
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
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

local function equipZoneTool(toolName)
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not hum or hum.Health <= 0 then return end
    if char:FindFirstChild(toolName) then return end
    local tool = LP.Backpack:FindFirstChild(toolName)
    if tool then hum:EquipTool(tool) end
end

task.spawn(function()
    while true do
        if sathAutofarmBlocked() then
            task.wait(0.15)
            continue
        end

        local chapter = readMainQuestChapterFromUI()
        local target

        if (_G.Settings.DeathGrinding and Z.canDeathGrind(_G.RawStats.BT))
            or shouldBtDeathGrindFarm() then
            target = Z.deathGrindTarget(_G.RawStats)
        elseif _G.Settings.FistStrength then
            target = Z.farmTarget({
                BodyToughness = false,
                FistStrength  = true,
                PsychicPower  = false,
            }, _G.RawStats, chapter)
        end

        if target then
            local char = LP.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root and (root.Position - target).Magnitude > 8 then
                root.CFrame = CFrame.new(target)
            end
        end

        task.wait(0.1)
    end
end)

task.spawn(function()
    while true do
        if sathAutofarmBlocked() then
            task.wait(0.15)
            continue
        end

        local chapter = readMainQuestChapterFromUI()

        if sathAllowsToolFarm("FistStrength") then
            local fsMode = Z.fsTrainingMode(chapter)
            if fsMode == "starter" then
                useStarterTraining("FistStrength")
            elseif fsMode == "rock" or fsMode == "zone" then
                equipZoneTool(Z.ZONE_TOOLS.FistStrength)
            end
        end

        if sathAllowsToolFarm("BodyToughness") and Z.btTrainingMode(_G.RawStats.BT) == "pushup" then
            usePushUpBodyToughness()
        end

        task.wait(0.35)
    end
end)

local function setFlyStatus(on)
    flyStatusSynced = on == true
    pcall(function()
        Remote:FireServer({ "Update_Flying_Status", flyStatusSynced })
    end)
end

local flyStatusSynced = false

isFlying = function()
    return _G.Flying == true or flyStatusSynced
end

hasMeditateEquipped = function()
    local char = LP.Character
    return char and char:FindFirstChild("Meditate") ~= nil
end

local function unequipMeditateTool()
    if not hasMeditateEquipped() then return end
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum:UnequipTools() end) end
end

local function waitUntilMeditateGone(maxSec)
    local t0 = os.clock()
    while hasMeditateEquipped() and os.clock() - t0 < (maxSec or 2) do
        unequipMeditateTool()
        task.wait(0.1)
    end
    return not hasMeditateEquipped()
end

local function pressSpace()
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
        task.wait(0.04)
        vim:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
    end)
end

local function doPhysicalJump()
    pcall(function() UserInputService:JumpRequest() end)
end

local function findOpenFlyPosition()
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local fallback = Vector3.new(420, 299, 878)
    if not root then return fallback end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { char }

    local offsets = {
        Vector3.zero,
        Vector3.new(25, 0, 0),
        Vector3.new(-25, 0, 0),
        Vector3.new(0, 0, 25),
        Vector3.new(0, 0, -25),
    }

    for _, off in ipairs(offsets) do
        local base = root.Position + off
        for lift = 35, 100, 15 do
            local pos = Vector3.new(base.X, base.Y + lift, base.Z)
            local clearAbove = not workspace:Raycast(pos, Vector3.new(0, 20, 0), params)
            local clearHead = not workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, 8, 0), params)
            if clearAbove and clearHead then
                return pos
            end
        end
    end

    return fallback
end

local function isOnGround(hum)
    return hum.FloorMaterial ~= Enum.Material.Air
end

local function isFalling(hum, root)
    local st = hum:GetState()
    if st == Enum.HumanoidStateType.Freefall then return true end
    if root then
        local vy = root.AssemblyLinearVelocity.Y
        if vy < -1.5 then return true end
    end
    return false
end

local function activateFlyJump(hum, root)
    if isFlying() then
        setFlyStatus(true)
        return true
    end

    if isFalling(hum, root) then
        pressSpace()
        task.wait(0.4)
        if isFlying() then
            setFlyStatus(true)
            return true
        end
        return false
    end

    if isOnGround(hum) then
        doPhysicalJump()
        task.wait(0.12)
        waitUntilFalling(hum, root, 1.2)
    end

    if isFalling(hum, root) then
        pressSpace()
        task.wait(0.4)
        if isFlying() then
            setFlyStatus(true)
            return true
        end
    end

    return false
end

local function waitUntilFalling(hum, root, maxSec)
    local t0 = os.clock()
    while os.clock() - t0 < (maxSec or 1.2) do
        if isFalling(hum, root) then return true end
        task.wait(0.05)
    end
    return isFalling(hum, root)
end

local function canUseFlyMeditate()
    local chapter = readMainQuestChapterFromUI()
    return Z.canFlyMeditateFarm(chapter, _G.RawStats)
end

stopFlyMode = function()
    if not isFlying() and not hasMeditateEquipped() then
        flyStatusSynced = false
        return
    end

    unequipMeditateTool()
    waitUntilMeditateGone(2)

    if isFlying() then
        pressSpace()
        task.wait(0.25)
    end

    setFlyStatus(false)
    _G.Flying = false
end

-- Fly: Freefall + Space -> _G.Flying; sunucu sync: Update_Flying_Status
local function tryEnterFlyMode()
    if isFlying() then
        setFlyStatus(true)
        return true
    end
    if not canUseFlyMeditate() then return false end

    pcall(function() Remote:FireServer({ "Setting", "ToggleFlight", true }) end)

    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then return false end

    if activateFlyJump(hum, root) then
        return true
    end

    root.CFrame = CFrame.new(findOpenFlyPosition())
    task.wait(0.3)
    hum = char:FindFirstChildOfClass("Humanoid")
    root = char and char:FindFirstChild("HumanoidRootPart")
    if hum and root then
        waitUntilFalling(hum, root, 1.5)
        activateFlyJump(hum, root)
    end
    return isFlying()
end

local function equipMeditateTool()
    if sathAutofarmBlocked() or not isFlying() then return end
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not hum or hum.Health <= 0 then return end
    if char:FindFirstChild("Meditate") then return end
    local tool = LP.Backpack:FindFirstChild("Meditate")
    if tool then hum:EquipTool(tool) end
end

task.spawn(function()
    while true do
        if sathAutofarmBlocked() then
            if not _G.Settings.PsychicPower then
                stopFlyMode()
                unequipAllTools()
            end
            task.wait(0.15)
            continue
        end

        if _G.Settings.PsychicPower then
            local chapter = readMainQuestChapterFromUI()
            local useFly = Z.canFlyMeditateFarm(chapter, _G.RawStats)

            if not ppTeleported then
                local target = Z.smartTarget({ PsychicPower = true }, _G.RawStats, chapter)
                if target then
                    local char = LP.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if root then
                        root.CFrame = CFrame.new(target)
                        ppTeleported = true
                        task.wait(0.5)
                    end
                else
                    ppTeleported = true
                end
            end

            if useFly then
                ppUseFlyMode = true
                if tryEnterFlyMode() and isFlying() then
                    equipMeditateTool()
                end
            else
                if ppUseFlyMode then
                    stopFlyMode()
                    ppUseFlyMode = false
                end
                equipMeditateTool()
            end
        else
            if ppTeleported or ppUseFlyMode then
                unequipAllTools()
                stopFlyMode()
            end
            ppTeleported = false
            ppUseFlyMode = false
        end
        task.wait(0.4)
    end
end)

task.spawn(function()
    while true do
        local w = _G.Settings.ActiveWeight
        if w > 0 then
            Remote:FireServer({[1]="EquipWeight_Request", [2]=w})
        end
        task.wait(3)
    end
end)

task.spawn(function()
    local questConfig = {
        DLQ = {"FS", "BT", "PP", "MS", "JF"},
        WLQ = {"FS", "BT", "PP"}
    }

    while true do
        if _G.Settings.AutoQuest then
            for qtype, stats in pairs(questConfig) do
                for _, stat in ipairs(stats) do
                    if _G.Settings.AutoQuest then
                        Remote:FireServer({[1]=qtype, [2]=stat, [3]="Claim"})
                        task.wait(0.5)
                    end
                end
            end
        end
        task.wait(8)
    end
end)

-- ── Auto Sath Quest loop (UI: ProgTxt farm → QuestTalkBtn → dialog Btn) ──
task.spawn(function()
    while true do
        if _G.Settings.AutoSathQuest then
            if needsQuestPickupFromSath() then
                if not sathDialogBusy then
                    tryAdvanceSathQuest()
                end
                task.wait(2)
            else
            local tasks = scanMainQuestUI()
            if tasks and #tasks > 0 then
                tasks = enrichTasksFromQuestDef(tasks)
            end

            if tasks and #tasks > 0 then
                local sg = getScreenGui()
                local talkBtn = sg and sg:FindFirstChild("QuestTalkBtn")

                if isReadyForSathTalk(tasks, talkBtn) then
                    tryAdvanceSathQuest()
                    task.wait(2)
                else
                    sathTalkMode = false
                    if needsSathFarm(tasks) then
                        applySathFarmPhase(tasks)
                    elseif hasPendingKillTask(tasks) then
                        clearSathFarmFlagsOnly()
                        unequipAllTools()
                        lastSathFarmFlag = nil
                        syncFarmToggles()
                    else
                        applySathFarmPhase(tasks)
                    end
                end
            else
                sathTalkMode = false
            end
            end

        elseif sathFarmLock then
            sathTalkMode = false
            restoreConflictingFarms()
            syncFarmToggles()
        else
            sathTalkMode = false
        end

        task.wait(0.35)
    end
end)

-- ── Character event binding ───────────────────────────────────
local Toggles = {}

local function bindCharacterEvents(char)
    local hum = char:WaitForChild("Humanoid", 8)
    if not hum then return end

    local prevHP  = hum.Health
    local lastDmg = 0

    hum:GetPropertyChangedSignal("Health"):Connect(function()
        local cur   = hum.Health
        local delta = prevHP - cur
        if delta > 0 then
            lastDmg = delta
            if shouldRespawnForBtFarm() and (cur - lastDmg) <= 0 then
                doRespawn()
            end
        end
        prevHP = cur
    end)

    hum.Died:Connect(function()
        if shouldRespawnForBtFarm() then
            task.wait(0.1)
            doRespawn()
        end
    end)
end

LP.CharacterAdded:Connect(function(char)
    ppTeleported = false

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

    bindCharacterEvents(char)
end)

if LP.Character then bindCharacterEvents(LP.Character) end

local function spam(flagName, payload, interval, gateFn)
    task.spawn(function()
        while true do
            if _G.Settings[flagName] and (not gateFn or gateFn()) then
                Remote:FireServer(payload)
            end
            task.wait(interval)
        end
    end)
end

spam("FistStrength", {[1] = "Add_FS_Request"}, 0.05, function()
    if sathAutofarmBlocked() then return false end
    local chapter = readMainQuestChapterFromUI()
    return Z.fsTrainingMode(chapter) ~= "starter"
end)
spam("MovementSpeed", {[1] = "Add_MS_Request"}, 0.25, function()
    return not sathAutofarmBlocked()
end)
spam("JumpForce", {[1] = "Add_JF_Request"}, 0.25, function()
    return not sathAutofarmBlocked()
end)

-- ══════════════════════════════════════════════════════════════
-- Players: Kill / Punch / ESP
-- ══════════════════════════════════════════════════════════════
local PlayerDropdown
local currentKillSelection = { "All" }
local playerByLabel = {}
local killBusy = false
local espEnabled = false
local espObjects = {}

local function getRoot(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("Torso")
        or char.PrimaryPart
end

local function formatPlayerLabel(plr)
    return string.format("%s (@%s)", plr.DisplayName, plr.Name)
end

local function buildPlayerDropdownOptions()
    local opts = { "All" }
    playerByLabel = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local label = formatPlayerLabel(plr)
            playerByLabel[label] = plr
            table.insert(opts, label)
        end
    end
    table.sort(opts, function(a, b)
        if a == "All" then return true end
        if b == "All" then return false end
        return a:lower() < b:lower()
    end)
    return opts
end

local function refreshPlayerDropdown()
    if not PlayerDropdown then return end
    local opts = buildPlayerDropdownOptions()
    local preserved = {}
    for _, sel in ipairs(currentKillSelection) do
        if sel == "All" or playerByLabel[sel] then
            table.insert(preserved, sel)
        end
    end
    if #preserved == 0 then
        preserved = { "All" }
    end
    PlayerDropdown:Refresh(opts)
    PlayerDropdown:Set(preserved)
    currentKillSelection = preserved
end

local function resolveKillTargets()
    local targets = {}
    local pickAll = false
    for _, opt in ipairs(currentKillSelection) do
        if opt == "All" then
            pickAll = true
            break
        end
    end
    if pickAll then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP then
                table.insert(targets, plr)
            end
        end
    else
        for _, opt in ipairs(currentKillSelection) do
            local plr = playerByLabel[opt]
            if plr and plr.Parent then
                table.insert(targets, plr)
            end
        end
    end
    return targets
end

local function bringAndAnchorTargets(targets)
    local myRoot = getRoot(LP.Character)
    if not myRoot then return {}, nil end

    local saved = {}
    local stackCF = myRoot.CFrame
    for _, plr in ipairs(targets) do
        local char = plr.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and getRoot(char)
        if hum and root and hum.Health > 0 then
            pcall(function()
                if hum.Sit then hum.Sit = false end
            end)

            local savedCF = root.CFrame
            root.CFrame = stackCF
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            root.Anchored = true

            table.insert(saved, {
                root = root,
                cframe = savedCF,
            })
        end
    end
    return saved, myRoot
end

local function restoreAnchored(saved)
    for _, entry in ipairs(saved) do
        local root = entry.root
        if root and root.Parent then
            root.Anchored = false
            root.CFrame = entry.cframe
        end
    end
end

local function getSkillFrame()
    local sg = getScreenGui()
    local menu = sg and sg:FindFirstChild("MenuFrame")
    return menu and menu:FindFirstChild("SkillFrame")
end

local function getSkillDefaultKeyName(skillTxtName, txtBoxName)
    local skillFrame = getSkillFrame()
    if not skillFrame then return nil end
    local skillTxt = skillFrame:FindFirstChild(skillTxtName)
    local txtBox = skillTxt and skillTxt:FindFirstChild(txtBoxName)
    local defKey = txtBox and txtBox:FindFirstChild("DefaultKey")
    if defKey and defKey:IsA("StringValue") and defKey.Value ~= "" then
        return defKey.Value
    end
    return nil
end

local function pressSkillKey(keyName)
    if not keyName or keyName == "" then return false end
    local keyCode
    local ok = pcall(function()
        keyCode = Enum.KeyCode[keyName]
    end)
    if not ok or not keyCode then return false end

    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true, keyCode, false, game)
        task.wait(0.05)
        vim:SendKeyEvent(false, keyCode, false, game)
    end)
    return true
end

local function pressPunchSkill()
    local key = getSkillDefaultKeyName("SkillTxt2", "Skill_2_TxtBox")
    return pressSkillKey(key or "C")
end

local function pressFireballSkill()
    local key = getSkillDefaultKeyName("SkillTxt4", "Skill_4_TxtBox")
    return pressSkillKey(key)
end

local function runKillWithFireball()
    if killBusy then return end
    local targets = resolveKillTargets()
    if #targets == 0 then
        Rayfield:Notify({ Title = "Kill", Content = "No targets selected.", Duration = 3, Image = "users" })
        return
    end

    killBusy = true
    pcall(function()
        local saved = bringAndAnchorTargets(targets)
        if #saved == 0 then
            Rayfield:Notify({ Title = "Kill", Content = "Targets not available.", Duration = 3, Image = "users" })
            return
        end

        if not pressFireballSkill() then
            Rayfield:Notify({ Title = "Kill", Content = "Fireball hotkey not found in SkillFrame.", Duration = 4, Image = "alert-circle" })
        end

        task.wait(1.5)
        restoreAnchored(saved)
    end)
    killBusy = false
end

local function runKeybindPunch()
    if not _G.Settings.AutoPunch then return end
    if killBusy then return end

    local targets = resolveKillTargets()
    if #targets == 0 then return end

    killBusy = true
    pcall(function()
        local saved = bringAndAnchorTargets(targets)
        if #saved == 0 then return end

        pressPunchSkill()
        task.wait(0.1)
        pressPunchSkill()

        task.wait(0.15)
        restoreAnchored(saved)
    end)
    killBusy = false
end

local function removePlayerEsp(plr)
    local pack = espObjects[plr]
    if not pack then return end
    if pack.conns then
        for _, c in ipairs(pack.conns) do
            pcall(function() c:Disconnect() end)
        end
    end
    if pack.charConn then
        pcall(function() pack.charConn:Disconnect() end)
    end
    if pack.highlight and pack.highlight.Parent then
        pack.highlight:Destroy()
    end
    if pack.gui and pack.gui.Parent then
        pack.gui:Destroy()
    end
    espObjects[plr] = nil
end

local function updateEspHealthLabel(pack, hum)
    if not pack or not pack.hpLbl or not hum then return end
    pack.hpLbl.Text = string.format("%d / %d HP", math.floor(hum.Health + 0.5), math.floor(hum.MaxHealth + 0.5))
end

local function attachPlayerEsp(plr)
    if plr == LP or not espEnabled then return end
    removePlayerEsp(plr)

    local pack = { conns = {} }
    espObjects[plr] = pack

    local function onCharacter(char)
        if not espEnabled or plr.Parent ~= Players then
            removePlayerEsp(plr)
            return
        end

        if pack.highlight and pack.highlight.Parent then pack.highlight:Destroy() end
        if pack.gui and pack.gui.Parent then pack.gui:Destroy() end
        if pack.conns then
            for _, c in ipairs(pack.conns) do
                pcall(function() c:Disconnect() end)
            end
        end
        pack.conns = {}

        local hum = char:WaitForChild("Humanoid", 8)
        local head = char:FindFirstChild("Head") or getRoot(char)
        if not hum or not head then return end

        local hl = Instance.new("Highlight")
        hl.Name = "SPTS_ESP"
        hl.Adornee = char
        hl.FillColor = Color3.fromRGB(220, 60, 80)
        hl.FillTransparency = 0.55
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.OutlineTransparency = 0.15
        pcall(function()
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        end)
        hl.Parent = char
        pack.highlight = hl

        local bb = Instance.new("BillboardGui")
        bb.Name = "SPTS_ESP_Label"
        bb.Adornee = head
        bb.Size = UDim2.fromOffset(220, 56)
        bb.StudsOffset = Vector3.new(0, 2.8, 0)
        bb.AlwaysOnTop = true
        bb.MaxDistance = 10000
        bb.Parent = head
        pack.gui = bb

        local nameLbl = Instance.new("TextLabel")
        nameLbl.BackgroundTransparency = 1
        nameLbl.Size = UDim2.new(1, 0, 0.55, 0)
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextScaled = true
        nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLbl.TextStrokeTransparency = 0.4
        nameLbl.Text = formatPlayerLabel(plr)
        nameLbl.Parent = bb

        local hpLbl = Instance.new("TextLabel")
        hpLbl.BackgroundTransparency = 1
        hpLbl.Position = UDim2.new(0, 0, 0.55, 0)
        hpLbl.Size = UDim2.new(1, 0, 0.45, 0)
        hpLbl.Font = Enum.Font.Gotham
        hpLbl.TextScaled = true
        hpLbl.TextColor3 = Color3.fromRGB(180, 255, 180)
        hpLbl.TextStrokeTransparency = 0.5
        hpLbl.Parent = bb
        pack.hpLbl = hpLbl

        updateEspHealthLabel(pack, hum)
        table.insert(pack.conns, hum.HealthChanged:Connect(function()
            updateEspHealthLabel(pack, hum)
        end))
        table.insert(pack.conns, hum.Died:Connect(function()
            updateEspHealthLabel(pack, hum)
        end))
    end

    pack.charConn = plr.CharacterAdded:Connect(onCharacter)
    if plr.Character then
        task.spawn(onCharacter, plr.Character)
    end
end

local function setPlayerEspEnabled(on)
    espEnabled = on == true
    _G.Settings.PlayerEsp = espEnabled
    if espEnabled then
        for _, plr in ipairs(Players:GetPlayers()) do
            attachPlayerEsp(plr)
        end
    else
        for plr in pairs(espObjects) do
            removePlayerEsp(plr)
        end
    end
end

-- ══════════════════════════════════════════════════════════════
-- UI
-- ══════════════════════════════════════════════════════════════
local Window = Rayfield:CreateWindow({
    Name            = "SPTS",
    Icon            = "shield",
    LoadingTitle    = "Syncing Engine Arrays...",
    LoadingSubtitle = "SPTS Premium Module",
    ShowText        = "Toggle Window",
    Theme           = "Default",
    ToggleUIKeybind = Enum.KeyCode.K,
    ConfigurationSaving = {
        Enabled    = true,
        FolderName = "SPTS_CoreSuite",
        FileName   = "Profiles",
    },
})

local DashTab   = Window:CreateTab("Dashboard","layout-dashboard")
local AutoTab   = Window:CreateTab("Autofarm","cpu")
local NavTab    = Window:CreateTab("Teleports","compass")
local EquipTab  = Window:CreateTab("Equipment","dumbbell")
local UtilTab   = Window:CreateTab("Utilities","wrench")
local ThemeTab  = Window:CreateTab("Themes","palette")

DashTab:CreateSection("Live Stats")
local LabelFS = DashTab:CreateLabel("Fist Strength: --",2197020684)
local LabelBT = DashTab:CreateLabel("Body Toughness: --",2197021260)
local LabelMS = DashTab:CreateLabel("Movement Speed: --",2197021644)
local LabelJF = DashTab:CreateLabel("Jump Force: --",2197021850)
local LabelPP = DashTab:CreateLabel("Psychic Power: --",2197021455)

task.spawn(function()
    while task.wait(0.5) do
        LabelFS:Set("Fist Strength: "  .. _G.Stats.FS)
        LabelBT:Set("Body Toughness: " .. _G.Stats.BT)
        LabelMS:Set("Movement Speed: " .. _G.Stats.MS)
        LabelJF:Set("Jump Force: "     .. _G.Stats.JF)
        LabelPP:Set("Psychic Power: "  .. _G.Stats.PP)
    end
end)

AutoTab:CreateSection("Training")

local keyMap = {
    FS="FistStrength", BT="BodyToughness",
    MS="MovementSpeed", JF="JumpForce", PP="PsychicPower",
}

local function cascade(id)
    if cascadeLock or _G.Settings.AutoSathQuest then return end
    cascadeLock = true

    if id == "PP" and _G.Settings.PsychicPower then
        for _, k in ipairs({"BT","MS","JF","DG"}) do
            local key = keyMap[k] or (k=="DG" and "DeathGrinding")
            if key then _G.Settings[key] = false end
            if Toggles[k] then Toggles[k]:Set(false) end
        end

    elseif id == "DG" and _G.Settings.DeathGrinding then
        if Z.btTrainingMode(_G.RawStats.BT) == "pushup" then
            _G.Settings.DeathGrinding = false
            if Toggles.DG then Toggles.DG:Set(false) end
        end
        _G.Settings.BodyToughness = false
        if Toggles.BT then Toggles.BT:Set(false) end
        _G.Settings.PsychicPower = false
        ppTeleported = false
        if Toggles.PP then Toggles.PP:Set(false) end

    elseif (id=="BT" or id=="MS" or id=="JF") and _G.Settings[keyMap[id]] then
        _G.Settings.PsychicPower = false
        ppTeleported = false
        if Toggles.PP then Toggles.PP:Set(false) end
        _G.Settings.DeathGrinding = false
        if Toggles.DG then Toggles.DG:Set(false) end
    end

    cascadeLock = false
end

setToggleVisual = function(id, value)
    local tog = Toggles and Toggles[id]
    if not tog then return end
    local wantOn = value == true
    local unlockForSet = _G.Settings.AutoSathQuest == true
    if unlockForSet then
        pcall(function() if tog.Unlock then tog:Unlock() end end)
        pcall(function() if tog.SetLocked then tog:SetLocked(false) end end)
        pcall(function() if tog.SetInteraction then tog:SetInteraction(true) end end)
    end
    pcall(function() tog:Set(wantOn) end)
    if unlockForSet then
        pcall(function() if tog.Lock then tog:Lock(true) end end)
        pcall(function() if tog.SetLocked then tog:SetLocked(true) end end)
        pcall(function() if tog.SetInteraction then tog:SetInteraction(false) end end)
    end
end

local matrixDefs = {
    {id="FS", name="Auto Fist Strength",  flag="Run_FS"},
    {id="BT", name="Auto Body Toughness", flag="Run_BT"},
    {id="MS", name="Auto Movement Speed", flag="Run_MS"},
    {id="JF", name="Auto Jump Force",     flag="Run_JF"},
    {id="PP", name="Auto Psychic Power",  flag="Run_PP"},
}

for _, def in ipairs(matrixDefs) do
    local id = def.id
    Toggles[id] = AutoTab:CreateToggle({
        Name         = def.name,
        CurrentValue = false,
        Flag         = def.flag,
        Callback     = function(v)
            if _G.Settings.AutoSathQuest then
                if setToggleVisual then setToggleVisual(id, false) end
                if v then disableSathQuestFromTraining() end
                return
            end
            _G.Settings[keyMap[id]] = v
            if id == "PP" and not v then
                ppTeleported = false
                unequipAllTools()
            end
            cascade(id)
        end,
    })
end

AutoTab:CreateSection("Anti-AFK")
Toggles["AA"] = AutoTab:CreateToggle({
    Name         = "Anti-AFK",
    CurrentValue = true,
    Flag         = "Run_AA",
    Callback     = function(v)
        _G.Settings.AntiAfk = v
    end,
})

AutoTab:CreateSection("Death Grinding")
Toggles["DG"] = AutoTab:CreateToggle({
    Name         = "Death Grinding (BT)",
    CurrentValue = false,
    Flag         = "Run_DG",
    Callback     = function(v)
        if _G.Settings.AutoSathQuest then
            if setToggleVisual then setToggleVisual("DG", false) end
            if v then disableSathQuestFromTraining() end
            return
        end
        if v and not Z.canDeathGrind(_G.RawStats.BT) then
            Rayfield:Notify({
                Title = "Death Grinding",
                Content = "Needs 20+ Body Toughness first.",
                Duration = 4,
                Image = "alert-circle",
            })
            if Toggles.DG then Toggles.DG:Set(false) end
            return
        end
        _G.Settings.DeathGrinding = v
        cascade("DG")
    end,
})

AutoTab:CreateSection("Quest Auto-Claim")
Toggles["AQ"] = AutoTab:CreateToggle({
    Name         = "Auto Quest Claim",
    CurrentValue = false,
    Flag         = "Run_AQ",
    Callback     = function(v)
        _G.Settings.AutoQuest = v
    end,
})

AutoTab:CreateSection("Sath Quest")
local SathQuestInfo = AutoTab:CreateLabel("—", 2197020684)

task.spawn(function()
    while task.wait(1) do
        SathQuestInfo:Set(buildSathInfoText())
    end
end)

Toggles["SQ"] = AutoTab:CreateToggle({
    Name         = "Auto Complete Sath Quest",
    CurrentValue = false,
    Flag         = "Run_SQ",
    Callback     = function(v)
        _G.Settings.AutoSathQuest = v
        if v then
            pauseConflictingFarms()
            if needsQuestPickupFromSath() then
                syncFarmToggles()
            else
                local tasks = scanMainQuestUI()
                if tasks and #tasks > 0 then
                    applySathFarmPhase(enrichTasksFromQuestDef(tasks))
                else
                    syncFarmToggles()
                end
            end
        else
            restoreConflictingFarms()
            syncFarmToggles()
        end
    end,
})

local function tp(pos)
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then root.CFrame = CFrame.new(pos) end
end

local lastSection = ""
for _, t in ipairs(Z.Teleports) do
    if t.section ~= lastSection then
        NavTab:CreateSection(t.section)
        lastSection = t.section
    end
    local pos = t.pos
    NavTab:CreateButton({ Name=t.name, Callback=function() tp(pos) end })
end

EquipTab:CreateSection("Leg Weights")

local weightLock = false

local function setWeight(level, fromId)
    if weightLock or sathWeightLock then return end
    if _G.Settings.AutoSathQuest then return end
    weightLock = true

    for i = 1, 4 do
        local wid = "W"..i
        if i ~= level and Toggles[wid] then
            Toggles[wid]:Set(false)
        end
    end

    if level > 0 then
        _G.Settings.ActiveWeight = level
        Remote:FireServer({[1]="EquipWeight_Request", [2]=level})
    else
        _G.Settings.ActiveWeight = 0
        Remote:FireServer({[1]="EquipWeight_Request", [2]=0})
    end

    weightLock = false
end

setSathEquipWeight = function(level)
    if not Toggles then return end
    sathWeightLock = true
    level = level or 0

    for i = 1, 4 do
        local wid = "W" .. i
        if Toggles[wid] then
            Toggles[wid]:Set(i == level)
        end
    end

    _G.Settings.ActiveWeight = level
    Remote:FireServer({[1] = "EquipWeight_Request", [2] = level})
    sathWeightLock = false
end

setTrainingUiLocked = function(locked)
    if not Toggles then return end

    local function lockGuiTree(root, on)
        if typeof(root) ~= "Instance" then return end
        if root:IsA("GuiObject") then
            root.Interactable = not on
        end
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("GuiObject") then
                d.Interactable = not on
            end
        end
    end

    local function lockOne(tog, keepValue, toggleId)
        if not tog then return end
        if not keepValue then
            if toggleId and setToggleVisual and locked then
                setToggleVisual(toggleId, false)
            else
                pcall(function() tog:Set(false) end)
            end
        end
        if tog.Lock then
            pcall(function() tog:Lock(locked) end)
        end
        if tog.SetInteraction then
            pcall(function() tog:SetInteraction(not locked) end)
        end
        if tog.SetLocked then
            pcall(function() tog:SetLocked(locked) end)
        end
        local root
        for _, key in ipairs({ "Toggle", "ToggleFrame", "Object", "Container", "Frame", "Holder" }) do
            if typeof(tog[key]) == "Instance" then
                root = tog[key]
                break
            end
        end
        lockGuiTree(root, locked)
    end

    for _, id in ipairs({ "FS", "BT", "MS", "JF", "PP", "DG" }) do
        lockOne(Toggles[id], false, id)
    end
    for i = 1, 4 do
        lockOne(Toggles["W" .. i], true, "W" .. i)
    end
end

for i = 1, 4 do
    local level = i
    local wname = ""
    if i == 1 then wname = "(100 LB)"
    elseif i == 2 then wname = "(1 TON)"
    elseif i == 3 then wname = "(10 TON)"
    elseif i == 4 then wname = "(100 TON)"
    end
    local wid = "W"..i
    Toggles[wid] = EquipTab:CreateToggle({
        Name         = "Weight Tier " .. i.." "..wname,
        CurrentValue = false,
        Flag         = "Run_W"..i,
        Callback     = function(v)
            if _G.Settings.AutoSathQuest or sathWeightLock then
                if _G.Settings.AutoSathQuest and v then
                    local aw = _G.Settings.ActiveWeight or 0
                    for j = 1, 4 do
                        if setToggleVisual then
                            setToggleVisual("W" .. j, j == aw)
                        elseif Toggles["W" .. j] then
                            Toggles["W" .. j]:Set(j == aw)
                        end
                    end
                end
                return
            end
            if v then
                setWeight(level, wid)
            else
                if _G.Settings.ActiveWeight == level then
                    setWeight(0, wid)
                end
            end
        end,
    })
end

-- Lock training/weight UI if Sath was saved as on (e.g. config load)
if _G.Settings.AutoSathQuest and setTrainingUiLocked then
    setTrainingUiLocked(true)
end

UtilTab:CreateSection("Respawn")
Toggles["IR"] = UtilTab:CreateToggle({
    Name         = "Instant Respawn",
    CurrentValue = false,
    Flag         = "Run_IR",
    Callback     = function(v) _G.Settings.InstantRespawn = v end,
})
UtilTab:CreateSection("Manual")
UtilTab:CreateButton({
    Name     = "Respawn Here",
    Callback = function() doRespawn() end,
})

ThemeTab:CreateSection("Preset Themes")

local themePresets = {
    { name = "Default",    id = "Default"   },
    { name = "Amber Glow", id = "AmberGlow" },
    { name = "Amethyst",   id = "Amethyst"  },
    { name = "Bloom",      id = "Bloom"     },
    { name = "Dark Blue",  id = "DarkBlue"  },
    { name = "Green",      id = "Green"     },
    { name = "Light",      id = "Light"     },
    { name = "Ocean",      id = "Ocean"     },
    { name = "Serenity",   id = "Serenity"  },
}

for _, preset in ipairs(themePresets) do
    local themeId = preset.id
    ThemeTab:CreateButton({
        Name     = preset.name,
        Callback = function()
            Window.ModifyTheme(themeId)
            Rayfield:Notify({
                Title    = "Theme Changed",
                Content  = preset.name .. " theme applied.",
                Duration = 2,
                Image    = "palette",
            })
        end,
    })
end

local PlayersTab = Window:CreateTab("Players", "users")

PlayersTab:CreateSection("ESP")
Toggles["ESP"] = PlayersTab:CreateToggle({
    Name         = "Player ESP",
    CurrentValue = false,
    Flag         = "Run_ESP",
    Callback     = function(v)
        setPlayerEspEnabled(v)
    end,
})

PlayersTab:CreateSection("Kill Players")
PlayerDropdown = PlayersTab:CreateDropdown({
    Name            = "Targets",
    Options         = buildPlayerDropdownOptions(),
    CurrentOption   = { "All" },
    MultipleOptions = true,
    Flag            = "KillTargets",
    Callback        = function(options)
        currentKillSelection = options
    end,
})

PlayersTab:CreateButton({
    Name     = "Kill Target(s) With Fireball",
    Callback = function()
        task.spawn(runKillWithFireball)
    end,
})

PlayersTab:CreateSection("Normal Punch (C)")
Toggles["Punch"] = PlayersTab:CreateToggle({
    Name         = "Enable Punch On Keybind",
    CurrentValue = false,
    Flag         = "Run_Punch",
    Callback     = function(v)
        _G.Settings.AutoPunch = v
    end,
})

PlayersTab:CreateKeybind({
    Name         = "Punch Keybind",
    CurrentKeybind = "X",
    HoldToInteract = false,
    Flag         = "PunchKey",
    Callback     = function(state)
        if state == false then return end
        task.spawn(runKeybindPunch)
    end,
})

Players.PlayerAdded:Connect(function(plr)
    if plr == LP then return end
    task.defer(refreshPlayerDropdown)
    if espEnabled then
        task.defer(function()
            attachPlayerEsp(plr)
        end)
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    removePlayerEsp(plr)
    task.defer(refreshPlayerDropdown)
end)

task.defer(refreshPlayerDropdown)

Rayfield:LoadConfiguration()

if _G.Settings.PlayerEsp then
    if Toggles["ESP"] then
        Toggles["ESP"]:Set(true)
    else
        setPlayerEspEnabled(true)
    end
end
