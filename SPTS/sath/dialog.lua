-- Handles everything related to physically talking to Sath:
-- teleporting to him, clicking through the dialog, and the top-level
-- tryAdvanceSathQuest function that the main loop calls.

local LP         = _G.LP
local Remote     = _G.Remote
local RepStorage = _G.RepStorage

-- Finds the ClientRemoteController_Module by searching all LocalScripts
-- under PlayerScripts, not just the first one.
local function getCRCModule()
    for _, ls in ipairs(LP.PlayerScripts:GetChildren()) do
        if ls:IsA("LocalScript") then
            local mod = ls:FindFirstChild("ClientRemoteController_Module")
            if mod then
                local ok, m = pcall(require, mod)
                if ok and m then
                    return m
                end
            end
        end
    end
    return nil
end

-- Sets TouchingQuestPart on the CRC module if available.
-- This is what makes the QuestTalkBtn appear.
local function setTouchingQuestPart(value)
    local crc = getCRCModule()
    if crc and crc.Storage then
        crc.Storage.TouchingQuestPart = value
        print("[SPTS] TouchingQuestPart = " .. tostring(value))
    else
        warn("[SPTS] getCRCModule() failed — QuestTalkBtn may not appear")
    end
end

-- Teleports the character next to Sath and marks TouchingQuestPart.
local function teleportToSath()
    local pos

    local sathPart = RepStorage:FindFirstChild("SathPart")
    if sathPart and sathPart:IsA("BasePart") then
        pos = sathPart.Position
        print("[SPTS] Sath pos from SathPart: " .. tostring(pos))
    else
        local map  = workspace:FindFirstChild("Map")
        local sath = map
            and map:FindFirstChild("QuestNPC")
            and map.QuestNPC:FindFirstChild("Sathopian")
        local part = sath
            and (sath:FindFirstChild("UpperTorso") or sath:FindFirstChild("HumanoidRootPart"))
        if part then
            pos = part.Position
            print("[SPTS] Sath pos from model: " .. tostring(pos))
        end
    end

    if not pos then
        warn("[SPTS] teleportToSath: could not find Sath position")
        return false
    end

    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    root.CFrame = CFrame.new(pos + Vector3.new(0, 3.5, 0))
    task.wait(0.7)

    setTouchingQuestPart(true)
    return true
end

-- Clicks a button using VirtualInputManager at its center.
local function clickBtnVIM(btn)
    if not btn then return end
    pcall(function()
        local pos   = btn.AbsolutePosition
        local size  = btn.AbsoluteSize
        local inset = game:GetService("GuiService"):GetGuiInset()
        local x = pos.X + size.X * 0.5 + inset.X
        local y = pos.Y + size.Y * 0.5 + inset.Y
        local vim = game:GetService("VirtualInputManager")
        vim:SendMouseButtonEvent(x, y, 0, true,  game, 0)
        task.wait(0.1)
        vim:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
end

-- Fires a button using firesignal → getconnections → VirtualInputManager.
local function clickBtn(btn)
    if not btn then return end
    local caps = _G.ExploitCaps or {}

    if caps.firesignal and firesignal then
        local ok, sig = pcall(function() return btn.MouseButton1Click end)
        if ok and sig then
            if pcall(firesignal, sig) then return end
        end
    end

    if caps.getconnections and getconnections then
        local ok, sig = pcall(function() return btn.MouseButton1Click end)
        if ok and sig then
            local ok2, conns = pcall(getconnections, sig)
            if ok2 and conns and #conns > 0 then
                for _, c in ipairs(conns) do pcall(function() c:Fire() end) end
                return
            end
        end
    end

    -- Fallback: physical click via VirtualInputManager
    clickBtnVIM(btn)
end

-- Clicks through the Sath dialog until the message frame closes.
local function runSathDialog()
    if _G.sathDialogBusy then return false end
    _G.sathDialogBusy = true

    local sg = _G.guiUtils.getScreenGui()
    if not sg then
        warn("[SPTS] runSathDialog: no ScreenGui")
        _G.sathDialogBusy = false
        return false
    end

    local talkBtn  = sg:FindFirstChild("QuestTalkBtn")
    local msgFrame = sg:FindFirstChild("QuestMsgFrame")
    if not talkBtn or not msgFrame then
        warn("[SPTS] runSathDialog: QuestTalkBtn or QuestMsgFrame not found")
        _G.sathDialogBusy = false
        return false
    end

    teleportToSath()

    -- Set the NPC value so the game knows we're talking to Sath.
    local npcVal = talkBtn:FindFirstChild("Npc")
    if npcVal then
        npcVal.Value = "Sath"
        print("[SPTS] Npc value set to Sath")
    else
        warn("[SPTS] QuestTalkBtn has no Npc child")
    end

    -- Wait for the talk button to become visible.
    print("[SPTS] Waiting for QuestTalkBtn to become visible...")
    for _ = 1, 40 do
        if talkBtn.Visible then break end
        task.wait(0.25)
    end

    if not talkBtn.Visible then
        warn("[SPTS] QuestTalkBtn never became visible — aborting")
        _G.sathDialogBusy = false
        return false
    end

    print("[SPTS] QuestTalkBtn visible, waiting for tween to settle...")
    task.wait(0.6)  -- QuestTalkBtn tweens in from top, wait for it to land
    print("[SPTS] Clicking QuestTalkBtn at " .. tostring(talkBtn.AbsolutePosition))
    clickBtn(talkBtn)
    task.wait(0.9)

    -- Wait for the message frame to open.
    for _ = 1, 40 do
        if msgFrame.Visible then break end
        task.wait(0.25)
    end

    if not msgFrame.Visible then
        warn("[SPTS] QuestMsgFrame never opened")
        _G.sathDialogBusy = false
        return false
    end

    print("[SPTS] Dialog open, clicking through pages...")
    local page = msgFrame:FindFirstChild("Page") or msgFrame:WaitForChild("Page", 5)
    local btn  = _G.guiUtils.resolveClickable(
        msgFrame:FindFirstChild("Btn") or msgFrame:WaitForChild("Btn", 5)
    )

    for _ = 1, 80 do
        if not msgFrame.Visible then break end
        if page and page.Value <= 0 then break end
        if btn then clickBtn(btn) end
        task.wait(0.35)
    end

    print("[SPTS] Dialog finished, page.Value = " .. tostring(page and page.Value))
    setTouchingQuestPart(false)

    _G.sathDialogBusy = false
    return page and page.Value <= 0
end

-- Top-level function called by the Sath loop.
local function tryAdvanceSathQuest()
    if _G.sathDialogBusy then return false end

    local sg = _G.guiUtils.getScreenGui()
    if not sg then return false end

    local function runTalkFlow()
        _G.prepareForSathTalk()
        _G.pauseConflictingFarms()
        _G.unequipAllTools()

        local ok = runSathDialog()

        _G.sathFarmLock = false
        _G.syncFarmToggles()
        _G.sathTalkMode = false

        return ok
    end

    local talkBtn = sg:FindFirstChild("QuestTalkBtn")
    if talkBtn and talkBtn.Visible then
        print("[SPTS] tryAdvanceSathQuest: talk button already visible, waiting for tween...")
        task.wait(0.6)
        return runTalkFlow()
    end

    -- Teleport and wait for the button.
    print("[SPTS] tryAdvanceSathQuest: teleporting to Sath...")
    _G.prepareForSathTalk()
    teleportToSath()

    for _ = 1, 50 do
        if (_G.isFlying and _G.isFlying()) or (_G.hasMeditateEquipped and _G.hasMeditateEquipped()) then
            if _G.stopFlyMode then _G.stopFlyMode() end
        end
        _G.unequipAllTools()

        talkBtn = sg:FindFirstChild("QuestTalkBtn")
        if talkBtn and talkBtn.Visible then
            print("[SPTS] tryAdvanceSathQuest: talk button appeared, waiting for tween...")
            task.wait(0.6)
            return runTalkFlow()
        end

        task.wait(0.25)
    end

    warn("[SPTS] tryAdvanceSathQuest: timed out waiting for talk button")
    _G.sathTalkMode = false
    return false
end

_G.tryAdvanceSathQuest = tryAdvanceSathQuest
