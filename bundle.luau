--[[
    AKIRI HUB - STANDALONE BUNDLE (FIXED)
--]]

local Modules = {}

-- 1. CORE CONFIG
Modules["core/config"] = (function()

local Config = {
    Notifications = true,
    
    Combat = {
        SilentAim = false,
        HitChance = 100,
        HitSound = "Gamesense",
        FOV = 25,
        TeamCheck = true,
        TargetPart = "Head",

        Aimbot = {
            Enabled = false,
            Type = "Camera",
            Smoothness = 5,
            FOV = 25,
            TeamCheck = true,
            TargetPart = "Head",
            VisibleCheck = true,
            Aiming = false
        }
    },
    
    SkinChanger = {
        Enabled = false,
        CustomKnifeEnabled = false,
        SelectedKnife = "Butterfly Knife",
        Wear = "Factory New",
        SelectedSkins = {}
    },
    
    ESP = {
        Enabled = true,
        TeamCheck = true,
        MaxDistance = 1000,
        VisibleCheck = false,
        
        Box = {
            Enabled = false,
            Type = "2D",
            Color = Color3.fromRGB(255, 0, 0),
            Thickness = 2,
            Transparency = 1,
        },
        
        Player = {
            Names = false,
            Health = false,
            Distance = false,
            Weapon = false,
            NamesColor = Color3.fromRGB(255, 255, 255),
            TextFont = 2,
            TextSize = 14,
        },
        
        Skeleton = {
            Enabled = false,
            Color = Color3.fromRGB(0, 255, 0),
            Thickness = 2,
            Transparency = 1,
        },
        
        Misc = {
            ShowTeammates = false,
            Arrows = false,
            ArrowsColor = Color3.fromRGB(255, 255, 255),
            DistFromCenter = 80,
            TriangleWidth = 16,
            TriangleHeight = 16
        }
    }
}

return Config

end)()

-- 2. CORE SOUNDS
Modules["core/sounds"] = (function()

local SoundService = game:GetService("SoundService")

local Sounds = {
    Notification = "rbxassetid://5453349528",
    Click        = "rbxassetid://535716488",
    Toggle       = "rbxassetid://6895079853",
    Hover        = "rbxassetid://9114223280",
    GamesenseOld = "rbxassetid://4817809188",
    Gamesense    = "rbxassetid://94204395881101",
    Neverlose    = "rbxassetid://139452805868562",
    Hitmarker    = "rbxassetid://94204395881101",
    Headshot     = "rbxassetid://139452805868562",
}

local SoundSystem = {}
SoundSystem.CurrentHitSound = "Gamesense"

function SoundSystem.Play(soundName)
    local id = Sounds[soundName] or Sounds[SoundSystem.CurrentHitSound] or Sounds.Gamesense
    if not id then return end
    local sound = Instance.new("Sound")
    sound.SoundId = id
    sound.Volume = 1
    sound.Parent = SoundService
    sound:Play()
    sound.Ended:Once(function() sound:Destroy() end)
end

function SoundSystem.GetId(soundName)
    return Sounds[soundName]
end

return SoundSystem

end)()

-- 3. UTILS ESP_UTILS
Modules["utils/esp_utils"] = (function()
    local Config = Modules["core/config"]

local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera
local lp = Players.LocalPlayer

-- FIX: characters están en workspace.Characters.PlayerName, no en player.Character
local function getCharacter(player)
    local chars = workspace:FindFirstChild("Characters")
    if not chars then return nil end
    return chars:FindFirstChild(player.Name)
end

local ESPUtils = {}

-- exponer pa que otros módulos lo usen
ESPUtils.GetCharacter = getCharacter

function ESPUtils.IsTeamMate(player)
    if player == lp then return true end
    if not Config.ESP.TeamCheck then return false end
    if Config.ESP.Misc.ShowTeammates then return false end

    -- FIX: team via GetAttribute, que sí funciona en este juego
    local team = player:GetAttribute("Team")
    local myteam = lp:GetAttribute("Team")

    if workspace:GetAttribute("Gamemode") == "Deathmatch" then
        return false
    end

    return team ~= nil and myteam ~= nil and team == myteam
end

function ESPUtils.IsVisible(part, character)
    if not Config.ESP.VisibleCheck then return true end
    if not part or not character then return false end

    local origin = Camera.CFrame.Position
    local direction = (part.Position - origin)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {Camera, getCharacter(lp)}

    local result = workspace:Raycast(origin, direction, raycastParams)
    if result then
        return result.Instance:IsDescendantOf(character)
    end
    return true
end

function ESPUtils.GetDistance(position)
    local myChar = getCharacter(lp)
    if not myChar or not myChar.PrimaryPart then return math.huge end
    return (myChar.PrimaryPart.Position - position).Magnitude
end

function ESPUtils.ShouldRender(player, primaryPart)
    if not Config.ESP.Enabled then return false end
    if not player or player == lp then return false end
    if ESPUtils.IsTeamMate(player) then return false end

    if primaryPart then
        local dist = ESPUtils.GetDistance(primaryPart.Position)
        if dist > (Config.ESP.MaxDistance or 1000) then return false end
        if Config.ESP.VisibleCheck and not ESPUtils.IsVisible(primaryPart, getCharacter(player)) then
            return false
        end
    end

    return true
end

return ESPUtils
end)()

-- 4. UTILS NOTIFICATIONS
Modules["utils/notifications"] = (function()
    local Sounds = Modules["core/sounds"]

local NotifLib

local function getNotif()
    if not NotifLib then
        pcall(function()
            NotifLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/insanedude59/notiflib/main/main"))()
        end)
    end
    return NotifLib
end

local Notifications = {}

function Notifications.Notify(title, description, time)
    Sounds.Play("Notification")
    local n = getNotif()
    if n then
        pcall(function()
            n:Notification(title or "Akiri", description or "", "GothamSemibold", "Gotham", time or 5)
        end)
    end
end

return Notifications
end)()

-- 5. FEATURES / ESP / ARROWS
Modules["features/esp/arrows"] = (function()
    local Config = Modules["core/config"]
    local ESPUtils = Modules["utils/esp_utils"]

local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")

local V2 = Vector2.new
local V3 = Vector3.new
local CF = CFrame.new
local COS = math.cos
local SIN = math.sin
local RAD = math.rad
local CWRAP = coroutine.wrap

local function GetRelative(pos, myChar)
    if not myChar then return V2(0,0) end
    local rootP = myChar.PrimaryPart and myChar.PrimaryPart.Position or pos
    local camP = Camera.CFrame.Position
    local relative = CF(V3(rootP.X, camP.Y, rootP.Z), camP):PointToObjectSpace(pos)
    return V2(relative.X, relative.Z)
end

local function RelativeToCenter(v)
    return Camera.ViewportSize/2 - v
end

local function RotateVect(v, a)
    a = RAD(a)
    return V2(v.x * COS(a) - v.y * SIN(a), v.x * SIN(a) + v.y * COS(a))
end

local function DrawTriangle()
    local l = Drawing.new("Triangle")
    l.Visible = false
    l.Color = Config.ESP.Misc.ArrowsColor
    l.Filled = true
    l.Thickness = 1
    l.Transparency = 1
    return l
end

local function ShowArrow(player)
    local Arrow = DrawTriangle()

    local function Update()
        local c; c = RunService.RenderStepped:Connect(function()
            local char = ESPUtils.GetCharacter(player)
            if Config.ESP.Enabled and Config.ESP.Misc.Arrows and char then
                if ESPUtils.IsTeamMate(player) then
                    Arrow.Visible = false
                    return
                end

                local HUM = char:FindFirstChildOfClass("Humanoid")
                local hrp = char:FindFirstChild("HumanoidRootPart")

                if HUM and hrp and HUM.Health > 0 then
                    local _, vis = Camera:WorldToViewportPoint(hrp.Position)
                    if not vis then
                        local myChar = ESPUtils.GetCharacter(lp)
                        local rel = GetRelative(hrp.Position, myChar)
                        local direction = rel.unit

                        local dist   = Config.ESP.Misc.DistFromCenter or 80
                        local width  = Config.ESP.Misc.TriangleWidth or 16
                        local height = Config.ESP.Misc.TriangleHeight or 16

                        local base   = direction * dist
                        local baseL  = base + RotateVect(direction, 90) * (width/2)
                        local baseR  = base + RotateVect(direction, -90) * (width/2)
                        local tip    = direction * (dist + height)

                        Arrow.PointA = RelativeToCenter(baseL)
                        Arrow.PointB = RelativeToCenter(baseR)
                        Arrow.PointC = RelativeToCenter(tip)
                        Arrow.Color  = Config.ESP.Misc.ArrowsColor
                        Arrow.Visible = true
                    else
                        Arrow.Visible = false
                    end
                else
                    Arrow.Visible = false
                end
            else
                Arrow.Visible = false
                if not player or not player.Parent then
                    Arrow:Remove()
                    c:Disconnect()
                end
            end
        end)
    end

    CWRAP(Update)()
end

for _, v in ipairs(Players:GetPlayers()) do
    if v ~= lp then ShowArrow(v) end
end

Players.PlayerAdded:Connect(function(v)
    if v ~= lp then ShowArrow(v) end
end)

end)()

-- 6. FEATURES / ESP / BONES
Modules["features/esp/bones"] = (function()
    local Config = Modules["core/config"]
    local ESPUtils = Modules["utils/esp_utils"]

local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")

-- R15 completo incluyendo lower arms/legs
local bonePairs = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"},
}

local function WorldToScreen(pos)
    local vec, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(vec.X, vec.Y), onScreen
end

local function CreateLine()
    local line = Drawing.new("Line")
    line.Thickness = Config.ESP.Skeleton.Thickness or 2
    line.Color = Config.ESP.Skeleton.Color
    line.Transparency = Config.ESP.Skeleton.Transparency or 1
    line.Visible = false
    return line
end

local function ShowSkeleton(player)
    local lines = {}
    for _ in ipairs(bonePairs) do
        table.insert(lines, CreateLine())
    end

    local conn
    conn = RunService.RenderStepped:Connect(function()
        local char = ESPUtils.GetCharacter(player)
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        if not char or not hrp or not Config.ESP.Skeleton.Enabled or not ESPUtils.ShouldRender(player, hrp) then
            for _, l in ipairs(lines) do l.Visible = false end
            if not player or not player.Parent then
                for _, l in ipairs(lines) do l:Remove() end
                conn:Disconnect()
            end
            return
        end

        for i, pair in ipairs(bonePairs) do
            local partA = char:FindFirstChild(pair[1])
            local partB = char:FindFirstChild(pair[2])
            if partA and partB then
                local aPos, aVis = WorldToScreen(partA.Position)
                local bPos, bVis = WorldToScreen(partB.Position)
                if aVis and bVis then
                    lines[i].From = aPos
                    lines[i].To = bPos
                    lines[i].Color = Config.ESP.Skeleton.Color
                    lines[i].Thickness = Config.ESP.Skeleton.Thickness
                    lines[i].Transparency = Config.ESP.Skeleton.Transparency
                    lines[i].Visible = true
                else
                    lines[i].Visible = false
                end
            else
                lines[i].Visible = false
            end
        end
    end)
end

local function Init()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Players.LocalPlayer then ShowSkeleton(p) end
    end
    Players.PlayerAdded:Connect(function(p)
        if p ~= Players.LocalPlayer then ShowSkeleton(p) end
    end)
end

Init()
end)()

-- 7. FEATURES / ESP / BOX
Modules["features/esp/box"] = (function()
    local Config = Modules["core/config"]
    local ESPUtils = Modules["utils/esp_utils"]

local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")

local function WorldToScreen(pos)
    local vec, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(vec.X, vec.Y), onScreen
end

local function CreateBoxDrawing()
    local box = Drawing.new("Square")
    box.Thickness = 2
    box.Color = Color3.fromRGB(255, 0, 0)
    box.Transparency = 1
    box.Visible = false

    local corners = {}
    for i = 1, 8 do
        local l = Drawing.new("Line")
        l.Thickness = 2
        l.Color = Color3.fromRGB(255, 0, 0)
        l.Transparency = 1
        l.Visible = false
        table.insert(corners, l)
    end

    return box, corners
end

local function ShowBox(player)
    local box, cornerLines = CreateBoxDrawing()

    local conn
    conn = RunService.RenderStepped:Connect(function()
        local char = ESPUtils.GetCharacter(player)
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        if not char or not hrp or not hum or hum.Health <= 0 or not Config.ESP.Box.Enabled or not ESPUtils.ShouldRender(player, hrp) then
            box.Visible = false
            for _, l in ipairs(cornerLines) do l.Visible = false end
            if not player or not player.Parent then
                box:Remove()
                for _, l in ipairs(cornerLines) do l:Remove() end
                conn:Disconnect()
            end
            return
        end

        local size = Vector3.new(4, 6, 2)
        local points = {
            hrp.Position + Vector3.new(-size.X/2,  size.Y/2, -size.Z/2),
            hrp.Position + Vector3.new( size.X/2,  size.Y/2, -size.Z/2),
            hrp.Position + Vector3.new( size.X/2, -size.Y/2, -size.Z/2),
            hrp.Position + Vector3.new(-size.X/2, -size.Y/2, -size.Z/2),
        }

        local screenPoints = {}
        local anyOnScreen = false
        for i, pt in ipairs(points) do
            local sp, vis = WorldToScreen(pt)
            screenPoints[i] = sp
            anyOnScreen = anyOnScreen or vis
        end

        if anyOnScreen then
            local minX, minY = math.huge, math.huge
            local maxX, maxY = -math.huge, -math.huge
            for _, pt in ipairs(screenPoints) do
                if pt.X < minX then minX = pt.X end
                if pt.Y < minY then minY = pt.Y end
                if pt.X > maxX then maxX = pt.X end
                if pt.Y > maxY then maxY = pt.Y end
            end

            local posX   = minX
            local posY   = minY
            local width  = maxX - minX
            local height = maxY - minY

            if Config.ESP.Box.Type == "Corner" then
                box.Visible = false
                local cl = width * 0.25

                cornerLines[1].From = Vector2.new(posX, posY)
                cornerLines[1].To   = Vector2.new(posX + cl, posY)
                cornerLines[2].From = Vector2.new(posX, posY)
                cornerLines[2].To   = Vector2.new(posX, posY + cl)

                cornerLines[3].From = Vector2.new(posX + width, posY)
                cornerLines[3].To   = Vector2.new(posX + width - cl, posY)
                cornerLines[4].From = Vector2.new(posX + width, posY)
                cornerLines[4].To   = Vector2.new(posX + width, posY + cl)

                cornerLines[5].From = Vector2.new(posX, posY + height)
                cornerLines[5].To   = Vector2.new(posX + cl, posY + height)
                cornerLines[6].From = Vector2.new(posX, posY + height)
                cornerLines[6].To   = Vector2.new(posX, posY + height - cl)

                cornerLines[7].From = Vector2.new(posX + width, posY + height)
                cornerLines[7].To   = Vector2.new(posX + width - cl, posY + height)
                cornerLines[8].From = Vector2.new(posX + width, posY + height)
                cornerLines[8].To   = Vector2.new(posX + width, posY + height - cl)

                for _, l in ipairs(cornerLines) do
                    l.Color = Config.ESP.Box.Color
                    l.Thickness = Config.ESP.Box.Thickness
                    l.Transparency = Config.ESP.Box.Transparency
                    l.Visible = true
                end
            else
                for _, l in ipairs(cornerLines) do l.Visible = false end
                box.Position    = Vector2.new(posX, posY)
                box.Size        = Vector2.new(width, height)
                box.Color       = Config.ESP.Box.Color
                box.Thickness   = Config.ESP.Box.Thickness
                box.Transparency = Config.ESP.Box.Transparency
                box.Visible     = true
            end
        else
            box.Visible = false
            for _, l in ipairs(cornerLines) do l.Visible = false end
        end
    end)
end

local function Init()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Players.LocalPlayer then ShowBox(p) end
    end
    Players.PlayerAdded:Connect(function(p)
        if p ~= Players.LocalPlayer then ShowBox(p) end
    end)
end

Init()
end)()

-- 8. FEATURES / ESP / HEALTH
Modules["features/esp/health"] = (function()
    local Config = Modules["core/config"]
    local ESPUtils = Modules["utils/esp_utils"]

local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")

local function WorldToScreen(pos)
    local vec, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(vec.X, vec.Y), onScreen
end

local function CreateHealthESP()
    local bg = Drawing.new("Square")
    bg.Thickness = 1
    bg.Color = Color3.fromRGB(0, 0, 0)
    bg.Filled = true
    bg.Transparency = 0.5
    bg.Visible = false

    local fill = Drawing.new("Square")
    fill.Thickness = 1
    fill.Color = Color3.fromRGB(0, 255, 0)
    fill.Filled = true
    fill.Transparency = 1
    fill.Visible = false

    local txt = Drawing.new("Text")
    txt.Size = Config.ESP.Player.TextSize or 14
    txt.Font = Config.ESP.Player.TextFont or 2
    txt.Center = true
    txt.Outline = true
    txt.Color = Color3.fromRGB(255, 255, 255)
    txt.Visible = false

    return bg, fill, txt
end

local function ShowHealth(player)
    local bg, fill, txt = CreateHealthESP()

    local conn
    conn = RunService.RenderStepped:Connect(function()
        local char = ESPUtils.GetCharacter(player)
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        if not char or not hum or not hrp or hum.Health <= 0 or not Config.ESP.Player.Health or not ESPUtils.ShouldRender(player, hrp) then
            bg.Visible = false
            fill.Visible = false
            txt.Visible = false
            if not player or not player.Parent then
                bg:Remove(); fill:Remove(); txt:Remove()
                conn:Disconnect()
            end
            return
        end

        local hrpPos, onScreen = WorldToScreen(hrp.Position)
        if onScreen then
            local healthPercent = math.clamp(hum.Health / hum.MaxHealth, 0, 1)

            local barWidth  = 4
            local barHeight = 40
            local barX = hrpPos.X - 30
            local barY = hrpPos.Y - (barHeight / 2)

            bg.Position = Vector2.new(barX, barY)
            bg.Size     = Vector2.new(barWidth, barHeight)
            bg.Visible  = true

            local fillHeight = barHeight * healthPercent
            fill.Position = Vector2.new(barX, barY + (barHeight - fillHeight))
            fill.Size     = Vector2.new(barWidth, fillHeight)
            fill.Color    = Color3.fromRGB(255 * (1 - healthPercent), 255 * healthPercent, 0)
            fill.Visible  = true

            txt.Position = Vector2.new(barX + barWidth + 2, barY + (barHeight / 2) - 7)
            txt.Font     = Config.ESP.Player.TextFont or 2
            txt.Size     = (Config.ESP.Player.TextSize or 14) - 2
            txt.Text     = math.floor(hum.Health) .. " HP"
            txt.Visible  = true
        else
            bg.Visible = false
            fill.Visible = false
            txt.Visible = false
        end
    end)
end

local function Init()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Players.LocalPlayer then ShowHealth(p) end
    end
    Players.PlayerAdded:Connect(function(p)
        if p ~= Players.LocalPlayer then ShowHealth(p) end
    end)
end

Init()
end)()

-- 9. FEATURES / ESP / NAMES
Modules["features/esp/names"] = (function()
    local Config = Modules["core/config"]
    local ESPUtils = Modules["utils/esp_utils"]

local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")

local function WorldToScreen(pos)
    local vec, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(vec.X, vec.Y), onScreen
end

local function CreateTextTag()
    local txt = Drawing.new("Text")
    txt.Size    = Config.ESP.Player.TextSize or 14
    txt.Font    = Config.ESP.Player.TextFont or 2
    txt.Center  = true
    txt.Outline = true
    txt.Color   = Config.ESP.Player.NamesColor
    txt.Visible = false
    return txt
end

local function GetEquippedWeapon(char)
    local tool = char:FindFirstChildOfClass("Tool")
    return tool and ("[" .. tool.Name .. "]") or "[None]"
end

local function ShowPlayerESP(player)
    local nameTag   = CreateTextTag()
    local distTag   = CreateTextTag()
    local weaponTag = CreateTextTag()

    local conn
    conn = RunService.RenderStepped:Connect(function()
        local char = ESPUtils.GetCharacter(player)
        local head = char and char:FindFirstChild("Head")
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildOfClass("Humanoid")

        if not char or not head or not hrp or not hum or hum.Health <= 0 or not ESPUtils.ShouldRender(player, hrp) then
            nameTag.Visible = false
            distTag.Visible = false
            weaponTag.Visible = false
            if not player or not player.Parent then
                nameTag:Remove(); distTag:Remove(); weaponTag:Remove()
                conn:Disconnect()
            end
            return
        end

        local headPos, onScreen = WorldToScreen(head.Position + Vector3.new(0, 1.5, 0))
        local feetPos = WorldToScreen(hrp.Position - Vector3.new(0, 3, 0))

        if onScreen then
            local yOffset = 0

            if Config.ESP.Player.Names then
                nameTag.Position = Vector2.new(headPos.X, headPos.Y - 16)
                nameTag.Text     = player.DisplayName or player.Name
                nameTag.Color    = Config.ESP.Player.NamesColor
                nameTag.Font     = Config.ESP.Player.TextFont or 2
                nameTag.Size     = Config.ESP.Player.TextSize or 14
                nameTag.Visible  = true
            else
                nameTag.Visible = false
            end

            if Config.ESP.Player.Distance then
                local distMeters = math.floor(ESPUtils.GetDistance(hrp.Position))
                distTag.Position = Vector2.new(feetPos.X, feetPos.Y + yOffset)
                distTag.Text     = distMeters .. "m"
                distTag.Font     = Config.ESP.Player.TextFont or 2
                distTag.Size     = (Config.ESP.Player.TextSize or 14) - 2
                distTag.Visible  = true
                yOffset = yOffset + 14
            else
                distTag.Visible = false
            end

            if Config.ESP.Player.Weapon then
                weaponTag.Position = Vector2.new(feetPos.X, feetPos.Y + yOffset)
                weaponTag.Text     = GetEquippedWeapon(char)
                weaponTag.Font     = Config.ESP.Player.TextFont or 2
                weaponTag.Size     = (Config.ESP.Player.TextSize or 14) - 2
                weaponTag.Visible  = true
            else
                weaponTag.Visible = false
            end
        else
            nameTag.Visible = false
            distTag.Visible = false
            weaponTag.Visible = false
        end
    end)
end

local function Init()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Players.LocalPlayer then ShowPlayerESP(p) end
    end
    Players.PlayerAdded:Connect(function(p)
        if p ~= Players.LocalPlayer then ShowPlayerESP(p) end
    end)
end

Init()
end)()

-- 10. FEATURES / COMBAT / SILENT
Modules["features/combat/silent"] = (function()
    local Config = Modules["core/config"]
    local Sounds  = Modules["core/sounds"]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bullet            = require(ReplicatedStorage.Components.Weapon.Classes.Bullet)
local lp                = Players.LocalPlayer

local BodyPartsR15 = {
    ["Head"]             = {"Head"},
    ["Torso"]            = {"UpperTorso", "LowerTorso"},
    ["UpperTorso"]       = {"UpperTorso"},
    ["HumanoidRootPart"] = {"HumanoidRootPart"},
    ["Left Arm"]         = {"LeftUpperArm", "LeftLowerArm", "LeftHand"},
    ["Right Arm"]        = {"RightUpperArm", "RightLowerArm", "RightHand"},
    ["Left Leg"]         = {"LeftUpperLeg", "LeftLowerLeg", "LeftFoot"},
    ["Right Leg"]        = {"RightUpperLeg", "RightLowerLeg", "RightFoot"},
}

local function getCharacter(player)
    local chars = workspace:FindFirstChild("Characters")
    if not chars then return nil end
    return chars:FindFirstChild(player.Name)
end

local function isEnemy(plr)
    if plr == lp then return false end
    if not Config.Combat.TeamCheck then return true end
    local team   = plr:GetAttribute("Team")
    local myteam = lp:GetAttribute("Team")
    if workspace:GetAttribute("Gamemode") == "Deathmatch" then
        return team ~= "Spectators"
    end
    return team ~= nil and myteam ~= nil and team ~= myteam and team ~= "Spectators"
end

local function getTargetPart(char)
    if not char then return nil end
    local selected = Config.Combat.TargetPart or "Head"

    if selected == "Random" then
        local parts = {}
        for _, p in ipairs(char:GetChildren()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                table.insert(parts, p)
            end
        end
        if #parts > 0 then return parts[math.random(1, #parts)] end
    end

    local names = BodyPartsR15[selected] or {selected}
    for _, name in ipairs(names) do
        local part = char:FindFirstChild(name)
        if part then return part end
    end
    return char:FindFirstChild("Head") or char.PrimaryPart
end

local function getTarget(cam, origin, range)
    local bestPart, bestAngle
    local fovLimit = Config.Combat.FOV or 25

    for _, plr in ipairs(Players:GetPlayers()) do
        local char = getCharacter(plr)
        if isEnemy(plr) and char and not char:GetAttribute("Dead") then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local part = getTargetPart(char)
                if part then
                    local offset = part.Position - origin
                    local dist   = offset.Magnitude
                    if dist <= range and dist > 0 then
                        local angle = math.deg(math.acos(math.clamp(cam.CFrame.LookVector:Dot(offset.Unit), -1, 1)))
                        if angle <= fovLimit and (not bestAngle or angle < bestAngle) then
                            bestPart, bestAngle = part, angle
                        end
                    end
                end
            end
        end
    end
    return bestPart
end

local old
old = hookfunction(Bullet._performRaycast, function(self, spread)
    local result = old(self, spread)

    if not Config.Combat.SilentAim then return result end

    local chance = Config.Combat.HitChance or 100
    if math.random(1, 100) > chance then return result end

    local cam = workspace.CurrentCamera
    if not cam then return result end

    local origin     = cam.CFrame.Position
    local range      = (self.Properties and self.Properties.Range) or 500
    local targetPart = getTarget(cam, origin, range)
    if not targetPart then return result end

    Sounds.Play(Config.Combat.HitSound or "Gamesense")

    local dir = (targetPart.Position - origin).Unit
    result.Direction = dir
    result.Distance  = (targetPart.Position - origin).Magnitude
    result.Hits = {{
        Position = targetPart.Position,
        Instance = targetPart,
        Material = "Plastic",
        Normal   = -dir,
        Exit     = false
    }}
    return result
end)

end)()

-- 11. FEATURES / COMBAT / AIMBOT
Modules["features/combat/aimbot"] = (function()
    local Config = Modules["core/config"]

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Camera           = workspace.CurrentCamera
local RunService       = game:GetService("RunService")
local lp               = Players.LocalPlayer

local BodyPartsR15 = {
    ["Head"]             = {"Head"},
    ["Torso"]            = {"UpperTorso", "LowerTorso"},
    ["UpperTorso"]       = {"UpperTorso"},
    ["HumanoidRootPart"] = {"HumanoidRootPart"},
    ["Left Arm"]         = {"LeftUpperArm", "LeftLowerArm"},
    ["Right Arm"]        = {"RightUpperArm", "RightLowerArm"},
    ["Left Leg"]         = {"LeftUpperLeg", "LeftLowerLeg"},
    ["Right Leg"]        = {"RightUpperLeg", "RightLowerLeg"},
}

local function getCharacter(player)
    local chars = workspace:FindFirstChild("Characters")
    if not chars then return nil end
    return chars:FindFirstChild(player.Name)
end

local function isTeamMate(player)
    if player == lp then return true end
    if not Config.Combat.Aimbot.TeamCheck then return false end
    local team   = player:GetAttribute("Team")
    local myteam = lp:GetAttribute("Team")
    if workspace:GetAttribute("Gamemode") == "Deathmatch" then return false end
    return team ~= nil and myteam ~= nil and team == myteam
end

local function isVisible(part, char)
    if not Config.Combat.Aimbot.VisibleCheck then return true end
    if not part or not char then return false end
    local origin = Camera.CFrame.Position
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {Camera, getCharacter(lp)}
    local result = workspace:Raycast(origin, (part.Position - origin), raycastParams)
    if result then return result.Instance:IsDescendantOf(char) end
    return true
end

local function getTargetPart(char)
    if not char then return nil end
    local names = BodyPartsR15[Config.Combat.Aimbot.TargetPart or "Head"] or {"Head"}
    for _, name in ipairs(names) do
        local part = char:FindFirstChild(name)
        if part then return part end
    end
    return char:FindFirstChild("Head") or char.PrimaryPart
end

local function getClosestPlayerToCursor()
    local closestPart = nil
    local shortest    = Config.Combat.Aimbot.FOV or 25
    local mousePos    = UserInputService:GetMouseLocation()

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and not isTeamMate(plr) then
            local char = getCharacter(plr)
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local part = getTargetPart(char)
                if part and isVisible(part, char) then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        if dist <= shortest then
                            shortest     = dist
                            closestPart  = part
                        end
                    end
                end
            end
        end
    end

    return closestPart
end

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        Config.Combat.Aimbot.Aiming = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        Config.Combat.Aimbot.Aiming = false
    end
end)

RunService.RenderStepped:Connect(function()
    if not Config.Combat.Aimbot.Enabled or not Config.Combat.Aimbot.Aiming then return end

    local targetPart = getClosestPlayerToCursor()
    if not targetPart then return end

    local smoothness = math.clamp(Config.Combat.Aimbot.Smoothness or 5, 1, 20)

    if Config.Combat.Aimbot.Type == "Camera" then
        local targetCF = CFrame.lookAt(Camera.CFrame.Position, targetPart.Position)
        Camera.CFrame  = Camera.CFrame:Lerp(targetCF, 1 / smoothness)
    elseif Config.Combat.Aimbot.Type == "Mouse" then
        local screenPos = Camera:WorldToViewportPoint(targetPart.Position)
        local mousePos  = UserInputService:GetMouseLocation()
        local moveVec   = (Vector2.new(screenPos.X, screenPos.Y) - mousePos) / smoothness
        if mousemoverel then
            mousemoverel(moveVec.X, moveVec.Y)
        else
            local targetCF = CFrame.lookAt(Camera.CFrame.Position, targetPart.Position)
            Camera.CFrame  = Camera.CFrame:Lerp(targetCF, 1 / smoothness)
        end
    end
end)

end)()

-- 12. FEATURES / MISC / SKINS
Modules["features/misc/skins"] = (function()
    local Config = Modules["core/config"]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local CAS               = game:GetService("ContextActionService")
local Players           = game:GetService("Players")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Characters = workspace:WaitForChild("Characters", 5)

pcall(function()
    ReplicatedStorage.Assets.Weapons.Karambit.Camera.ViewmodelLight.Transparency = 1
end)

local knives = {
    ["Karambit"]        = {Offset = CFrame.new(0, -1.5, 1.5)},
    ["Butterfly Knife"] = {Offset = CFrame.new(0, -1.5, 1.5)},
    ["M9 Bayonet"]      = {Offset = CFrame.new(0, -1.5, 1)},
    ["Flip Knife"]      = {Offset = CFrame.new(0, -1.5, 1.25)},
    ["Gut Knife"]       = {Offset = CFrame.new(0, -1.5, 0.5)},
}

local spawned = false
local inspecting = false
local swinging = false
local lastAttackTime = 0
local ATTACK_COOLDOWN = 1
local ACTION_INSPECT = "AkiriInspectKnifeAction"
local ACTION_ATTACK  = "AkiriAttackKnifeAction"

local vm, animator
local equipAnim, idleAnim, inspectAnim
local HeavySwingAnim, Swing1Anim, Swing2Anim

local function isAlive()
    if not Characters then return false end
    local t  = Characters:FindFirstChild("Terrorists")
    local ct = Characters:FindFirstChild("Counter-Terrorists")
    return (t and t:FindFirstChild(player.Name)) or (ct and ct:FindFirstChild(player.Name))
end

local function getKnifeInCamera()
    return camera:FindFirstChild("T Knife") or camera:FindFirstChild("CT Knife")
end

local function cleanPart(part)
    if not part:IsA("BasePart") then return end
    part.CanCollide = false
    part.Anchored   = false
    part.CastShadow = false
    part.CanTouch   = false
    part.CanQuery   = false
end

local function disableCollisions(model)
    for _, part in model:GetDescendants() do cleanPart(part) end
end

local function hideOriginalKnife(knife)
    for _, part in knife:GetDescendants() do
        if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("Texture") then
            part.Transparency = 1
        end
    end
end

local function playSound(folder, name)
    local weaponSounds = ReplicatedStorage.Sounds:FindFirstChild(Config.SkinChanger.SelectedKnife)
    if not weaponSounds then return end
    local sf = weaponSounds:FindFirstChild(folder)
    if not sf then return end
    local so = sf:FindFirstChild(name)
    if not so then return end
    local sound = so:Clone()
    sound.Parent = camera
    sound:Play()
    sound.Ended:Once(function() sound:Destroy() end)
    return sound
end

local function attachAsset(folder, armPartName, assetModelName, finalName, offset)
    local targetArm = vm:FindFirstChild(armPartName)
    if not targetArm then return end
    local assetMesh = folder:WaitForChild(assetModelName, 2)
    if not assetMesh then return end
    assetMesh = assetMesh:Clone()
    cleanPart(assetMesh)
    assetMesh.Name   = finalName
    assetMesh.Parent = targetArm
    local motor  = Instance.new("Motor6D")
    motor.Part0  = targetArm
    motor.Part1  = assetMesh
    motor.C0     = offset
    motor.Parent = targetArm
end

local function handleAction(actionName, inputState)
    if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
    if not spawned or not animator or not isAlive() then return Enum.ContextActionResult.Pass end

    if actionName == ACTION_INSPECT then
        if (equipAnim and equipAnim.IsPlaying) or inspecting or swinging then return Enum.ContextActionResult.Pass end
        inspecting = true
        if idleAnim then idleAnim:Stop() end
        if inspectAnim then
            inspectAnim:Play()
            inspectAnim.Stopped:Once(function() inspecting = false end)
        else
            inspecting = false
        end
    elseif actionName == ACTION_ATTACK then
        local now = os.clock()
        if (equipAnim and equipAnim.IsPlaying) or (now - lastAttackTime < ATTACK_COOLDOWN) then return Enum.ContextActionResult.Pass end
        lastAttackTime = now
        if inspecting then
            inspecting = false
            if inspectAnim then inspectAnim:Stop() end
        end
        swinging = true
        if idleAnim then idleAnim:Stop() end
        local anims = {HeavySwingAnim, Swing1Anim, Swing2Anim}
        local chosen = anims[math.random(1, #anims)]
        if chosen then
            local sf = (chosen == HeavySwingAnim and "HitOne") or (chosen == Swing1Anim and "HitTwo") or "HitThree"
            chosen:Play()
            local s = playSound(sf, "1")
            if s then s.Volume = 5 end
            chosen.Stopped:Once(function() swinging = false end)
        else
            swinging = false
        end
    end

    return Enum.ContextActionResult.Pass
end

local function removeViewmodel()
    spawned = false
    CAS:UnbindAction(ACTION_INSPECT)
    CAS:UnbindAction(ACTION_ATTACK)
    if vm then vm:Destroy(); vm = nil end
    animator   = nil
    inspecting = false
    swinging   = false
end

local function spawnViewmodel(knife)
    if spawned or not Config.SkinChanger.CustomKnifeEnabled then return end
    local myModel = isAlive()
    if not myModel then return end
    spawned = true

    local selectedKnife = Config.SkinChanger.SelectedKnife
    local weaponsFolder = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Weapons")
    if not weaponsFolder then return end
    local knifeTemplate = weaponsFolder:FindFirstChild(selectedKnife)
    if not knifeTemplate then return end

    local knifeOffset = (knives[selectedKnife] or {Offset = CFrame.new(0, -1.5, 1.5)}).Offset

    vm = knifeTemplate:WaitForChild("Camera"):Clone()
    vm.Name   = selectedKnife
    vm.Parent = camera
    disableCollisions(vm)
    hideOriginalKnife(knife)

    if myModel.Parent.Name == "Terrorists" then
        local tGloves = weaponsFolder:FindFirstChild("T Glove")
        if tGloves then
            attachAsset(tGloves, "Left Arm",  "Left Arm",  "Glove", CFrame.new(0, 0, -1.5))
            attachAsset(tGloves, "Right Arm", "Right Arm", "Glove", CFrame.new(0, 0, -1.5))
        end
    else
        local sleeves  = ReplicatedStorage.Assets:FindFirstChild("Sleeves") and ReplicatedStorage.Assets.Sleeves:FindFirstChild("IDF")
        local ctGloves = weaponsFolder:FindFirstChild("CT Glove")
        if sleeves and ctGloves then
            attachAsset(sleeves,  "Left Arm",  "Left Arm",  "Sleeve", CFrame.new(0, 0, 0.5))
            attachAsset(ctGloves, "Left Arm",  "Left Arm",  "Glove",  CFrame.new(0, 0, -1.5))
            attachAsset(sleeves,  "Right Arm", "Right Arm", "Sleeve", CFrame.new(0, 0, 0.5))
            attachAsset(ctGloves, "Right Arm", "Right Arm", "Glove",  CFrame.new(0, 0, -1.5))
        end
    end

    local animController = vm:FindFirstChildOfClass("AnimationController") or vm:FindFirstChildOfClass("Animator")
    animator = animController and (animController:FindFirstChildWhichIsA("Animator") or animController)

    local animFolder = ReplicatedStorage.Assets:FindFirstChild("WeaponAnimations")
        and ReplicatedStorage.Assets.WeaponAnimations:FindFirstChild(selectedKnife)
        and ReplicatedStorage.Assets.WeaponAnimations[selectedKnife]:FindFirstChild("CameraAnimations")

    if animFolder and animator then
        equipAnim      = animFolder:FindFirstChild("Equip")        and animator:LoadAnimation(animFolder.Equip)
        idleAnim       = animFolder:FindFirstChild("Idle")         and animator:LoadAnimation(animFolder.Idle)
        inspectAnim    = animFolder:FindFirstChild("Inspect")      and animator:LoadAnimation(animFolder.Inspect)
        HeavySwingAnim = animFolder:FindFirstChild("Heavy Swing")  and animator:LoadAnimation(animFolder["Heavy Swing"])
        Swing1Anim     = animFolder:FindFirstChild("Swing1")       and animator:LoadAnimation(animFolder.Swing1)
        Swing2Anim     = animFolder:FindFirstChild("Swing2")       and animator:LoadAnimation(animFolder.Swing2)
    end

    vm:SetPrimaryPartCFrame(camera.CFrame * CFrame.new(0, -1.5, 5))
    TweenService:Create(vm.PrimaryPart, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        CFrame = camera.CFrame * knifeOffset
    }):Play()

    if equipAnim then equipAnim:Play() end
    playSound("Equip", "1")
    CAS:BindAction(ACTION_INSPECT, handleAction, false, Enum.KeyCode.F)
    CAS:BindAction(ACTION_ATTACK,  handleAction, false, Enum.UserInputType.MouseButton1)
end

RunService.RenderStepped:Connect(function()
    if not Config.SkinChanger.CustomKnifeEnabled or not vm or not vm.PrimaryPart then return end
    local knifeOffset = (knives[Config.SkinChanger.SelectedKnife] or {Offset = CFrame.new(0, -1.5, 1.5)}).Offset
    vm.PrimaryPart.CFrame = camera.CFrame * knifeOffset
    if not (equipAnim and equipAnim.IsPlaying) and not inspecting and not swinging then
        if idleAnim and not idleAnim.IsPlaying then idleAnim:Play() end
    end
end)

task.spawn(function()
    while true do
        local living      = isAlive()
        local currentKnife = getKnifeInCamera()
        if Config.SkinChanger.CustomKnifeEnabled and living and currentKnife and not spawned then
            spawnViewmodel(currentKnife)
        elseif (not Config.SkinChanger.CustomKnifeEnabled or not currentKnife or not living) and spawned then
            removeViewmodel()
        end
        task.wait(0.1)
    end
end)

local GLOVES     = { ["Sports Gloves"] = true }
local SkinsFolder = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Skins")

local function applyWeaponSkin(model)
    if not model or not Config.SkinChanger.Enabled or not isAlive() or not SkinsFolder then return end
    local skinName = Config.SkinChanger.SelectedSkins[model.Name]
    if not skinName then return end

    pcall(function()
        local skinFolder  = SkinsFolder:FindFirstChild(model.Name)
        if not skinFolder then return end
        local skinType    = skinFolder:FindFirstChild(skinName)
        local sourceFolder = skinType and skinType:FindFirstChild("Camera") and skinType.Camera:FindFirstChild(Config.SkinChanger.Wear)
        if not sourceFolder then return end

        for _, obj in camera:GetChildren() do
            if obj:FindFirstChild("Left Arm") or obj:FindFirstChild("Right Arm") then
                local gloveFolder      = SkinsFolder:FindFirstChild("Sports Gloves")
                local selectedGloveSkin = Config.SkinChanger.SelectedSkins["Sports Gloves"]
                local gloveSkin        = gloveFolder and selectedGloveSkin and gloveFolder:FindFirstChild(selectedGloveSkin)
                local gloveSource      = gloveSkin and gloveSkin:FindFirstChild("Camera") and gloveSkin.Camera:FindFirstChild(Config.SkinChanger.Wear)
                if gloveSource then
                    for _, side in {"Left Arm", "Right Arm"} do
                        local arm  = obj:FindFirstChild(side)
                        local src  = gloveSource:FindFirstChild(side)
                        if arm and src then
                            local gloveMesh = arm:FindFirstChild("Glove")
                            if gloveMesh then
                                local ex = gloveMesh:FindFirstChildOfClass("SurfaceAppearance")
                                if ex then ex:Destroy() end
                                local clone = src:Clone()
                                clone.Name   = "SurfaceAppearance"
                                clone.Parent = gloveMesh
                            end
                        end
                    end
                end
            end
        end

        if not GLOVES[model.Name] then
            local weaponFolder = model:FindFirstChild("Weapon")
            if weaponFolder then
                for _, part in weaponFolder:GetDescendants() do
                    if part:IsA("BasePart") then
                        local newSkin = sourceFolder:FindFirstChild(part.Name)
                        if newSkin then
                            local ex = part:FindFirstChildOfClass("SurfaceAppearance")
                            if ex then ex:Destroy() end
                            local clone = newSkin:Clone()
                            clone.Name   = "SurfaceAppearance"
                            clone.Parent = part
                        end
                    end
                end
            end
        end

        model:SetAttribute("SkinApplied", skinName)
    end)
end

camera.ChildAdded:Connect(function(obj)
    if not Config.SkinChanger.Enabled or not isAlive() then return end
    task.wait(0.1)
    applyWeaponSkin(obj)
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        if Config.SkinChanger.Enabled and isAlive() then
            for _, obj in camera:GetChildren() do
                if Config.SkinChanger.SelectedSkins[obj.Name] and obj:GetAttribute("SkinApplied") ~= Config.SkinChanger.SelectedSkins[obj.Name] then
                    applyWeaponSkin(obj)
                end
            end
        end
    end
end)

local Skins = {}
function Skins.Apply(model) applyWeaponSkin(model) end
return Skins

end)()

-- 13. MAIN ENTRYPOINT
local Config = Modules["core/config"]
local Notif  = Modules["utils/notifications"]

local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

local Window = WindUI:CreateWindow({
    Title  = "Akiri Hub",
    Icon   = "crosshair",
    Author = "Akiri Team",
    Folder = "AkiriConfig"
})

Notif.Notify("Akiri Hub", "¡Cargado exitosamente!", 5)

-- TAB COMBAT
local TabCombat     = Window:Tab({ Title = "Combat",       Icon = "swords" })
local SectionAimbot = TabCombat:Section({ Title = "Aimbot (Hold Right Click)" })

SectionAimbot:Toggle({
    Title = "Aimbot Enabled", Value = Config.Combat.Aimbot.Enabled,
    Callback = function(s) Config.Combat.Aimbot.Enabled = s; Notif.Notify("Aimbot", s and "Activado" or "Desactivado", 2) end
})
SectionAimbot:Dropdown({
    Title = "Aim Method", Values = {"Camera", "Mouse"}, Value = Config.Combat.Aimbot.Type,
    Callback = function(v) Config.Combat.Aimbot.Type = v end
})
SectionAimbot:Slider({
    Title = "Smoothness", Value = { Min = 1, Max = 20, Default = Config.Combat.Aimbot.Smoothness }, Step = 1,
    Callback = function(v) Config.Combat.Aimbot.Smoothness = v end
})
SectionAimbot:Dropdown({
    Title = "Target Hitbox (Aimbot)",
    Values = {"Head","Torso","UpperTorso","HumanoidRootPart","Left Arm","Right Arm","Left Leg","Right Leg"},
    Value = Config.Combat.Aimbot.TargetPart,
    Callback = function(v) Config.Combat.Aimbot.TargetPart = v end
})
SectionAimbot:Slider({
    Title = "Aimbot FOV", Value = { Min = 5, Max = 180, Default = Config.Combat.Aimbot.FOV }, Step = 1,
    Callback = function(v) Config.Combat.Aimbot.FOV = v end
})

local SectionSilent = TabCombat:Section({ Title = "Silent Aim" })

SectionSilent:Toggle({
    Title = "Silent Aim Enabled", Value = Config.Combat.SilentAim,
    Callback = function(s) Config.Combat.SilentAim = s; Notif.Notify("Silent Aim", s and "Activado" or "Desactivado", 2) end
})
SectionSilent:Slider({
    Title = "Hit Chance (%)", Value = { Min = 0, Max = 100, Default = Config.Combat.HitChance }, Step = 1,
    Callback = function(v) Config.Combat.HitChance = v end
})
SectionSilent:Dropdown({
    Title = "Hit Sound Effect", Values = {"Gamesense","GamesenseOld","Neverlose"}, Value = Config.Combat.HitSound,
    Callback = function(v) Config.Combat.HitSound = v end
})
SectionSilent:Toggle({
    Title = "Team Check (Silent)", Value = Config.Combat.TeamCheck,
    Callback = function(s) Config.Combat.TeamCheck = s end
})
SectionSilent:Dropdown({
    Title = "Target Hitbox (Silent)",
    Values = {"Head","Torso","UpperTorso","HumanoidRootPart","Left Arm","Right Arm","Left Leg","Right Leg","Random"},
    Value = Config.Combat.TargetPart,
    Callback = function(v) Config.Combat.TargetPart = v end
})
SectionSilent:Slider({
    Title = "Silent FOV Radius", Value = { Min = 5, Max = 180, Default = Config.Combat.FOV }, Step = 1,
    Callback = function(v) Config.Combat.FOV = v end
})

-- TAB ESP
local TabESP        = Window:Tab({ Title = "Visuals (ESP)", Icon = "eye" })
local SectionGeneral = TabESP:Section({ Title = "General" })

SectionGeneral:Toggle({
    Title = "Master ESP Enabled", Value = Config.ESP.Enabled,
    Callback = function(s) Config.ESP.Enabled = s; Notif.Notify("Master ESP", s and "Activado" or "Desactivado", 2) end
})
SectionGeneral:Toggle({
    Title = "Team Check", Value = Config.ESP.TeamCheck,
    Callback = function(s) Config.ESP.TeamCheck = s end
})
SectionGeneral:Slider({
    Title = "Max Distance", Value = { Min = 100, Max = 5000, Default = Config.ESP.MaxDistance }, Step = 50,
    Callback = function(v) Config.ESP.MaxDistance = v end
})
SectionGeneral:Toggle({
    Title = "Visible Check", Value = Config.ESP.VisibleCheck,
    Callback = function(s) Config.ESP.VisibleCheck = s end
})

local SectionBox = TabESP:Section({ Title = "Box" })
SectionBox:Toggle({
    Title = "Box ESP Enabled", Value = Config.ESP.Box.Enabled,
    Callback = function(s) Config.ESP.Box.Enabled = s end
})
SectionBox:Dropdown({
    Title = "Box Type", Values = {"2D","Corner"}, Value = Config.ESP.Box.Type,
    Callback = function(v) Config.ESP.Box.Type = v end
})
SectionBox:Colorpicker({
    Title = "Box Color", Default = Config.ESP.Box.Color,
    Callback = function(c) Config.ESP.Box.Color = c end
})
SectionBox:Slider({
    Title = "Box Thickness", Value = { Min = 1, Max = 5, Default = Config.ESP.Box.Thickness }, Step = 1,
    Callback = function(v) Config.ESP.Box.Thickness = v end
})
SectionBox:Slider({
    Title = "Box Transparency", Value = { Min = 0.1, Max = 1, Default = Config.ESP.Box.Transparency }, Step = 0.1,
    Callback = function(v) Config.ESP.Box.Transparency = v end
})

local SectionPlayer = TabESP:Section({ Title = "Player" })
SectionPlayer:Toggle({ Title = "Player Names",    Value = Config.ESP.Player.Names,    Callback = function(s) Config.ESP.Player.Names    = s end })
SectionPlayer:Toggle({ Title = "Player Health",   Value = Config.ESP.Player.Health,   Callback = function(s) Config.ESP.Player.Health   = s end })
SectionPlayer:Toggle({ Title = "Player Distance", Value = Config.ESP.Player.Distance, Callback = function(s) Config.ESP.Player.Distance = s end })
SectionPlayer:Toggle({ Title = "Player Weapon",   Value = Config.ESP.Player.Weapon,   Callback = function(s) Config.ESP.Player.Weapon   = s end })
SectionPlayer:Colorpicker({
    Title = "Names Color", Default = Config.ESP.Player.NamesColor,
    Callback = function(c) Config.ESP.Player.NamesColor = c end
})

local SectionSkeleton = TabESP:Section({ Title = "Skeleton" })
SectionSkeleton:Toggle({
    Title = "Skeleton Enabled", Value = Config.ESP.Skeleton.Enabled,
    Callback = function(s) Config.ESP.Skeleton.Enabled = s end
})
SectionSkeleton:Colorpicker({
    Title = "Skeleton Color", Default = Config.ESP.Skeleton.Color,
    Callback = function(c) Config.ESP.Skeleton.Color = c end
})
SectionSkeleton:Slider({
    Title = "Skeleton Thickness", Value = { Min = 1, Max = 5, Default = Config.ESP.Skeleton.Thickness }, Step = 1,
    Callback = function(v) Config.ESP.Skeleton.Thickness = v end
})
SectionSkeleton:Slider({
    Title = "Skeleton Transparency", Value = { Min = 0.1, Max = 1, Default = Config.ESP.Skeleton.Transparency }, Step = 0.1,
    Callback = function(v) Config.ESP.Skeleton.Transparency = v end
})

local SectionMisc = TabESP:Section({ Title = "Misc" })
SectionMisc:Toggle({
    Title = "Show Teammates", Value = Config.ESP.Misc.ShowTeammates,
    Callback = function(s) Config.ESP.Misc.ShowTeammates = s end
})
SectionMisc:Toggle({
    Title = "Out of View Arrows", Value = Config.ESP.Misc.Arrows,
    Callback = function(s) Config.ESP.Misc.Arrows = s end
})
SectionMisc:Colorpicker({
    Title = "Arrows Color", Default = Config.ESP.Misc.ArrowsColor,
    Callback = function(c) Config.ESP.Misc.ArrowsColor = c end
})

-- TAB SKINS
local TabSkins          = Window:Tab({ Title = "Skins", Icon = "palette" })
local SectionGeneralSkins = TabSkins:Section({ Title = "Skin Changer" })
SectionGeneralSkins:Toggle({
    Title = "Enable Skin Changer", Value = Config.SkinChanger.Enabled,
    Callback = function(s) Config.SkinChanger.Enabled = s; Notif.Notify("Skin Changer", s and "Activado" or "Desactivado", 2) end
})

local SectionKnives = TabSkins:Section({ Title = "Custom Knives" })
SectionKnives:Toggle({
    Title = "Enable Custom Knife", Value = Config.SkinChanger.CustomKnifeEnabled,
    Callback = function(s) Config.SkinChanger.CustomKnifeEnabled = s; Notif.Notify("Custom Knife", s and "Activado" or "Desactivado", 2) end
})
SectionKnives:Dropdown({
    Title = "Select Custom Knife",
    Values = {"Butterfly Knife","Karambit","M9 Bayonet","Flip Knife","Gut Knife"},
    Value = Config.SkinChanger.SelectedKnife,
    Callback = function(v) Config.SkinChanger.SelectedKnife = v; Notif.Notify("Knife Selected", v, 2) end
})

print("[Akiri Hub] Cargado correctamente V3.")
