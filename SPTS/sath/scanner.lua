-- Reads the MainQuestFrame UI and turns it into a structured task list.
-- Also handles enriching that list with data from quest_defs when the UI
-- only shows a subset of the actual targets (which happens sometimes).

local Z = _G.Z

-- Shorthand aliases set by quest_defs.lua and gui_utils.lua.
local function DEFS()        return _G.SATH_QUEST_DEFS  end
local function FLAG_LABELS() return _G.SATH_FLAG_LABELS end
local function guiUtils()    return _G.guiUtils          end

-- Tries to read the current quest number from ClientPlrData first.
-- That's more reliable than scraping the UI text.
local function getMainQuestNo()
    if _G.ClientPlrData
        and _G.ClientPlrData.QuestData
        and _G.ClientPlrData.QuestData.MainQuest
    then
        return _G.ClientPlrData.QuestData.MainQuest.No
    end
    return nil
end

-- Splits "1,234 / 5,678" style progress text into two numbers.
local function parseProgTxt(text)
    if not text or text == "" then return 0, 0 end
    local left, right = text:match("^%s*(.-)%s*/%s*(.+)%s*$")
    if not left then return 0, 0 end
    return Z.parseNum(left), Z.parseNum(right)
end

-- Maps a quest label string to the flag/key/isKill triple we use internally.
local function questTxtToMeta(questTxt)
    local t = string.lower(questTxt or "")
    if t:find("villain") or t:find("hero") or t:find("killed") then
        return nil, "KILLS", true
    end
    if t:find("fist")     then return "FistStrength",  "FS", false end
    if t:find("body")     then return "BodyToughness",  "BT", false end
    if t:find("movement") then return "MovementSpeed",  "MS", false end
    if t:find("jump")     then return "JumpForce",      "JF", false end
    if t:find("psychic")  then return "PsychicPower",   "PP", false end
    return nil, nil, false
end

-- Checks whether a scanned task matches a definition entry.
local function taskMatchesQuestDef(t, dt)
    if t.isKill then return dt.key == "KILLS" end
    return t.key == dt.key and t.target == dt.target
end

-- Figures out which quest number a task list belongs to by comparing signatures.
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
        local def    = DEFS()[id]
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
                    ok = false; break
                end
            end
            if ok then return id end
        end
    end

    -- Quest 13 has a kill task alongside PP, so handle that edge case.
    local hasKill, hasPP = false, false
    for _, t in ipairs(tasks) do
        if t.isKill      then hasKill = true end
        if t.key == "PP" then hasPP   = true end
    end
    if hasKill and hasPP then return 13 end

    return nil
end

-- Filters and sorts a raw task list to match the definition order.
local function normalizeQuestTasks(tasks)
    if not tasks or #tasks == 0 then return tasks end

    local no       = getMainQuestNo()
    local defToUse = (no and no > 0) and DEFS()[no] or nil

    if not defToUse then
        local qid = detectQuestId(tasks)
        defToUse  = qid and DEFS()[qid] or nil
    end

    if defToUse then
        local filtered = {}
        for _, t in ipairs(tasks) do
            for _, dt in ipairs(defToUse.tasks) do
                if taskMatchesQuestDef(t, dt) then
                    table.insert(filtered, t); break
                end
            end
        end
        table.sort(filtered, function(a, b) return (a.index or 0) < (b.index or 0) end)
        return filtered
    end

    -- No matching def found — just keep valid tasks in UI order.
    local filtered = {}
    for _, t in ipairs(tasks) do
        if t.isKill or (t.flag and t.target > 0) then
            table.insert(filtered, t)
        end
    end
    table.sort(filtered, function(a, b) return (a.index or 0) < (b.index or 0) end)
    return filtered
end

-- Reads up to 5 MaxFrame slots from the MainQuestFrame and returns a task list.
local function scanMainQuestUI()
    if getMainQuestNo() == 0 then return {} end

    local mqf = guiUtils().getMainQuestFrame()
    if not mqf then return nil end

    local tasks = {}
    for i = 1, 5 do
        local frame = mqf:FindFirstChild("MaxFrame" .. i)
        if frame and frame.Visible == true then
            local questLbl = frame:FindFirstChild("QuestTxt")
            local progLbl  = frame:FindFirstChild("ProgTxt")
            local claimBtn = frame:FindFirstChild("ClaimBtn")
            local qt = questLbl and questLbl.Text or ""
            local pt = progLbl  and progLbl.Text  or ""

            if qt ~= "" then
                local flag, key, isKill = questTxtToMeta(qt)
                if flag or isKill then
                    local cur, tgt = parseProgTxt(pt)
                    if tgt > 0 then
                        table.insert(tasks, {
                            index     = i,
                            questTxt  = qt,
                            progTxt   = pt,
                            current   = cur,
                            target    = tgt,
                            flag      = flag,
                            key       = key,
                            isKill    = isKill,
                            claimable = claimBtn and claimBtn.Visible == true,
                            complete  = cur >= tgt,
                        })
                    end
                end
            end
        end
    end

    return normalizeQuestTasks(tasks)
end

-- The UI sometimes only shows one row even when the quest has multiple targets.
-- This fills in the missing tasks using the definition so the farm loop always
-- has the full picture and respects the correct order.
local function enrichTasksFromQuestDef(tasks)
    if not tasks then return tasks end

    local no  = getMainQuestNo()
    local qid = (no and no > 0) and no or detectQuestId(tasks)
    if not qid or not DEFS()[qid] then return tasks end

    local byKey = {}
    for _, t in ipairs(tasks) do
        if t.key then byKey[t.key] = t end
    end

    local enriched = {}
    for _, dt in ipairs(DEFS()[qid].tasks) do
        if dt.farm == false or dt.key == "KILLS" then
            -- Kill tasks are never farmed; just carry them through if present.
            if byKey[dt.key] then table.insert(enriched, byKey[dt.key]) end
        else
            local raw = _G.RawStats[dt.key] or 0
            local t   = byKey[dt.key]
            if t then
                t.flag    = t.flag   or dt.flag
                t.target  = t.target or dt.target
                t.current = math.max(t.current or 0, raw)
                t.complete = t.complete or (t.current >= t.target)
                table.insert(enriched, t)
            else
                -- Task wasn't visible in the UI — synthesize it from the def.
                local raw2 = _G.RawStats[dt.key] or 0
                table.insert(enriched, {
                    key      = dt.key,
                    flag     = dt.flag,
                    target   = dt.target,
                    current  = raw2,
                    complete = raw2 >= dt.target,
                    isKill   = false,
                    questTxt = FLAG_LABELS()[dt.flag] or dt.flag,
                    progTxt  = tostring(raw2) .. " / " .. tostring(dt.target),
                })
            end
        end
    end

    return enriched
end

-- Returns true when the player has no active quest and needs to visit Sath.
local function needsQuestPickupFromSath()
    local no = getMainQuestNo()
    if no == 0 then return true end
    if no ~= nil and no > 0 then return false end
    local tasks = scanMainQuestUI()
    return not tasks or #tasks == 0
end

-- Reads the current chapter number, trying ClientPlrData first then UI text.
local function readMainQuestChapterFromUI()
    local no = getMainQuestNo()
    if no ~= nil then return no end

    local mqf = guiUtils().getMainQuestFrame()
    if mqf then
        for _, d in ipairs(mqf:GetDescendants()) do
            if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text then
                local cur = d.Text:match("(%d+)%s*/%s*13")
                if cur then return tonumber(cur) end
            end
        end
    end

    local sg   = guiUtils().getScreenGui()
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

-- Store in _G so farm.lua, dialog.lua, loop.lua, and training modules
-- can all call these without require().
_G.sathScanner = {
    getMainQuestNo             = getMainQuestNo,
    detectQuestId              = detectQuestId,
    scanMainQuestUI            = scanMainQuestUI,
    enrichTasksFromQuestDef    = enrichTasksFromQuestDef,
    needsQuestPickupFromSath   = needsQuestPickupFromSath,
    readMainQuestChapterFromUI = readMainQuestChapterFromUI,
}
