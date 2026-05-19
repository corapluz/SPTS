-- Movement Speed and Jump Force training loops.
-- Both stats fire server remotes on a timer. Weight equipping is handled
-- by the Sath farm phase logic in sath/farm.lua.

local Remote = _G.Remote

-- MS fires every 0.25 s.
task.spawn(function()
    while true do
        if _G.Settings.MovementSpeed and not _G.sathAutofarmBlocked() then
            Remote:FireServer({ [1] = "Add_MS_Request" })
        end
        task.wait(0.25)
    end
end)

-- JF fires every 0.25 s.
task.spawn(function()
    while true do
        if _G.Settings.JumpForce and not _G.sathAutofarmBlocked() then
            Remote:FireServer({ [1] = "Add_JF_Request" })
        end
        task.wait(0.25)
    end
end)

-- Re-equips the active weight tier every 3 s to keep it from falling off.
task.spawn(function()
    while true do
        local w = _G.Settings.ActiveWeight
        if w > 0 then
            Remote:FireServer({ [1] = "EquipWeight_Request", [2] = w })
        end
        task.wait(3)
    end
end)
