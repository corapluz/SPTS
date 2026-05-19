-- SPTS Loader UI
-- Tween-in from zero size, animated loading bar with bubbles,
-- status text fades out/in on each step update.

local TweenService = game:GetService("TweenService")
local Debris       = game:GetService("Debris")
local RunService   = game:GetService("RunService")
local Players      = game:GetService("Players")
local LP           = Players.LocalPlayer

-- ── Build UI ──────────────────────────────────────────────────

local UI = {}

UI.ScreenGui = Instance.new("ScreenGui")
UI.ScreenGui.Name            = "LoaderUI"
UI.ScreenGui.ResetOnSpawn    = false
UI.ScreenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
UI.ScreenGui.Parent          = LP:WaitForChild("PlayerGui")

UI.MainFrame = Instance.new("Frame", UI.ScreenGui)
UI.MainFrame.Name                = "MainFrame"
UI.MainFrame.BorderSizePixel     = 0
UI.MainFrame.BackgroundColor3    = Color3.fromRGB(36, 36, 36)
UI.MainFrame.AnchorPoint         = Vector2.new(0.5, 0.5)
UI.MainFrame.ClipsDescendants    = true
UI.MainFrame.Position            = UDim2.new(0.5, 0, 0.5, 0)
UI.MainFrame.Size                = UDim2.new(0, 0, 0, 0)  -- starts at zero

local corner = Instance.new("UICorner", UI.MainFrame)
corner.CornerRadius = UDim.new(0, 12)

local gradient = Instance.new("UIGradient", UI.MainFrame)
gradient.Rotation    = -90
gradient.Transparency = NumberSequence.new{
    NumberSequenceKeypoint.new(0, 0),
    NumberSequenceKeypoint.new(1, 0.125),
}
gradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(128, 128, 128)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
}

local padding = Instance.new("UIPadding", UI.MainFrame)
padding.PaddingLeft  = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)

-- Top title
UI.TopTitle = Instance.new("TextLabel", UI.MainFrame)
UI.TopTitle.Name                = "TopTitle"
UI.TopTitle.BorderSizePixel     = 0
UI.TopTitle.BackgroundTransparency = 1
UI.TopTitle.Size                = UDim2.new(1, 0, 0.15, 0)
UI.TopTitle.TextSize            = 27
UI.TopTitle.FontFace            = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Bold)
UI.TopTitle.TextColor3          = Color3.fromRGB(255, 255, 255)
UI.TopTitle.Text                = "SPTS - Loader"

local divider = Instance.new("Frame", UI.TopTitle)
divider.Name             = "TopTitleDivider"
divider.BorderSizePixel  = 0
divider.BackgroundColor3 = Color3.fromRGB(255, 102, 25)
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
UI.BarContainer.Name                = "LoadingBarContainer"
UI.BarContainer.BorderSizePixel     = 0
UI.BarContainer.BackgroundTransparency = 1
UI.BarContainer.Size                = UDim2.new(1, 0, 0.434, 0)
UI.BarContainer.Position            = UDim2.new(0, 0, 0.15, 0)

local barPad = Instance.new("UIPadding", UI.BarContainer)
barPad.PaddingLeft  = UDim.new(0, 8)
barPad.PaddingRight = UDim.new(0, 8)

UI.LoadingBar = Instance.new("Frame", UI.BarContainer)
UI.LoadingBar.Name             = "LoadingBar"
UI.LoadingBar.BorderSizePixel  = 0
UI.LoadingBar.BackgroundColor3 = Color3.fromRGB(51, 51, 51)
UI.LoadingBar.AnchorPoint      = Vector2.new(0.5, 0.5)
UI.LoadingBar.Size             = UDim2.new(1, 0, 0.4, 0)
UI.LoadingBar.Position         = UDim2.new(0.5, 0, 0.5, 0)

local lbCorner = Instance.new("UICorner", UI.LoadingBar)
lbCorner.CornerRadius = UDim.new(0, 4)

local lbStroke = Instance.new("UIStroke", UI.LoadingBar)
lbStroke.Color = Color3.fromRGB(23, 23, 23)

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

-- The orange fill bar
UI.Bar = Instance.new("CanvasGroup", UI.LoadingBar)
UI.Bar.Name             = "Bar"
UI.Bar.BorderSizePixel  = 0
UI.Bar.BackgroundColor3 = Color3.fromRGB(255, 102, 25)
UI.Bar.Size             = UDim2.new(0, 0, 1, 0)

local barCorner = Instance.new("UICorner", UI.Bar)
barCorner.CornerRadius = UDim.new(0, 4)

UI.BubbleFrame = Instance.new("Frame", UI.Bar)
UI.BubbleFrame.Name                = "Frame"
UI.BubbleFrame.BackgroundTransparency = 1
UI.BubbleFrame.ClipsDescendants    = true
UI.BubbleFrame.Size                = UDim2.new(1, 0, 1, 0)
UI.BubbleFrame.BorderSizePixel     = 0

-- Status text
UI.StatusHolder = Instance.new("Frame", UI.MainFrame)
UI.StatusHolder.Name                = "StatusBackgroundHolder"
UI.StatusHolder.BorderSizePixel     = 0
UI.StatusHolder.BackgroundTransparency = 1
UI.StatusHolder.AnchorPoint         = Vector2.new(0.5, 0)
UI.StatusHolder.Size                = UDim2.new(0.7, 0, 0.2, 0)
UI.StatusHolder.Position            = UDim2.new(0.5, 0, 0.6, 0)

local statusBg = Instance.new("ImageLabel", UI.StatusHolder)
statusBg.Name                = "Background"
statusBg.ZIndex              = 0
statusBg.BorderSizePixel     = 0
statusBg.BackgroundTransparency = 1
statusBg.ImageTransparency   = 0.75
statusBg.Image               = "rbxassetid://15241223512"
statusBg.Size                = UDim2.new(1, 0, 1, 0)
Instance.new("UICorner", statusBg).CornerRadius = UDim.new(0, 25)

UI.Status = Instance.new("TextLabel", UI.StatusHolder)
UI.Status.Name                = "Status"
UI.Status.BorderSizePixel     = 0
UI.Status.BackgroundTransparency = 1
UI.Status.Size                = UDim2.new(1, 0, 1, 0)
UI.Status.TextSize            = 20
UI.Status.FontFace            = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.SemiBold)
UI.Status.TextColor3          = Color3.fromRGB(158, 158, 158)
UI.Status.Text                = "Initializing..."

-- ── Bubble animation ──────────────────────────────────────────

local BUBBLE_SPEED = 0.5

local function spawnBubble()
    local randomY    = math.random(15, 85) / 100
    local holder     = Instance.new("Frame")
    holder.Name                = "BubbleHolder"
    holder.BackgroundTransparency = 1
    holder.Size                = UDim2.new(0, 8, 0, 8)
    holder.Position            = UDim2.new(0, -20, randomY, -4)
    holder.Parent              = UI.BubbleFrame

    local bubble = Instance.new("ImageLabel", holder)
    bubble.BackgroundTransparency = 1
    bubble.BorderSizePixel     = 0
    bubble.Size                = UDim2.new(0, 8, 0, 8)
    bubble.Image               = "rbxassetid://3113298346"

    local mainFreq   = math.random(5, 8)
    local phase      = math.random() * math.pi * 2
    local fastFreq   = math.pi
    local tween      = TweenService:Create(holder, TweenInfo.new(BUBBLE_SPEED, Enum.EasingStyle.Linear), {
        Position = UDim2.new(1, 15, randomY, -4),
    })
    tween:Play()

    local conn
    local t0 = os.clock()
    conn = RunService.RenderStepped:Connect(function()
        if not holder or not holder.Parent then conn:Disconnect(); return end
        local elapsed = os.clock() - t0
        local sx = holder.Position.X.Scale
        local ox = holder.Position.X.Offset
        local wave  = (ox >= 0 or sx > 0) and math.sin((elapsed * mainFreq) + phase) * 5 or 0
        local micro = (ox >= 0 or sx > 0) and math.sin(elapsed * fastFreq) * 2 or 0
        holder.Position  = UDim2.new(sx, ox, randomY, -4 + wave)
        bubble.Position  = UDim2.new(0, 0, 0, micro)
    end)

    Debris:AddItem(holder, BUBBLE_SPEED + 0.1)
end

local function getDynamicSpawnRate()
    local sx = UI.Bar.Size.X.Scale
    local ox = UI.Bar.Size.X.Offset
    return (sx >= 0.95 or (sx == 0 and ox > 300)) and 0.02 or 0.09
end

task.spawn(function()
    while UI.ScreenGui and UI.ScreenGui.Parent do
        spawnBubble()
        task.wait(getDynamicSpawnRate())
    end
end)

-- ── Tween-in on open ──────────────────────────────────────────

TweenService:Create(UI.MainFrame, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Size = UDim2.new(0.25, 0, 0.2, 0),
}):Play()

-- ── Public API ────────────────────────────────────────────────

local TOTAL_STEPS = 18
local currentStep = 0

-- Updates the status text with a fade out/in transition.
local function setStatus(text)
    TweenService:Create(UI.Status, TweenInfo.new(0.1), { TextTransparency = 1 }):Play()
    task.wait(0.12)
    UI.Status.Text = text
    TweenService:Create(UI.Status, TweenInfo.new(0.15), { TextTransparency = 0 }):Play()
end

-- Advances the loading bar by one step and updates the status label.
local function step(label)
    currentStep = math.min(currentStep + 1, TOTAL_STEPS)
    local pct = currentStep / TOTAL_STEPS

    TweenService:Create(UI.Bar, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(pct, 0, 1, 0),
    }):Play()

    setStatus(label)
end

-- Call when everything is loaded — fills bar to 100% and closes the UI.
local function finish()
    currentStep = TOTAL_STEPS
    TweenService:Create(UI.Bar, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(1, 0, 1, 0),
    }):Play()
    setStatus("Ready!")
    task.wait(0.8)
    TweenService:Create(UI.MainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0),
    }):Play()
    task.wait(0.4)
    UI.ScreenGui:Destroy()
end

-- Expose globally so main.lua can call _G.Loader.step() and _G.Loader.finish()
_G.Loader = {
    step   = step,
    finish = finish,
    status = setStatus,
}
