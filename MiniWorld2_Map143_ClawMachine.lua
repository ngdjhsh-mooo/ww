--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║      AXIOM — PS99 WORLD 2 (MAP 143) CLAW MACHINE v4.0       ║
    ║      Executor-Proof GUI + Instant Auto-Runner                ║
    ║      Loadstring / GitHub Ready                               ║
    ╚══════════════════════════════════════════════════════════════╝
]]--

-- Prevent multiple instances
if getgenv and getgenv().AxiomLoaded then
    if getgenv().AxiomCleanup then getgenv().AxiomCleanup() end
end
if getgenv then getgenv().AxiomLoaded = true end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer

-- Safe Parent Finder for Executed Guis
local function GetSafeGuiParent()
    local success, parent = pcall(function()
        if gethui then return gethui() end
        if syn and syn.protect_gui then
            local g = Instance.new("Folder")
            syn.protect_gui(g)
            g.Parent = CoreGui
            return g
        end
        return CoreGui
    end)
    if success and parent then return parent end
    return Player:WaitForChild("PlayerGui")
end

-- ═══════════════════════════════════════════
-- CONFIG & STATE
-- ═══════════════════════════════════════════
local Config = {
    FullAuto = true,           -- Starts automatically
    AutoTeleportMap = true,
    AutoPlayClaw = true,
    AutoHopWhenEmpty = true,
    MinEggsBeforeHop = 0,
    EmptyCheckCount = 3,
    CycleDelay = 0.5,
    TargetArea = 143,
    PlaceId = game.PlaceId
}

local State = {
    Eggs = 0,
    EmptyStreak = 0,
    TotalPlays = 0,
    TotalHops = 0,
    IsHopping = false,
    Status = "Starting Up...",
    StartTime = tick()
}

-- ═══════════════════════════════════════════
-- ANTI-AFK (Zero Crash Implementation)
-- ═══════════════════════════════════════════
task.spawn(function()
    pcall(function()
        Player.Idled:Connect(function()
            local vu = game:GetService("VirtualUser")
            vu:CaptureController()
            vu:ClickButton2(Vector2.new(50, 50))
        end)
    end)
end)

-- ═══════════════════════════════════════════
-- PS99 NETWORK BRIDGE
-- ═══════════════════════════════════════════
local function FireNetwork(name, ...)
    local args = {...}
    -- Method 1: PS99 Library Fire
    pcall(function()
        local lib = require(ReplicatedStorage.Library.Client)
        if lib and lib.Network and lib.Network.Fire then
            lib.Network.Fire(name, unpack(args))
        end
    end)
    -- Method 2: Direct Network Folder
    pcall(function()
        local net = ReplicatedStorage:FindFirstChild("Network")
        if net then
            local rem = net:FindFirstChild(name)
            if rem and rem:IsA("RemoteEvent") then
                rem:FireServer(unpack(args))
            elseif rem and rem:IsA("RemoteFunction") then
                rem:InvokeServer(unpack(args))
            end
        end
    end)
end

-- ═══════════════════════════════════════════
-- TELEPORT & MINIGAME ENGINE
-- ═══════════════════════════════════════════
local Engine = {}

function Engine:TeleportArea143()
    local char = Player.Character or Player.CharacterAdded:Wait()
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    State.Status = "Warping to Area 143..."
    
    -- Try remotes
    FireNetwork("Teleports_RequestTeleport", "Area 143")
    FireNetwork("Teleports_RequestTeleport", 143)
    FireNetwork("Teleports_RequestTeleport", "143 | Tiki")
    FireNetwork("Teleports_RequestTeleport", "Tiki")
    
    -- Physical Search
    pcall(function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and (obj.Name:find("143") or obj.Name:lower():find("claw")) then
                hrp.CFrame = obj.CFrame + Vector3.new(0, 5, 0)
                break
            end
        end
    end)
end

function Engine:EnterClawMachine()
    State.Status = "Entering Claw Minigame..."
    
    -- PS99 Instancing calls
    local instances = {"ClawMachine", "Claw Machine", "Arcade", "Minigame_ClawMachine"}
    for _, inst in ipairs(instances) do
        FireNetwork("Instancing_RequestTeleport", inst)
        FireNetwork("Instancing_Enter", inst)
        FireNetwork("Minigames_RequestPlay", inst)
    end
    
    -- Proximity / Touch fallback
    pcall(function()
        local char = Player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        for _, p in ipairs(Workspace:GetDescendants()) do
            if p:IsA("ProximityPrompt") and (p.Parent.Name:lower():find("claw") or p.Parent.Name:lower():find("play") or p.Parent.Name:lower():find("enter")) then
                fireproximityprompt(p)
            end
        end
    end)
end

function Engine:PlayClaw()
    State.Status = "Grabbing Eggs..."
    FireNetwork("ClawMachine_Play")
    FireNetwork("ClawMachine_Drop")
    FireNetwork("ClawMachine_Grab")
    FireNetwork("Arcade_Drop")
    FireNetwork("Arcade_Play")
    
    State.TotalPlays = State.TotalPlays + 1
end

-- ═══════════════════════════════════════════
-- EGG DETECTOR
-- ═══════════════════════════════════════════
function Engine:CountEggs()
    local count = 0
    pcall(function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") or obj:IsA("MeshPart") or obj:IsA("Model") then
                local n = obj.Name:lower()
                if (n:find("egg") or n:find("prize") or n:find("capsule") or n:find("toy") or n:find("huge") or n:find("titanic")) then
                    if obj:IsA("BasePart") and obj.Transparency < 0.9 and obj.Size.Magnitude > 0.5 then
                        count = count + 1
                    elseif obj:IsA("Model") and obj.PrimaryPart and obj.PrimaryPart.Transparency < 0.9 then
                        count = count + 1
                    end
                end
            end
        end
    end)
    State.Eggs = count
    return count
end

-- ═══════════════════════════════════════════
-- SERVER HOPPER
-- ═══════════════════════════════════════════
local Hopper = {}

function Hopper:Hop()
    if State.IsHopping then return end
    State.IsHopping = true
    State.Status = "Hopping Servers..."
    State.TotalHops = State.TotalHops + 1
    
    task.spawn(function()
        local placeId = game.PlaceId
        local success, result = pcall(function()
            return game:HttpGet("https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100")
        end)
        
        if success and result then
            local data = HttpService:JSONDecode(result)
            if data and data.data then
                local goodServers = {}
                for _, s in ipairs(data.data) do
                    if s.playing and s.maxPlayers and s.id ~= game.JobId and s.playing < s.maxPlayers then
                        table.insert(goodServers, s.id)
                    end
                end
                if #goodServers > 0 then
                    local target = goodServers[math.random(1, math.min(10, #goodServers))]
                    TeleportService:TeleportToPlaceInstance(placeId, target, Player)
                    task.wait(10)
                end
            end
        end
        TeleportService:Teleport(placeId, Player)
        State.IsHopping = false
    end)
end

-- ═══════════════════════════════════════════
-- RELIABLE UI BUILDER
-- ═══════════════════════════════════════════
local function CreateUI()
    local targetParent = GetSafeGuiParent()
    
    local existing = targetParent:FindFirstChild("AxiomPS99_ClawUI")
    if existing then existing:Destroy() end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "AxiomPS99_ClawUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = targetParent
    
    local Frame = Instance.new("Frame")
    Frame.Name = "MainFrame"
    Frame.Size = UDim2.new(0, 320, 0, 370)
    Frame.Position = UDim2.new(0, 25, 0.4, -185)
    Frame.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
    Frame.BorderSizePixel = 0
    Frame.Active = true
    Frame.Draggable = true
    Frame.Parent = ScreenGui
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 12)
    Corner.Parent = Frame
    
    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(120, 80, 255)
    Stroke.Thickness = 2
    Stroke.Parent = Frame
    
    -- Title
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -20, 0, 35)
    Title.Position = UDim2.new(0, 15, 0, 8)
    Title.BackgroundTransparency = 1
    Title.Text = "⚡ AXIOM — PS99 CLAW v4.0"
    Title.TextColor3 = Color3.fromRGB(190, 150, 255)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 15
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Frame
    
    -- Status Card
    local Card = Instance.new("Frame")
    Card.Size = UDim2.new(1, -30, 0, 60)
    Card.Position = UDim2.new(0, 15, 0, 45)
    Card.BackgroundColor3 = Color3.fromRGB(22, 25, 40)
    Card.BorderSizePixel = 0
    Card.Parent = Frame
    
    local CardCorner = Instance.new("UICorner")
    CardCorner.CornerRadius = UDim.new(0, 8)
    CardCorner.Parent = Card
    
    local StatusText = Instance.new("TextLabel")
    StatusText.Size = UDim2.new(1, -16, 0, 24)
    StatusText.Position = UDim2.new(0, 8, 0, 4)
    StatusText.BackgroundTransparency = 1
    StatusText.Text = "🟢 Status: " .. State.Status
    StatusText.TextColor3 = Color3.fromRGB(120, 255, 170)
    StatusText.Font = Enum.Font.GothamBold
    StatusText.TextSize = 12
    StatusText.TextXAlignment = Enum.TextXAlignment.Left
    StatusText.Parent = Card
    
    local StatDetails = Instance.new("TextLabel")
    StatDetails.Size = UDim2.new(1, -16, 0, 24)
    StatDetails.Position = UDim2.new(0, 8, 0, 28)
    StatDetails.BackgroundTransparency = 1
    StatDetails.Text = "🥚 Eggs: 0 | 🎮 Drops: 0 | 🔄 Hops: 0"
    StatDetails.TextColor3 = Color3.fromRGB(170, 170, 210)
    StatDetails.Font = Enum.Font.GothamMedium
    StatDetails.TextSize = 11
    StatDetails.TextXAlignment = Enum.TextXAlignment.Left
    StatDetails.Parent = Card
    
    -- Buttons
    local function MakeBtn(text, y, col, cb)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -30, 0, 36)
        btn.Position = UDim2.new(0, 15, 0, y)
        btn.BackgroundColor3 = col
        btn.BorderSizePixel = 0
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.Parent = Frame
        
        local bCorner = Instance.new("UICorner")
        bCorner.CornerRadius = UDim.new(0, 8)
        bCorner.Parent = btn
        
        btn.MouseButton1Click:Connect(function()
            cb(btn)
        end)
        return btn
    end
    
    local autoBtn = MakeBtn("✔ FULL AUTO ACTIVE (CLICK TO STOP)", 115, Color3.fromRGB(30, 160, 80), function(btn)
        Config.FullAuto = not Config.FullAuto
        if Config.FullAuto then
            btn.BackgroundColor3 = Color3.fromRGB(30, 160, 80)
            btn.Text = "✔ FULL AUTO ACTIVE (CLICK TO STOP)"
        else
            btn.BackgroundColor3 = Color3.fromRGB(110, 50, 220)
            btn.Text = "🔥 START FULL AUTO PIPELINE"
        end
    end)
    
    MakeBtn("🗺 FORCE TP MAP 143", 160, Color3.fromRGB(45, 65, 120), function()
        Engine:TeleportArea143()
    end)
    
    MakeBtn("🚪 ENTER CLAW MINIGAME", 205, Color3.fromRGB(60, 45, 120), function()
        Engine:EnterClawMachine()
    end)
    
    MakeBtn("🎮 DROP CLAW NOW", 250, Color3.fromRGB(40, 120, 80), function()
        Engine:PlayClaw()
    end)
    
    MakeBtn("🔄 HOP SERVER NOW", 295, Color3.fromRGB(140, 70, 30), function()
        Hopper:Hop()
    end)
    
    -- Keybind toggle
    UserInputService.InputBegan:Connect(function(input, gpe)
        if not gpe and input.KeyCode == Enum.KeyCode.RightShift then
            Frame.Visible = not Frame.Visible
        end
    end)
    
    -- Loop updater for UI
    task.spawn(function()
        while ScreenGui.Parent do
            pcall(function()
                local count = Engine:CountEggs()
                StatusText.Text = "🟢 Status: " .. State.Status
                StatDetails.Text = string.format("🥚 Eggs: %d | 🎮 Plays: %d | 🔄 Hops: %d", count, State.TotalPlays, State.TotalHops)
            end)
            task.wait(1)
        end
    end)
    
    if getgenv then
        getgenv().AxiomCleanup = function()
            pcall(function() ScreenGui:Destroy() end)
        end
    end
end

-- ═══════════════════════════════════════════
-- AUTO-LOOP THREAD
-- ═══════════════════════════════════════════
task.spawn(function()
    while true do
        if Config.FullAuto and not State.IsHopping then
            pcall(function()
                local count = Engine:CountEggs()
                
                -- Check for empty / hop
                if Config.AutoHopWhenEmpty and count <= Config.MinEggsBeforeHop then
                    State.EmptyStreak = State.EmptyStreak + 1
                    if State.EmptyStreak >= Config.EmptyCheckCount then
                        print("[Axiom] Map is empty — Server hopping now!")
                        Hopper:Hop()
                        task.wait(10)
                        return
                    end
                else
                    State.EmptyStreak = 0
                end
                
                -- Execution cycle
                if Config.AutoTeleportMap then
                    Engine:TeleportArea143()
                    task.wait(0.5)
                    Engine:EnterClawMachine()
                    task.wait(0.5)
                end
                
                if Config.AutoPlayClaw then
                    Engine:PlayClaw()
                end
            end)
        end
        task.wait(Config.CycleDelay)
    end
end)

-- ═══════════════════════════════════════════
-- LAUNCH
-- ═══════════════════════════════════════════
pcall(CreateUI)
print("------------------------------------------")
print("⚡ [AXIOM] v4.0 PS99 CLAW SCRIPT LOADED!")
print("⚡ Press RightShift to Toggle UI")
print("------------------------------------------")
