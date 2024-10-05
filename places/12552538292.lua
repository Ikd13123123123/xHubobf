--// SETUP \\--
local library = getgenv().Library

if not getgenv().xhub_loaded then
    getgenv().xhub_loaded = true
else
    library:Notify("Already Loaded!")
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
local events = repStorage:WaitForChild("Events")

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

local function _setupESP(properties)
    local esp = ESPLib.ESP.Highlight({
        Name = properties.Name or "No Text",
        Model = properties.Model,
        FillColor = properties.FillColour,
        OutlineColor = properties.OutlineColour,
        TextColor = properties.EntityColour,

        Tracer = {
            Enabled = properties.Tracer.Enabled,
            Color = properties.Tracer.Colour
        }
    })

    return esp
end

local function setupMonsterESP(monster, name)
    if not toggles.EntityESP.Value then return end

    local colour = options.EntityColour.Value

    _setupESP({
        Name = name or monster.Name,
        Model = monster,
        FillColor = colour,
        OutlineColor = colour,
        TextColor = colour,

        Tracer = {
            Enabled = toggles.EntityESPTracer.Value,
            Color = colour
        }
    })
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
    Exploits = tabs.Main:AddRightGroupbox("Exploits")
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

main.Movement:AddSlider("JumpHeight", {
    Text = "Jump Power",
    Default = 0,
    Min = 0,
    Max = 20,
    Rounding = 0
})

main.Movement:AddToggle("Noclip", {
    Text = "Noclip",
    Risky = true
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

main.Exploits:AddToggle("LessLag", {
    Text = "Performance Increase",
    Tooltip = "Just a few optimisations"
})

main.Exploits:AddButton({
    Text = "Play Again",
    DoubleClick = true,
    Func = function()
        events.PlayAgain:FireServer()
        library:Notify("Teleporting in 5")
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

------------------------------------------------

local entity = {
    Exploits = tabs.Entity:AddLeftGroupbox("Exploits")
}

entity.Exploits:AddToggle("AntiEyefestation", { Text = "Anti Eyefestation", Risky = true })

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

notifiers.Entity:AddToggle("EyefestationNotifier", { Text = "Eyefestation Notifier", Risky = true })

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
        "Turret Controls"
    }
})

esp.Interactables:AddDivider()

esp.Interactables:AddToggle("InteractableESPName", { Text = "Name", Risky = true })

esp.Interactables:AddToggle("InteractableESPDistance", {
    Text = "Distance",
    Risky = true,
    Tooltip = "Not Implemented Yet"
})

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

esp.Entities:AddToggle("EntityESPName", { Text = "Name" })

esp.Entities:AddToggle("EntityESPDistance", {
    Text = "Distance",
    Risky = true,
    Tooltip = "Not Implemented Yet"
})

esp.Entities:AddToggle("EntityESPTracer", { Text = "Tracer" })

esp.Other:AddToggle("VoidMassESP", {
    Text = "Void Mass ESP",
    Risky = true,
    Tooltip = "ALPHA, Not working yet"
})

esp.Other:AddToggle("BeaconESP", {
    Text = "Water Beacon ESP",
    Risky = true,
    Tooltip = "ALPHA, Not working yet"
})

esp.Players:AddToggle("PlayerESP", { Text = "Enabled", Risky = true })

esp.Players:AddDivider()

esp.Players:AddToggle("PlayerESPName", { Text = "Name", Risky = true })

esp.Players:AddToggle("PlayerESPDistance", { Text = "Distance", Risky = true })

esp.Players:AddToggle("PlayerESPTracer", { Text = "Tracer", Risky = true })

esp.Colours:AddLabel("Items"):AddColorPicker("ItemColour", {
    Default = Color3.fromRGB(0, 255, 0)
})

esp.Colours:AddLabel("Documents"):AddColorPicker("DocumentColour", {
    Default = Color3.fromRGB(255, 0, 0)
})

esp.Colours:AddLabel("Keycards"):AddColorPicker("KeycardColour", {
    Default = Color3.fromRGB(255, 127, 0)
})

esp.Colours:AddLabel("Money"):AddColorPicker("MoneyColour", {
    Default = Color3.fromRGB(255, 255, 0)
})

esp.Colours:AddLabel("Doors"):AddColorPicker("DoorColour", {
    Default = Color3.fromRGB(0, 255, 0)
})

esp.Colours:AddLabel("Generators"):AddColorPicker("GeneratorColour", {
    Default = Color3.fromRGB(0, 255, 255)
})

esp.Colours:AddLabel("Entities"):AddColorPicker("EntityColour", {
    Default = Color3.fromRGB(0, 0, 255)
})

esp.Colours:AddLabel("Players"):AddColorPicker("PlayerColour", {
    Default = Color3.fromRGB(255, 255, 255)
})

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

    if roomNumber == 100 then return end

    if toggles.NodeMonsterNotifier.Value then
        for _, monster in ipairs(nodeMonsters) do
            if child.Name == monster then
                local name = string.gsub(monster, "Ridge", "")

                getgenv().Alert(name .. " spawned. Hide!")

                if options.EntityESPList.Value["Node Monsters"] then setupMonsterESP(child, name) end
            end
        end
    end

    if toggles.PandemoniumNotifier.Value and child.Name == "Pandemonium" then
        getgenv().Alert("Pandemonium spawned. Good luck!")

        if options.EntityESPList.Value["Pandemonium"] then
            setupMonsterESP(child)
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

    if options.EntityESPList.Value["Wall Dwellers"] then setupMonsterESP(monster, "Wall Dweller") end
end))

library:GiveSignal(playerGui.ChildAdded:Connect(function(child)
    if child.Name ~= "Pixel" then return end

    local friend = child.ViewportFrame:FindFirstChild("ImaginaryFriend")

    if friend then
        friend.Friend.Transparency = 1
    end

    child.ViewportFrame.ImaginaryFriend.Friend.Transparency = 1
end))

library:GiveSignal(rooms.ChildAdded:Connect(function(room)
    if toggles.RareRoomNotifier.Value and (room.Name == "ValculaVoidMass" or room.Name == "Mindscape" or room.Name == "KeyKeyKeyKeyKey" or string.find(room.Name, "IntentionallyUnfinished") or room.Name == "AirlockStart") then
        getgenv().Alert("The next room is rare!")
    end

    if toggles.TurretNotifier.Value and string.find(room.Name, "Turret") then
        getgenv().Alert("Turrets will spawn in the next room!")
    end

    if toggles.GauntletNotifier.Value and string.find(room.Name, "Gauntlet") then
        getgenv().Alert("The next room is a gauntlet. Good luck!")
    end

    if toggles.PuzzleNotifier.Value and (string.find(room.Name, "PipeBoard") or string.find(room.Name, "Steam")) then
        getgenv().Alert("The next room is a puzzle!")
    end

    if toggles.DangerousNotifier.Value then
        local parent = room:FindFirstChild("DamageParts") or room:FindFirstChild("DamagePart")

        if parent and (parent:FindFirstChild("Electricity") or parent:FindFirstChild("Pit")) then
            getgenv().Alert("The next room is dangerous. Careful as you enter!")
        end
    end

    local interactables = room:WaitForChild("Interactables")

    local spawn = interactables:WaitForChild("EyefestationSpawn", 1)

    if spawn then
        spawn.ChildAdded:Connect(function(child)
            if toggles.EyefestationNotifier.Value then
                library.Alert("Eyefestation Spawned!")
            end
            if options.EntityESPList.Value["Eyefestation"] then
                setupMonsterESP(child)
            end
            if toggles.AntiEyefestation.Value then
                child:WaitForChild("Active").Changed:Connect(function(value)
                    if not value then return end

                    value = false
                end)
            end
        end)

        spawn.ChildRemoved:Connect(function(child)
            for _, connection in pairs(getconnections(child.Active.Changed)) do
                connection:Disconnect()
            end
        end)
    end
end))

library:GiveSignal(rooms.ChildRemoved:Connect(function(room)
    local spawn = room.Interactables:FindFirstChild("EyefestationSpawn")

    if spawn then
        for _, connection in pairs(getconnections(spawn.ChildAdded)) do
            connection:Disconnect()
        end
    end
end))

library:GiveSignal(runService.RenderStepped:Connect(function()
    if toggles.NoAmbience.Value then
        local part = workspace:FindFirstChild("AmbiencePart")

        if part then
            local child = part:FindFirstChildWhichIsA("Sound")

            if child then
                child:Destroy()
            end
        end
    end

    if toggles.NoFootsteps.Value then
        for _, char in pairs(workspace.Characters:GetChildren()) do
            for _, child in (char.LowerTorso:GetChildren()) do
                if child:IsA("Sound") then
                    child:Destroy()
                end
            end
        end
    end

    if toggles.AntiImaginaryFriend.Value then
        local part = workspace:FindFirstChild("FriendPart")

        if part then
            local child = part:FindFirstChildWhichIsA("Sound")

            if child then
                child:Destroy()
            end
        end
    end

    if player.Character.Parent.Name == "Characters" then
        if toggles.ThirdPerson.Value and options.ThirdPersonKey:GetState() then
            camera.CFrame = camera.CFrame * CFrame.new(1.5, -0.5, 6.5)
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

-- Event Hooking
local zoneChangeEvent = events.ZoneChange

-- Method Hooking

local oldMethod
oldMethod = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()

    local args = { ... }
    local room = args[1]

    task.spawn(function()
        if method == "FireServer" then
            if self == zoneChangeEvent then
                print("Entered room: " .. room.Name)
            end
        end
    end)

    return oldMethod(self, ...)
end)
