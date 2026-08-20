-- bladeball.lua
-- ⚔️ BLADE BALL ULTIMATE v7.0 (PREMIUM UI & FULL ESP & AUTO PARRY)

-- ====================================================================
-- 1. SERVİSLER VE BAŞLANGIÇ
-- ====================================================================

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera or workspace:FindFirstChildOfClass("Camera")
local getTime = os.clock or tick

-- Gui Parent Belirleme (Executor güvenli gethui veya CoreGui)
local function getSafeGuiParent()
    local success, res = pcall(function()
        if gethui then return gethui() end
        return CoreGui
    end)
    if success and res then return res end
    return player:WaitForChild("PlayerGui")
end

-- ====================================================================
-- 2. AYARLAR VE DURUM (SETTINGS & STATE)
-- ====================================================================

local Settings = {
    -- Combat
    AutoParry = true,
    ParryRange = 32,
    ParryTiming = 0.28,
    ParryCooldown = 0.22,
    CheckTarget = true,
    AutoSpam = true,
    SpamDistance = 14,
    
    -- Visuals / ESP
    BallESP = true,
    BallHighlight = true,
    BallInfo = true,
    PlayerESP = true,
    PlayerHighlight = true,
    TargetHighlight = true,
    
    -- Misc / Movement
    WalkSpeedEnabled = false,
    WalkSpeed = 32,
    JumpPowerEnabled = false,
    JumpPower = 70,
    CustomFOV = false,
    FOVValue = 90,
    AntiAFK = true,
    
    -- System
    DebugMode = false,
    UIKey = Enum.KeyCode.RightControl
}

local State = {
    lastParryTime = 0,
    lastSpamTime = 0,
    parryCount = 0,
    isClashing = false,
    uiOpen = true,
    connections = {},
    espObjects = {}
}

-- ====================================================================
-- 3. BİLDİRİM VE YARDIMCI FONKSİYONLAR
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

-- ====================================================================
-- 4. KARAKTER YÖNETİMİ
-- ====================================================================

local character = player.Character
local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
local humanoid = character and character:FindFirstChildOfClass("Humanoid")

local function updateCharacter(newChar)
    character = newChar
    humanoidRootPart = newChar:WaitForChild("HumanoidRootPart", 5)
    humanoid = newChar:WaitForChild("Humanoid", 5)
    
    if Settings.DebugMode and humanoidRootPart then
        print("[BladeBall] Karakter yüklendi: " .. newChar.Name)
    end
end

if character then
    updateCharacter(character)
end
player.CharacterAdded:Connect(updateCharacter)

-- ====================================================================
-- 5. ANTI-AFK SİSTEMİ
-- ====================================================================

if Settings.AntiAFK then
    pcall(function()
        player.Idled:Connect(function()
            if Settings.AntiAFK then
                local VirtualUser = game:GetService("VirtualUser")
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
                if Settings.DebugMode then
                    print("[BladeBall] Anti-AFK tetiklendi (bağlantı kopması engellendi)")
                end
            end
        end)
    end)
end

-- ====================================================================
-- 6. TOP BULMA VE HEDEF TESPİT ALGORİTMASI
-- ====================================================================

local function getBallsFolder()
    return workspace:FindFirstChild("Balls") or workspace
end

local function findTargetBall()
    local ballsFolder = getBallsFolder()
    local myChar = character
    if not myChar or not humanoidRootPart then return nil, false, 0, nil end
    
    local myName = player.Name
    local charName = myChar.Name
    
    local closestBall = nil
    local minDistance = math.huge
    local isTargetedToMe = false
    local targetPlayerName = "Bilinmiyor"
    
    for _, obj in pairs(ballsFolder:GetChildren()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if part then
                local isReal = obj:GetAttribute("realBall") or obj.Name == "Ball" or obj.Name:lower():find("ball")
                if isReal or ballsFolder ~= workspace then
                    local targetAttr = obj:GetAttribute("target") or part:GetAttribute("target")
                    local targeted = false
                    
                    if targetAttr then
                        targetPlayerName = tostring(targetAttr)
                        targeted = (targetAttr == myName or targetAttr == charName)
                    else
                        local ballVel = part.AssemblyLinearVelocity or part.Velocity or Vector3.new(0, 0, 0)
                        local dirToMe = (humanoidRootPart.Position - part.Position)
                        if dirToMe.Magnitude > 0 and ballVel.Magnitude > 0 then
                            local dot = ballVel.Unit:Dot(dirToMe.Unit)
                            targeted = (dot > 0.35)
                        end
                    end
                    
                    local dist = (part.Position - humanoidRootPart.Position).Magnitude
                    if dist < minDistance then
                        minDistance = dist
                        closestBall = part
                        isTargetedToMe = targeted
                    end
                end
            end
        end
    end
    
    return closestBall, isTargetedToMe, minDistance, targetPlayerName
end

-- ====================================================================
-- 7. PARRY & CLASH MOTORU (ASENKRON & GÜVENLİ)
-- ====================================================================

local function doParry(isSpam)
    local now = getTime()
    local cd = isSpam and 0.08 or Settings.ParryCooldown
    
    if (now - State.lastParryTime) < cd then 
        return 
    end
    
    State.lastParryTime = now
    State.parryCount = State.parryCount + 1
    
    if Settings.DebugMode then
        print((isSpam and "⚡ SPAM PARRY! #" or "🔥 PARRY! #") .. State.parryCount)
    end
    
    -- VirtualInputManager ile güvenli tuş basımı
    task.spawn(function()
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
            task.wait(0.02)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
        end)
    end)
end

-- ====================================================================
-- 8. ESP & GÖRSEL SİSTEMİ (BALL & PLAYER ESP)
-- ====================================================================

local function clearESP()
    for _, obj in pairs(State.espObjects) do
        pcall(function()
            if obj and obj.Parent then obj:Destroy() end
        end)
    end
    State.espObjects = {}
end

local function updateBallESP(ball, isTargeted, distance, speed, targetName)
    if not Settings.BallESP or not ball or not ball.Parent then return end
    
    -- 1. Ball Highlight
    if Settings.BallHighlight then
        local hl = ball:FindFirstChild("BB_BallHighlight")
        if not hl then
            hl = Instance.new("Highlight")
            hl.Name = "BB_BallHighlight"
            hl.Adornee = ball
            hl.FillTransparency = 0.4
            hl.OutlineTransparency = 0
            hl.Parent = ball
            table.insert(State.espObjects, hl)
        end
        
        if isTargeted then
            hl.FillColor = Color3.fromRGB(255, 30, 60)
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        else
            hl.FillColor = Color3.fromRGB(0, 230, 180)
            hl.OutlineColor = Color3.fromRGB(0, 255, 200)
        end
    end
    
    -- 2. Ball Info Billboard
    if Settings.BallInfo then
        local bb = ball:FindFirstChild("BB_BallInfo")
        if not bb then
            bb = Instance.new("BillboardGui")
            bb.Name = "BB_BallInfo"
            bb.Adornee = ball
            bb.Size = UDim2.new(0, 160, 0, 45)
            bb.StudsOffset = Vector3.new(0, 3, 0)
            bb.AlwaysOnTop = true
            
            local lbl = Instance.new("TextLabel")
            lbl.Name = "InfoLabel"
            lbl.Size = UDim2.new(1, 0, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 12
            lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
            lbl.TextStrokeTransparency = 0
            lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            lbl.Parent = bb
            
            bb.Parent = ball
            table.insert(State.espObjects, bb)
        end
        
        local label = bb:FindFirstChild("InfoLabel")
        if label then
            local targetText = isTargeted and "🚨 SEN!" or tostring(targetName)
            label.Text = string.format("⚡ Hız: %.0f | 📏 %.0fm\n🎯 Hedef: %s", speed, distance, targetText)
            label.TextColor3 = isTargeted and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(100, 255, 200)
        end
    end
end

local function updatePlayerESP(targetPlayerName)
    if not Settings.PlayerESP then return end
    
    for _, otherPlayer in pairs(Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local char = otherPlayer.Character
            local isTarget = (otherPlayer.Name == targetPlayerName or char.Name == targetPlayerName)
            
            -- Player Highlight
            if Settings.PlayerHighlight then
                local hl = char:FindFirstChild("BB_PlayerHighlight")
                if not hl then
                    hl = Instance.new("Highlight")
                    hl.Name = "BB_PlayerHighlight"
                    hl.Adornee = char
                    hl.FillTransparency = 0.6
                    hl.OutlineTransparency = 0.2
                    hl.Parent = char
                    table.insert(State.espObjects, hl)
                end
                
                if isTarget and Settings.TargetHighlight then
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
-- 9. ANA DÖNGÜ (HEARTBEAT - COMBAT & VISUALS)
-- ====================================================================

RunService.Heartbeat:Connect(function()
    -- Karakter kontrolü
    if not character or not humanoidRootPart or not humanoidRootPart.Parent then return end
    
    -- Movement / Misc Enforcement
    if Settings.WalkSpeedEnabled and humanoid and humanoid.WalkSpeed ~= Settings.WalkSpeed then
        humanoid.WalkSpeed = Settings.WalkSpeed
    end
    if Settings.JumpPowerEnabled and humanoid and humanoid.JumpPower ~= Settings.JumpPower then
        humanoid.JumpPower = Settings.JumpPower
    end
    if Settings.CustomFOV and camera then
        camera.FieldOfView = Settings.FOVValue
    end
    
    -- Top ve Hedef Tespiti
    local ball, isTargeted, distance, targetName = findTargetBall()
    if not ball then return end
    
    local velocity = ball.AssemblyLinearVelocity or ball.Velocity or Vector3.new(0, 0, 0)
    local speed = velocity.Magnitude
    local timeToHit = speed > 5 and (distance / speed) or math.huge
    
    -- ESP Güncellemesi
    updateBallESP(ball, isTargeted, distance, speed, targetName)
    updatePlayerESP(targetName)
    
    -- Auto Parry Kontrolü
    if not Settings.AutoParry then return end
    
    -- Hedef Kontrolü (Sadece bize geliyorsa)
    if Settings.CheckTarget and not isTargeted then
        return
    end
    
    -- 1. Clash / Spam Parry (Top çok yakın ve hızlıysa)
    if Settings.AutoSpam and distance <= Settings.SpamDistance then
        doParry(true)
        return
    end
    
    -- 2. Normal Auto Parry (Zamanlama veya Mesafe eşiği)
    if timeToHit <= Settings.ParryTiming or distance <= Settings.ParryRange then
        doParry(false)
    end
end)

-- ====================================================================
-- 10. MODERN VE ŞIK KULLANICI ARAYÜZÜ (PREMIUM UI)
-- ====================================================================

local function createUI()
    local parent = getSafeGuiParent()
    
    -- Varsa eski GUI'yi temizle
    local oldGui = parent:FindFirstChild("BladeBallUltimateUI")
    if oldGui then oldGui:Destroy() end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "BladeBallUltimateUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Ana Pencere
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 520, 0, 360)
    MainFrame.Position = UDim2.new(0.5, -260, 0.5, -180)
    MainFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 29)
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui
    
    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 12)
    MainCorner.Parent = MainFrame
    
    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(124, 58, 237)
    MainStroke.Thickness = 1.5
    MainStroke.Parent = MainFrame
    
    -- Başlık Çubuğu (Title Bar)
    local TitleBar = Instance.new("Frame")
    TitleBar.Name = "TitleBar"
    TitleBar.Size = UDim2.new(1, 0, 0, 42)
    TitleBar.BackgroundColor3 = Color3.fromRGB(24, 27, 40)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame
    
    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 12)
    TitleCorner.Parent = TitleBar
    
    local TitleGradient = Instance.new("UIGradient")
    TitleGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(124, 58, 237)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 182, 212))
    })
    
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Name = "TitleLabel"
    TitleLabel.Size = UDim2.new(0, 260, 1, 0)
    TitleLabel.Position = UDim2.new(0, 16, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.Text = "⚔️ BLADE BALL ULTIMATE v7.0"
    TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLabel.TextSize = 14
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = TitleBar
    TitleGradient:Clone().Parent = TitleLabel
    
    -- Kapatma / Küçültme Butonları
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Name = "CloseBtn"
    CloseBtn.Size = UDim2.new(0, 28, 0, 28)
    CloseBtn.Position = UDim2.new(1, -36, 0, 7)
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
    
    -- Sürükleme (Drag) Desteği
    local dragging, dragInput, dragStart, startPos
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
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
    
    -- Sol Menü (Tabs Sidebar)
    local Sidebar = Instance.new("Frame")
    Sidebar.Name = "Sidebar"
    Sidebar.Size = UDim2.new(0, 130, 1, -42)
    Sidebar.Position = UDim2.new(0, 0, 0, 42)
    Sidebar.BackgroundColor3 = Color3.fromRGB(15, 17, 24)
    Sidebar.BorderSizePixel = 0
    Sidebar.Parent = MainFrame
    
    local ContentContainer = Instance.new("Frame")
    ContentContainer.Name = "ContentContainer"
    ContentContainer.Size = UDim2.new(1, -140, 1, -52)
    ContentContainer.Position = UDim2.new(0, 135, 0, 47)
    ContentContainer.BackgroundTransparency = 1
    ContentContainer.Parent = MainFrame
    
    -- Sekmeler
    local tabs = {
        { id = "Combat", name = "⚔️ Savaş" },
        { id = "Visuals", name = "👁️ ESP & Görsel" },
        { id = "Player", name = "⚡ Oyuncu" },
        { id = "Settings", name = "⚙️ Ayarlar" },
    }
    
    local tabButtons = {}
    local tabPages = {}
    
    local function switchTab(tabId)
        for id, page in pairs(tabPages) do
            page.Visible = (id == tabId)
        end
        for id, btn in pairs(tabButtons) do
            if id == tabId then
                btn.BackgroundColor3 = Color3.fromRGB(124, 58, 237)
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                btn.BackgroundColor3 = Color3.fromRGB(20, 23, 33)
                btn.TextColor3 = Color3.fromRGB(160, 165, 185)
            end
        end
    end
    
    for i, tab in ipairs(tabs) do
        local btn = Instance.new("TextButton")
        btn.Name = "Tab_" .. tab.id
        btn.Size = UDim2.new(1, -16, 0, 34)
        btn.Position = UDim2.new(0, 8, 0, 10 + (i - 1) * 40)
        btn.BackgroundColor3 = Color3.fromRGB(20, 23, 33)
        btn.Font = Enum.Font.GothamSemibold
        btn.Text = tab.name
        btn.TextColor3 = Color3.fromRGB(160, 165, 185)
        btn.TextSize = 12
        btn.Parent = Sidebar
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = btn
        
        tabButtons[tab.id] = btn
        
        -- Sayfa Frame
        local page = Instance.new("ScrollingFrame")
        page.Name = "Page_" .. tab.id
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 4
        page.ScrollBarImageColor3 = Color3.fromRGB(124, 58, 237)
        page.Visible = (i == 1)
        page.Parent = ContentContainer
        
        local pageLayout = Instance.new("UIListLayout")
        pageLayout.Padding = UDim.new(0, 8)
        pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
        pageLayout.Parent = page
        
        tabPages[tab.id] = page
        
        btn.MouseButton1Click:Connect(function()
            switchTab(tab.id)
        end)
    end
    
    -- UI Bileşen Oluşturucuları (Toggle & Slider)
    local function createToggle(parentPage, text, defaultVal, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -8, 0, 36)
        frame.BackgroundColor3 = Color3.fromRGB(25, 28, 40)
        frame.Parent = parentPage
        
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
            
            TweenService:Create(toggleBtn, TweenInfo.new(0.2), {
                BackgroundColor3 = state and Color3.fromRGB(124, 58, 237) or Color3.fromRGB(45, 48, 65)
            }):Play()
            
            TweenService:Create(circle, TweenInfo.new(0.2), {
                Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
            }):Play()
        end)
    end
    
    local function createSlider(parentPage, text, min, max, defaultVal, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -8, 0, 50)
        frame.BackgroundColor3 = Color3.fromRGB(25, 28, 40)
        frame.Parent = parentPage
        
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
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                sliding = false
            end
        end)
        
        UserInputService.InputChanged:Connect(function(input)
            if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                update(input)
            end
        end)
    end
    
    -- ====================
    -- SAYFA 1: SAVAŞ (COMBAT)
    -- ====================
    createToggle(tabPages["Combat"], "⚔️ Auto Parry", Settings.AutoParry, function(v)
        Settings.AutoParry = v
        notify("⚔️ Auto Parry", v and "Aktif edildi ✅" or "Kapatıldı ❌")
    end)
    
    createToggle(tabPages["Combat"], "🎯 Sadece Hedef Bendeyken Parry At", Settings.CheckTarget, function(v)
        Settings.CheckTarget = v
    end)
    
    createToggle(tabPages["Combat"], "⚡ Auto Spam / Clash Parry", Settings.AutoSpam, function(v)
        Settings.AutoSpam = v
    end)
    
    createSlider(tabPages["Combat"], "📏 Parry Mesafesi (Studs)", 15, 60, Settings.ParryRange, function(v)
        Settings.ParryRange = v
    end)
    
    createSlider(tabPages["Combat"], "⏱️ Parry Zamanlaması (x100 ms)", 15, 45, math.floor(Settings.ParryTiming * 100), function(v)
        Settings.ParryTiming = v / 100
    end)
    
    -- ====================
    -- SAYFA 2: VISUALS / ESP
    -- ====================
    createToggle(tabPages["Visuals"], "⚽ Top ESP (Genel)", Settings.BallESP, function(v)
        Settings.BallESP = v
        if not v then clearESP() end
    end)
    
    createToggle(tabPages["Visuals"], "✨ Top Highlight Parlaması", Settings.BallHighlight, function(v)
        Settings.BallHighlight = v
        if not v then clearESP() end
    end)
    
    createToggle(tabPages["Visuals"], "📊 Top Bilgileri (Hız & Mesafe)", Settings.BallInfo, function(v)
        Settings.BallInfo = v
        if not v then clearESP() end
    end)
    
    createToggle(tabPages["Visuals"], "👥 Oyuncu ESP", Settings.PlayerESP, function(v)
        Settings.PlayerESP = v
        if not v then clearESP() end
    end)
    
    createToggle(tabPages["Visuals"], "🎯 Hedef Oyuncuyu Vurgula", Settings.TargetHighlight, function(v)
        Settings.TargetHighlight = v
    end)
    
    -- ====================
    -- SAYFA 3: OYUNCU (PLAYER)
    -- ====================
    createToggle(tabPages["Player"], "⚡ Hızlı Koşma (Speed Boost)", Settings.WalkSpeedEnabled, function(v)
        Settings.WalkSpeedEnabled = v
        if not v and humanoid then humanoid.WalkSpeed = 16 end
    end)
    
    createSlider(tabPages["Player"], "🏃 Koşma Hızı", 16, 120, Settings.WalkSpeed, function(v)
        Settings.WalkSpeed = v
    end)
    
    createToggle(tabPages["Player"], "🦘 Yüksek Zıplama (Jump Boost)", Settings.JumpPowerEnabled, function(v)
        Settings.JumpPowerEnabled = v
        if not v and humanoid then humanoid.JumpPower = 50 end
    end)
    
    createSlider(tabPages["Player"], "🆙 Zıplama Gücü", 50, 200, Settings.JumpPower, function(v)
        Settings.JumpPower = v
    end)
    
    createToggle(tabPages["Player"], "🔭 Özel Görüş Açısı (FOV)", Settings.CustomFOV, function(v)
        Settings.CustomFOV = v
        if not v and camera then camera.FieldOfView = 70 end
    end)
    
    createSlider(tabPages["Player"], "📐 FOV Derecesi", 70, 120, Settings.FOVValue, function(v)
        Settings.FOVValue = v
    end)
    
    createToggle(tabPages["Player"], "🛡️ Anti-AFK (Oyun Düşmesini Önle)", Settings.AntiAFK, function(v)
        Settings.AntiAFK = v
    end)
    
    -- ====================
    -- SAYFA 4: AYARLAR (SETTINGS)
    -- ====================
    createToggle(tabPages["Settings"], "🐞 Debug Konsol Modu", Settings.DebugMode, function(v)
        Settings.DebugMode = v
        notify("Debug Modu", v and "Açık" or "Kapalı")
    end)
    
    -- Floating UI Açma/Kapama Butonu
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
    
    local FloatStroke = Instance.new("UIStroke")
    FloatStroke.Color = Color3.fromRGB(255, 255, 255)
    FloatStroke.Thickness = 1.5
    FloatStroke.Parent = FloatBtn
    
    FloatBtn.MouseButton1Click:Connect(function()
        State.uiOpen = not State.uiOpen
        MainFrame.Visible = State.uiOpen
    end)
    
    -- İlk sekmeyi seç
    switchTab("Combat")
    
    ScreenGui.Parent = parent
    return ScreenGui
end

-- UI'yi Başlat
local guiInstance = createUI()

-- ====================================================================
-- 11. KLAVYE KISAYOLLARI (KEYBINDS)
-- ====================================================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- Sağ Ctrl veya Insert ile Menüyü Aç/Kapat
    if input.KeyCode == Enum.KeyCode.RightControl or input.KeyCode == Enum.KeyCode.Insert then
        State.uiOpen = not State.uiOpen
        local mf = guiInstance and guiInstance:FindFirstChild("MainFrame")
        if mf then mf.Visible = State.uiOpen end
    end
    
    -- P tuşu: Hızlı Auto Parry Toggle
    if input.KeyCode == Enum.KeyCode.P then
        Settings.AutoParry = not Settings.AutoParry
        local status = Settings.AutoParry and "✅ AÇIK" or "❌ KAPALI"
        notify("⚔️ Blade Ball", "Auto Parry: " .. status)
    end
    
    -- F tuşu: Manuel Test Parry
    if input.KeyCode == Enum.KeyCode.F then
        doParry(false)
    end
end)

-- ====================================================================
-- 12. BAŞLANGIÇ MESAJI
-- ====================================================================

print("")
print("╔═══════════════════════════════════════════════════╗")
print("║   ⚔️ BLADE BALL ULTIMATE v7.0                    ║")
print("║   Gelişmiş UI, ESP & Auto Parry Aktif!          ║")
print("╠═══════════════════════════════════════════════════╣")
print("║   📌 KONTROLLER:                                  ║")
print("║   [Sağ Ctrl / Insert / Sol Buton] = Menüyü Aç/Kapa║")
print("║   [P] = Auto Parry Aç/Kapat                       ║")
print("║   [F] = Manuel Parry                              ║")
print("╚═══════════════════════════════════════════════════╝")
print("")

notify("⚔️ Blade Ball v7.0", "✅ Menü ve ESP başarıyla yüklendi!\nMenü için: Sağ Ctrl veya ⚔️ butonuna bas.", 4)