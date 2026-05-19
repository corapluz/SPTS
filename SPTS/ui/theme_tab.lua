-- Themes tab: one button per preset that calls Window.ModifyTheme.

local Tabs     = _G.Tabs
local Rayfield = _G.Rayfield
local Window   = _G.RayfieldWindow

local presets = {
    { name = "Default",    id = "Default"   },
    { name = "Amber Glow", id = "AmberGlow" },
    { name = "Amethyst",   id = "Amethyst"  },
    { name = "Bloom",      id = "Bloom"     },
    { name = "Dark Blue",  id = "DarkBlue"  },
    { name = "Green",      id = "Green"     },
    { name = "Light",      id = "Light"     },
    { name = "Ocean",      id = "Ocean"     },
    { name = "Serenity",   id = "Serenity"  },
}

Tabs.Theme:CreateSection("Preset Themes")

for _, preset in ipairs(presets) do
    local themeId = preset.id
    Tabs.Theme:CreateButton({
        Name     = preset.name,
        Callback = function()
            Window.ModifyTheme(themeId)
            Rayfield:Notify({
                Title    = "Theme Changed",
                Content  = preset.name .. " theme applied.",
                Duration = 2,
                Image    = "palette",
            })
        end,
    })
end
