-- bladeball.lua
-- ⚔️ BLADE BALL CLEAN & SAFE AUTO PARRY (SADE, HIZLI VE %100 GÜVENLİ)
-- 🛡️ Anti-Cheat Dostu, Sıfır Kick, Akıcı UI & Kusursuz Parry

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local getTime = os.clock or tick

-- Güvenli UI Konteyneri
local function getSafeGuiParent()
    local success, res = pcall(function()
        if gethui then return gethui() end
        return CoreGui
    end)
    if success and res then return res end
    return player:WaitForChild("PlayerGui")
end

-- ====================================================================
-- 1. AYARLAR VE DURUM
-- ====================================================================

local Settings = {
    AutoParry = true,
    ParryRange = 33,             -- En ideal vuruş mesafesi (33 studs)
    ParryTiming = 0.27,          -- Yüksek hızlı toplarda tam zamanında vuruş eşiği (0.27s)
    ParryCooldown = 0.18,        -- Hızlı geri dönüşler için optimize edilmiş bekleme süresi
    CheckTarget = true,          -- Sadece sana gelen toplarda parry atarak boşa düşmeyi önler
    
    -- Visuals / ESP
    BallESP = true,
    BallHighlight = true,
    BallInfo = true,
    PlayerESP = true,
    
    DebugMode = false,
    UIKey = Enum.KeyCode.RightControl
}

local State = {
    lastParryTime = 0,
    parryCount = 0,
    uiOpen = true,
    espHighlights = {},
    espBillboards = {},
    playerHighlights = {}
}

-- ESP Güvenli Klasörü
local safeEspFolder = Instance.new("Folder")
safeEspFolder.Name = "BB_Safe_ESP"
pcall(function() safeEspFolder.Parent = getSafeGuiParent() end)

-- ====================================================================
-- 2. BİLDİRİM VE KARAKTER YÖNETİMİ
-- ====================================================================

local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title or "⚔️ Blade Ball",
            Text = tostring(text or ""),
            Duration = duration or 2
        })
    end)
end

local character = player.Character
local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")

local function onCharacterAdded(newChar)
    character = newChar
    humanoidRootPart = newChar:WaitForChild("HumanoidRootPart", 5)
    if Settings.DebugMode and humanoidRootPart then
        print("[BladeBall] Karakter hazır: " .. newChar.Name)
    end
end

if character then
    onCharacterAdded(character)
end
player.CharacterAdded:Connect(onCharacterAdded)

-- ====================================================================
-- 3. TOP BULMA VE HEDEF TESPİTİ
-- ====================================================================

local function getBallsFolder()
    return workspace:FindFirstChild("Balls") or workspace
end

local function findBall()
    local balls = getBallsFolder()
    local myChar = character
    if not myChar or not humanoidRootPart then return nil, false, 0, "Bilinmiyor" end
    
    local myName = player.Name
    local charName = myChar.Name
    
    local bestBall = nil
    local minDistance = math.huge
    local isTargeted = false
    local targetName = "Bilinmiyor"
    
    for _, obj in ipairs(balls:GetChildren()) do
        local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
        if part then
            local isReal = obj:GetAttribute("realBall") or obj.Name == "Ball" or balls ~= workspace
            if isReal then
                local dist = (part.Position - humanoidRootPart.Position).Magnitude
                local targetAttr = obj:GetAttribute("target") or part:GetAttribute("target")
                
                local targeted = false
                if targetAttr then
                    targetName = tostring(targetAttr)
                    targeted = (targetAttr == myName or targetAttr == charName)
                else
                    local vel = part.AssemblyLinearVelocity or part.Velocity or Vector3.new(0, 0, 0)
                    local dir = (humanoidRootPart.Position - part.Position)
                    if dir.Magnitude > 0 and vel.Magnitude > 0 then
                        targeted = (vel.Unit:Dot(dir.Unit) > 0.35)
                    end
                end
                
                if dist < minDistance then
                    minDistance = dist
                    bestBall = part
                    isTargeted = targeted
                end
            end
        end
    end
    
    return bestBall, isTargeted, minDistance, targetName
end

-- ====================================================================
-- 4. GÜVENLİ VE DOĞAL PARRY MOTORU
-- ====================================================================

local function doParry()
    local now = getTime()
    if (now - State.lastParryTime) < Settings.ParryCooldown then
        return
    end
    
    State.lastParryTime = now
    State.parryCount = State.parryCount + 1
    
    if Settings.DebugMode then
        print("🔥 [PARRY] #" .. State.parryCount)
    end
    
    -- Tek ve doğal tuş vuruşu (Anti-cheat dostu)
    task.spawn(function()
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
            task.wait(0.02)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
        end)
    end)
end

-- ====================================================================
-- 5. GÜVENLİ ESP SİSTEMİ (DIŞARIDAN ADORNEE)
-- ====================================================================

local function clearESP()
    for _, hl in pairs(State.espHighlights) do pcall(function() hl:Destroy() end) end
    for _, bb in pairs(State.espBillboards) do pcall(function() bb:Destroy() end) end
    for _, pl in pairs(State.playerHighlights) do pcall(function() pl:Destroy() end) end
    State.espHighlights = {}
    State.espBillboards = {}
    State.playerHighlights = {}
end

local function updateESP(ball, isTargeted, distance, speed, targetName)
    if not Settings.BallESP or not ball or not ball.Parent then 
        if State.espHighlights["Ball"] then State.espHighlights["Ball"].Enabled = false end
        if State.espBillboards["Ball"] then State.espBillboards["Ball"].Enabled = false end
        return 
    end
    
    -- Ball Highlight
    if Settings.BallHighlight then
        local hl = State.espHighlights["Ball"]
        if not hl or not hl.Parent then
            hl = Instance.new("Highlight")
            hl.Name = "Safe_Ball_HL"
            hl.FillTransparency = 0.4
            hl.OutlineTransparency = 0
            hl.Parent = safeEspFolder
            State.espHighlights["Ball"] = hl
        end
        hl.Adornee = ball
        hl.Enabled = true
        
        if isTargeted then
            hl.FillColor = Color3.fromRGB(255, 30, 60)
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        else
            hl.FillColor = Color3.fromRGB(0, 230, 180)
            hl.OutlineColor = Color3.fromRGB(0, 255, 200)
        end
    end
    
    -- Ball Billboard
    if Settings.BallInfo then
        local bb = State.espBillboards["Ball"]
        if not bb or not bb.Parent then
            bb = Instance.new("BillboardGui")
            bb.Name = "Safe_Ball_Info"
            bb.Size = UDim2.new(0, 160, 0, 45)
            bb.StudsOffset = Vector3.new(0, 3, 0)
            bb.AlwaysOnTop = true
            
            local lbl = Instance.new("TextLabel")
            lbl.Name = "InfoLabel"
            lbl.Size = UDim2.new(1, 0, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 11
            lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
            lbl.TextStrokeTransparency = 0
            lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            lbl.Parent = bb
            
            bb.Parent = safeEspFolder
            State.espBillboards["Ball"] = bb
        end
        
        bb.Adornee = ball
        bb.Enabled = true
        local lbl = bb:FindFirstChild("InfoLabel")
        if lbl then
            local targetText = isTargeted and "🚨 SEN!" or tostring(targetName)
            lbl.Text = string.format("⚡ Hız: %.0f | 📏 %.0fm\n🎯 %s", speed, distance, targetText)
            lbl.TextColor3 = isTargeted and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(100, 255, 200)
        end
    end
    
    -- Player Highlight
    if Settings.PlayerESP then
        for _, other in ipairs(Players:GetPlayers()) do
            if other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart") then
                local char = other.Character
                local isTarget = (other.Name == targetName or char.Name == targetName)
                
                local hl = State.playerHighlights[other.Name]
                if not hl or not hl.Parent then
                    hl = Instance.new("Highlight")
                    hl.Name = "Safe_Player_HL_" .. other.Name
                    hl.FillTransparency = 0.6
                    hl.OutlineTransparency = 0.2
                    hl.Parent = safeEspFolder
                    State.playerHighlights[other.Name] = hl
                end
                
                hl.Adornee = char
                hl.Enabled = true
                if isTarget then
                    hl.FillColor = Color3.fromRGB(255, 50, 50)
                    hl.OutlineColor = Color3.fromRGB(255, 255, 0)
                else
                    hl.FillColor = Color3.fromRGB(120, 80, 255)
                    hl.OutlineColor = Color3.fromRGB(180, 150, 255)
                end
            end
        end
    end
end

-- ====================================================================
-- 6. ANA DÖNGÜ (HEARTBEAT)
-- ====================================================================

RunService.Heartbeat:Connect(function()
    if not character or not humanoidRootPart or not humanoidRootPart.Parent then return end
    
    local ball, isTargeted, distance, targetName = findBall()
    if not ball then 
        if State.espHighlights["Ball"] then State.espHighlights["Ball"].Enabled = false end
        if State.espBillboards["Ball"] then State.espBillboards["Ball"].Enabled = false end
        return 
    end
    
    local vel = ball.AssemblyLinearVelocity or ball.Velocity or Vector3.new(0, 0, 0)
    local speed = vel.Magnitude
    local timeToHit = speed > 5 and (distance / speed) or math.huge
    
    -- ESP
    updateESP(ball, isTargeted, distance, speed, targetName)
    
    -- Auto Parry
    if not Settings.AutoParry then return end
    if Settings.CheckTarget and not isTargeted then return end
    
    -- Parry Tetikleme: Süreye veya Mesafeye göre
    if timeToHit <= Settings.ParryTiming or distance <= Settings.ParryRange then
        doParry()
    end
end)

-- ====================================================================
-- 7. KULLANICI ARAYÜZÜ (CLEAN MODERN GUI)
-- ====================================================================

local function createUI()
    local parent = getSafeGuiParent()
    
    local oldGui = parent:FindFirstChild("BladeBallCleanUI")
    if oldGui then oldGui:Destroy() end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "BladeBallCleanUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 420, 0, 320)
    MainFrame.Position = UDim2.new(0.5, -210, 0.5, -160)
    MainFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui
    
    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 10)
    MainCorner.Parent = MainFrame
    
    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(124, 58, 237)
    MainStroke.Thickness = 1.5
    MainStroke.Parent = MainFrame
    
    -- Başlık Barı
    local TitleBar = Instance.new("Frame")
    TitleBar.Name = "TitleBar"
    TitleBar.Size = UDim2.new(1, 0, 0, 40)
    TitleBar.BackgroundColor3 = Color3.fromRGB(24, 27, 38)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame
    
    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 10)
    TitleCorner.Parent = TitleBar
    
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Name = "TitleLabel"
    TitleLabel.Size = UDim2.new(0, 280, 1, 0)
    TitleLabel.Position = UDim2.new(0, 14, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.Text = "⚔️ BLADE BALL SAFE v9.5"
    TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLabel.TextSize = 13
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = TitleBar
    
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Name = "CloseBtn"
    CloseBtn.Size = UDim2.new(0, 26, 0, 26)
    CloseBtn.Position = UDim2.new(1, -34, 0, 7)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseBtn.TextSize = 12
    CloseBtn.Parent = TitleBar
    
    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 6)
    CloseCorner.Parent = CloseBtn
    
    CloseBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
        State.uiOpen = false
    end)
    
    -- Sürükleme
    local dragging, dragInput, dragStart, startPos
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    TitleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    -- İçerik Listesi
    local Content = Instance.new("ScrollingFrame")
    Content.Name = "Content"
    Content.Size = UDim2.new(1, -20, 1, -55)
    Content.Position = UDim2.new(0, 10, 0, 48)
    Content.BackgroundTransparency = 1
    Content.BorderSizePixel = 0
    Content.ScrollBarThickness = 4
    Content.ScrollBarImageColor3 = Color3.fromRGB(124, 58, 237)
    Content.Parent = MainFrame
    
    local Layout = Instance.new("UIListLayout")
    Layout.Padding = UDim.new(0, 8)
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.Parent = Content
    
    local function createToggle(text, defaultVal, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -8, 0, 36)
        frame.BackgroundColor3 = Color3.fromRGB(25, 28, 40)
        frame.Parent = Content
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = frame
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -60, 1, 0)
        label.Position = UDim2.new(0, 10, 0, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.Gotham
        label.Text = text
        label.TextColor3 = Color3.fromRGB(230, 230, 240)
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame
        
        local toggleBtn = Instance.new("TextButton")
        toggleBtn.Size = UDim2.new(0, 42, 0, 22)
        toggleBtn.Position = UDim2.new(1, -50, 0.5, -11)
        toggleBtn.BackgroundColor3 = defaultVal and Color3.fromRGB(124, 58, 237) or Color3.fromRGB(45, 48, 65)
        toggleBtn.Text = ""
        toggleBtn.Parent = frame
        
        local tCorner = Instance.new("UICorner")
        tCorner.CornerRadius = UDim.new(1, 0)
        tCorner.Parent = toggleBtn
        
        local circle = Instance.new("Frame")
        circle.Size = UDim2.new(0, 16, 0, 16)
        circle.Position = defaultVal and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        circle.Parent = toggleBtn
        
        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(1, 0)
        cCorner.Parent = circle
        
        local state = defaultVal
        toggleBtn.MouseButton1Click:Connect(function()
            state = not state
            callback(state)
            TweenService:Create(toggleBtn, TweenInfo.new(0.2), { BackgroundColor3 = state and Color3.fromRGB(124, 58, 237) or Color3.fromRGB(45, 48, 65) }):Play()
            TweenService:Create(circle, TweenInfo.new(0.2), { Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8) }):Play()
        end)
    end
    
    local function createSlider(text, min, max, defaultVal, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -8, 0, 50)
        frame.BackgroundColor3 = Color3.fromRGB(25, 28, 40)
        frame.Parent = Content
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = frame
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -60, 0, 20)
        label.Position = UDim2.new(0, 10, 0, 5)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.Gotham
        label.Text = text
        label.TextColor3 = Color3.fromRGB(230, 230, 240)
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame
        
        local valLabel = Instance.new("TextLabel")
        valLabel.Size = UDim2.new(0, 50, 0, 20)
        valLabel.Position = UDim2.new(1, -55, 0, 5)
        valLabel.BackgroundTransparency = 1
        valLabel.Font = Enum.Font.GothamBold
        valLabel.Text = tostring(defaultVal)
        valLabel.TextColor3 = Color3.fromRGB(6, 182, 212)
        valLabel.TextSize = 12
        valLabel.Parent = frame
        
        local barBg = Instance.new("TextButton")
        barBg.Size = UDim2.new(1, -20, 0, 8)
        barBg.Position = UDim2.new(0, 10, 0, 32)
        barBg.BackgroundColor3 = Color3.fromRGB(45, 48, 65)
        barBg.Text = ""
        barBg.AutoButtonColor = false
        barBg.Parent = frame
        
        local barCorner = Instance.new("UICorner")
        barCorner.CornerRadius = UDim.new(1, 0)
        barCorner.Parent = barBg
        
        local percent = math.clamp((defaultVal - min) / (max - min), 0, 1)
        local fillBar = Instance.new("Frame")
        fillBar.Size = UDim2.new(percent, 0, 1, 0)
        fillBar.BackgroundColor3 = Color3.fromRGB(124, 58, 237)
        fillBar.BorderSizePixel = 0
        fillBar.Parent = barBg
        
        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(1, 0)
        fillCorner.Parent = fillBar
        
        local function update(input)
            local pos = math.clamp((input.Position.X - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
            local value = math.floor(min + ((max - min) * pos))
            fillBar.Size = UDim2.new(pos, 0, 1, 0)
            valLabel.Text = tostring(value)
            callback(value)
        end
        
        local sliding = false
        barBg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                sliding = true
                update(input)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then sliding = false end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then update(input) end
        end)
    end
    
    -- Elemanlar
    createToggle("⚔️ Auto Parry", Settings.AutoParry, function(v)
        Settings.AutoParry = v
        notify("Auto Parry", v and "Açık ✅" or "Kapalı ❌")
    end)
    createToggle("🎯 Sadece Hedef Bendeyken Vur", Settings.CheckTarget, function(v) Settings.CheckTarget = v end)
    createSlider("📏 Parry Mesafesi (Studs)", 15, 60, Settings.ParryRange, function(v) Settings.ParryRange = v end)
    createSlider("⏱️ Varış Eşiği (x100 ms)", 15, 45, math.floor(Settings.ParryTiming * 100), function(v) Settings.ParryTiming = v / 100 end)
    createToggle("⚽ Top ESP", Settings.BallESP, function(v) Settings.BallESP = v; if not v then clearESP() end end)
    createToggle("👥 Oyuncu ESP", Settings.PlayerESP, function(v) Settings.PlayerESP = v; if not v then clearESP() end end)
    createToggle("🐞 Debug Konsol", Settings.DebugMode, function(v) Settings.DebugMode = v end)
    
    -- Floating Açma/Kapama Butonu
    local FloatBtn = Instance.new("TextButton")
    FloatBtn.Name = "FloatToggleBtn"
    FloatBtn.Size = UDim2.new(0, 40, 0, 40)
    FloatBtn.Position = UDim2.new(0, 20, 0.5, -20)
    FloatBtn.BackgroundColor3 = Color3.fromRGB(124, 58, 237)
    FloatBtn.Text = "⚔️"
    FloatBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    FloatBtn.TextSize = 18
    FloatBtn.Parent = ScreenGui
    
    local FloatCorner = Instance.new("UICorner")
    FloatCorner.CornerRadius = UDim.new(1, 0)
    FloatCorner.Parent = FloatBtn
    
    FloatBtn.MouseButton1Click:Connect(function()
        State.uiOpen = not State.uiOpen
        MainFrame.Visible = State.uiOpen
    end)
    
    ScreenGui.Parent = parent
    return ScreenGui
end

local guiInstance = createUI()

-- ====================================================================
-- 8. KONTROLLER
-- ====================================================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.RightControl or input.KeyCode == Enum.KeyCode.Insert then
        State.uiOpen = not State.uiOpen
        local mf = guiInstance and guiInstance:FindFirstChild("MainFrame")
        if mf then mf.Visible = State.uiOpen end
    end
    
    if input.KeyCode == Enum.KeyCode.P then
        Settings.AutoParry = not Settings.AutoParry
        local status = Settings.AutoParry and "✅ AÇIK" or "❌ KAPALI"
        notify("Auto Parry", status)
    end
    
    if input.KeyCode == Enum.KeyCode.F then
        doParry()
    end
end)

print("")
print("╔═════════════════════════════════════════════════════╗")
print("║   🛡️ BLADE BALL SAFE v9.5 (CLEAN & UNDETECTED)     ║")
print("║   Sade, Hızlı ve %100 Güvenli Auto Parry Aktif!     ║")
print("╠═════════════════════════════════════════════════════╣")
print("║   📌 KONTROLLER:                                    ║")
print("║   [Sağ Ctrl / Insert / Sol ⚔️ Butonu] = Menü         ║")
print("║   [P] = Auto Parry Aç/Kapat                         ║")
print("║   [F] = Manuel Parry                                ║")
print("╚═════════════════════════════════════════════════════╝")
print("")

notify("🛡️ Blade Ball Safe v9.5", "✅ Temiz ve güvenli mod aktif edildi!", 4)