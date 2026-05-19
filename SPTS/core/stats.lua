-- Polls the in-game stat labels every 0.8 s and keeps _G.Stats / _G.RawStats fresh.
-- Other modules read from those globals instead of touching the UI themselves.

local Z = _G.Z

task.spawn(function()
    while true do
        local gui   = _G.LP:FindFirstChild("PlayerGui")
        local frame = gui
            and gui:FindFirstChild("ScreenGui")
            and gui.ScreenGui:FindFirstChild("MenuFrame")
            and gui.ScreenGui.MenuFrame:FindFirstChild("InfoFrame")

        if frame then
            -- Pull the value that comes after the colon in each label.
            local function txt(key)
                local obj = frame:FindFirstChild(key)
                return obj and obj.Text:match(":%s*(.+)") or "0"
            end

            local fs, bt, ms, jf, pp =
                txt("FSTxt"), txt("BTTxt"), txt("MSTxt"), txt("JFTxt"), txt("PPTxt")

            _G.RawStats.FS = Z.parseNum(fs); _G.Stats.FS = fs
            _G.RawStats.BT = Z.parseNum(bt); _G.Stats.BT = bt
            _G.RawStats.MS = Z.parseNum(ms); _G.Stats.MS = ms
            _G.RawStats.JF = Z.parseNum(jf); _G.Stats.JF = jf
            _G.RawStats.PP = Z.parseNum(pp); _G.Stats.PP = pp
        end

        task.wait(0.8)
    end
end)
