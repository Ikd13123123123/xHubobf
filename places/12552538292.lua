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

local currentRoom = Instance.new("ObjectValue")
currentRoom.Name = "CurrentRoom"
currentRoom.Parent = player

local playerGui = player.PlayerGui
local camera = workspace.CurrentCamera

if not player.Character then player.CharacterAdded:Wait() end

local function contains(_table, str)
    for _, word in pairs(_table) do
        if str == word then
            return true
        end
    end

    return false
end

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

local assets = {
    Items = {
        "Blacklight",
        "CodeBreacher",
        "DwellerPiece",
        "FlashBeacon",
        "Flashlight",
        "Gummylight",
        "SmallLantern",
        "Lantern",
        "Medkit",
        "WindupLight"
    }
}

local activeRoomStuff = {
    Connections = {},
    ESP = {
        Items = {},
        Documents = {},
        Keycards = {},
        Money = {},
        Doors = {},
        Generators = {},
        Levers = {},
        Entities = {},
    }
}

local funcs = {}

funcs._ESP = function(properties)
    return ESPLib.ESP.Highlight({
        Name = properties.Name or "No Text",
        Model = properties.Model,
        FillColor = properties.Color,
        OutlineColor = properties.Color,
        TextColor = properties.Color,

        Tracer = {
            Enabled = properties.TracerEnabled,
            Color = properties.Color
        },

        Arrow = {
            Enabled = properties.ArrowEnabled,
            Color = properties.Color
        }
    })
end

funcs.setupMonsterESP = function(monster, colour, name, enabled)
    local tracerEnabled
    local arrowEnabled

    if monster.Name == "Eyefestation" then
        tracerEnabled = false
        arrowEnabled = false
    else
        tracerEnabled = toggles.EntityESPTracers.Value
        arrowEnabled = toggles.EntityESPArrows.Value
    end

    local esp = funcs._ESP({
        Name = name,
        Model = monster,
        Color = colour,

        TracerEnabled = tracerEnabled,
        ArrowEnabled = arrowEnabled
    })

    if not toggles.EntityESP.Value then
        esp.SetVisible(false)
    elseif not enabled then
        esp.SetVisible(false)
    end

    return esp
end

funcs.setupInteractableESP = function(interactable, colour, name, enabled)
    local proxyPart = interactable:FindFirstChild("ProxyPart")

    if proxyPart then
        interactable.PrimaryPart = proxyPart
    end

    local iName = name

    if iName == "CodeBreacher" then
        iName = "Code Breacher"
    elseif iName == "FlashBeacon" then
        iName = "Flash Beacon"
    elseif iName == "WindupLight" then
        iName = "Hand-Cranked Flashlight"
    elseif iName == "DwellerPiece" then
        iName = "Wall Dweller Piece"
    end

    local esp = funcs._ESP({
        Name = iName,
        Model = interactable,
        Color = colour,

        TracerEnabled = toggles.InteractableESPTracers.Value,
        ArrowEnabled = toggles.InteractableESPArrows.Value
    })

    if not toggles.InteractableESP.Value then
        esp.SetVisible(false)
    elseif not enabled then
        esp.SetVisible(false)
    end

    return esp
end

funcs.clearActiveRoomStuff = function()
    for _, connection in pairs(activeRoomStuff.Connections) do
        connection:Disconnect()
        connection = nil
    end
    for _, espTable in pairs(activeRoomStuff.ESP) do
        for _, esp in pairs(espTable) do
            esp.Destroy()
            esp = nil
        end
    end
end

funcs.checkForESP = function(obj)
    if not obj:IsA("Model") then return end

    if string.find(obj.Name, "Document") then
        table.insert(
            activeRoomStuff.ESP.Documents,
            funcs.setupInteractableESP(
                obj,
                options.DocumentColour.Value,
                "Document",
                options.InteractableESPList.Value["Documents"]
            )
        )
    end

    if obj.Parent.Parent.Name ~= "SpawnLocations" then return end

    if string.find(obj.Name, "KeyCard") then
        table.insert(activeRoomStuff.ESP.Keycards,
            funcs.setupInteractableESP(
                obj,
                options.KeycardColour.Value,
                "Keycard",
                options.InteractableESPList.Value["Keycards"]
            )
        )
    elseif string.find(obj.Name, "Currency") then
        table.insert(
            activeRoomStuff.ESP.Money,
            funcs.setupInteractableESP(
                obj,
                options.MoneyColour.Value,
                "Money",
                options.InteractableESPList.Value["Money"]
            )
        )
    elseif contains(assets.Items, obj.Name) then
        table.insert(
            activeRoomStuff.ESP.Items,
            funcs.setupInteractableESP(
                obj,
                options.ItemColour.Value,
                obj.Name,
                options.InteractableESPList.Value["Items"]
            )
        )
    end
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

main.Movement:AddSlider("JumpHeight", {
    Text = "Jump Power",
    Default = 0,
    Min = 0,
    Max = 30,
    Rounding = 0
})

main.Movement:AddToggle("AbsoluteMadness", {
    Text = "Absolute Madness",
    Callback = function(value)
        if value then
            options.SpeedBoost:SetMax(900)
            options.JumpHeight:SetMax(900)
        else
            options.SpeedBoost:SetMax(45)
            options.JumpHeight:SetMax(30)
        end
    end
})

main.Movement:AddDivider()

main.Movement:AddToggle("NoAccel", {
    Text = "No Acceleration",
    Callback = function(value)
        if not value then
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
    Default = "G",
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

notifiers.Entity:AddToggle("A60Notifier", { Text = "A60 Notifier" })

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

esp.Interactables:AddToggle("InteractableESP", { Text = "Enabled" })

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

esp.Interactables:AddToggle("InteractableESPTracers", { Text = "Tracers" })

esp.Interactables:AddToggle("InteractableESPArrows", { Text = "Arrows" })

esp.Entities:AddToggle("EntityESP", { Text = "Enabled" })

esp.Entities:AddDivider()

esp.Entities:AddDropdown("EntityESPList", {
    Text = "Entity List",
    AllowNull = true,
    Multi = true,
    Values = {
        "Node Monsters",
        "Pandemonium",
        "A60",
        "Wall Dwellers",
        "Eyefestation",
        "Void Mass",
        "Turrets"
    }
})

esp.Entities:AddDivider()

esp.Entities:AddToggle("EntityESPTracers", { Text = "Tracers" })

esp.Entities:AddToggle("EntityESPArrows", { Text = "Arrows" })

esp.Other:AddToggle("BeaconESP", {
    Text = "Water Beacon ESP",
    Risky = true
})

esp.Players:AddToggle("PlayerESP", { Text = "Enabled", Risky = true })

esp.Players:AddToggle("PlayerESPTracer", { Text = "Tracer", Risky = true })

esp.Colours:AddToggle("RainbowESP", {
    Text = "Rainbow ESP",
    Callback = function(value) ESPLib.Rainbow.Set(value) end
})

esp.Colours:AddDivider()

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

esp.Colours:AddLabel("Node Monsters"):AddColorPicker("NodeMonsterColour", {
    Default = Color3.fromRGB(255, 0, 0) -- Red
})

esp.Colours:AddLabel("Pandemonium"):AddColorPicker("PandemoniumColour", {
    Default = Color3.fromRGB(255, 0, 0) -- Red
})

esp.Colours:AddLabel("A60"):AddColorPicker("A60Colour", {
    Default = Color3.fromRGB(255, 255, 255) -- Red
})

esp.Colours:AddLabel("Wall Dwellers"):AddColorPicker("WallDwellerColour", {
    Default = Color3.fromRGB(255, 0, 0) -- Red
})

esp.Colours:AddLabel("Eyefestation"):AddColorPicker("EyefestationColour", {
    Default = Color3.fromRGB(0, 0, 255) -- Dark Blue
})

esp.Colours:AddLabel("Void Mass"):AddColorPicker("VoidMassColour", {
    Default = Color3.fromRGB(255, 0, 255) -- Purple
})

esp.Colours:AddLabel("Turrets"):AddColorPicker("TurretColour", {
    Default = Color3.fromRGB(255, 0, 0) -- Red
})

esp.Colours:AddLabel("Players"):AddColorPicker("PlayerColour", {
    Default = Color3.fromRGB(255, 255, 255) -- White
})

--// FUNCTIONS \\--
library:GiveSignal(proximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
    if not toggles.InstantInteract.Value then return end

    fireproximityprompt(prompt)
end))

library:GiveSignal(workspace.ChildAdded:Connect(function(child)
    local roomNumber = events.CurrentRoomNumber:InvokeServer()

    if roomNumber ~= 100 then
        if contains(nodeMonsters, child.Name) then
            local name = string.gsub(child.Name, "Ridge", "")

            if toggles.NodeMonsterNotifier.Value then getgenv().Alert(name .. " spawned. Hide!") end

            funcs.setupMonsterESP(
                child,
                options.NodeMonsterColour.Value,
                name,
                options.EntityESPList.Value["Node Monsters"]
            )
        end

        if child.Name == "Pandemonium" then
            if toggles.PandemoniumNotifier.Value then getgenv().Alert("Pandemonium spawned. Good luck!") end

            funcs.setupMonsterESP(
                child,
                options.PandemoniumColour.Value,
                "Pandemonium",
                options.EntityESPList.Value["Pandemonium"]
            )
        end

        if child.Name == "A60" then
            if toggles.A60Notifier.Value then getgenv().Alert("A60 SPAWNED! THAT'S RARE LOL!!!!!!!!!") end

            funcs.setupMonsterESP(
                child,
                options.A60Colour.Value,
                "A60",
                options.EntityESPList.Value["A60"]
            )
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
    if monster.Name == "WallDweller" then
        if toggles.WallDwellerNotifier.Value then getgenv().Alert("A Wall Dweller has spawned in the walls. Find it!") end

        funcs.setupMonsterESP(
            monster,
            options.WallDwellerColour.Value,
            "Wall Dweller",
            options.EntityESPList.Value["Wall Dwellers"]
        )
    end
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
            room.Name == "Cabin?" or
            room.Name == "LookUp" or
            room.Name == "Huh?DeadEnd?" or
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
            room.Name == "BigHallPit" or
            room.Name == "Overheat1" or
            room.Name == "ElectricityPuzzleFloor1" or
            string.find(room.Name, "Electrfieid") or
            string.find(room.Name, "Electrified") or
            string.find(room.Name, "BigHole")
        ) then
        getgenv().Alert("The next room is dangerous!", 15)
    end

    local roomCon = room.DescendantAdded:Connect(function(possibleEyefestation)
        if possibleEyefestation.Name ~= "Eyefestation" then return end

        if toggles.EyefestationNotifier.Value then
            getgenv().Alert("Eyefestation Spawned!")
        end
        if options.EntityESPList.Value["Eyefestation"] then
            funcs.setupMonsterESP(possibleEyefestation, options.EyefestationColour.Value)
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

library:GiveSignal(currentRoom.Changed:Connect(function(room)
    funcs.clearActiveRoomStuff()

    for _, child in pairs(room:GetChildren()) do
        if child.Name == "MonsterLocker" then
            table.insert(
                activeRoomStuff.ESP.Entities,
                funcs.setupMonsterESP(
                    child.highlight,
                    options.VoidMassColour.Value,
                    "Void Mass",
                    options.EntityESPList.Value["Void Mass"]
                )
            )
        end
    end

    for _, interactable in pairs(room.Interactables:GetChildren()) do
        if (interactable.Name == "Generator" or interactable.Name == "EncounterGenerator") then
            table.insert(
                activeRoomStuff.ESP.Generators,
                funcs.setupInteractableESP(
                    interactable.Model,
                    options.GeneratorColour.Value,
                    "Generator",
                    options.InteractableESPList.Value["Generators"]
                )
            )
        elseif interactable.Name == "BrokenCables" then
            table.insert(
                activeRoomStuff.ESP.Generators,
                funcs.setupInteractableESP(
                    interactable.Model,
                    options.GeneratorColour.Value,
                    "Cable",
                    options.InteractableESPList.Value["Generators"]
                )
            )
        elseif interactable.Name == "TurretControls" then
            table.insert(activeRoomStuff.ESP.Levers,
                funcs.setupInteractableESP(
                    interactable,
                    options.LeverColour.Value,
                    "Lever",
                    options.InteractableESPList.Value["Levers"]
                )
            )
        end
    end

    for _, obj in pairs(room:GetDescendants()) do
        funcs.checkForESP(obj)
    end

    table.insert(activeRoomStuff.Connections, room.DescendantAdded:Connect(function(obj)
        funcs.checkForESP(obj)
    end))
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

    if player.Character.PrimaryPart.Massless then
        player.Character.PrimaryPart.CustomPhysicalProperties = nil
    elseif toggles.NoAccel.Value then
        player.Character.PrimaryPart.CustomPhysicalProperties = PhysicalProperties.new(100, 0.5, 0.3, 1, 1)
    end
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
    funcs.clearActiveRoomStuff()
    ESPLib.ESP.Clear()
    currentRoom:Destroy()
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
local zoneChangeEvent = events.ZoneChange

local oldMethod
oldMethod = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()

    local args = { ... }

    if not checkcaller() and method == "FireServer" then
        if self == zoneChangeEvent then
            currentRoom.Value = args[1]
        end
    end

    return oldMethod(self, ...)
end))
