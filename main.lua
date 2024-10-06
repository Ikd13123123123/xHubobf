local validPlaceIds = { 12552538292, }
local foundGame = false

local linoriaLib = "https://raw.githubusercontent.com/mstudio45/LinoriaLib/main/"
local addons = linoriaLib .. "addons/"

loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/MS-ESP/refs/heads/main/source.lua"))()
loadstring(game:HttpGet(linoriaLib .. 'Library.lua'))()
getgenv().ThemeManager = loadstring(game:HttpGet(addons .. 'ThemeManager.lua'))()
getgenv().SaveManager = loadstring(game:HttpGet(addons .. 'SaveManager.lua'))()

local library = getgenv().Library

getgenv().Alert = function(message, time)
    library:Notify("[xHub] " .. message, time or 5, "rbxassetid://4590662766")
end

local placesRepo = "https://raw.githubusercontent.com/xBackpack/xHub/refs/heads/main/places/"

for _, id in ipairs(validPlaceIds) do
    if game.PlaceId == id then
        loadstring(game:HttpGet(placesRepo .. game.PlaceId .. ".lua"))()
        foundGame = true
        break
    end
end

if not foundGame then
    getgenv().Alert("The place you are currently in is not valid. Please look at our github for a list of valid games!")
    getgenv().Alert = nil
    task.wait(5)
    library:Unload()
end
