-- Handles everything related to physically talking to Sath:
-- teleporting to him, clicking through the dialog, and the top-level
-- tryAdvanceSathQuest function that the main loop calls.

local LP         = _G.LP
local Remote     = _G.Remote
local RepStorage = _G.RepStorage

-- Finds the ClientRemoteController_Module by searching all LocalScripts
-- under PlayerScripts, not just the first one.
local function getCRCModule()
    for _, obj in ipairs(LP.PlayerScripts:GetDescendants()) do
        if obj.Name == "ClientRemoteController_Module" and obj:IsA("ModuleScript") then
            local ok, m = pcall(require, obj)
            if ok and m then return m end
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
-- Temporarily raises ZIndex so nothing blocks the click.
local function clickBtnVIM(btn)
    if not btn then return end
    pcall(function()
        local sg = btn:FindFirstAncestorOfClass("ScreenGui")
        local oldBtnZ = btn.ZIndex
        local oldSgZ  = sg and sg.ZIndexBehavior

        -- Bring button to front so nothing intercepts the click
        btn.ZIndex = 9999
        if sg then sg.ZIndexBehavior = Enum.ZIndexBehavior.Global end

        local pos   = btn.AbsolutePosition
        local size  = btn.AbsoluteSize
        local inset = game:GetService("GuiService"):GetGuiInset()
        local x = pos.X + size.X * 0.5 + inset.X
        local y = pos.Y + size.Y * 0.5 + inset.Y
        local vim = game:GetService("VirtualInputManager")
        vim:SendMouseButtonEvent(x, y, 0, true,  game, 0)
        task.wait(0.1)
        vim:SendMouseButtonEvent(x, y, 0, false, game, 0)

        -- Restore original ZIndex after click
        task.wait(0.05)
        btn.ZIndex = oldBtnZ
        if sg and oldSgZ then sg.ZIndexBehavior = oldSgZ end
    end)
end

-- Presses Space via VirtualInputManager to advance dialog pages.
local function pressSpaceVIM()
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true,  Enum.KeyCode.Space, false, game)
        task.wait(0.05)
        vim:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
    end)
end

-- Fires a button: firesignal(Activated) → getconnections(Activated) → VIM click.
local function clickBtn(btn)
    if not btn then return end
    local caps = _G.ExploitCaps or {}

    -- Method 1: firesignal on Activated
    if caps.firesignal and firesignal then
        local ok, sig = pcall(function() return btn.Activated end)
        if ok and sig then
            if pcall(firesignal, sig) then return end
        end
    end

    -- Method 2: getconnections on Activated
    if caps.getconnections and getconnections then
        local ok, sig = pcall(function() return btn.Activated end)
        if ok and sig then
            local ok2, conns = pcall(getconnections, sig)
            if ok2 and conns then
                for _, c in pairs(conns) do
                    if c.Enabled then pcall(function() c:Fire() end) end
                end
                return
            end
        end
    end

    -- Method 3: VIM click with ZIndex boost
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
    -- Wait for the tween to finish: position stabilizes when it stops changing.
    local lastY = -999
    local stableCount = 0
    local settleDeadline = tick() + 4
    while tick() < settleDeadline do
        local currentY = talkBtn.AbsolutePosition.Y
        if math.abs(currentY - lastY) < 0.5 then
            stableCount = stableCount + 1
            if stableCount >= 3 then break end
        else
            stableCount = 0
        end
        lastY = currentY
        task.wait(0.05)
    end
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
        if page and page.Value == 0 then break end
        if btn then clickBtn(btn) end
        -- Also press Space — works as a dialog advance on its own
        pressSpaceVIM()
        task.wait(0.15)
    end

    print("[SPTS] Dialog finished, page.Value = " .. tostring(page and page.Value))
    setTouchingQuestPart(false)

    _G.sathDialogBusy = false
    return not msgFrame.Visible or (page and page.Value == 0)
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
        local lastY, stable = -999, 0
        local d = tick() + 4
        while tick() < d do
            local y = talkBtn.AbsolutePosition.Y
            if math.abs(y - lastY) < 0.5 then stable = stable + 1; if stable >= 3 then break end
            else stable = 0 end
            lastY = y; task.wait(0.05)
        end
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
            local lastY, stable = -999, 0
            local d = tick() + 4
            while tick() < d do
                local y = talkBtn.AbsolutePosition.Y
                if math.abs(y - lastY) < 0.5 then stable = stable + 1; if stable >= 3 then break end
                else stable = 0 end
                lastY = y; task.wait(0.05)
            end
            return runTalkFlow()
        end

        task.wait(0.25)
    end

    warn("[SPTS] tryAdvanceSathQuest: timed out waiting for talk button")
    _G.sathTalkMode = false
    return false
end

_G.tryAdvanceSathQuest = tryAdvanceSathQuest
