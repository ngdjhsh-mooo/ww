--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║          MINI WORLD 2 — MAP 143 CLAW MACHINE v2.0           ║
    ║          Author: Axiom                                      ║
    ║          Auto Map TP + Server Hop + Full Auto                ║
    ║          Loadstring Ready — GitHub Compatible                ║
    ╚══════════════════════════════════════════════════════════════╝
    
    Usage (paste in executor):
    loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/MiniWorld2_Map143_ClawMachine.lua"))()
]]--

-- ═══════════════════════════════════════════
-- SERVICES
-- ═══════════════════════════════════════════
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

-- ═══════════════════════════════════════════
-- CONFIGURATION
-- ═══════════════════════════════════════════
local Config = {
    -- Core Settings
    AutoGrab = false,
    AutoPlay = false,
    AutoCollect = false,
    AutoTeleport = false,
    AutoMapTP = false,
    AutoServerHop = false,
    
    -- Map Settings
    TargetMap = 143,
    GamePlaceId = game.PlaceId,
    
    -- Egg / Prize Detection
    EggCheckInterval = 3,
    MinEggsBeforeHop = 0,          -- hop when eggs <= this
    EmptyCheckCount = 5,           -- confirm empty X times before hop
    ServerHopCooldown = 10,        -- seconds between hop attempts
    
    -- Claw Settings
    ClawGrabDelay = 0.3,
    ClawDropDelay = 0.15,
    ClawCycleSpeed = 0.5,
    MaxRetries = 50,
    
    -- Teleport
    TeleportSpeed = 75,
    TeleportDelay = 0.8,
    
    -- Anti-Detection
    AntiAFK = true,
    AntiDetect = true,
    HumanizeDelay = true,
    MinDelay = 0.08,
    MaxDelay = 0.25,
    
    -- Server Hop
    MaxHopAttempts = 10,
    HopRetryDelay = 5,
    
    -- UI
    ToggleKey = Enum.KeyCode.RightShift,
    UIVisible = true
}

-- ═══════════════════════════════════════════
-- STATS TRACKER
-- ═══════════════════════════════════════════
local Stats = {
    EggsCollected = 0,
    ServerHops = 0,
    MachinesPlayed = 0,
    SessionStart = tick(),
    CurrentEggCount = 0,
    EmptyStreak = 0,
    LastHopTime = 0
}

-- ═══════════════════════════════════════════
-- ANTI-DETECTION LAYER
-- ═══════════════════════════════════════════
local AntiDetect = {}

function AntiDetect:RandomDelay()
    if Config.HumanizeDelay then
        local delay = Config.MinDelay + math.random() * (Config.MaxDelay - Config.MinDelay)
        task.wait(delay)
    end
end

function AntiDetect:JitterPosition(pos, range)
    range = range or 0.5
    return pos + Vector3.new(
        (math.random() - 0.5) * range,
        0,
        (math.random() - 0.5) * range
    )
end

function AntiDetect:SimulateInput(callback)
    self:RandomDelay()
    local success, err = pcall(callback)
    if not success then
        warn("[Axiom] Input sim failed: " .. tostring(err))
    end
    self:RandomDelay()
end

-- Anti-AFK
if Config.AntiAFK then
    Player.Idled:Connect(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
        task.wait(0.1)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
    end)
end

-- ═══════════════════════════════════════════
-- MAP TELEPORTER — AUTO JOIN MAP 143
-- ═══════════════════════════════════════════
local MapTeleporter = {}
MapTeleporter.Active = false
MapTeleporter.InMap = false

function MapTeleporter:FindMapPortals()
    local portals = {}
    
    local function scan(parent)
        for _, obj in pairs(parent:GetDescendants()) do
            local nameLower = obj.Name:lower()
            -- Look for map 143 portal / teleporter / door
            if nameLower:find("143") or nameLower:find("map") or nameLower:find("portal") 
               or nameLower:find("teleport") or nameLower:find("door") or nameLower:find("enter") then
                if obj:IsA("BasePart") then
                    table.insert(portals, {Object = obj, Type = "Part"})
                elseif obj:IsA("ProximityPrompt") then
                    table.insert(portals, {Object = obj, Type = "Prompt"})
                elseif obj:IsA("ClickDetector") then
                    table.insert(portals, {Object = obj, Type = "Click"})
                elseif obj:IsA("Model") then
                    local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                    if primary then
                        table.insert(portals, {Object = primary, Type = "Part", Model = obj})
                    end
                end
            end
        end
    end
    
    scan(Workspace)
    return portals
end

function MapTeleporter:FindMapRemotes()
    local remotes = {}
    
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local nameLower = obj.Name:lower()
            if nameLower:find("map") or nameLower:find("teleport") or nameLower:find("join") 
               or nameLower:find("enter") or nameLower:find("select") or nameLower:find("travel")
               or nameLower:find("load") or nameLower:find("play") then
                remotes[obj.Name] = obj
            end
        end
    end
    
    return remotes
end

function MapTeleporter:TeleportToPortal(portal)
    Character = Player.Character
    if not Character then return false end
    HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
    if not HumanoidRootPart then return false end
    
    local targetPos
    if portal.Type == "Part" then
        targetPos = portal.Object.Position + Vector3.new(0, 3, 0)
    elseif portal.Type == "Prompt" then
        targetPos = portal.Object.Parent.Position + Vector3.new(0, 3, 0)
    elseif portal.Type == "Click" then
        targetPos = portal.Object.Parent.Position + Vector3.new(0, 3, 0)
    end
    
    if not targetPos then return false end
    targetPos = AntiDetect:JitterPosition(targetPos)
    
    if Config.AntiDetect then
        local tweenInfo = TweenInfo.new(Config.TeleportDelay, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local tween = TweenService:Create(HumanoidRootPart, tweenInfo, {CFrame = CFrame.new(targetPos)})
        tween:Play()
        tween.Completed:Wait()
    else
        HumanoidRootPart.CFrame = CFrame.new(targetPos)
    end
    
    task.wait(0.5)
    return true
end

function MapTeleporter:InteractWithPortal(portal)
    AntiDetect:SimulateInput(function()
        if portal.Type == "Prompt" then
            fireproximityprompt(portal.Object)
        elseif portal.Type == "Click" then
            fireclickdetector(portal.Object)
        elseif portal.Type == "Part" then
            firetouchinterest(HumanoidRootPart, portal.Object, 0)
            task.wait(0.15)
            firetouchinterest(HumanoidRootPart, portal.Object, 1)
        end
    end)
end

function MapTeleporter:FireMapRemotes()
    local remotes = self:FindMapRemotes()
    
    local mapArgs = {
        Config.TargetMap,
        tostring(Config.TargetMap),
        "Map" .. Config.TargetMap,
        "map_" .. Config.TargetMap,
        "Map " .. Config.TargetMap
    }
    
    for name, remote in pairs(remotes) do
        for _, arg in pairs(mapArgs) do
            pcall(function()
                if remote:IsA("RemoteEvent") then
                    remote:FireServer(arg)
                    task.wait(0.3)
                    remote:FireServer("join", arg)
                    task.wait(0.3)
                    remote:FireServer("teleport", arg)
                elseif remote:IsA("RemoteFunction") then
                    remote:InvokeServer(arg)
                    task.wait(0.3)
                    remote:InvokeServer("join", arg)
                end
            end)
            task.wait(0.2)
        end
    end
end

function MapTeleporter:EnterMap()
    print("[Axiom] Attempting to enter Map " .. Config.TargetMap .. "...")
    
    -- Method 1: Fire remotes with map args
    self:FireMapRemotes()
    task.wait(1)
    
    -- Method 2: Find and interact with portals
    local portals = self:FindMapPortals()
    
    -- Sort by name relevance (prioritize ones with "143")
    table.sort(portals, function(a, b)
        local aHas143 = a.Object.Name:lower():find("143") and 1 or 0
        local bHas143 = b.Object.Name:lower():find("143") and 1 or 0
        return aHas143 > bHas143
    end)
    
    for _, portal in pairs(portals) do
        self:TeleportToPortal(portal)
        task.wait(0.5)
        self:InteractWithPortal(portal)
        task.wait(1)
    end
    
    self.InMap = true
    print("[Axiom] Map " .. Config.TargetMap .. " entry sequence completed")
end

function MapTeleporter:Start()
    self.Active = true
    Config.AutoMapTP = true
    
    task.spawn(function()
        task.wait(2) -- wait for game to load
        self:EnterMap()
    end)
end

function MapTeleporter:Stop()
    self.Active = false
    Config.AutoMapTP = false
end

-- ═══════════════════════════════════════════
-- EGG / PRIZE DETECTOR
-- ═══════════════════════════════════════════
local EggDetector = {}

function EggDetector:ScanForEggs()
    local eggs = {}
    
    for _, obj in pairs(Workspace:GetDescendants()) do
        local nameLower = obj.Name:lower()
        if (obj:IsA("BasePart") or obj:IsA("Model") or obj:IsA("MeshPart") or obj:IsA("UnionOperation")) then
            if nameLower:find("egg") or nameLower:find("trứng") or nameLower:find("prize") 
               or nameLower:find("reward") or nameLower:find("toy") or nameLower:find("capsule")
               or nameLower:find("ball") or nameLower:find("collectible") or nameLower:find("item")
               or nameLower:find("loot") or nameLower:find("drop") or nameLower:find("gift") then
                -- Make sure it's visible and in play
                if obj:IsA("BasePart") and obj.Transparency < 1 then
                    table.insert(eggs, obj)
                elseif obj:IsA("Model") then
                    local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                    if part and part.Transparency < 1 then
                        table.insert(eggs, obj)
                    end
                end
            end
        end
    end
    
    return eggs
end

function EggDetector:ScanClawMachineContents()
    local contents = {}
    
    for _, obj in pairs(Workspace:GetDescendants()) do
        local nameLower = obj.Name:lower()
        if nameLower:find("claw") or nameLower:find("crane") or nameLower:find("machine") then
            if obj:IsA("Model") then
                for _, child in pairs(obj:GetDescendants()) do
                    if child:IsA("BasePart") or child:IsA("MeshPart") then
                        local childName = child.Name:lower()
                        if childName:find("egg") or childName:find("prize") or childName:find("toy") 
                           or childName:find("item") or childName:find("ball") or childName:find("capsule") then
                            if child.Transparency < 1 then
                                table.insert(contents, child)
                            end
                        end
                    end
                end
            end
        end
    end
    
    return contents
end

function EggDetector:GetCount()
    local eggs = self:ScanForEggs()
    local machineContents = self:ScanClawMachineContents()
    
    -- Deduplicate
    local seen = {}
    local total = 0
    
    for _, obj in pairs(eggs) do
        if not seen[obj] then
            seen[obj] = true
            total = total + 1
        end
    end
    for _, obj in pairs(machineContents) do
        if not seen[obj] then
            seen[obj] = true
            total = total + 1
        end
    end
    
    return total
end

function EggDetector:IsEmpty()
    local count = self:GetCount()
    Stats.CurrentEggCount = count
    
    if count <= Config.MinEggsBeforeHop then
        Stats.EmptyStreak = Stats.EmptyStreak + 1
    else
        Stats.EmptyStreak = 0
    end
    
    -- Confirm empty multiple times to avoid false positive
    return Stats.EmptyStreak >= Config.EmptyCheckCount
end

-- ═══════════════════════════════════════════
-- SERVER HOPPER
-- ═══════════════════════════════════════════
local ServerHopper = {}
ServerHopper.Active = false
ServerHopper.Hopping = false

function ServerHopper:FetchServers()
    local servers = {}
    local success, result = pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. Config.GamePlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        return game:HttpGet(url)
    end)
    
    if success and result then
        local data = HttpService:JSONDecode(result)
        if data and data.data then
            for _, server in pairs(data.data) do
                if server.playing and server.maxPlayers and server.id then
                    -- Skip full servers and current server
                    if server.playing < server.maxPlayers and server.id ~= game.JobId then
                        table.insert(servers, {
                            Id = server.id,
                            Playing = server.playing,
                            MaxPlayers = server.maxPlayers,
                            Ping = server.ping or 0
                        })
                    end
                end
            end
        end
    end
    
    -- Sort by player count (prefer less crowded)
    table.sort(servers, function(a, b)
        return a.Playing < b.Playing
    end)
    
    return servers
end

function ServerHopper:Hop()
    if self.Hopping then return end
    if (tick() - Stats.LastHopTime) < Config.ServerHopCooldown then
        print("[Axiom] Server hop on cooldown... waiting")
        return
    end
    
    self.Hopping = true
    Stats.LastHopTime = tick()
    Stats.ServerHops = Stats.ServerHops + 1
    
    print("[Axiom] ═══ SERVER HOP #" .. Stats.ServerHops .. " ═══")
    print("[Axiom] Eggs depleted — scanning for fresh server...")
    
    local attempts = 0
    
    while attempts < Config.MaxHopAttempts do
        attempts = attempts + 1
        print("[Axiom] Hop attempt " .. attempts .. "/" .. Config.MaxHopAttempts)
        
        local servers = self:FetchServers()
        
        if #servers > 0 then
            -- Pick a random server from the least crowded ones
            local pickRange = math.min(5, #servers)
            local targetServer = servers[math.random(1, pickRange)]
            
            print("[Axiom] Joining server: " .. targetServer.Id)
            print("[Axiom] Players: " .. targetServer.Playing .. "/" .. targetServer.MaxPlayers)
            
            local teleportSuccess, teleportErr = pcall(function()
                TeleportService:TeleportToPlaceInstance(Config.GamePlaceId, targetServer.Id, Player)
            end)
            
            if teleportSuccess then
                print("[Axiom] Teleport initiated — see you on the other side, boss man")
                -- Wait for teleport to process
                task.wait(15)
            else
                warn("[Axiom] Teleport failed: " .. tostring(teleportErr))
            end
        else
            print("[Axiom] No available servers found, retrying in " .. Config.HopRetryDelay .. "s...")
        end
        
        task.wait(Config.HopRetryDelay)
    end
    
    -- Fallback: rejoin same place
    print("[Axiom] Max attempts reached — using fallback rejoin")
    pcall(function()
        TeleportService:Teleport(Config.GamePlaceId, Player)
    end)
    
    self.Hopping = false
end

function ServerHopper:StartMonitor()
    self.Active = true
    Config.AutoServerHop = true
    
    task.spawn(function()
        -- Give time for map to load
        task.wait(5)
        
        while Config.AutoServerHop and self.Active do
            pcall(function()
                local isEmpty = EggDetector:IsEmpty()
                local count = Stats.CurrentEggCount
                
                if isEmpty and not self.Hopping then
                    print("[Axiom] Map confirmed empty (" .. Stats.EmptyStreak .. " consecutive checks)")
                    print("[Axiom] Eggs remaining: " .. count)
                    self:Hop()
                end
            end)
            
            task.wait(Config.EggCheckInterval)
        end
    end)
end

function ServerHopper:Stop()
    self.Active = false
    Config.AutoServerHop = false
end

-- ═══════════════════════════════════════════
-- CLAW MACHINE SCANNER
-- ═══════════════════════════════════════════
local Scanner = {}

function Scanner:FindClawMachines()
    local machines = {}
    
    local function deepScan(parent)
        for _, obj in pairs(parent:GetChildren()) do
            if obj:IsA("Model") or obj:IsA("Folder") then
                local nameLower = obj.Name:lower()
                if nameLower:find("claw") or nameLower:find("crane") or nameLower:find("grab") or nameLower:find("machine") then
                    table.insert(machines, obj)
                end
                deepScan(obj)
            end
        end
    end
    
    deepScan(Workspace)
    return machines
end

function Scanner:FindInteractionPoints(machine)
    local points = {}
    
    for _, obj in pairs(machine:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            table.insert(points, {Type = "ProximityPrompt", Object = obj})
        elseif obj:IsA("ClickDetector") then
            table.insert(points, {Type = "ClickDetector", Object = obj})
        elseif obj:IsA("BasePart") then
            local nameLower = obj.Name:lower()
            if nameLower:find("button") or nameLower:find("lever") or nameLower:find("interact") or nameLower:find("play") or nameLower:find("start") then
                table.insert(points, {Type = "TouchPart", Object = obj})
            end
        end
    end
    
    return points
end

function Scanner:FindRemotes()
    local remotes = {}
    
    local function scanRemotes(parent)
        for _, obj in pairs(parent:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                local nameLower = obj.Name:lower()
                if nameLower:find("claw") or nameLower:find("grab") or nameLower:find("play") 
                   or nameLower:find("machine") or nameLower:find("crane") or nameLower:find("collect")
                   or nameLower:find("claim") or nameLower:find("prize") then
                    remotes[obj.Name] = obj
                end
            end
        end
    end
    
    scanRemotes(ReplicatedStorage)
    return remotes
end

function Scanner:GetNearestMachine()
    local machines = self:FindClawMachines()
    local nearest, minDist = nil, math.huge
    
    for _, machine in pairs(machines) do
        local machinePart = machine:IsA("Model") and (machine.PrimaryPart or machine:FindFirstChildWhichIsA("BasePart")) or machine
        if machinePart and machinePart:IsA("BasePart") then
            local dist = (HumanoidRootPart.Position - machinePart.Position).Magnitude
            if dist < minDist then
                minDist = dist
                nearest = machine
            end
        end
    end
    
    return nearest, minDist
end

-- ═══════════════════════════════════════════
-- CLAW CONTROLLER
-- ═══════════════════════════════════════════
local ClawController = {}
ClawController.Active = false
ClawController.CurrentMachine = nil

function ClawController:TeleportTo(machine)
    local targetPart = machine:IsA("Model") and (machine.PrimaryPart or machine:FindFirstChildWhichIsA("BasePart")) or machine
    if not targetPart or not targetPart:IsA("BasePart") then return false end
    
    Character = Player.Character
    if not Character then return false end
    HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
    if not HumanoidRootPart then return false end
    
    local targetPos = AntiDetect:JitterPosition(targetPart.Position + Vector3.new(0, 3, -5))
    
    if Config.AntiDetect then
        local tweenInfo = TweenInfo.new(Config.TeleportDelay, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local tween = TweenService:Create(HumanoidRootPart, tweenInfo, {CFrame = CFrame.new(targetPos)})
        tween:Play()
        tween.Completed:Wait()
    else
        HumanoidRootPart.CFrame = CFrame.new(targetPos)
    end
    
    task.wait(0.3)
    return true
end

function ClawController:InteractWithMachine(machine)
    local points = Scanner:FindInteractionPoints(machine)
    
    for _, point in pairs(points) do
        AntiDetect:SimulateInput(function()
            if point.Type == "ProximityPrompt" then
                fireproximityprompt(point.Object)
            elseif point.Type == "ClickDetector" then
                fireclickdetector(point.Object)
            elseif point.Type == "TouchPart" then
                firetouchinterest(HumanoidRootPart, point.Object, 0)
                task.wait(0.1)
                firetouchinterest(HumanoidRootPart, point.Object, 1)
            end
        end)
        task.wait(Config.ClawGrabDelay)
    end
end

function ClawController:FireRemotes(action)
    local remotes = Scanner:FindRemotes()
    
    for name, remote in pairs(remotes) do
        local nameLower = name:lower()
        AntiDetect:SimulateInput(function()
            if remote:IsA("RemoteEvent") then
                if action == "play" and (nameLower:find("play") or nameLower:find("start") or nameLower:find("use")) then
                    remote:FireServer()
                elseif action == "grab" and (nameLower:find("grab") or nameLower:find("claw") or nameLower:find("drop")) then
                    remote:FireServer()
                elseif action == "collect" and (nameLower:find("collect") or nameLower:find("claim") or nameLower:find("prize")) then
                    remote:FireServer()
                end
            elseif remote:IsA("RemoteFunction") then
                if action == "play" and (nameLower:find("play") or nameLower:find("start")) then
                    pcall(function() remote:InvokeServer() end)
                elseif action == "collect" and (nameLower:find("collect") or nameLower:find("claim")) then
                    pcall(function() remote:InvokeServer() end)
                end
            end
        end)
    end
end

function ClawController:ExecuteGrabCycle(machine)
    self:InteractWithMachine(machine)
    task.wait(Config.ClawCycleSpeed)
    
    self:FireRemotes("play")
    task.wait(Config.ClawCycleSpeed)
    
    self:FireRemotes("grab")
    task.wait(Config.ClawGrabDelay)
    
    self:FireRemotes("collect")
    task.wait(Config.ClawDropDelay)
    
    Stats.MachinesPlayed = Stats.MachinesPlayed + 1
end

function ClawController:StartAutoPlay()
    Config.AutoPlay = true
    self.Active = true
    
    task.spawn(function()
        while Config.AutoPlay and self.Active do
            pcall(function()
                Character = Player.Character
                if not Character then return end
                HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
                
                -- Don't play if server hop is in progress
                if ServerHopper.Hopping then
                    task.wait(2)
                    return
                end
                
                local machine, dist = Scanner:GetNearestMachine()
                
                if machine then
                    if dist > 15 and Config.AutoTeleport then
                        self:TeleportTo(machine)
                    end
                    
                    self.CurrentMachine = machine
                    self:ExecuteGrabCycle(machine)
                end
            end)
            
            AntiDetect:RandomDelay()
            task.wait(Config.ClawCycleSpeed)
        end
    end)
end

function ClawController:StopAutoPlay()
    Config.AutoPlay = false
    self.Active = false
    self.CurrentMachine = nil
end

-- ═══════════════════════════════════════════
-- AUTO COLLECTOR
-- ═══════════════════════════════════════════
local Collector = {}
Collector.Active = false

function Collector:CollectDroppedPrizes()
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local nameLower = obj.Name:lower()
            if nameLower:find("drop") or nameLower:find("prize") or nameLower:find("reward") or nameLower:find("loot") then
                local part = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")) or obj
                if part and part:IsA("BasePart") then
                    local dist = (HumanoidRootPart.Position - part.Position).Magnitude
                    if dist < 50 then
                        AntiDetect:SimulateInput(function()
                            firetouchinterest(HumanoidRootPart, part, 0)
                            task.wait(0.05)
                            firetouchinterest(HumanoidRootPart, part, 1)
                        end)
                        Stats.EggsCollected = Stats.EggsCollected + 1
                    end
                end
            end
        end
    end
end

function Collector:Start()
    self.Active = true
    Config.AutoCollect = true
    
    task.spawn(function()
        while Config.AutoCollect and self.Active do
            pcall(function()
                Character = Player.Character
                if Character then
                    HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
                    self:CollectDroppedPrizes()
                end
            end)
            task.wait(1)
        end
    end)
end

function Collector:Stop()
    self.Active = false
    Config.AutoCollect = false
end

-- ═══════════════════════════════════════════
-- FULL AUTO PIPELINE
-- ═══════════════════════════════════════════
local FullAuto = {}
FullAuto.Active = false

function FullAuto:Start()
    self.Active = true
    
    print("[Axiom] ═══ FULL AUTO PIPELINE ENGAGED ═══")
    print("[Axiom] Step 1: Teleporting to Map " .. Config.TargetMap)
    
    -- Step 1: Enter the map
    MapTeleporter:Start()
    task.wait(5)
    
    -- Step 2: Start claw auto play
    print("[Axiom] Step 2: Starting Auto Play")
    Config.AutoTeleport = true
    ClawController:StartAutoPlay()
    
    -- Step 3: Start auto collect
    print("[Axiom] Step 3: Starting Auto Collect")
    Collector:Start()
    
    -- Step 4: Start server hop monitor
    print("[Axiom] Step 4: Starting Server Hop Monitor")
    ServerHopper:StartMonitor()
    
    print("[Axiom] ═══ ALL SYSTEMS ONLINE ═══")
end

function FullAuto:Stop()
    self.Active = false
    MapTeleporter:Stop()
    ClawController:StopAutoPlay()
    Collector:Stop()
    ServerHopper:Stop()
    print("[Axiom] Full auto pipeline stopped")
end

-- ═══════════════════════════════════════════
-- UI FRAMEWORK
-- ═══════════════════════════════════════════
local UI = {}

function UI:Create()
    local oldGui = Player.PlayerGui:FindFirstChild("AxiomClawUI")
    if oldGui then oldGui:Destroy() end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "AxiomClawUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = Player.PlayerGui
    
    -- Main Frame
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 330, 0, 560)
    MainFrame.Position = UDim2.new(0, 20, 0.5, -280)
    MainFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 22)
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    
    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 12)
    MainCorner.Parent = MainFrame
    
    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(120, 80, 255)
    MainStroke.Thickness = 1.5
    MainStroke.Transparency = 0.3
    MainStroke.Parent = MainFrame
    
    -- Glow effect
    local Glow = Instance.new("ImageLabel")
    Glow.Size = UDim2.new(1, 40, 0, 60)
    Glow.Position = UDim2.new(0, -20, 0, -10)
    Glow.BackgroundTransparency = 1
    Glow.Image = "rbxassetid://5028857084"
    Glow.ImageColor3 = Color3.fromRGB(100, 60, 220)
    Glow.ImageTransparency = 0.85
    Glow.Parent = MainFrame
    
    -- Title Bar
    local TitleBar = Instance.new("Frame")
    TitleBar.Name = "TitleBar"
    TitleBar.Size = UDim2.new(1, 0, 0, 50)
    TitleBar.BackgroundColor3 = Color3.fromRGB(18, 18, 32)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame
    
    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 12)
    TitleCorner.Parent = TitleBar
    
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1, -20, 0, 25)
    TitleLabel.Position = UDim2.new(0, 15, 0, 8)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = "⚡ AXIOM — CLAW v2.0"
    TitleLabel.TextColor3 = Color3.fromRGB(180, 140, 255)
    TitleLabel.TextSize = 16
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = TitleBar
    
    local SubTitle = Instance.new("TextLabel")
    SubTitle.Size = UDim2.new(1, -20, 0, 15)
    SubTitle.Position = UDim2.new(0, 15, 0, 30)
    SubTitle.BackgroundTransparency = 1
    SubTitle.Text = "Map 143 | Auto TP + Server Hop"
    SubTitle.TextColor3 = Color3.fromRGB(100, 100, 140)
    SubTitle.TextSize = 10
    SubTitle.Font = Enum.Font.Gotham
    SubTitle.TextXAlignment = Enum.TextXAlignment.Left
    SubTitle.Parent = TitleBar
    
    -- Status Panel
    local StatusPanel = Instance.new("Frame")
    StatusPanel.Size = UDim2.new(1, -30, 0, 55)
    StatusPanel.Position = UDim2.new(0, 15, 0, 55)
    StatusPanel.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
    StatusPanel.BorderSizePixel = 0
    StatusPanel.Parent = MainFrame
    
    local SPCorner = Instance.new("UICorner")
    SPCorner.CornerRadius = UDim.new(0, 8)
    SPCorner.Parent = StatusPanel
    
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Name = "StatusLabel"
    StatusLabel.Size = UDim2.new(1, -16, 0, 18)
    StatusLabel.Position = UDim2.new(0, 10, 0, 5)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = "⏸ Idle — Waiting for orders"
    StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
    StatusLabel.TextSize = 11
    StatusLabel.Font = Enum.Font.GothamMedium
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    StatusLabel.Parent = StatusPanel
    
    local EggLabel = Instance.new("TextLabel")
    EggLabel.Name = "EggLabel"
    EggLabel.Size = UDim2.new(0.5, -8, 0, 14)
    EggLabel.Position = UDim2.new(0, 10, 0, 25)
    EggLabel.BackgroundTransparency = 1
    EggLabel.Text = "🥚 Eggs: Scanning..."
    EggLabel.TextColor3 = Color3.fromRGB(140, 180, 220)
    EggLabel.TextSize = 10
    EggLabel.Font = Enum.Font.Gotham
    EggLabel.TextXAlignment = Enum.TextXAlignment.Left
    EggLabel.Parent = StatusPanel
    
    local HopLabel = Instance.new("TextLabel")
    HopLabel.Name = "HopLabel"
    HopLabel.Size = UDim2.new(0.5, -8, 0, 14)
    HopLabel.Position = UDim2.new(0.5, 0, 0, 25)
    HopLabel.BackgroundTransparency = 1
    HopLabel.Text = "🔄 Hops: 0"
    HopLabel.TextColor3 = Color3.fromRGB(140, 180, 220)
    HopLabel.TextSize = 10
    HopLabel.Font = Enum.Font.Gotham
    HopLabel.TextXAlignment = Enum.TextXAlignment.Left
    HopLabel.Parent = StatusPanel
    
    local PlayedLabel = Instance.new("TextLabel")
    PlayedLabel.Name = "PlayedLabel"
    PlayedLabel.Size = UDim2.new(1, -16, 0, 14)
    PlayedLabel.Position = UDim2.new(0, 10, 0, 38)
    PlayedLabel.BackgroundTransparency = 1
    PlayedLabel.Text = "🎮 Played: 0 | ⏱ Uptime: 0m"
    PlayedLabel.TextColor3 = Color3.fromRGB(140, 180, 220)
    PlayedLabel.TextSize = 10
    PlayedLabel.Font = Enum.Font.Gotham
    PlayedLabel.TextXAlignment = Enum.TextXAlignment.Left
    PlayedLabel.Parent = StatusPanel
    
    -- Button Container
    local ButtonContainer = Instance.new("ScrollingFrame")
    ButtonContainer.Name = "ButtonContainer"
    ButtonContainer.Size = UDim2.new(1, -30, 0, 320)
    ButtonContainer.Position = UDim2.new(0, 15, 0, 118)
    ButtonContainer.BackgroundTransparency = 1
    ButtonContainer.ScrollBarThickness = 3
    ButtonContainer.ScrollBarImageColor3 = Color3.fromRGB(120, 80, 255)
    ButtonContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
    ButtonContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
    ButtonContainer.BorderSizePixel = 0
    ButtonContainer.Parent = MainFrame
    
    local ButtonLayout = Instance.new("UIListLayout")
    ButtonLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ButtonLayout.Padding = UDim.new(0, 6)
    ButtonLayout.Parent = ButtonContainer
    
    -- Section Label Factory
    local function CreateSectionLabel(text, order)
        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(1, 0, 0, 22)
        Label.BackgroundTransparency = 1
        Label.Text = text
        Label.TextColor3 = Color3.fromRGB(90, 70, 160)
        Label.TextSize = 10
        Label.Font = Enum.Font.GothamBold
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.LayoutOrder = order
        Label.Parent = ButtonContainer
        return Label
    end
    
    -- Toggle Button Factory
    local function CreateToggleButton(name, text, order, callback)
        local Button = Instance.new("TextButton")
        Button.Name = name
        Button.Size = UDim2.new(1, 0, 0, 35)
        Button.BackgroundColor3 = Color3.fromRGB(25, 25, 42)
        Button.BorderSizePixel = 0
        Button.Text = "  ○  " .. text
        Button.TextColor3 = Color3.fromRGB(190, 190, 210)
        Button.TextSize = 12
        Button.Font = Enum.Font.GothamMedium
        Button.TextXAlignment = Enum.TextXAlignment.Left
        Button.LayoutOrder = order
        Button.Parent = ButtonContainer
        
        local BtnCorner = Instance.new("UICorner")
        BtnCorner.CornerRadius = UDim.new(0, 8)
        BtnCorner.Parent = Button
        
        local BtnStroke = Instance.new("UIStroke")
        BtnStroke.Color = Color3.fromRGB(45, 45, 70)
        BtnStroke.Thickness = 1
        BtnStroke.Parent = Button
        
        local isOn = false
        
        Button.MouseButton1Click:Connect(function()
            isOn = not isOn
            if isOn then
                Button.Text = "  ●  " .. text
                Button.TextColor3 = Color3.fromRGB(120, 255, 170)
                BtnStroke.Color = Color3.fromRGB(80, 220, 130)
                Button.BackgroundColor3 = Color3.fromRGB(20, 45, 30)
            else
                Button.Text = "  ○  " .. text
                Button.TextColor3 = Color3.fromRGB(190, 190, 210)
                BtnStroke.Color = Color3.fromRGB(45, 45, 70)
                Button.BackgroundColor3 = Color3.fromRGB(25, 25, 42)
            end
            callback(isOn)
        end)
        
        Button.MouseEnter:Connect(function()
            TweenService:Create(Button, TweenInfo.new(0.15), {BackgroundColor3 = isOn and Color3.fromRGB(25, 55, 35) or Color3.fromRGB(32, 32, 55)}):Play()
        end)
        Button.MouseLeave:Connect(function()
            TweenService:Create(Button, TweenInfo.new(0.15), {BackgroundColor3 = isOn and Color3.fromRGB(20, 45, 30) or Color3.fromRGB(25, 25, 42)}):Play()
        end)
        
        return Button
    end
    
    -- Action Button Factory
    local function CreateActionButton(name, text, color, order, callback)
        local Button = Instance.new("TextButton")
        Button.Name = name
        Button.Size = UDim2.new(1, 0, 0, 38)
        Button.BackgroundColor3 = color
        Button.BorderSizePixel = 0
        Button.Text = text
        Button.TextColor3 = Color3.fromRGB(255, 255, 255)
        Button.TextSize = 13
        Button.Font = Enum.Font.GothamBold
        Button.LayoutOrder = order
        Button.Parent = ButtonContainer
        
        local BtnCorner = Instance.new("UICorner")
        BtnCorner.CornerRadius = UDim.new(0, 8)
        BtnCorner.Parent = Button
        
        Button.MouseButton1Click:Connect(callback)
        
        Button.MouseEnter:Connect(function()
            TweenService:Create(Button, TweenInfo.new(0.15), {BackgroundColor3 = Color3.new(
                math.min(color.R + 0.08, 1),
                math.min(color.G + 0.08, 1),
                math.min(color.B + 0.08, 1)
            )}):Play()
        end)
        Button.MouseLeave:Connect(function()
            TweenService:Create(Button, TweenInfo.new(0.15), {BackgroundColor3 = color}):Play()
        end)
        
        return Button
    end
    
    -- ═══ BUILD UI SECTIONS ═══
    
    -- FULL AUTO
    CreateSectionLabel("━━━ 🔥 FULL AUTO ━━━", 0)
    
    CreateActionButton("FullAutoBtn", "⚡ START FULL AUTO PIPELINE", Color3.fromRGB(80, 40, 180), 1, function()
        if not FullAuto.Active then
            FullAuto:Start()
            StatusLabel.Text = "🔥 FULL AUTO — ALL SYSTEMS GO"
            StatusLabel.TextColor3 = Color3.fromRGB(120, 255, 170)
        else
            FullAuto:Stop()
            StatusLabel.Text = "⏸ Pipeline stopped"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
        end
    end)
    
    -- MAP & SERVER
    CreateSectionLabel("━━━ 🗺️ MAP & SERVER ━━━", 10)
    
    CreateToggleButton("AutoMapTPBtn", "Auto Teleport to Map 143", 11, function(state)
        if state then
            MapTeleporter:Start()
            StatusLabel.Text = "🗺️ Teleporting to Map 143..."
        else
            MapTeleporter:Stop()
        end
    end)
    
    CreateToggleButton("ServerHopBtn", "Auto Server Hop (Empty → Hop)", 12, function(state)
        if state then
            ServerHopper:StartMonitor()
            StatusLabel.Text = "🔄 Server hop monitor active"
        else
            ServerHopper:Stop()
        end
    end)
    
    CreateActionButton("ManualHopBtn", "🔄 Manual Server Hop", Color3.fromRGB(50, 80, 50), 13, function()
        StatusLabel.Text = "🔄 Hopping server..."
        task.spawn(function()
            ServerHopper:Hop()
        end)
    end)
    
    -- CLAW MACHINE
    CreateSectionLabel("━━━ 🎮 CLAW MACHINE ━━━", 20)
    
    CreateToggleButton("AutoPlayBtn", "Auto Play Claw", 21, function(state)
        if state then
            ClawController:StartAutoPlay()
            StatusLabel.Text = "🎮 Auto playing claw machines..."
            StatusLabel.TextColor3 = Color3.fromRGB(120, 255, 170)
        else
            ClawController:StopAutoPlay()
            StatusLabel.Text = "⏸ Claw stopped"
        end
    end)
    
    CreateToggleButton("AutoCollectBtn", "Auto Collect Prizes", 22, function(state)
        if state then Collector:Start() else Collector:Stop() end
    end)
    
    CreateToggleButton("AutoTPBtn", "Auto TP to Nearest Machine", 23, function(state)
        Config.AutoTeleport = state
    end)
    
    CreateActionButton("TPNearestBtn", "⚡ Teleport to Nearest", Color3.fromRGB(50, 30, 80), 24, function()
        local machine = Scanner:GetNearestMachine()
        if machine then
            ClawController:TeleportTo(machine)
            StatusLabel.Text = "⚡ Teleported!"
        else
            StatusLabel.Text = "❌ No machines found"
        end
    end)
    
    -- SAFETY
    CreateSectionLabel("━━━ 🛡️ SAFETY ━━━", 30)
    
    CreateToggleButton("AntiDetectBtn", "Anti-Detection", 31, function(state)
        Config.AntiDetect = state
        Config.HumanizeDelay = state
    end)
    
    CreateToggleButton("AntiAFKBtn", "Anti-AFK", 32, function(state)
        Config.AntiAFK = state
    end)
    
    -- Footer
    local Footer = Instance.new("TextLabel")
    Footer.Size = UDim2.new(1, 0, 0, 20)
    Footer.Position = UDim2.new(0, 0, 1, -22)
    Footer.BackgroundTransparency = 1
    Footer.Text = "RightShift to toggle | Axiom v2.0"
    Footer.TextColor3 = Color3.fromRGB(60, 60, 80)
    Footer.TextSize = 9
    Footer.Font = Enum.Font.Gotham
    Footer.Parent = MainFrame
    
    -- Draggable
    local dragging, dragStart, startPos
    
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
        end
    end)
    
    TitleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    -- Toggle Visibility
    UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == Config.ToggleKey then
            Config.UIVisible = not Config.UIVisible
            MainFrame.Visible = Config.UIVisible
        end
    end)
    
    -- Live Stats Updater
    task.spawn(function()
        while ScreenGui.Parent do
            pcall(function()
                local eggCount = EggDetector:GetCount()
                local machines = Scanner:FindClawMachines()
                local uptime = math.floor((tick() - Stats.SessionStart) / 60)
                
                EggLabel.Text = "🥚 Eggs: " .. eggCount .. " | Machines: " .. #machines
                HopLabel.Text = "🔄 Hops: " .. Stats.ServerHops
                PlayedLabel.Text = "🎮 Played: " .. Stats.MachinesPlayed .. " | ⏱ " .. uptime .. "m"
                
                if ServerHopper.Hopping then
                    StatusLabel.Text = "🔄 HOPPING SERVER..."
                    StatusLabel.TextColor3 = Color3.fromRGB(255, 180, 60)
                elseif eggCount <= Config.MinEggsBeforeHop and Config.AutoServerHop then
                    StatusLabel.Text = "⚠ Map depleted — hop in " .. (Config.EmptyCheckCount - Stats.EmptyStreak) .. " checks"
                    StatusLabel.TextColor3 = Color3.fromRGB(255, 130, 80)
                end
            end)
            task.wait(2)
        end
    end)
    
    -- Intro Animation
    MainFrame.BackgroundTransparency = 1
    TweenService:Create(MainFrame, TweenInfo.new(0.6, Enum.EasingStyle.Back), {BackgroundTransparency = 0}):Play()
    
    return ScreenGui
end

-- ═══════════════════════════════════════════
-- CHARACTER RESPAWN HANDLER
-- ═══════════════════════════════════════════
Player.CharacterAdded:Connect(function(char)
    Character = char
    HumanoidRootPart = char:WaitForChild("HumanoidRootPart")
    Humanoid = char:WaitForChild("Humanoid")
    task.wait(1)
    
    -- Resume all active systems after respawn
    if FullAuto.Active then
        FullAuto:Start()
    else
        if Config.AutoPlay then ClawController:StartAutoPlay() end
        if Config.AutoCollect then Collector:Start() end
        if Config.AutoMapTP then MapTeleporter:Start() end
    end
end)

-- ═══════════════════════════════════════════
-- TELEPORT HANDLER — Re-init after server hop
-- ═══════════════════════════════════════════
TeleportService.TeleportInitFailed:Connect(function(_, _, teleportResult, errorMessage)
    warn("[Axiom] Teleport failed: " .. tostring(teleportResult) .. " — " .. tostring(errorMessage))
    ServerHopper.Hopping = false
    
    -- Retry after delay
    task.wait(Config.HopRetryDelay)
    if Config.AutoServerHop then
        ServerHopper:Hop()
    end
end)

-- ═══════════════════════════════════════════
-- INITIALIZATION
-- ═══════════════════════════════════════════
print("═══════════════════════════════════════════")
print("  ⚡ AXIOM — CLAW MACHINE v2.0")
print("  Mini World 2 | Map 143")
print("  Auto Map TP | Server Hop | Full Auto")
print("  Toggle UI: RightShift")
print("═══════════════════════════════════════════")

UI:Create()

local machines = Scanner:FindClawMachines()
print("[Axiom] Scanned " .. #machines .. " claw machines")

local eggs = EggDetector:GetCount()
print("[Axiom] Detected " .. eggs .. " eggs/prizes on map")

local remotes = Scanner:FindRemotes()
local rc = 0
for _ in pairs(remotes) do rc = rc + 1 end
print("[Axiom] Found " .. rc .. " relevant remotes")
print("[Axiom] Ready — hit Full Auto or configure manually")
