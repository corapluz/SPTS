-- Player ESP: highlights every other player with a colored outline and
-- shows their name + current HP in a billboard above their head.

local LP      = _G.LP
local Players = _G.Players

local espEnabled = false
local espObjects = {}  -- keyed by Player instance

local function getRoot(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("Torso")
        or char.PrimaryPart
end

local function formatPlayerLabel(plr)
    return string.format("%s (@%s)", plr.DisplayName, plr.Name)
end

local function updateEspHealthLabel(pack, hum)
    if not pack or not pack.hpLbl or not hum then return end
    pack.hpLbl.Text = string.format(
        "%d / %d HP",
        math.floor(hum.Health + 0.5),
        math.floor(hum.MaxHealth + 0.5)
    )
end

local function removePlayerEsp(plr)
    local pack = espObjects[plr]
    if not pack then return end

    if pack.conns then
        for _, c in ipairs(pack.conns) do pcall(function() c:Disconnect() end) end
    end
    if pack.charConn then pcall(function() pack.charConn:Disconnect() end) end
    if pack.highlight and pack.highlight.Parent then pack.highlight:Destroy() end
    if pack.gui       and pack.gui.Parent       then pack.gui:Destroy()       end

    espObjects[plr] = nil
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

        -- Clean up any leftover ESP from the previous character.
        if pack.highlight and pack.highlight.Parent then pack.highlight:Destroy() end
        if pack.gui       and pack.gui.Parent       then pack.gui:Destroy()       end
        if pack.conns then
            for _, c in ipairs(pack.conns) do pcall(function() c:Disconnect() end) end
        end
        pack.conns = {}

        local hum  = char:WaitForChild("Humanoid", 8)
        local head = char:FindFirstChild("Head") or getRoot(char)
        if not hum or not head then return end

        -- Red highlight visible through walls.
        local hl = Instance.new("Highlight")
        hl.Name               = "SPTS_ESP"
        hl.Adornee            = char
        hl.FillColor          = Color3.fromRGB(220, 60, 80)
        hl.FillTransparency   = 0.55
        hl.OutlineColor       = Color3.fromRGB(255, 255, 255)
        hl.OutlineTransparency = 0.15
        pcall(function() hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop end)
        hl.Parent = char
        pack.highlight = hl

        -- Billboard with name + HP.
        local bb = Instance.new("BillboardGui")
        bb.Name         = "SPTS_ESP_Label"
        bb.Adornee      = head
        bb.Size         = UDim2.fromOffset(220, 56)
        bb.StudsOffset  = Vector3.new(0, 2.8, 0)
        bb.AlwaysOnTop  = true
        bb.MaxDistance  = 10000
        bb.Parent       = head
        pack.gui = bb

        local nameLbl = Instance.new("TextLabel")
        nameLbl.BackgroundTransparency = 1
        nameLbl.Size                   = UDim2.new(1, 0, 0.55, 0)
        nameLbl.Font                   = Enum.Font.GothamBold
        nameLbl.TextScaled             = true
        nameLbl.TextColor3             = Color3.fromRGB(255, 255, 255)
        nameLbl.TextStrokeTransparency = 0.4
        nameLbl.Text                   = formatPlayerLabel(plr)
        nameLbl.Parent                 = bb

        local hpLbl = Instance.new("TextLabel")
        hpLbl.BackgroundTransparency = 1
        hpLbl.Position               = UDim2.new(0, 0, 0.55, 0)
        hpLbl.Size                   = UDim2.new(1, 0, 0.45, 0)
        hpLbl.Font                   = Enum.Font.Gotham
        hpLbl.TextScaled             = true
        hpLbl.TextColor3             = Color3.fromRGB(180, 255, 180)
        hpLbl.TextStrokeTransparency = 0.5
        hpLbl.Parent                 = bb
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
    if plr.Character then task.spawn(onCharacter, plr.Character) end
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

_G.espModule = {
    attachPlayerEsp     = attachPlayerEsp,
    removePlayerEsp     = removePlayerEsp,
    setPlayerEspEnabled = setPlayerEspEnabled,
    formatPlayerLabel   = formatPlayerLabel,
}
