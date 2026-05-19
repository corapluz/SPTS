-- SPTS Loader UI
-- Cancel button, drop shadow tracking, blur, error display in status.

local TweenService = game:GetService("TweenService")
local Debris       = game:GetService("Debris")
local RunService   = game:GetService("RunService")
local Players      = game:GetService("Players")
local LP           = Players.LocalPlayer

local cancelled = false

-- ── Blur frame (loader size, behind main frame) ───────────────
-- Sits directly behind the loader at the same position/size.
-- Gives a frosted-glass feel without blurring the whole screen.

local Lighting = game:GetService("Lighting")
local blur = Instance.new("BlurEffect")
blur.Size   = 0
blur.Parent = Lighting
TweenService:Create(blur, TweenInfo.new(0.4), { Size = 12 }):Play()

local function removeBlur()
    TweenService:Create(blur, TweenInfo.new(0.3), { Size = 0 }):Play()
    task.delay(0.35, function() blur:Destroy() end)
end

-- ── Build UI ──────────────────────────────────────────────────

local UI = {}

UI.ScreenGui = Instance.new("ScreenGui")
UI.ScreenGui.Name           = "LoaderUI"
UI.ScreenGui.ResetOnSpawn   = false
UI.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
UI.ScreenGui.Parent         = LP:WaitForChild("PlayerGui")

-- Drop shadow (behind main frame, same ScreenGui)
UI.DropShadowHolder = Instance.new("Frame", UI.ScreenGui)
UI.DropShadowHolder.Name                = "DropShadowHolder"
UI.DropShadowHolder.ZIndex              = 0
UI.DropShadowHolder.BorderSizePixel     = 0
UI.DropShadowHolder.BackgroundTransparency = 1
UI.DropShadowHolder.AnchorPoint         = Vector2.new(0.5, 0.5)
UI.DropShadowHolder.Position            = UDim2.new(0.5, 0, 0.5, 0)
UI.DropShadowHolder.Size                = UDim2.new(0, 0, 0, 0)

UI.DropShadow = Instance.new("ImageLabel", UI.DropShadowHolder)
UI.DropShadow.Name                = "DropShadow"
UI.DropShadow.ZIndex              = 0
UI.DropShadow.BorderSizePixel     = 0
UI.DropShadow.BackgroundTransparency = 1
UI.DropShadow.AnchorPoint         = Vector2.new(0.5, 0.5)
UI.DropShadow.Position            = UDim2.new(0.5, 0, 0.5, 0)
UI.DropShadow.Size                = UDim2.new(1.1, 0, 1.2, 0)
UI.DropShadow.Image               = "rbxassetid://6014261993"
UI.DropShadow.ScaleType           = Enum.ScaleType.Slice
UI.DropShadow.SliceCenter         = Rect.new(49, 49, 450, 450)
UI.DropShadow.ImageTransparency   = 0.6
UI.DropShadow.ImageColor3         = Color3.fromRGB(0, 0, 0)

-- Main frame
UI.MainFrame = Instance.new("Frame", UI.ScreenGui)
UI.MainFrame.Name                = "MainFrame"
UI.MainFrame.ZIndex              = 2
UI.MainFrame.BorderSizePixel     = 0
UI.MainFrame.BackgroundColor3    = Color3.fromRGB(36, 36, 36)
UI.MainFrame.AnchorPoint         = Vector2.new(0.5, 0.5)
UI.MainFrame.ClipsDescendants    = true
UI.MainFrame.Position            = UDim2.new(0.5, 0, 0.5, 0)
UI.MainFrame.Size                = UDim2.new(0, 0, 0, 0)

Instance.new("UICorner", UI.MainFrame).CornerRadius = UDim.new(0, 12)

local mfGrad = Instance.new("UIGradient", UI.MainFrame)
mfGrad.Rotation = -90
mfGrad.Transparency = NumberSequence.new{
    NumberSequenceKeypoint.new(0, 0),
    NumberSequenceKeypoint.new(1, 0.125),
}
mfGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(128, 128, 128)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
}

local mfPad = Instance.new("UIPadding", UI.MainFrame)
mfPad.PaddingLeft  = UDim.new(0, 8)
mfPad.PaddingRight = UDim.new(0, 8)

-- Top title
UI.TopTitle = Instance.new("TextLabel", UI.MainFrame)
UI.TopTitle.Name                   = "TopTitle"
UI.TopTitle.BorderSizePixel        = 0
UI.TopTitle.BackgroundTransparency = 1
UI.TopTitle.Size                   = UDim2.new(1, 0, 0.15, 0)
UI.TopTitle.TextSize               = 27
UI.TopTitle.FontFace               = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Bold)
UI.TopTitle.TextColor3             = Color3.fromRGB(255, 255, 255)
UI.TopTitle.Text                   = "SPTS - Loader"

local divider = Instance.new("Frame", UI.TopTitle)
divider.Name             = "TopTitleDivider"
divider.BorderSizePixel  = 0
divider.BackgroundColor3 = Color3.fromRGB(74, 146, 219)
divider.Size             = UDim2.new(1, 0, 0, 1)
divider.Position         = UDim2.new(0, 0, 1, 0)

local divGrad = Instance.new("UIGradient", divider)
divGrad.Transparency = NumberSequence.new{
    NumberSequenceKeypoint.new(0,     1),
    NumberSequenceKeypoint.new(0.35,  1),
    NumberSequenceKeypoint.new(0.501, 0.5),
    NumberSequenceKeypoint.new(0.65,  1),
    NumberSequenceKeypoint.new(1,     1),
}

-- Loading bar container
UI.BarContainer = Instance.new("Frame", UI.MainFrame)
UI.BarContainer.Name                   = "LoadingBarContainer"
UI.BarContainer.BorderSizePixel        = 0
UI.BarContainer.BackgroundTransparency = 1
UI.BarContainer.Size                   = UDim2.new(1, 0, 0.434, 0)
UI.BarContainer.Position               = UDim2.new(0, 0, 0.15, 0)

local barContPad = Instance.new("UIPadding", UI.BarContainer)
barContPad.PaddingLeft  = UDim.new(0, 8)
barContPad.PaddingRight = UDim.new(0, 8)

UI.LoadingBar = Instance.new("Frame", UI.BarContainer)
UI.LoadingBar.Name             = "LoadingBar"
UI.LoadingBar.BorderSizePixel  = 0
UI.LoadingBar.BackgroundColor3 = Color3.fromRGB(51, 51, 51)
UI.LoadingBar.AnchorPoint      = Vector2.new(0.5, 0.5)
UI.LoadingBar.Size             = UDim2.new(1, 0, 0.4, 0)
UI.LoadingBar.Position         = UDim2.new(0.5, 0, 0.5, 0)

Instance.new("UICorner", UI.LoadingBar).CornerRadius = UDim.new(0, 4)
Instance.new("UIStroke", UI.LoadingBar).Color = Color3.fromRGB(23, 23, 23)

local lbGrad = Instance.new("UIGradient", UI.LoadingBar)
lbGrad.Rotation = -90
lbGrad.Transparency = NumberSequence.new{
    NumberSequenceKeypoint.new(0,     0.70625),
    NumberSequenceKeypoint.new(0.384, 0.175),
    NumberSequenceKeypoint.new(1,     0.65625),
}
lbGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(136, 136, 136)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
}

local lbPad = Instance.new("UIPadding", UI.LoadingBar)
lbPad.PaddingTop    = UDim.new(0, 1)
lbPad.PaddingBottom = UDim.new(0, 1)
lbPad.PaddingLeft   = UDim.new(0, 1)
lbPad.PaddingRight  = UDim.new(0, 1)

-- Orange fill bar (CanvasGroup)
UI.Bar = Instance.new("CanvasGroup", UI.LoadingBar)
UI.Bar.Name             = "Bar"
UI.Bar.BorderSizePixel  = 0
UI.Bar.BackgroundColor3 = Color3.fromRGB(74, 146, 219)
UI.Bar.Size             = UDim2.new(0, 0, 1, 0)

Instance.new("UICorner", UI.Bar).CornerRadius = UDim.new(0, 4)

UI.BubbleFrame = Instance.new("Frame", UI.Bar)
UI.BubbleFrame.Name                   = "Frame"
UI.BubbleFrame.BackgroundTransparency = 1
UI.BubbleFrame.ClipsDescendants       = true
UI.BubbleFrame.Size                   = UDim2.new(1, 0, 1, 0)
UI.BubbleFrame.BorderSizePixel        = 0

-- Status text
UI.StatusHolder = Instance.new("Frame", UI.MainFrame)
UI.StatusHolder.Name                   = "StatusBackgroundHolder"
UI.StatusHolder.BorderSizePixel        = 0
UI.StatusHolder.BackgroundTransparency = 1
UI.StatusHolder.AnchorPoint            = Vector2.new(0.5, 0)
UI.StatusHolder.Size                   = UDim2.new(0.7, 0, 0.2, 0)
UI.StatusHolder.Position               = UDim2.new(0.5, 0, 0.48, 0)

local statusBg = Instance.new("ImageLabel", UI.StatusHolder)
statusBg.ZIndex              = 0
statusBg.BorderSizePixel     = 0
statusBg.BackgroundTransparency = 1
statusBg.ImageTransparency   = 0.75
statusBg.Image               = "rbxassetid://15241223512"
statusBg.Size                = UDim2.new(1, 0, 1, 0)
Instance.new("UICorner", statusBg).CornerRadius = UDim.new(0, 25)

UI.Status = Instance.new("TextLabel", UI.StatusHolder)
UI.Status.Name                   = "Status"
UI.Status.BorderSizePixel        = 0
UI.Status.BackgroundTransparency = 1
UI.Status.Size                   = UDim2.new(1, 0, 1, 0)
UI.Status.TextSize               = 20
UI.Status.FontFace               = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.SemiBold)
UI.Status.TextColor3             = Color3.fromRGB(158, 158, 158)
UI.Status.RichText               = true
UI.Status.Text                   = "Initializing..."

-- Cancel button
UI.CancelHolder = Instance.new("Frame", UI.MainFrame)
UI.CancelHolder.Name                   = "CancelBackgroundHolder"
UI.CancelHolder.BorderSizePixel        = 0
UI.CancelHolder.BackgroundTransparency = 1
UI.CancelHolder.AnchorPoint            = Vector2.new(0.5, 0)
UI.CancelHolder.Size                   = UDim2.new(0.45, 0, 0.2, 0)
UI.CancelHolder.Position               = UDim2.new(0.5, 0, 0.7, 0)

local cancelBg = Instance.new("ImageLabel", UI.CancelHolder)
cancelBg.Name                = "Background"
cancelBg.ZIndex              = 0
cancelBg.BorderSizePixel     = 0
cancelBg.BackgroundTransparency = 1
cancelBg.ImageTransparency   = 0.79
cancelBg.ImageColor3         = Color3.fromRGB(36, 36, 36)
cancelBg.Image               = "rbxassetid://6805220123"
cancelBg.Size                = UDim2.new(1, 0, 1, 0)
Instance.new("UICorner", cancelBg).CornerRadius = UDim.new(0, 7)

UI.CancelBtn = Instance.new("TextButton", UI.CancelHolder)
UI.CancelBtn.Name                   = "Status"
UI.CancelBtn.Active                 = false
UI.CancelBtn.Selectable             = false
UI.CancelBtn.BorderSizePixel        = 0
UI.CancelBtn.BackgroundTransparency = 1
UI.CancelBtn.Size                   = UDim2.new(1, 0, 1, 0)
UI.CancelBtn.TextSize               = 20
UI.CancelBtn.FontFace               = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.SemiBold)
UI.CancelBtn.TextColor3             = Color3.fromRGB(158, 158, 158)
UI.CancelBtn.Text                   = "Cancel"

-- Cancel button interactions
UI.CancelBtn.MouseEnter:Connect(function()
    TweenService:Create(cancelBg, TweenInfo.new(0.15), {
        ImageColor3 = Color3.fromRGB(255, 255, 255)
    }):Play()
end)

UI.CancelBtn.MouseLeave:Connect(function()
    TweenService:Create(cancelBg, TweenInfo.new(0.15), {
        ImageColor3 = Color3.fromRGB(36, 36, 36)
    }):Play()
end)

UI.CancelBtn.MouseButton1Down:Connect(function()
    TweenService:Create(UI.CancelHolder, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0.42, 0, 0.18, 0)
    }):Play()
end)

UI.CancelBtn.MouseButton1Up:Connect(function()
    TweenService:Create(UI.CancelHolder, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0.45, 0, 0.2, 0)
    }):Play()
end)

UI.CancelBtn.MouseButton1Click:Connect(function()
    cancelled = true
    TweenService:Create(cancelBg, TweenInfo.new(0.15), {
        ImageColor3 = Color3.fromRGB(200, 60, 60)
    }):Play()
    -- Collapse the main frame inward
    TweenService:Create(UI.MainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0)
    }):Play()
    TweenService:Create(UI.DropShadowHolder, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0)
    }):Play()
    task.delay(0.4, function()
        removeBlur()
        UI.ScreenGui:Destroy()
    end)
end)

-- ── Drop shadow tracking ──────────────────────────────────────
-- Follows MainFrame size with a slight scale offset so it's always
-- a bit larger than the frame itself.

RunService.RenderStepped:Connect(function()
    if not UI.MainFrame or not UI.MainFrame.Parent then return end
    local s = UI.MainFrame.Size
    UI.DropShadowHolder.Size = UDim2.new(s.X.Scale + 0.004, s.X.Offset, s.Y.Scale + 0.008, s.Y.Offset)
end)

-- ── Bubble animation ──────────────────────────────────────────

local function getBarFill()
    return UI.Bar.Size.X.Scale
end

local function spawnBubble()
    local fill = getBarFill()
    if fill <= 0.01 then return end

    local travelTime = math.clamp(0.9 - fill * 0.55, 0.3, 0.9)
    local laneY      = math.random(20, 80) / 100
    local amplitude  = math.random(2, 4)
    local freq       = math.random(2, 4)
    local phase      = math.random() * math.pi * 2

    local holder = Instance.new("Frame")
    holder.Name                   = "BubbleHolder"
    holder.BackgroundTransparency = 1
    holder.Size                   = UDim2.new(0, 7, 0, 7)
    holder.Position               = UDim2.new(0, -10, laneY, -3)
    holder.Parent                 = UI.BubbleFrame

    local bubble = Instance.new("ImageLabel", holder)
    bubble.BackgroundTransparency = 1
    bubble.BorderSizePixel        = 0
    bubble.Size                   = UDim2.new(1, 0, 1, 0)
    bubble.Image                  = "rbxassetid://3113298346"
    bubble.ImageTransparency      = math.random(0, 30) / 100

    TweenService:Create(holder, TweenInfo.new(travelTime, Enum.EasingStyle.Linear), {
        Position = UDim2.new(1, 10, laneY, -3),
    }):Play()

    local conn
    local t0 = os.clock()
    conn = RunService.RenderStepped:Connect(function()
        if not holder or not holder.Parent then conn:Disconnect(); return end
        local elapsed = os.clock() - t0
        local drift   = math.sin(elapsed * freq + phase) * amplitude
        local p       = holder.Position
        holder.Position = UDim2.new(p.X.Scale, p.X.Offset, laneY, -3 + drift)
    end)

    Debris:AddItem(holder, travelTime + 0.15)
end

local function getSpawnRate()
    local fill = getBarFill()
    return math.clamp(0.18 - fill * 0.14, 0.04, 0.18)
end

task.spawn(function()
    while UI.ScreenGui and UI.ScreenGui.Parent do
        spawnBubble()
        task.wait(getSpawnRate())
    end
end)

-- ── Tween-in ──────────────────────────────────────────────────
-- X: 0.15 + 0.025 = 0.175  |  Y: 0.1 + 0.05 = 0.15

local TARGET_SIZE = UDim2.new(0.175, 0, 0.15, 0)

TweenService:Create(UI.MainFrame, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Size = TARGET_SIZE,
}):Play()

-- ── Rich text helpers ─────────────────────────────────────────

local function colored(text, r, g, b)
    return string.format('<font color="rgb(%d,%d,%d)">%s</font>', r, g, b, text)
end

local function white(t)  return colored(t, 230, 230, 230) end
local function gray(t)   return colored(t, 140, 140, 140) end
local function green(t)  return colored(t, 80,  220, 100) end
local function red(t)    return colored(t, 255, 90,  90)  end
local function orange(t) return colored(t, 255, 140, 40)  end
local function yellow(t) return colored(t, 255, 210, 60)  end

local function buildStatusText(label)
    -- Use ASCII symbols to avoid broken characters on some executors
    if label:find("supported") then
        local name = label:gsub("%s*%-%-%s*supported","")
        return green("[OK] ") .. white(name) .. gray(" - supported")
    elseif label:find("not available") or label:find("NOT") then
        local name = label:gsub("%s*%-%-%s*.*","")
        return red("[!!] ") .. white(name) .. yellow(" - not available")
    elseif label:find("ClientPlrData") and label:find("ready") and not label:find("not") then
        return green("[OK] ") .. white("ClientPlrData") .. gray(" - ready")
    elseif label:find("ClientPlrData") and (label:find("not ready") or label:find("still not")) then
        return yellow("[??] ") .. white("ClientPlrData") .. red(" - not ready")
    elseif label:find("[Ee]rror") or label:find("failed") then
        return red("[!!] ") .. white(label:gsub("[Ee]rror[: ]*",""):sub(1, 55))
    elseif label == "Ready!" then
        return green("[OK] ") .. white("All systems ") .. green("ready!")
    elseif label:find("Initializing") or label:find("modules") then
        return gray("Starting ") .. white("SPTS") .. gray("...")
    else
        return gray("Loading ") .. orange(label) .. gray("...")
    end
end

-- ── Public API ────────────────────────────────────────────────

local TOTAL_STEPS = 18
local currentStep = 0

local function setStatus(text)
    -- Run fade in a separate thread so step() doesn't block loading
    task.spawn(function()
        TweenService:Create(UI.Status, TweenInfo.new(0.08), { TextTransparency = 1 }):Play()
        task.wait(0.09)
        if UI.Status and UI.Status.Parent then
            UI.Status.Text = buildStatusText(text)
            TweenService:Create(UI.Status, TweenInfo.new(0.12), { TextTransparency = 0 }):Play()
        end
    end)
end

local function step(label)
    if cancelled then return end
    currentStep = math.min(currentStep + 1, TOTAL_STEPS)
    local pct = currentStep / TOTAL_STEPS

    TweenService:Create(UI.Bar, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(pct, 0, 1, 0),
    }):Play()

    setStatus(label)
end

local function finish()
    if cancelled then return end
    currentStep = TOTAL_STEPS

    TweenService:Create(UI.Bar, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(1, 0, 1, 0),
    }):Play()

    setStatus("Ready!")

    -- Wait for bar to actually reach 1
    local deadline = tick() + 3
    while tick() < deadline do
        if UI.Bar.Size.X.Scale >= 0.99 then break end
        task.wait(0.05)
    end

    task.wait(0.5)

    TweenService:Create(UI.MainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0),
    }):Play()
    TweenService:Create(UI.DropShadowHolder, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0),
    }):Play()

    task.wait(0.4)
    removeBlur()
    UI.ScreenGui:Destroy()
end

-- Shows an error in the status label instead of F9.
local function showError(msg)
    if UI.Status and UI.Status.Parent then
        UI.Status.TextTransparency = 0
        UI.Status.Text = buildStatusText("Error: " .. tostring(msg))
    end
end

_G.Loader = {
    step      = step,
    finish    = finish,
    status    = setStatus,
    error     = showError,
    cancelled = function() return cancelled end,
}
