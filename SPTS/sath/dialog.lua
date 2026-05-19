-- Handles everything related to physically talking to Sath:
-- teleporting to him, clicking through the dialog, and the top-level
-- tryAdvanceSathQuest function that the main loop calls.

local LP         = _G.LP
local Remote     = _G.Remote
local RepStorage = _G.RepStorage

-- Tries to grab the ClientRemoteController module so we can set
-- TouchingQuestPart, which is needed for the dialog to trigger.
local function getCRCModule()
    local ls  = LP.PlayerScripts:FindFirstChild("LocalScript")
    local mod = ls and ls:FindFirstChild("ClientRemoteController_Module")
    if mod then
        local ok, m = pcall(require, mod)
        if ok then return m end
    end
    return nil
end

-- Teleports the character next to Sath and marks TouchingQuestPart.
-- Returns false if Sath's position can't be found.
local function teleportToSath()
    local pos

    local sathPart = RepStorage:FindFirstChild("SathPart")
    if sathPart and sathPart:IsA("BasePart") then
        pos = sathPart.Position
    else
        local map  = workspace:FindFirstChild("Map")
        local sath = map
            and map:FindFirstChild("QuestNPC")
            and map.QuestNPC:FindFirstChild("Sathopian")
        local part = sath
            and (sath:FindFirstChild("UpperTorso") or sath:FindFirstChild("HumanoidRootPart"))
        if part then pos = part.Position end
    end

    if not pos then return false end

    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    -- Land slightly above him so we don't clip into geometry.
    root.CFrame = CFrame.new(pos + Vector3.new(0, 3.5, 0))
    task.wait(0.7)

    local crc = getCRCModule()
    if crc and crc.Storage then
        crc.Storage.TouchingQuestPart = true
    end

    return true
end

-- Clicks through the Sath dialog until the message frame closes.
-- Returns true when the conversation finished cleanly.
local function runSathDialog()
    if _G.sathDialogBusy then return false end
    _G.sathDialogBusy = true

    local gui = _G.guiUtils
    local sg  = gui.getScreenGui()
    if not sg then _G.sathDialogBusy = false; return false end

    local talkBtn  = sg:FindFirstChild("QuestTalkBtn")
    local msgFrame = sg:FindFirstChild("QuestMsgFrame")
    if not talkBtn or not msgFrame then
        _G.sathDialogBusy = false
        return false
    end

    teleportToSath()

    -- Make sure the NPC value is set so the game knows who we're talking to.
    local npcVal = talkBtn:FindFirstChild("Npc")
    if npcVal then npcVal.Value = "Sath" end

    -- Wait for the talk button to appear after the teleport.
    for _ = 1, 40 do
        if talkBtn.Visible then break end
        task.wait(0.25)
    end

    if not talkBtn.Visible then
        _G.sathDialogBusy = false
        return false
    end

    gui.fireGuiSignal(talkBtn)
    task.wait(0.9)

    -- Wait for the message frame to open.
    for _ = 1, 40 do
        if msgFrame.Visible then break end
        task.wait(0.25)
    end

    local page = msgFrame:FindFirstChild("Page") or msgFrame:WaitForChild("Page", 5)
    local btn  = gui.resolveClickable(
        msgFrame:FindFirstChild("Btn") or msgFrame:WaitForChild("Btn", 5)
    )

    -- Keep clicking Next until the dialog ends.
    for _ = 1, 80 do
        if not msgFrame.Visible then break end
        if page and page.Value <= 0 then break end
        if btn then gui.fireGuiSignal(btn) end
        task.wait(0.35)
    end

    local crc = getCRCModule()
    if crc and crc.Storage then
        crc.Storage.TouchingQuestPart = false
    end

    _G.sathDialogBusy = false
    return page and page.Value <= 0
end

-- Top-level function called by the Sath loop.
-- Handles both the "talk button already visible" fast path and the
-- "teleport and wait" slow path.
local function tryAdvanceSathQuest()
    if _G.sathDialogBusy then return false end

    local sg = _G.guiUtils.getScreenGui()
    if not sg then return false end

    -- Shared talk flow used by both paths below.
    local function runTalkFlow()
        _G.prepareForSathTalk()
        _G.pauseConflictingFarms()
        _G.unequipAllTools()

        local ok = runSathDialog()

        -- Don't call restoreConflictingFarms here — the farm loop will call
        -- applySathFarmPhase on the next tick and set the correct phase.
        -- Restoring here would bring back the old BT/FS toggles and break
        -- the tool switch that's supposed to happen after a stat is done.
        _G.sathFarmLock = false
        _G.syncFarmToggles()
        _G.sathTalkMode = false

        return ok
    end

    local talkBtn = sg:FindFirstChild("QuestTalkBtn")
    if talkBtn and talkBtn.Visible then
        return runTalkFlow()
    end

    -- Talk button isn't visible yet — teleport and wait for it.
    _G.prepareForSathTalk()
    teleportToSath()

    for _ = 1, 50 do
        -- Stop flying/meditating if we somehow ended up in that state.
        if (_G.isFlying and _G.isFlying()) or (_G.hasMeditateEquipped and _G.hasMeditateEquipped()) then
            if _G.stopFlyMode then _G.stopFlyMode() end
        end
        _G.unequipAllTools()

        talkBtn = sg:FindFirstChild("QuestTalkBtn")
        if talkBtn and talkBtn.Visible then
            return runTalkFlow()
        end

        task.wait(0.25)
    end

    -- Timed out waiting for the button.
    _G.sathTalkMode = false
    return false
end

_G.tryAdvanceSathQuest = tryAdvanceSathQuest
