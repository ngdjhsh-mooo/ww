--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║      AXIOM — PS99 WORLD 2 (MAP 143) CLAW MACHINE v3.0       ║
    ║      Engineered for Pet Simulator 99 Instancing Framework    ║
    ║      GitHub / Loadstring Compatible                          ║
    ╚══════════════════════════════════════════════════════════════╝
]]--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- ═══════════════════════════════════════════
-- PS99 FRAMEWORK HOOKS
-- ═══════════════════════════════════════════
local PS99 = {
    Library = nil,
    Network = nil,
    Instancing = nil
}

pcall(function()
    if ReplicatedStorage:FindFirstChild("Library") then
        local lib = ReplicatedStorage.Library
        if lib:FindFirstChild("Client") then
            PS99.Library = require(lib.Client)
            PS99.Network = PS99.Library.Network
        end
    end
end)

local function FirePS99Remote(name, ...)
    if PS99.Network and PS99.Network.Fire then
        pcall(function()
            PS99.Network.Fire(name, ...)
        end)
    end
    -- Fallback to direct network folder
    local netFolder = ReplicatedStorage:FindFirstChild("Network")
    if netFolder then
        local remote = netFolder:FindFirstChild(name)
        if remote and remote:IsA("RemoteEvent") then
            pcall(function() remote:FireServer(...) end)
        end
    end
end

local function InvokePS99Remote(name, ...)
    if PS99.Network and PS99.Network.Invoke then
        local res
        pcall(function()
            res = PS99.Network.Invoke(name, ...)
        end)
        return res
    end
    local netFolder = ReplicatedStorage:FindFirstChild("Network")
    if netFolder then
        local remote = netFolder:FindFirstChild(name)
        if remote and remote:IsA("RemoteFunction") then
            local success, res = pcall(function() return remote:InvokeServer(...) end)
            if success then return res end
        end
    end
    return nil
end

-- ═══════════════════════════════════════════
-- CONFIGURATION
-- ═══════════════════════════════════════════
local Config = {
    FullAuto = false,
    AutoEnterMinigame = true,
    AutoPlayClaw = true,
    AutoGrabEggs = true,
    AutoServerHop = true,
    MinEggsBeforeHop = 0,
    EmptyCheckThreshold = 3,
    
    -- Map 143 Specifics
    TargetMapId = 143,
    MinigameInstanceName = "ClawMachine", -- PS99 Instance ID
    World2PlaceId = 16498369169,
    
    -- Tuning
    CycleDelay = 0.4,
    ServerHopCooldown = 8,
    AntiAFK = true,
    ToggleKey = Enum.KeyCode.RightShift,
    UIVisible = true
}

local State = {
    EggsFound = 0,
    EmptyStreak = 0,
    TotalHops = 0,
    TotalPlayed = 0,
    IsHopping = false,
    InMinigame = false,
    LastHopTick = 0
}

-- ═══════════════════════════════════════════
-- ANTI-AFK
-- ═══════════════════════════════════════════
if Config.AntiAFK then
    Player.Idled:Connect(function()
        local vu = game:GetService("VirtualUser")
        vu:Button2Down(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
        task.wait(1)
        vu:Button2Up(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
    end)
end

-- ═══════════════════════════════════════════
-- MAP 143 & MINIGAME INSTANCE TELEPORTER
-- ═══════════════════════════════════════════
local MinigameEngine = {}

function MinigameEngine:TeleportToMap143()
    -- Method 1: PS99 Area Teleport
    pcall(function()
        FirePS99Remote("Teleports_RequestTeleport", "Area 143")
        FirePS99Remote("Teleporting_TeleportArea", 143)
    end)
    
    -- Method 2: Physical Area Search
    local mapFolder = Workspace:FindFirstChild("Map") or Workspace:FindFirstChild("Worlds")
    if mapFolder then
        for _, area in ipairs(mapFolder:GetDescendants()) do
            if area.Name:find("143") or area.Name:lower():find("claw") or area.Name:lower():find("arcade") then
                local part = area:IsA("BasePart") and area or (area:IsA("Model") and area.PrimaryPart)
                if part then
                    HumanoidRootPart.CFrame = part.CFrame + Vector3.new(0, 5, 0)
                    break
                end
            end
        end
    end
end

function MinigameEngine:EnterClawMinigame()
    print("[Axiom] Attempting direct Minigame Instance Request...")
    
    -- 1. Try PS99 Instancing Remote directly
    local instanceNames = {"ClawMachine", "Claw Machine", "Arcade", "Claw_Machine", "MiniGame_ClawMachine"}
    for _, inst in ipairs(instanceNames) do
        pcall(function()
            InvokePS99Remote("Instancing_RequestTeleport", inst)
            FirePS99Remote("Instancing_RequestTeleport", inst)
            InvokePS99Remote("Instancing_Enter", inst)
            FirePS99Remote("Instancing_Enter", inst)
        end)
    end
    
    -- 2. Scan for physical prompts / pads in map 143
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and (obj.Parent.Name:lower():find("claw") or obj.Parent.Name:lower():find("enter") or obj.Parent.Name:lower():find("play")) then
            fireproximityprompt(obj)
        elseif obj:IsA("TouchTransmitter") and obj.Parent and obj.Parent.Name:lower():find("portal") then
            firetouchinterest(HumanoidRootPart, obj.Parent, 0)
            task.wait(0.1)
            firetouchinterest(HumanoidRootPart, obj.Parent, 1)
        end
    end
end

function MinigameEngine:CheckIfInMinigame()
    -- Check if instance world loaded or claw container is present
    if Workspace:FindFirstChild("__INSTANCES") or Workspace:FindFirstChild("ActiveInstance") or Workspace:FindFirstChild("ClawMachine") then
        State.InMinigame = true
        return true
    end
    
    -- Check UI elements
    local pGui = Player:FindFirstChild("PlayerGui")
    if pGui and (pGui:FindFirstChild("ClawMachine") or pGui:FindFirstChild("ArcadeMachine") or pGui:FindFirstChild("_MACHINES")) then
        State.InMinigame = true
        return true
    end
    
    return false
end

-- ═══════════════════════════════════════════
-- EGG & PRIZE SCANNER
-- ═══════════════════════════════════════════
local EggScanner = {}

function EggScanner:CountEggs()
    local count = 0
    local targetContainers = {
        Workspace:FindFirstChild("__INSTANCES"),
        Workspace:FindFirstChild("ActiveInstance"),
        Workspace:FindFirstChild("ClawMachine"),
        Workspace:FindFirstChild("Map"),
        Workspace
    }
    
    for _, container in ipairs(targetContainers) do
        if container then
            for _, obj in ipairs(container:GetDescendants()) do
                local name = obj.Name:lower()
                if (name:find("egg") or name:find("prize") or name:find("reward") or name:find("capsule") or name:find("loot")) 
                   and (obj:IsA("BasePart") or obj:IsA("Model") or obj:IsA("MeshPart")) then
                    if obj:IsA("BasePart") and obj.Transparency < 1 and obj.Size.Magnitude > 0.5 then
                        count = count + 1
                    elseif obj:IsA("Model") and obj.PrimaryPart and obj.PrimaryPart.Transparency < 1 then
                        count = count + 1
                    end
                end
            end
        end
    end
    
    State.EggsFound = count
    return count
end

function EggScanner:IsDepleted()
    local count = self:CountEggs()
    if count <= Config.MinEggsBeforeHop then
        State.EmptyStreak = State.EmptyStreak + 1
    else
        State.EmptyStreak = 0
    end
    
    return State.EmptyStreak >= Config.EmptyCheckThreshold
end

-- ═══════════════════════════════════════════
-- CLAW AUTOMATION CORE
-- ═══════════════════════════════════════════
local ClawBot = {}

function ClawBot:DropClawOnBestEgg()
    -- Direct remote call to drop claw
    local remotes = {
        "ClawMachine_Play", "ClawMachine_Drop", "ClawMachine_Grab",
        "Arcade_Play", "Claw_Drop", "Minigame_Play"
    }
    
    for _, rem in ipairs(remotes) do
        FirePS99Remote(rem)
        InvokePS99Remote(rem)
    end
    
    -- If there are interactive claw parts, move humanoid near control or touch
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "ClawLever" or obj.Name == "PlayButton" or obj.Name == "DropButton" then
            if obj:IsA("ProximityPrompt") then
                fireproximityprompt(obj)
            elseif obj:IsA("ClickDetector") then
                fireclickdetector(obj)
            end
        end
    end
    
    State.TotalPlayed = State.TotalPlayed + 1
end

-- ═══════════════════════════════════════════
-- ROBUST SERVER HOPPER (PS99 PLACE ID)
-- ═══════════════════════════════════════════
local ServerHop = {}

function ServerHop:Hop()
    if State.IsHopping then return end
    if (tick() - State.LastHopTick) < Config.ServerHopCooldown then return end
    
    State.IsHopping = true
    State.LastHopTick = tick()
    State.TotalHops = State.TotalHops + 1
    
    print("[Axiom] Hopping server... fetching server list for PlaceId " .. game.PlaceId)
    
    local placeId = game.PlaceId
    local serversApi = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
    
    local success, response = pcall(function()
        return game:HttpGet(serversApi)
    end)
    
    if success and response then
        local data = HttpService:JSONDecode(response)
        if data and data.data then
            local validServers = {}
            for _, s in ipairs(data.data) do
                if s.playing and s.maxPlayers and s.id ~= game.JobId and s.playing < s.maxPlayers then
                    table.insert(validServers, s.id)
                end
            end
            
            if #validServers > 0 then
                local chosenServer = validServers[math.random(1, math.min(10, #validServers))]
                print("[Axiom] Teleporting to server ID: " .. chosenServer)
                TeleportService:TeleportToPlaceInstance(placeId, chosenServer, Player)
                task.wait(10)
            end
        end
    end
    
    -- Fallback normal teleport
    TeleportService:Teleport(placeId, Player)
    State.IsHopping = false
end

-- ═══════════════════════════════════════════
-- MAIN ORCHESTRATION LOOP
-- ═══════════════════════════════════════════
local function RunPipeline()
    task.spawn(function()
        while true do
            if Config.FullAuto then
                -- 1. Check if we need to enter minigame
                if not MinigameEngine:CheckIfInMinigame() then
                    MinigameEngine:TeleportToMap143()
                    task.wait(1)
                    MinigameEngine:EnterClawMinigame()
                    task.wait(2)
                end
                
                -- 2. Check egg count
                if Config.AutoServerHop and EggScanner:IsDepleted() then
                    print("[Axiom] 0 Eggs remaining detected! Initiating server hop...")
                    ServerHop:Hop()
                    task.wait(10)
                else
                    -- 3. Execute Claw Play
                    if Config.AutoPlayClaw then
                        ClawBot:DropClawOnBestEgg()
                    end
                end
            end
            task.wait(Config.CycleDelay)
        end
    end)
end

-- ═══════════════════════════════════════════
-- COMPACT MODERN UI
-- ═══════════════════════════════════════════
local function BuildUI()
    local old = Player.PlayerGui:FindFirstChild("AxiomPS99Claw")
    if old then old:Destroy() end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "AxiomPS99Claw"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = Player.PlayerGui
    
    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0, 310, 0, 390)
    Main.Position = UDim2.new(0, 30, 0.5, -195)
    Main.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
    Main.BorderSizePixel = 0
    Main.Parent = ScreenGui
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 10)
    Corner.Parent = Main
    
    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(130, 90, 255)
    Stroke.Thickness = 1.8
    Stroke.Parent = Main
    
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -20, 0, 35)
    Title.Position = UDim2.new(0, 15, 0, 8)
    Title.BackgroundTransparency = 1
    Title.Text = "⚡ AXIOM — PS99 CLAW MAP 143"
    Title.TextColor3 = Color3.fromRGB(180, 140, 255)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 14
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Main
    
    local StatBox = Instance.new("TextLabel")
    StatBox.Size = UDim2.new(1, -30, 0, 45)
    StatBox.Position = UDim2.new(0, 15, 0, 45)
    StatBox.BackgroundColor3 = Color3.fromRGB(22, 25, 38)
    StatBox.Text = "🥚 Eggs: Scanning... | Hops: 0\nStatus: Ready"
    StatBox.TextColor3 = Color3.fromRGB(160, 230, 180)
    StatBox.Font = Enum.Font.GothamMedium
    StatBox.TextSize = 11
    StatBox.Parent = Main
    
    local StatCorner = Instance.new("UICorner")
    StatCorner.CornerRadius = UDim.new(0, 6)
    StatCorner.Parent = StatBox
    
    local function AddBtn(text, pos_y, color, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -30, 0, 34)
        btn.Position = UDim2.new(0, 15, 0, pos_y)
        btn.BackgroundColor3 = color
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.Parent = Main
        
        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 6)
        bCorner.Parent = btn
        
        btn.MouseButton1Click:Connect(function()
            callback(btn)
        end)
        return btn
    end
    
    AddBtn("🔥 TOGGLE FULL AUTO (MAP 143 + HOP)", 100, Color3.fromRGB(110, 50, 220), function(btn)
        Config.FullAuto = not Config.FullAuto
        if Config.FullAuto then
            btn.BackgroundColor3 = Color3.fromRGB(30, 160, 80)
            btn.Text = "✔ FULL AUTO RUNNING"
        else
            btn.BackgroundColor3 = Color3.fromRGB(110, 50, 220)
            btn.Text = "🔥 TOGGLE FULL AUTO (MAP 143 + HOP)"
        end
    end)
    
    AddBtn("🗺 FORCE TP TO MAP 143 / CLAW", 142, Color3.fromRGB(40, 60, 120), function()
        MinigameEngine:TeleportToMap143()
        MinigameEngine:EnterClawMinigame()
    end)
    
    AddBtn("🎮 DROP CLAW NOW", 184, Color3.fromRGB(50, 100, 70), function()
        ClawBot:DropClawOnBestEgg()
    end)
    
    AddBtn("🔄 MANUAL SERVER HOP", 226, Color3.fromRGB(140, 80, 40), function()
        ServerHop:Hop()
    end)
    
    local Footer = Instance.new("TextLabel")
    Footer.Size = UDim2.new(1, 0, 0, 20)
    Footer.Position = UDim2.new(0, 0, 1, -25)
    Footer.BackgroundTransparency = 1
    Footer.Text = "[RightShift] Toggle UI | Axiom v3.0"
    Footer.TextColor3 = Color3.fromRGB(100, 100, 140)
    Footer.Font = Enum.Font.Gotham
    Footer.TextSize = 10
    Footer.Parent = Main
    
    UserInputService.InputBegan:Connect(function(input, gpe)
        if not gpe and input.KeyCode == Config.ToggleKey then
            Main.Visible = not Main.Visible
        end
    end)
    
    task.spawn(function()
        while ScreenGui.Parent do
            pcall(function()
                local count = EggScanner:CountEggs()
                local status = Config.FullAuto and (State.IsHopping and "Hopping Server..." or "Farming...") or "Paused"
                StatBox.Text = string.format("🥚 Eggs: %d | Drops: %d | Hops: %d\nStatus: %s", count, State.TotalPlayed, State.TotalHops, status)
            end)
            task.wait(1.5)
        end
    end)
end

-- ═══════════════════════════════════════════
-- INIT
-- ═══════════════════════════════════════════
print("[Axiom] PS99 Map 143 Claw Automation Loaded!")
BuildUI()
RunPipeline()
