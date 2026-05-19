-- Kill and punch helpers.
-- Fireball: teleports targets on top of the player, fires the skill, then restores them.
-- Punch: same bring-and-anchor trick but uses the C skill key instead.

local LP      = _G.LP
local Players = _G.Players

local killBusy = false

-- ── Target management ─────────────────────────────────────────

-- Exposed so the UI dropdown can update it.
_G.currentKillSelection = { "All" }
_G.playerByLabel        = {}

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
    _G.playerByLabel = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local label = formatPlayerLabel(plr)
            _G.playerByLabel[label] = plr
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

local function resolveKillTargets()
    local targets = {}
    local pickAll = false
    for _, opt in ipairs(_G.currentKillSelection) do
        if opt == "All" then pickAll = true; break end
    end

    if pickAll then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP then table.insert(targets, plr) end
        end
    else
        for _, opt in ipairs(_G.currentKillSelection) do
            local plr = _G.playerByLabel[opt]
            if plr and plr.Parent then table.insert(targets, plr) end
        end
    end
    return targets
end

-- ── Bring / anchor / restore ──────────────────────────────────

local function bringAndAnchorTargets(targets)
    local myRoot = getRoot(LP.Character)
    if not myRoot then return {}, nil end

    local saved   = {}
    local stackCF = myRoot.CFrame

    for _, plr in ipairs(targets) do
        local char = plr.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
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
            table.insert(saved, { root = root, cframe = savedCF })
        end
    end

    return saved, myRoot
end

local function restoreAnchored(saved)
    for _, entry in ipairs(saved) do
        local root = entry.root
        if root and root.Parent then
            root.Anchored = false
            root.CFrame   = entry.cframe
        end
    end
end

-- ── Skill key helpers ─────────────────────────────────────────

local function getSkillFrame()
    local sg   = _G.LP:FindFirstChild("PlayerGui") and _G.LP.PlayerGui:FindFirstChild("ScreenGui")
    local menu = sg and sg:FindFirstChild("MenuFrame")
    return menu and menu:FindFirstChild("SkillFrame")
end

local function getSkillDefaultKeyName(skillTxtName, txtBoxName)
    local skillFrame = getSkillFrame()
    if not skillFrame then return nil end
    local skillTxt = skillFrame:FindFirstChild(skillTxtName)
    local txtBox   = skillTxt and skillTxt:FindFirstChild(txtBoxName)
    local defKey   = txtBox and txtBox:FindFirstChild("DefaultKey")
    if defKey and defKey:IsA("StringValue") and defKey.Value ~= "" then
        return defKey.Value
    end
    return nil
end

local function pressSkillKey(keyName)
    if not keyName or keyName == "" then return false end
    local keyCode
    local ok = pcall(function() keyCode = Enum.KeyCode[keyName] end)
    if not ok or not keyCode then return false end
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true,  keyCode, false, game)
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

-- ── Kill actions ──────────────────────────────────────────────

local function runKillWithFireball()
    if killBusy then return end
    local targets = resolveKillTargets()
    if #targets == 0 then
        _G.Rayfield:Notify({ Title = "Kill", Content = "No targets selected.", Duration = 3, Image = "users" })
        return
    end

    killBusy = true
    pcall(function()
        local saved = bringAndAnchorTargets(targets)
        if #saved == 0 then
            _G.Rayfield:Notify({ Title = "Kill", Content = "Targets not available.", Duration = 3, Image = "users" })
            return
        end

        if not pressFireballSkill() then
            _G.Rayfield:Notify({
                Title   = "Kill",
                Content = "Fireball hotkey not found in SkillFrame.",
                Duration = 4,
                Image   = "alert-circle",
            })
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

_G.killModule = {
    buildPlayerDropdownOptions = buildPlayerDropdownOptions,
    runKillWithFireball         = runKillWithFireball,
    runKeybindPunch             = runKeybindPunch,
    formatPlayerLabel           = formatPlayerLabel,
}
