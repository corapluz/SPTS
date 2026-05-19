-- Equipment tab: leg weight tier toggles.
-- Only one tier can be active at a time. Sath mode locks these and
-- manages them automatically through setSathEquipWeight.

local Tabs    = _G.Tabs
local Toggles = _G.Toggles
local Remote  = _G.Remote

local weightLock = false

local function setWeight(level)
    if weightLock or _G.sathWeightLock then return end
    if _G.Settings.AutoSathQuest then return end
    weightLock = true

    -- Turn off every other tier first.
    for i = 1, 4 do
        if i ~= level and Toggles["W" .. i] then
            Toggles["W" .. i]:Set(false)
        end
    end

    _G.Settings.ActiveWeight = level > 0 and level or 0
    Remote:FireServer({ [1] = "EquipWeight_Request", [2] = _G.Settings.ActiveWeight })

    weightLock = false
end

-- Called by the Sath farm phase to switch weights without triggering the
-- normal toggle callbacks.
_G.setSathEquipWeight = function(level)
    if not Toggles then return end
    _G.sathWeightLock = true
    level = level or 0

    for i = 1, 4 do
        if Toggles["W" .. i] then
            Toggles["W" .. i]:Set(i == level)
        end
    end

    _G.Settings.ActiveWeight = level
    Remote:FireServer({ [1] = "EquipWeight_Request", [2] = level })
    _G.sathWeightLock = false
end

Tabs.Equip:CreateSection("Leg Weights")

local weightNames = { "(100 LB)", "(1 TON)", "(10 TON)", "(100 TON)" }

for i = 1, 4 do
    local level = i
    local wid   = "W" .. i
    Toggles[wid] = Tabs.Equip:CreateToggle({
        Name         = "Weight Tier " .. i .. " " .. weightNames[i],
        CurrentValue = false,
        Flag         = "Run_W" .. i,
        Callback     = function(v)
            -- In Sath mode, snap back to whatever tier Sath set.
            if _G.cascadeLock then return end
            if _G.Settings.AutoSathQuest or _G.sathWeightLock then
                if _G.Settings.AutoSathQuest and v then
                    local aw = _G.Settings.ActiveWeight or 0
                    for j = 1, 4 do
                        if _G.setToggleVisual then
                            _G.setToggleVisual("W" .. j, j == aw)
                        elseif Toggles["W" .. j] then
                            Toggles["W" .. j]:Set(j == aw)
                        end
                    end
                end
                return
            end

            if v then
                setWeight(level)
            else
                if _G.Settings.ActiveWeight == level then
                    setWeight(0)
                end
            end
        end,
    })
end
