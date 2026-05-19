-- Fist Strength training loop.
-- starter mode (quest 1-2): fire Add_FS_Request in place, no teleport.
-- rock mode (quest 3+): teleport to Rock Zone + equip Fist Training tool.
-- zone mode (quest 9+): teleport to Crystal/Star zones.

local Z      = _G.Z
local Remote = _G.Remote

-- Fires Add_FS_Request every 0.05 s regardless of mode.
-- In starter mode there's no zone to teleport to, but the remote still works.
task.spawn(function()
    while true do
        if _G.Settings.FistStrength and not _G.sathAutofarmBlocked() then
            Remote:FireServer({ [1] = "Add_FS_Request" })
        end
        task.wait(0.05)
    end
end)

-- Equips the right tool depending on the current chapter.
-- Starter: nothing to equip (Push Up is for BT, not FS).
-- Rock / zone: equip Fist Training tool.
task.spawn(function()
    while true do
        if _G.sathAutofarmBlocked() then
            task.wait(0.15)
            continue
        end

        if _G.sathAllowsToolFarm("FistStrength") then
            local chapter = _G.sathScanner.readMainQuestChapterFromUI()
            local fsMode  = Z.fsTrainingMode(chapter)

            if fsMode == "rock" or fsMode == "zone" then
                _G.equipZoneTool(Z.ZONE_TOOLS.FistStrength)
            end
            -- starter mode: no tool needed, Add_FS_Request handles it above.
        end

        task.wait(0.35)
    end
end)

-- Teleport loop: only active in rock/zone mode.
-- In starter mode the player stays in place.
task.spawn(function()
    while true do
        if _G.sathAutofarmBlocked() then
            task.wait(0.15)
            continue
        end

        if _G.Settings.FistStrength then
            local chapter = _G.sathScanner.readMainQuestChapterFromUI()
            local fsMode  = Z.fsTrainingMode(chapter)

            -- Don't teleport in starter mode — rock zone isn't unlocked yet.
            if fsMode ~= "starter" then
                local target = Z.farmTarget(
                    { BodyToughness = false, FistStrength = true, PsychicPower = false },
                    _G.RawStats,
                    chapter
                )
                if target then
                    local char = _G.LP.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if root and (root.Position - target).Magnitude > 8 then
                        root.CFrame = CFrame.new(target)
                    end
                end
            end
        end

        task.wait(0.1)
    end
end)
