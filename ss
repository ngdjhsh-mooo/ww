-- ============================================================
-- SCRIPT MAP 58 - LUỒNG 1: UNLOCK → SPIN (tuần tự)
-- Chạy từng bước: tìm nút Unlock → click → chờ hộp thoại Yes → click
-- Sau đó chuyển sang quay Spin liên tục
-- ============================================================
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local TeleportService = game:GetService("TeleportService")

local isRunning = false
local isUnlocked = false  -- cờ đánh dấu đã mở cửa thành công

-- [1] HÀM TÌM NÚT THEO VĂN BẢN (không phân biệt hoa thường)
local function FindButtonByText(textPatterns)
    for _, gui in ipairs(CoreGui:GetDescendants()) do
        if gui:IsA("TextButton") or gui:IsA("TextLabel") then
            local txt = gui.Text or ""
            for _, pattern in ipairs(textPatterns) do
                if string.find(string.lower(txt), string.lower(pattern)) then
                    return gui
                end
            end
        end
    end
    return nil
end

-- [2] HÀM CLICK + LOG
local function ClickAndLog(btn, actionName)
    if not btn then 
        print("[DEBUG] Không tìm thấy nút: " .. actionName)
        return false 
    end
    btn:Activate()
    btn:Click()
    print("[DEBUG] Đã click: " .. actionName .. " - Text: " .. btn.Text)
    return true
end

-- [3] LUỒNG CHÍNH - THỰC HIỆN TUẦN TỰ
local function MainLoop()
    while isRunning do
        -- BƯỚC 1: Nếu chưa unlock, tìm nút Unlock / Use Key
        if not isUnlocked then
            local unlockBtn = FindButtonByText({"unlock", "use key", "secret key", "open door"})
            if unlockBtn then
                ClickAndLog(unlockBtn, "Unlock")
                task.wait(0.2)  -- chờ hộp thoại xuất hiện
            end

            -- BƯỚC 2: Tìm hộp thoại Yes/Confirm
            local yesBtn = FindButtonByText({"yes", "confirm", "ok", "accept"})
            if yesBtn then
                ClickAndLog(yesBtn, "Yes/Confirm")
                task.wait(0.3)
                -- Giả định nếu click Yes thành công, cửa đã mở
                isUnlocked = true
                print("[PS99] ✅ Unlock thành công! Chuyển sang Spin.")
            else
                -- Nếu không tìm thấy Yes, có thể chưa xuất hiện, thử lại
                task.wait(0.1)
            end
        else
            -- BƯỚC 3: Sau khi unlock, quay Spin liên tục
            local spinBtn = FindButtonByText({"spin", "spin!", "quay"})
            if spinBtn then
                ClickAndLog(spinBtn, "Spin")
            end

            -- Xử lý nút Ok sau khi quay xong
            local okBtn = FindButtonByText({"ok", "continue", "next"})
            if okBtn then
                ClickAndLog(okBtn, "Ok")
            end

            task.wait(0.01)  -- tốc độ cao khi đã unlock
        end
    end
end

-- [4] NHẢY MAP 58 (nếu cần)
task.spawn(function()
    if game.PlaceId ~= 8737899170 then
        print("[PS99] Teleport đến map 58...")
        TeleportService:Teleport(8737899170, LocalPlayer)
        wait(5)
    end
end)

-- [5] ĐIỀU KHIỂN
local function StartSingleThread()
    if isRunning then return end
    isRunning = true
    isUnlocked = false
    task.spawn(MainLoop)
    print("[PS99] Đã khởi động LUỒNG 1 (Unlock → Spin).")
end

local function StopSingleThread()
    isRunning = false
    print("[PS99] Đã dừng.")
end

-- [6] UI
local ScreenGui = Instance.new("ScreenGui", CoreGui)
local Btn = Instance.new("TextButton", ScreenGui)
Btn.Size = UDim2.new(0, 220, 0, 50)
Btn.Position = UDim2.new(0.02, 0, 0.1, 0)
Btn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
Btn.Text = "[ START ] LUỒNG 1"
Btn.TextColor3 = Color3.new(1,1,1)
Btn.Font = Enum.Font.GothamBold
Btn.TextScaled = true

local Status = Instance.new("TextLabel", ScreenGui)
Status.Size = UDim2.new(0, 220, 0, 30)
Status.Position = UDim2.new(0.02, 0, 0.16, 0)
Status.BackgroundTransparency = 1
Status.Text = "Trạng thái: DỪNG"
Status.TextColor3 = Color3.fromRGB(200,200,200)
Status.TextScaled = true

Btn.MouseButton1Click:Connect(function()
    if isRunning then
        StopSingleThread()
        Btn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        Btn.Text = "[ START ] LUỒNG 1"
        Status.Text = "Trạng thái: DỪNG"
        Status.TextColor3 = Color3.fromRGB(200,100,100)
    else
        StartSingleThread()
        Btn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        Btn.Text = "[ STOP ] LUỒNG 1"
        Status.Text = "Trạng thái: ĐANG CHẠY (1 luồng)"
        Status.TextColor3 = Color3.fromRGB(0,255,100)
    end
end)

print("[PS99] Script LUỒNG 1 đã sẵn sàng. Nhấn START để bắt đầu.")
print("[PS99] Theo dõi cửa sổ Console (F9) để xem log click.")
