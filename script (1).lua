local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

local Network = ReplicatedStorage:WaitForChild("Network")
local LocalPlayer = Players.LocalPlayer

-- [ CẤU HÌNH ]
local TARGET_PLACE_ID = 8737899170  -- Place ID mày yêu cầu
local HOP_TIME = 180
local THREAD_COUNT = 2
local DELAY_TIME = 0.01
local isWorking = true

local spawn = task.spawn
local wait = task.wait

local Unlock = Network.SecretRoom_Unlock
local Enter = Network.Instancing_PlayerEnterInstance
local Custom = Network.Instancing_InvokeCustomFromClient
local Leave = Network.Instancing_PlayerLeaveInstance

local Invk = Unlock.InvokeServer
local Fire = Leave.FireServer

local S_CR1, S_CR2, S_SC = "Chest Roulette", "ChestRoulette", "SelectChest"

-- Hàm xả đạn (Dùng task.spawn để bypass hàng chờ)
local function UltraBurstFire()
    spawn(Invk, Unlock, S_CR1) 
    spawn(Invk, Enter, S_CR2) 
    spawn(Invk, Custom, S_CR2, S_SC, 2) 
    Fire(Leave, S_CR2)
end

-- Hàm nhảy Server (Tối ưu để reset RAM nhanh nhất)
local function FastServerHop()
    isWorking = false -- Dừng script ngay lập tức
    
    -- Bật lại Render để Roblox xử lý Teleport không bị treo
    RunService:Set3dRenderingEnabled(true)
    
    -- Nghỉ 2 giây để thông nghẽn Network
    wait(2)
    
    print("🚀 ĐANG RESET RAM - NHẢY TỚI PLACE: " .. TARGET_PLACE_ID)
    
    -- Nhảy thẳng vào Place ID mày chọn
    TeleportService:Teleport(TARGET_PLACE_ID, LocalPlayer)
    
    -- Chống kẹt: Nếu sau 5 giây không đi được thì ép nhảy lại lần nữa
    task.delay(5, function()
        TeleportService:Teleport(TARGET_PLACE_ID, LocalPlayer)
    end)
end

-- Khởi động hệ thống
spawn(function()
    wait(5)
    RunService:Set3dRenderingEnabled(false) 
    settings().Physics.PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.Disabled
    
    -- Dọn rác định kỳ
    task.spawn(function()
        while isWorking do
            wait(30)
            collectgarbage("collect")
        end
    end)

    -- Đặt lịch nhảy Server
    task.delay(HOP_TIME, FastServerHop)

    -- Chạy luồng bắn phá
    for i = 1, THREAD_COUNT do
        spawn(function()
            while isWorking do
                UltraBurstFire()
                wait(DELAY_TIME)
            end
        end)
    end
end)

-- [ Giao diện UI ]
local ScreenGui = Instance.new("ScreenGui", CoreGui)
local Label = Instance.new("TextLabel", ScreenGui)
Label.Size, Label.Position = UDim2.new(0, 250, 0, 50), UDim2.new(0.02, 0, 0.05, 0)
Label.BackgroundColor3, Label.TextColor3 = Color3.fromRGB(0, 0, 0), Color3.fromRGB(0, 255, 255) 
Label.Font, Label.TextScaled = Enum.Font.Code, true

spawn(function()
    local startTime = tick()
    while isWorking do
        local timeLeft = math.max(0, math.floor(HOP_TIME - (tick() - startTime)))
        Label.Text = "🚨 RAM RESET MODE\n🔥 NEXT PLACE HOP: " .. timeLeft .. "s"
        wait(1)
    end
end)
