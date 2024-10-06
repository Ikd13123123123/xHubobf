--// SETUP \\--
local library = getgenv().Library

if not getgenv().xhub_loaded then
    getgenv().xhub_loaded = true
else
    library:Notify("[xHub] Already Loaded!")
    return
end

--// SERVICES \\--
local workspace = game:GetService("Workspace")
local lighting = game:GetService("Lighting")
local players = game:GetService("Players")
local repStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local proximityPromptService = game:GetService("ProximityPromptService")

local rooms = workspace:WaitForChild("Rooms")
local monsters = workspace:WaitForChild("Monsters")
local characters = workspace:WaitForChild("Characters")
local events = repStorage:WaitForChild("Events")
local blur = lighting:WaitForChild("Blur")
local depthOfField = lighting:WaitForChild("DepthOfField")

local ESPLib = getgenv().mstudio45.ESPLibrary
local themes = getgenv().ThemeManager
local saves = getgenv().SaveManager
local options = getgenv().Linoria.Options
local toggles = getgenv().Linoria.Toggles

ESPLib:SetPrefix("xHub")
ESPLib:SetIsLoggingEnabled(true)
ESPLib:SetDebugEnabled(true)

local player = players.LocalPlayer
local playerGui = player.PlayerGui
local camera = workspace.CurrentCamera

if not player.Character then player.CharacterAdded:Wait() end

local nodeMonsters = {
    "Angler",
    "Froger",
    "Pinkie",
    "Chainsmoker",
    "Blitz",
    "RidgeAngler",
    "RidgeFroger",
    "RidgePinkie",
    "RidgeChainsmoker",
    "RidgeBlitz"
}

local currentRoomStuff = {
    Connections = {},
    ESP = {}
}

local activeConnections = {
    FurthestRoom = {}
}

local function _ESP(properties)
    local esp = ESPLib.ESP.Highlight({
        Name = properties.Name or "No Text",
        Model = properties.Model,
        FillColor = properties.FillColor,
        OutlineColor = properties.OutlineColor,
        TextColor = properties.TextColor,

        Tracer = {
            Enabled = properties.Tracer.Enabled,
            Color = properties.Tracer.Color
        }
    })

    return esp
end

local function monsterESP(monster, name)
    if not toggles.EntityESP.Value then return end

    local tracerEnabled

    if monster.Name == "Eyefestation" then
        tracerEnabled = false
    else
        tracerEnabled = toggles.EntityESPTracer.Value
    end

    local colour = options.EntityColour.Value

    _ESP({
        Name = name or monster.Name,
        Model = monster,
        FillColor = colour,
        OutlineColor = colour,
        TextColor = colour,

        Tracer = {
            Enabled = tracerEnabled,
            Color = colour
        }
    })
end

local function interactableESP(interactable, colour, name)
    if not toggles.InteractableESP.Value then return end

    _ESP({
        Name = name or interactable.Name,
        Model = interactable,
        FillColor = colour,
        OutlineColor = colour,
        TextColor = colour,

        Tracer = {
            Enabled = toggles.InteractableESPTracer.Value,
            Color = colour
        }
    })
end

local function clearCurrentRoomStuff()
    for _, connection in pairs(currentRoomStuff.Connections) do connection:Disconnect() end
    for _, esp in pairs(currentRoomStuff.ESP) do esp.Destroy() end
end

local function setupCurrentRoomStuff(room)
    clearCurrentRoomStuff()

    for _, child in pairs(room:GetChildren()) do
        if child.Name == "Lever" then
            table.insert(currentRoomStuff.ESP, interactableESP(child, options.LeverColour.Value))
        end

        if child.Name == "MonsterLocker" then
            table.insert(currentRoomStuff.ESP, monsterESP(child, "Void Mass"))
        end
    end

    table.insert(currentRoomStuff.Connections, room.DescendantAdded:Connect(function(descendant)
    end))
end

--// UI \\--
local window = library:CreateWindow({
    Title = "xHub - " .. player.DisplayName,
    Center = true,
    AutoShow = true
})

local tabs = {
    Main = window:AddTab("Main"),
    Visual = window:AddTab("Visual"),
    Entity = window:AddTab("Entity"),
    Notifiers = window:AddTab("Notifiers"),
    ESP = window:AddTab("ESP"),
    Settings = window:AddTab("Settings")
}

local main = {
    Movement = tabs.Main:AddLeftGroupbox("Movement"),
    Sound = tabs.Main:AddLeftGroupbox("Sound"),
    Interaction = tabs.Main:AddRightGroupbox("Interaction"),
    Other = tabs.Main:AddRightGroupbox("Other")
}

main.Movement:AddSlider("SpeedBoost", {
    Text = "Speed Boost",
    Default = 0,
    Min = 0,
    Max = 45,
    Rounding = 0
})

main.Movement:AddToggle("FasterSpeed", {
    Text = "Faster than the monsters!",
    Callback = function(value)
        if value then
            options.SpeedBoost:SetMax(90)
        else
            options.SpeedBoost:SetMax(45)
        end
    end
})

main.Movement:AddDivider()

main.Movement:AddSlider("JumpHeight", {
    Text = "Jump Power",
    Default = 0,
    Min = 0,
    Max = 20,
    Rounding = 0
})

main.Movement:AddDivider()

main.Movement:AddToggle("NoAccel", {
    Text = "No Acceleration",
    Callback = function(value)
        if value then
            player.Character.PrimaryPart.CustomPhysicalProperties = PhysicalProperties.new(100, 0.5, 0.3, 1, 1)
        else
            player.Character.PrimaryPart.CustomPhysicalProperties = nil
        end
    end
})

main.Movement:AddToggle("Noclip", {
    Text = "Noclip"
}):AddKeyPicker("NoclipKey", {
    Text = "Noclip",
    Default = "N",
    Mode = "Toggle"
})

main.Movement:AddToggle("Fly", {
    Text = "Fly",
    Risky = true
}):AddKeyPicker("FlyKey", {
    Text = "Fly",
    Default = "F",
    Mode = "Toggle"
})

main.Interaction:AddToggle("InstantInteract", { Text = "Instant Interact" })

main.Interaction:AddToggle("AutoInteract", {
    Text = "Auto Interact",
    Risky = true
}):AddKeyPicker("AutoInteractKey", {
    Text = "Auto Interact",
    Default = "R",
    Mode = "Hold"
})

main.Interaction:AddToggle("AutoGenerator", { Text = "Auto Searchlights Generator", Risky = true })

main.Sound:AddToggle("NoAmbience", {
    Text = "Mute Ambience",
    Callback = function(value)
        if value then
            local ambience = workspace:WaitForChild("Ambience"):WaitForChild("FacilityAmbience")

            ambience.Volume = 0
        end
    end
})

main.Sound:AddToggle("NoFootsteps", { Text = "Mute Footsteps" })

main.Sound:AddToggle("NoAnticipationMusic", {
    Text = "Mute Room 1 Music",
    Callback = function(value)
        if value then
            local music = workspace:WaitForChild("AnticipationIntro")
            local loop = music:WaitForChild("AnticipationLoop")
            local fadeout = loop:WaitForChild("AnticipationFadeout")

            music.Volume = 0
            loop.Volume = 0
            fadeout.Volume = 0
        end
    end
})

main.Other:AddToggle("LessLag", {
    Text = "Performance Increase",
    Tooltip = "Just a few optimisations"
})

main.Other:AddButton({
    Text = "Play Again",
    DoubleClick = true,
    Func = function()
        events.PlayAgain:FireServer()
        library:Notify("[xHub] Teleporting in 5")
        for i = 1, 4 do
            task.wait(1)
            library:Notify(5 - i)
        end
    end
})

------------------------------------------------

local visual = {
    Camera = tabs.Visual:AddLeftGroupbox("Camera"),
    Lighting = tabs.Visual:AddRightGroupbox("Lighting")
}

visual.Camera:AddSlider("FieldOfView", {
    Text = "Field Of View",
    Default = 90,
    Min = 30,
    Max = 120,
    Rounding = 0,
    Callback = function(value) camera.FieldOfView = value end
})

visual.Camera:AddDivider()

visual.Camera:AddToggle("ThirdPerson", {
    Text = "Third Person"
}):AddKeyPicker("ThirdPersonKey", {
    Text = "Third Person",
    Default = "V",
    Mode = "Toggle",
    Callback = function(value)
        if value then
            player.Character.Head.Transparency = 0
        else
            player.Character.Head.Transparency = 1
        end
    end
})

visual.Lighting:AddToggle("Fullbright", {
    Text = "Fullbright",
    Callback = function(value)
        if value then
            lighting.Ambient = Color3.fromRGB(255, 255, 255)
        else
            lighting.Ambient = Color3.fromRGB(40, 53, 65)
        end
    end
})

visual.Lighting:AddToggle("NoFog", {
    Text = "No Underwater Fog",
    Callback = function(value)
        if value then
            blur.Size = 0
            depthOfField.FarIntensity = 0
        else
            blur.Size = 4
            depthOfField.FarIntensity = 0.25
        end
    end
})

visual.Lighting:AddToggle("XRayVision", {
    Text = "X-ray effect",
    Tooltip = "Not X-ray vision haha",
    Callback = function(value)
        lighting:WaitForChild("Test").Enabled = value
    end
})

------------------------------------------------

local entity = {
    Exploits = tabs.Entity:AddLeftGroupbox("Exploits")
}

entity.Exploits:AddToggle("AntiEyefestation", { Text = "Anti Eyefestation" })

entity.Exploits:AddToggle("AntiImaginaryFriend", { Text = "Anti Imaginary Friend" })

entity.Exploits:AddToggle("AntiPandemonium", { Text = "Anti Pandemonium", Risky = true })

entity.Exploits:AddToggle("AntiSearchlights", { Text = "Anti Searchlights", Risky = true })

entity.Exploits:AddToggle("AntiSquiddles", { Text = "Anti Squiddles", Risky = true })

entity.Exploits:AddToggle("AntiSteam", { Text = "Anti Steam", Risky = true })

entity.Exploits:AddToggle("AntiTurret", { Text = "Anti Turret", Risky = true })

------------------------------------------------

local notifiers = {
    Entity = tabs.Notifiers:AddLeftGroupbox("Entity"),
    Rooms = tabs.Notifiers:AddRightGroupbox("Rooms")
}

notifiers.Entity:AddToggle("NodeMonsterNotifier", { Text = "Node Monster Notifier" })

notifiers.Entity:AddToggle("PandemoniumNotifier", { Text = "Pandemonium Notifier" })

notifiers.Entity:AddToggle("WallDwellerNotifier", { Text = "Wall Dweller Notifier" })

notifiers.Entity:AddToggle("EyefestationNotifier", { Text = "Eyefestation Notifier" })

notifiers.Entity:AddToggle("LopeeNotifier", { Text = "Mr. Lopee Notifier " })

notifiers.Rooms:AddToggle("TurretNotifier", { Text = "Turret Notifier" })

notifiers.Rooms:AddToggle("GauntletNotifier", { Text = "Gauntlet Notifier" })

notifiers.Rooms:AddToggle("PuzzleNotifier", { Text = "Puzzle Room Notifier" })

notifiers.Rooms:AddToggle("DangerousNotifier", { Text = "Dangerous Room Notifier" })

notifiers.Rooms:AddToggle("RareRoomNotifier", { Text = "Rare Room Notifier" })

------------------------------------------------

local esp = {
    Interactables = tabs.ESP:AddLeftGroupbox("Interactables"),
    Entities = tabs.ESP:AddLeftGroupbox("Entities"),
    Other = tabs.ESP:AddLeftGroupbox("Other"),
    Players = tabs.ESP:AddRightGroupbox("Players"),
    Colours = tabs.ESP:AddRightGroupbox("Colours")
}

esp.Interactables:AddToggle("InteractableESP", { Text = "Enabled", Risky = true })

esp.Interactables:AddDivider()

esp.Interactables:AddDropdown("InteractableESPList", {
    Text = "Interactables List",
    AllowNull = true,
    Multi = true,
    Values = {
        "Items",
        "Documents",
        "Keycards",
        "Money",
        "Doors",
        "Generators",
        "Levers"
    }
})

esp.Interactables:AddDivider()

esp.Interactables:AddToggle("InteractableESPTracer", { Text = "Tracers", Risky = true })

esp.Entities:AddToggle("EntityESP", { Text = "Enabled" })

esp.Entities:AddDivider()

esp.Entities:AddDropdown("EntityESPList", {
    Text = "Entity List",
    AllowNull = true,
    Multi = true,
    Values = {
        "Node Monsters",
        "Pandemonium",
        "Wall Dwellers",
        "Eyefestation"
    }
})

esp.Entities:AddDivider()

esp.Entities:AddToggle("EntityESPTracer", { Text = "Tracer", Risky = true })

esp.Other:AddToggle("TurretESP", {
    Text = "Turret ESP",
    Risky = true
})

esp.Other:AddToggle("VoidMassESP", {
    Text = "Void Mass ESP",
    Risky = true
})

esp.Other:AddToggle("BeaconESP", {
    Text = "Water Beacon ESP",
    Risky = true
})

esp.Players:AddToggle("PlayerESP", { Text = "Enabled", Risky = true })

esp.Players:AddToggle("PlayerESPTracer", { Text = "Tracer", Risky = true })

esp.Colours:AddLabel("Items"):AddColorPicker("ItemColour", {
    Default = Color3.fromRGB(0, 64, 255) -- Blue
})

esp.Colours:AddLabel("Documents"):AddColorPicker("DocumentColour", {
    Default = Color3.fromRGB(255, 127, 0) -- Orange
})

esp.Colours:AddLabel("Keycards"):AddColorPicker("KeycardColour", {
    Default = Color3.fromRGB(255, 127, 0) -- Orange
})

esp.Colours:AddLabel("Money"):AddColorPicker("MoneyColour", {
    Default = Color3.fromRGB(255, 255, 0) -- Yellow
})

esp.Colours:AddLabel("Doors"):AddColorPicker("DoorColour", {
    Default = Color3.fromRGB(0, 255, 255) -- Light Blue
})

esp.Colours:AddLabel("Generators"):AddColorPicker("GeneratorColour", {
    Default = Color3.fromRGB(0, 255, 0) -- Green
})

esp.Colours:AddLabel("Levers"):AddColorPicker("LeverColour", {
    Default = Color3.fromRGB(0, 255, 0) -- Green
})

esp.Colours:AddLabel("Entities"):AddColorPicker("EntityColour", {
    Default = Color3.fromRGB(255, 0, 0) -- Red
})

esp.Colours:AddLabel("Players"):AddColorPicker("PlayerColour", {
    Default = Color3.fromRGB(255, 255, 255) -- White
})

esp.Colours:AddDivider()

esp.Colours:AddToggle("RainbowESP", {
    Text = "Rainbow ESP",
    Callback = function(value) ESPLib.Rainbow.Set(value) end
})

--// FUNCTIONS \\--
library:GiveSignal(proximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
    if not toggles.InstantInteract.Value then return end

    fireproximityprompt(prompt)
end))

library:GiveSignal(workspace.ChildAdded:Connect(function(child)
    local roomNumber = events.CurrentRoomNumber:InvokeServer()

    if roomNumber ~= 100 then
        if toggles.NodeMonsterNotifier.Value then
            for _, monster in ipairs(nodeMonsters) do
                if child.Name == monster then
                    local name = string.gsub(monster, "Ridge", "")

                    getgenv().Alert(name .. " spawned. Hide!")

                    if options.EntityESPList.Value["Node Monsters"] then monsterESP(child, name) end
                end
            end
        end

        if toggles.PandemoniumNotifier.Value and child.Name == "Pandemonium" then
            getgenv().Alert("Pandemonium spawned. Good luck!")

            if options.EntityESPList.Value["Pandemonium"] then
                monsterESP(child)
            end
        end
    end

    if toggles.LessLag.Value and child.Name == "VentCover" then
        child:Destroy()
    end

    if toggles.LopeeNotifier.Value and child.Name == "LopeePart" then
        getgenv().Alert("Mr. Lopee spawned!")
    end
end))

library:GiveSignal(monsters.ChildAdded:Connect(function(monster)
    if toggles.WallDwellerNotifier.Value and monster.Name == "WallDweller" then
        getgenv().Alert("A Wall Dweller has spawned in the walls. Find it!")
    end

    if options.EntityESPList.Value["Wall Dwellers"] then monsterESP(monster, "Wall Dweller") end
end))

library:GiveSignal(playerGui.ChildAdded:Connect(function(child)
    if child.Name ~= "Pixel" then return end

    local friend = child.ViewportFrame:FindFirstChild("ImaginaryFriend")

    if friend then
        friend.Friend.Transparency = 1
    end
end))

library:GiveSignal(rooms.ChildAdded:Connect(function(room)
    if toggles.RareRoomNotifier.Value and (
            room.Name == "ValculaVoidMass" or
            room.Name == "Mindscape" or
            room.Name == "KeyKeyKeyKeyKey" or
            room.Name == "AirlockStart" or
            room.Name == "HCCheckpointStart" or
            string.find(room.Name, "IntentionallyUnfinished")
        ) then
        getgenv().Alert("The next room is rare!")
    end

    if toggles.TurretNotifier.Value and string.find(room.Name, "Turret") then
        getgenv().Alert("Turrets will spawn in the next room!")
    end

    if toggles.GauntletNotifier.Value and string.find(room.Name, "Gauntlet") then
        getgenv().Alert("The next room is a gauntlet. Good luck!")
    end

    if toggles.PuzzleNotifier.Value and (
            string.find(room.Name, "PipeBoard") or
            string.find(room.Name, "Steam") or
            string.find(room.Name, "Puzzle")
        ) then
        getgenv().Alert("The next room is a puzzle!")
    end

    if toggles.DangerousNotifier.Value and (
            room.Name == "RoundaboutDestroyed1" or
            room.Name == "LongStraightBrokenSide" or
            string.find(room.Name, "Electrfieid") or
            string.find(room.Name, "BigHole")
        ) then
        getgenv().Alert("The next room is dangerous!")
    end

    local roomCon = room.DescendantAdded:Connect(function(possibleEyefestation)
        if possibleEyefestation.Name ~= "Eyefestation" then return end

        if toggles.EyefestationNotifier.Value then
            getgenv().Alert("Eyefestation Spawned!")
        end
        if options.EntityESPList.Value["Eyefestation"] then
            monsterESP(possibleEyefestation)
        end
        if toggles.AntiEyefestation.Value then
            local active = possibleEyefestation:WaitForChild("Active")
            local eyefestCon = active.Changed:Connect(function(value)
                if not value then return end

                active.Value = false
            end)

            possibleEyefestation.Destroying:Once(function()
                eyefestCon:Disconnect()
            end)
        end
    end)

    room.Destroying:Once(function()
        roomCon:Disconnect()
    end)
end))

library:GiveSignal(runService.RenderStepped:Connect(function()
    if toggles.NoAmbience.Value then
        local part = workspace:FindFirstChild("AmbiencePart")

        if part then
            local sound = part:FindFirstChildWhichIsA("Sound")

            if sound then sound:Destroy() end
        end
    end

    if toggles.NoFootsteps.Value then
        for _, char in pairs(characters:GetChildren()) do
            for _, sound in pairs(char.LowerTorso:GetChildren()) do
                if sound:IsA("Sound") then
                    sound:Destroy()
                end
            end
        end
    end

    if toggles.AntiImaginaryFriend.Value then
        local part = workspace:FindFirstChild("FriendPart")

        if part then
            local sound = part:FindFirstChildWhichIsA("Sound")

            if sound then sound:Destroy() end
        end
    end

    if player.Character.Parent == characters then
        if toggles.ThirdPerson.Value and options.ThirdPersonKey:GetState() then
            camera.CFrame = camera.CFrame * CFrame.new(1.5, -0.5, 6.5)
        end

        if toggles.Noclip.Value and options.NoclipKey:GetState() then
            for _, part in pairs(player.Character:GetChildren()) do
                if part:IsA("BasePart") or part:IsA("MeshPart") then
                    part.CanCollide = false
                end
            end
        end

        camera.FieldOfView = options.FieldOfView.Value
    end

    player.Character.Humanoid.WalkSpeed = 16 + options.SpeedBoost.Value

    player.Character.Humanoid.JumpHeight = options.JumpHeight.Value
end))

------------------------------------------------

local settings = {
    Menu = tabs.Settings:AddLeftGroupbox("Menu"),
    Credits = tabs.Settings:AddRightGroupbox("Credits")
}

settings.Menu:AddToggle("KeybindMenu", {
    Text = "Open Keybind Menu",
    Callback = function(value) library.KeybindFrame.Visible = value end
})

settings.Menu:AddToggle("CustomCursor", {
    Text = "Show Custom Cursor",
    Default = true,
    Callback = function(value) library.ShowCustomCursor = value end
})

settings.Menu:AddDivider()

settings.Menu:AddLabel("Menu Keybind"):AddKeyPicker("MenuKeybind", {
    Text = "Menu Keybind",
    NoUI = true,
    Default = "RightShift"
})

settings.Menu:AddButton("Unload", library.Unload)

settings.Credits:AddLabel("xBackpack - Creator & Scripter")

library.ToggleKeybind = options.MenuKeybind

library:OnUnload(function()
    clearCurrentRoomStuff()
    ESPLib.ESP.Clear()
    getgenv().Alert = nil
    getgenv().xhub_loaded = nil
end)

themes:SetLibrary(library)
saves:SetLibrary(library)

saves:IgnoreThemeSettings()

saves:SetIgnoreIndexes({ "MenuKeybind" })

themes:SetFolder("xHub")
saves:SetFolder("xHub/Pressure")

themes:ApplyToTab(tabs.Settings)
saves:BuildConfigSection(tabs.Settings)

saves:LoadAutoloadConfig()

--// METHOD HOOKING \\--
-- local zoneChangeEvent = events.ZoneChange

-- local oldMethod
-- oldMethod = hookfunction(zoneChangeEvent.FireServer, newcclosure(function(self, ...)
--     local method = getnamecallmethod()

--     local args = { ... }

--     if not checkcaller() and method == "FireServer" then
--         if self == zoneChangeEvent then
--             setupCurrentRoomStuff(args[1])
--         end
--     end

--     return oldMethod(self, ...)
-- end))
