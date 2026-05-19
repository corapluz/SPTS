-- Fist Strength training loop.
-- Handles starter (Push Up), Rock Zone, and Crystal/Star zones depending
-- on the current chapter. Uses Module.lua's fsTrainingMode to decide.

local Z      = _G.Z
local Remote = _G.Remote

-- Fires the server-side FS increment at a high rate when in a zone.
-- Skipped during Sath dialog and in starter mode (tool activation handles that).
task.spawn(function()
    while true do
        if _G.Settings.FistStrength and not _G.sathAutofarmBlocked() then
            local chapter = _G.sathScanner.readMainQuestChapterFromUI()
            if Z.fsTrainingMode(chapter) ~= "starter" then
                Remote:FireServer({ [1] = "Add_FS_Request" })
            end
        end
        task.wait(0.05)
    end
end)

-- Tool equip loop: runs at 0.35 s and picks the right tool for the current mode.
task.spawn(function()
    while true do
        if _G.sathAutofarmBlocked() then
            task.wait(0.15)
            continue
        end

        if _G.sathAllowsToolFarm("FistStrength") then
            local chapter = _G.sathScanner.readMainQuestChapterFromUI()
            local fsMode  = Z.fsTrainingMode(chapter)

            if fsMode == "starter" then
                -- Below Rock chapter — just use Push Up.
                _G.useStarterTraining("FistStrength")
            elseif fsMode == "rock" or fsMode == "zone" then
                -- Rock / Crystal / Star zones — equip the Fist Training tool.
                _G.equipZoneTool(Z.ZONE_TOOLS.FistStrength)
            end
        end

        task.wait(0.35)
    end
end)

-- Teleport loop: keeps the character at the right FS zone position.
task.spawn(function()
    while true do
        if _G.sathAutofarmBlocked() then
            task.wait(0.15)
            continue
        end

        if _G.Settings.FistStrength then
            local chapter = _G.sathScanner.readMainQuestChapterFromUI()
            local target  = Z.farmTarget(
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

        task.wait(0.1)
    end
end)
