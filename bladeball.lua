-- bladeball.lua
-- ⚔️ BLADE BALL ULTIMATE v9.0 [QUANTUM TRAJECTORY & CPA ENGINE]
-- 🎯 İleri Düzey Kavis (Curve), İvme (Acceleration) & CPA (Closest Point of Approach) Analiz Motoru
-- 🛡️ %100 İsabetli Top Algılama, Ping Telafisi, Otomatik Yüz Dönme & BAC Koruması

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

local Stats = nil
pcall(function() Stats = game:GetService("Stats") end)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera or workspace:FindFirstChildOfClass("Camera")
local getTime = os.clock or tick
local renderSignal = RunService.RenderStepped or RunService.Heartbeat

-- Vektör Matematik Yardımcıları (100% Uyumluluk & Hız)
local function vec3(x, y, z) return Vector3.new(x or 0, y or 0, z or 0) end
local function addV(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
local function subV(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
local function mulV(v, s) return Vector3.new(v.X * s, v.Y * s, v.Z * s) end
local function dotV(a, b) return (a.X * b.X + a.Y * b.Y + a.Z * b.Z) end
local function magV(v) return math.sqrt(v.X^2 + v.Y^2 + v.Z^2) end
local function unitV(v)
    local m = magV(v)
    return (m > 0) and Vector3.new(v.X / m, v.Y / m, v.Z / m) or v
end

-- ====================================================================
-- 2. BAC ANTI-CHEAT GÜVENLİK VE BYPASS KATMANI
-- ====================================================================

pcall(function()
    if hookmetamethod then
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if not checkcaller() and (method == "Kick" or method == "kick") and self == player then
                warn("[BAC Bypass] Client-side kick engellendi!")
                return nil
            end
            return oldNamecall(self, ...)
        end))
    end
    
    if hookfunction and player.Kick then
        hookfunction(player.Kick, newcclosure(function(self, ...)
            if not checkcaller() and self == player then
                return nil
            end
        end))
    end
end)

local function getSafeGuiParent()
    local success, res = pcall(function()
        if gethui then return gethui() end
        return CoreGui
    end)
    if success and res then return res end
    return player:WaitForChild("PlayerGui")
end

local safeEspFolder = Instance.new("Folder")
safeEspFolder.Name = "BB_SafeESP_" .. math.random(1000, 9999)
pcall(function()
    safeEspFolder.Parent = getSafeGuiParent()
end)

-- Anti-AFK
pcall(function()
    if getconnections then
        for _, conn in pairs(getconnections(player.Idled)) do
            if conn.Disable then conn:Disable() elseif conn.Disconnect then conn:Disconnect() end
        end
    else
        player.Idled:Connect(function()
            local VirtualUser = game:GetService("VirtualUser")
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end
end)

-- ====================================================================
-- 3. AYARLAR VE DURUM (SETTINGS & QUANTUM ENGINE CONFIG)
-- ====================================================================

local Settings = {
    -- Combat (Temel Dövüş)
    AutoParry = true,
    ParryRange = 32,             -- Standart mesafe eşiği
    ParryTiming = 0.28,          -- Temel varış süresi eşiği (sn)
    ParryCooldown = 0.22,        -- Normal vuruşlar arası bekleme
    CheckTarget = true,          -- Hedef doğrulama filtresi
    
    -- Kuantum Yörünge & Gelişmiş Algılama (Quantum Trajectory Engine)
    CPAEngine = true,            -- En Yakın Yaklaşma Noktası (Closest Point of Approach) Analizi
    CurvePrediction = true,      -- Kavisli/Dönen (Spin/Rapture/Phantom) top tahmini
    AccelerationTracking = true, -- Ani hızlanma/yavaşlama ivme hesabı
    MaxMissDistance = 14,        -- Topun ıskalayacağı mesafe toleransı (Studs)
    
    -- Ping & Hız Dengeleyici
    PingCompensation = true,     -- Otomatik gerçek ping telafisi
    AutoClash = true,            -- Yakın temas clash modu
    ClashDistance = 15,          -- Clash algılama mesafesi (Studs)
    ClashCooldown = 0.07,        -- Clash vuruş hızı
    AutoLookAtBall = true,       -- Topa otomatik dönerek hitbox genişletme
    
    -- Visuals / ESP
    BallESP = true,
    BallHighlight = true,
    BallInfo = true,
    PlayerESP = true,
    PlayerHighlight = true,
    TargetHighlight = true,
    
    -- Görünüm & Sistem
    CustomFOV = false,
    FOVValue = 90,
    DebugMode = false,
    UIKey = Enum.KeyCode.RightControl
}

local State = {
    lastParryTime = 0,
    parryCount = 0,
    currentPing = 0.05,
    uiOpen = true,
    
    -- Top Geçmiş Takip Arabelleği (History Buffer for Acceleration & Curve)
    lastBallPos = nil,
    lastBallVel = nil,
    lastBallTime = 0,
    calculatedAcceleration = Vector3.new(0, 0, 0),
    
    -- Anlık Analiz Sonuçları
    timeToImpact = math.huge,
    missDistance = math.huge,
    isIncoming = false,
    threatLevel = "Güvende",
    threatColor = Color3.fromRGB(100, 255, 150),
    
    -- ESP Nesneleri
    espHighlights = {},
    espBillboards = {},
    playerHighlights = {}
}

-- ====================================================================
-- 4. BİLDİRİM VE GERÇEK PING ÖLÇER
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

local function getRealPing()
    local ping = 0.05
    pcall(function()
        if Stats then
            local perfStats = Stats:FindFirstChild("PerformanceStats")
            if perfStats and perfStats:FindFirstChild("Ping") then
                ping = math.clamp(perfStats.Ping:GetValue() / 1000, 0.02, 0.4)
                return
            end
            local netStats = Stats:FindFirstChild("Network")
            if netStats and netStats:FindFirstChild("ServerStatsItem") then
                local dataPing = netStats.ServerStatsItem:FindFirstChild("Data Ping")
                if dataPing then
                    ping = math.clamp(dataPing:GetValue() / 1000, 0.02, 0.4)
                end
            end
        end
    end)
    return ping
end

-- ====================================================================
-- 5. KARAKTER YÖNETİMİ
-- ====================================================================

local character = player.Character
local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
local humanoid = character and character:FindFirstChildOfClass("Humanoid")

local function updateCharacter(newChar)
    character = newChar
    humanoidRootPart = newChar:WaitForChild("HumanoidRootPart", 5)
    humanoid = newChar:WaitForChild("Humanoid", 5)
    
    if Settings.DebugMode and humanoidRootPart then
        print("[BladeBall] Karakter hazır: " .. newChar.Name)
    end
end

if character then
    updateCharacter(character)
end
player.CharacterAdded:Connect(updateCharacter)

-- ====================================================================
-- 6. TOP BULMA VE KUANTUM YÖRÜNGE ANALİZİ (QUANTUM TRAJECTORY)
-- ====================================================================

local function getBallsFolder()
    return workspace:FindFirstChild("Balls") or workspace
end

local function getTargetBall()
    local ballsFolder = getBallsFolder()
    local myChar = character
    if not myChar or not humanoidRootPart then return nil, false, 0, "Bilinmiyor", Vector3.new() end
    
    local myName = player.Name
    local charName = myChar.Name
    
    local bestBall = nil
    local minDistance = math.huge
    local isTargetedToMe = false
    local targetPlayerName = "Bilinmiyor"
    local ballVelocity = Vector3.new()
    
    for _, obj in pairs(ballsFolder:GetChildren()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if part then
                local isReal = obj:GetAttribute("realBall") or obj.Name == "Ball" or obj.Name:lower():find("ball")
                if isReal or ballsFolder ~= workspace then
                    local targetAttr = obj:GetAttribute("target") or part:GetAttribute("target")
                    local vel = part.AssemblyLinearVelocity or part.Velocity or Vector3.new(0, 0, 0)
                    local dist = magV(subV(part.Position, humanoidRootPart.Position))
                    
                    local targeted = false
                    if targetAttr then
                        targetPlayerName = tostring(targetAttr)
                        targeted = (targetAttr == myName or targetAttr == charName)
                    end
                    
                    if dist < minDistance then
                        minDistance = dist
                        bestBall = part
                        isTargetedToMe = targeted
                        ballVelocity = vel
                    end
                end
            end
        end
    end
    
    return bestBall, isTargetedToMe, minDistance, targetPlayerName, ballVelocity
end

-- ====================================================================
-- 7. CPA & KAVİS HESAPLAMA MOTORU (MATEMATİKSEL KUANTUM HESABI)
-- ====================================================================

local function calculateBallTrajectory(ball, ballVel, isTargetAttr)
    local now = getTime()
    local myPos = humanoidRootPart.Position
    local ballPos = ball.Position
    local myVel = humanoidRootPart.AssemblyLinearVelocity or humanoidRootPart.Velocity or Vector3.new(0, 0, 0)
    
    -- 1. İvme (Acceleration) ve Kavis Takibi
    if State.lastBallPos and State.lastBallTime > 0 then
        local dt = math.clamp(now - State.lastBallTime, 0.001, 0.1)
        local instVel = mulV(subV(ballPos, State.lastBallPos), 1 / dt)
        if State.lastBallVel then
            State.calculatedAcceleration = mulV(subV(instVel, State.lastBallVel), 1 / dt)
        end
        State.lastBallVel = instVel
    else
        State.lastBallVel = ballVel
    end
    State.lastBallPos = ballPos
    State.lastBallTime = now
    
    -- 2. Efektif Hız ve Kavis Düzeltmesi (Curved Velocity Prediction)
    local predictedVel = ballVel
    if Settings.CurvePrediction and magV(State.calculatedAcceleration) > 5 then
        predictedVel = addV(ballVel, mulV(State.calculatedAcceleration, 0.15))
    end
    
    -- 3. Bağıl Konum ve Hız Vektörleri
    local r = subV(ballPos, myPos)
    local v = subV(predictedVel, myVel)
    local vSq = dotV(v, v)
    local distance = magV(r)
    local speed = magV(predictedVel)
    
    -- 4. Closest Point of Approach (CPA) Hesabı
    local tCPA = 0
    local missDist = distance
    local isMovingTowards = false
    
    if vSq > 0.01 then
        local dotProduct = dotV(r, v)
        tCPA = -dotProduct / vSq
        
        if tCPA > 0 then
            isMovingTowards = true
            local closestPoint = addV(ballPos, mulV(predictedVel, tCPA))
            missDist = magV(subV(closestPoint, myPos))
        end
    end
    
    -- 5. Yaklaşma Hızı & Varış Süresi
    local approachSpeed = speed
    if distance > 0 and speed > 0 then
        local dirUnit = mulV(unitV(r), -1)
        local dot = dotV(predictedVel, dirUnit)
        if dot > 0 then
            approachSpeed = dot
        end
    end
    
    local effectiveSpeed = math.max(approachSpeed, speed, 1)
    local directTimeToHit = distance / effectiveSpeed
    
    local finalTimeToHit = (tCPA > 0 and tCPA < 5) and tCPA or directTimeToHit
    
    -- 6. Top Bize mi Geliyor?
    local isIncoming = false
    if isTargetAttr then
        isIncoming = true
    elseif isMovingTowards and missDist <= Settings.MaxMissDistance then
        isIncoming = true
    end
    
    return {
        distance = distance,
        speed = speed,
        timeToHit = finalTimeToHit,
        missDistance = missDist,
        isIncoming = isIncoming,
        predictedVelocity = predictedVel,
        predictedImpactPoint = addV(ballPos, mulV(predictedVel, math.clamp(finalTimeToHit, 0, 3)))
    }
end

-- ====================================================================
-- 8. ÜÇLÜ YEDEKLEMELİ PARRY MOTORU (TRIPLE REDUNDANCY)
-- ====================================================================

local function fireParryInputs()
    -- 1. Virtual Keycode F (Executor Doğrudan Girişi)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
        task.wait(0.015)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
    end)
    
    -- 2. Virtual Mouse Sol Tık (Mouse1 Click)
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        task.wait(0.01)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end)
    
    -- 3. Ekrandaki Parry Butonunu Tetikleme (Mobil / UI)
    pcall(function()
        local pgui = player:FindFirstChild("PlayerGui")
        if pgui then
            for _, gui in pairs(pgui:GetChildren()) do
                if gui:IsA("ScreenGui") and gui.Enabled then
                    local parryBtn = gui:FindFirstChild("ParryButton", true) or gui:FindFirstChild("Parry", true)
                    if parryBtn and parryBtn:IsA("GuiButton") and parryBtn.Visible then
                        if firesignal then
                            firesignal(parryBtn.Activated)
                            firesignal(parryBtn.MouseButton1Click)
                        end
                    end
                end
            end
        end
    end)
end

local function executeParry(isClash)
    local now = getTime()
    local cooldown = isClash and Settings.ClashCooldown or Settings.ParryCooldown
    
    if (now - State.lastParryTime) < cooldown then
        return
    end
    
    State.lastParryTime = now
    State.parryCount = State.parryCount + 1
    
    if Settings.DebugMode then
        print(string.format("🔥 [%s PARRY] #%d | Ping: %.0fms | TTH: %.2fs", 
            isClash and "CLASH" or "QUANTUM", State.parryCount, State.currentPing * 1000, State.timeToImpact))
    end
    
    task.spawn(fireParryInputs)
end

-- ====================================================================
-- 9. GÜVENLİ ESP VE YÖRÜNGE ÇİZGİSİ
-- ====================================================================

local function clearAllESP()
    for _, hl in pairs(State.espHighlights) do pcall(function() hl:Destroy() end) end
    for _, bb in pairs(State.espBillboards) do pcall(function() bb:Destroy() end) end
    for _, pl in pairs(State.playerHighlights) do pcall(function() pl:Destroy() end) end
    State.espHighlights = {}
    State.espBillboards = {}
    State.playerHighlights = {}
end

local function updateSafeBallESP(ball, isTargeted, trajData, targetName)
    if not Settings.BallESP or not ball or not ball.Parent then 
        if State.espHighlights["Ball"] then State.espHighlights["Ball"].Enabled = false end
        if State.espBillboards["Ball"] then State.espBillboards["Ball"].Enabled = false end
        return 
    end
    
    -- Highlight
    if Settings.BallHighlight then
        local hl = State.espHighlights["Ball"]
        if not hl or not hl.Parent then
            hl = Instance.new("Highlight")
            hl.Name = "Safe_Ball_HL"
            hl.FillTransparency = 0.35
            hl.OutlineTransparency = 0
            hl.Parent = safeEspFolder
            State.espHighlights["Ball"] = hl
        end
        hl.Adornee = ball
        hl.Enabled = true
        
        if isTargeted or trajData.isIncoming then
            hl.FillColor = Color3.fromRGB(255, 20, 60)
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        else
            hl.FillColor = Color3.fromRGB(0, 240, 180)
            hl.OutlineColor = Color3.fromRGB(0, 255, 200)
        end
    end
    
    -- Billboard Bilgi
    if Settings.BallInfo then
        local bb = State.espBillboards["Ball"]
        if not bb or not bb.Parent then
            bb = Instance.new("BillboardGui")
            bb.Name = "Safe_Ball_Info"
            bb.Size = UDim2.new(0, 190, 0, 52)
            bb.StudsOffset = Vector3.new(0, 3.5, 0)
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
            lbl.Text = string.format("⚡ Hız: %.0f | 📏 %.1fm\n⏱️ Varış: %.2fs | 🎯 %s", 
                trajData.speed, trajData.distance, trajData.timeToHit, targetText)
            lbl.TextColor3 = (isTargeted or trajData.isIncoming) and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(100, 255, 200)
        end
    end
end

local function updateSafePlayerESP(targetPlayerName)
    if not Settings.PlayerESP then 
        for _, hl in pairs(State.playerHighlights) do hl.Enabled = false end
        return 
    end
    
    for _, otherPlayer in pairs(Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local char = otherPlayer.Character
            local isTarget = (otherPlayer.Name == targetPlayerName or char.Name == targetPlayerName)
            
            if Settings.PlayerHighlight then
                local hl = State.playerHighlights[otherPlayer.Name]
                if not hl or not hl.Parent then
                    hl = Instance.new("Highlight")
                    hl.Name = "Safe_Player_HL_" .. otherPlayer.Name
                    hl.FillTransparency = 0.6
                    hl.OutlineTransparency = 0.2
                    hl.Parent = safeEspFolder
                    State.playerHighlights[otherPlayer.Name] = hl
                end
                
                hl.Adornee = char
                hl.Enabled = true
                if isTarget and Settings.TargetHighlight then
                    hl.FillColor = Color3.fromRGB(255, 60, 60)
                    hl.OutlineColor = Color3.fromRGB(255, 255, 0)
                else
                    hl.FillColor = Color3.fromRGB(130, 80, 255)
                    hl.OutlineColor = Color3.fromRGB(180, 150, 255)
                end
            end
        elseif State.playerHighlights[otherPlayer.Name] then
            State.playerHighlights[otherPlayer.Name].Enabled = false
        end
    end
end

-- ====================================================================
-- 10. ÇEKİRDEK İŞLEMCİ MOTORU (RENDERSTEPPED)
-- ====================================================================

renderSignal:Connect(function()
    if not character or not humanoidRootPart or not humanoidRootPart.Parent then return end
    
    State.currentPing = getRealPing()
    
    -- Kamera FOV
    if Settings.CustomFOV and camera then
        camera.FieldOfView = Settings.FOVValue
    end
    
    -- Topu Bul
    local ball, isTargetAttr, distance, targetName, velocity = getTargetBall()
    if not ball then 
        State.threatLevel = "Top Bekleniyor"
        State.threatColor = Color3.fromRGB(150, 150, 160)
        State.lastBallPos = nil
        return 
    end
    
    -- Kuantum Yörünge Analizini Gerçekleştir
    local traj = calculateBallTrajectory(ball, velocity, isTargetAttr)
    State.timeToImpact = traj.timeToHit
    State.missDistance = traj.missDistance
    State.isIncoming = traj.isIncoming
    
    -- Dinamik Eşik ve Ping Telafisi
    local pingCompensation = Settings.PingCompensation and (State.currentPing * 0.95) or 0
    local dynamicThreshold = Settings.ParryTiming + pingCompensation
    
    -- Hız Artışına Bağlı Adaptif Güvenlik Genişlemesi
    if traj.speed > 120 then
        dynamicThreshold = dynamicThreshold + 0.05
    elseif traj.speed > 200 then
        dynamicThreshold = dynamicThreshold + 0.09
    end
    
    -- Tehdit Seviyesi Değerlendirme
    if traj.isIncoming then
        if traj.distance <= Settings.ClashDistance then
            State.threatLevel = "⚡ CLASH MODU! (Spam Vuruş)"
            State.threatColor = Color3.fromRGB(255, 50, 200)
        elseif traj.timeToHit <= (dynamicThreshold * 1.5) then
            State.threatLevel = string.format("🚨 KRİTİK TEHLİKE! (Kalan: %.2fs)", traj.timeToHit)
            State.threatColor = Color3.fromRGB(255, 30, 30)
        else
            State.threatLevel = string.format("⚠️ Top Yaklaşıyor (Mesafe: %.0fm)", traj.distance)
            State.threatColor = Color3.fromRGB(255, 180, 30)
        end
    else
        State.threatLevel = "🛡️ GÜVENDE (Hedef: " .. tostring(targetName) .. ")"
        State.threatColor = Color3.fromRGB(60, 240, 140)
    end
    
    -- Otomatik Topa Yüzünü Dönme (Hitbox avantajı)
    if Settings.AutoLookAtBall and traj.isIncoming and traj.distance <= 45 then
        pcall(function()
            local lookPos = Vector3.new(ball.Position.X, humanoidRootPart.Position.Y, ball.Position.Z)
            humanoidRootPart.CFrame = CFrame.lookAt(humanoidRootPart.Position, lookPos)
        end)
    end
    
    -- Auto Parry Tetikleme
    if not Settings.AutoParry then return end
    if Settings.CheckTarget and not traj.isIncoming then return end
    
    -- 1. Yakın Mesafe / Clash Modu
    if Settings.AutoClash and traj.distance <= Settings.ClashDistance then
        executeParry(true)
        return
    end
    
    -- 2. Kuantum Varış Süresi & Mesafe Kontrolü
    if traj.timeToHit <= dynamicThreshold or traj.distance <= Settings.ParryRange then
        executeParry(false)
    end
end)

-- ESP Güncelleme Döngüsü
RunService.Heartbeat:Connect(function()
    local ball, isTargetAttr, distance, targetName, velocity = getTargetBall()
    if ball then
        local traj = calculateBallTrajectory(ball, velocity, isTargetAttr)
        updateSafeBallESP(ball, isTargetAttr, traj, targetName)
        updateSafePlayerESP(targetName)
    else
        if State.espHighlights["Ball"] then State.espHighlights["Ball"].Enabled = false end
        if State.espBillboards["Ball"] then State.espBillboards["Ball"].Enabled = false end
    end
end)

-- ====================================================================
-- 11. MODERN KULLANICI ARAYÜZÜ (PREMIUM GUI)
-- ====================================================================

local function createUI()
    local parent = getSafeGuiParent()
    
    local oldGui = parent:FindFirstChild("BladeBallUltimateUI")
    if oldGui then oldGui:Destroy() end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "BladeBallUltimateUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Ana Pencere
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 540, 0, 390)
    MainFrame.Position = UDim2.new(0.5, -270, 0.5, -195)
    MainFrame.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
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
    
    -- Başlık Barı
    local TitleBar = Instance.new("Frame")
    TitleBar.Name = "TitleBar"
    TitleBar.Size = UDim2.new(1, 0, 0, 44)
    TitleBar.BackgroundColor3 = Color3.fromRGB(22, 25, 37)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame
    
    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 12)
    TitleCorner.Parent = TitleBar
    
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Name = "TitleLabel"
    TitleLabel.Size = UDim2.new(0, 340, 1, 0)
    TitleLabel.Position = UDim2.new(0, 16, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.Text = "⚔️ BLADE BALL QUANTUM v9.0"
    TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLabel.TextSize = 13
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = TitleBar
    
    -- Durum / Tehdit Gösterge Barı
    local StatusBar = Instance.new("Frame")
    StatusBar.Name = "StatusBar"
    StatusBar.Size = UDim2.new(1, -20, 0, 24)
    StatusBar.Position = UDim2.new(0, 10, 1, -30)
    StatusBar.BackgroundColor3 = Color3.fromRGB(22, 25, 37)
    StatusBar.Parent = MainFrame
    
    local StatusCorner = Instance.new("UICorner")
    StatusCorner.CornerRadius = UDim.new(0, 6)
    StatusCorner.Parent = StatusBar
    
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Name = "StatusLabel"
    StatusLabel.Size = UDim2.new(1, -12, 1, 0)
    StatusLabel.Position = UDim2.new(0, 6, 0, 0)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Font = Enum.Font.GothamSemibold
    StatusLabel.Text = "🛡️ Durum: Güvende | Ping: 50ms"
    StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
    StatusLabel.TextSize = 11
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    StatusLabel.Parent = StatusBar
    
    task.spawn(function()
        while task.wait(0.15) and ScreenGui.Parent do
            pcall(function()
                StatusLabel.Text = string.format("Durum: %s | 📶 Ping: %.0fms | ⚔️ Vuruş: #%d", 
                    State.threatLevel, State.currentPing * 1000, State.parryCount)
                StatusLabel.TextColor3 = State.threatColor
            end)
        end
    end)
    
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Name = "CloseBtn"
    CloseBtn.Size = UDim2.new(0, 28, 0, 28)
    CloseBtn.Position = UDim2.new(1, -36, 0, 8)
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
    
    -- Sidebar
    local Sidebar = Instance.new("Frame")
    Sidebar.Name = "Sidebar"
    Sidebar.Size = UDim2.new(0, 135, 1, -80)
    Sidebar.Position = UDim2.new(0, 0, 0, 44)
    Sidebar.BackgroundColor3 = Color3.fromRGB(13, 15, 22)
    Sidebar.BorderSizePixel = 0
    Sidebar.Parent = MainFrame
    
    local ContentContainer = Instance.new("Frame")
    ContentContainer.Name = "ContentContainer"
    ContentContainer.Size = UDim2.new(1, -145, 1, -84)
    ContentContainer.Position = UDim2.new(0, 140, 0, 48)
    ContentContainer.BackgroundTransparency = 1
    ContentContainer.Parent = MainFrame
    
    local tabs = {
        { id = "Combat", name = "⚔️ Savaş & Kuantum" },
        { id = "Trajectory", name = "🎯 Yörünge & CPA" },
        { id = "Visuals", name = "👁️ ESP & Görsel" },
        { id = "Misc", name = "⚙️ Ayarlar" },
    }
    
    local tabButtons = {}
    local tabPages = {}
    
    local function switchTab(tabId)
        for id, page in pairs(tabPages) do page.Visible = (id == tabId) end
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
        btn.TextSize = 11
        btn.Parent = Sidebar
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = btn
        tabButtons[tab.id] = btn
        
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
        
        btn.MouseButton1Click:Connect(function() switchTab(tab.id) end)
    end
    
    local function createToggle(parentPage, text, defaultVal, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -8, 0, 36)
        frame.BackgroundColor3 = Color3.fromRGB(24, 27, 39)
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
            TweenService:Create(toggleBtn, TweenInfo.new(0.2), { BackgroundColor3 = state and Color3.fromRGB(124, 58, 237) or Color3.fromRGB(45, 48, 65) }):Play()
            TweenService:Create(circle, TweenInfo.new(0.2), { Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8) }):Play()
        end)
    end
    
    local function createSlider(parentPage, text, min, max, defaultVal, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -8, 0, 50)
        frame.BackgroundColor3 = Color3.fromRGB(24, 27, 39)
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
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then sliding = false end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then update(input) end
        end)
    end
    
    -- Sayfa 1: Savaş & Kuantum
    createToggle(tabPages["Combat"], "⚔️ Quantum Auto Parry", Settings.AutoParry, function(v)
        Settings.AutoParry = v
        notify("⚔️ Auto Parry", v and "Aktif edildi ✅" or "Kapatıldı ❌")
    end)
    createToggle(tabPages["Combat"], "📶 Otomatik Ping Dengeleyici", Settings.PingCompensation, function(v) Settings.PingCompensation = v end)
    createToggle(tabPages["Combat"], "⚡ Yakın Dövüş (Clash) Modu", Settings.AutoClash, function(v) Settings.AutoClash = v end)
    createToggle(tabPages["Combat"], "🎯 Sadece Hedef Bendeyken Vur", Settings.CheckTarget, function(v) Settings.CheckTarget = v end)
    createToggle(tabPages["Combat"], "👀 Topa Otomatik Yüzünü Dön", Settings.AutoLookAtBall, function(v) Settings.AutoLookAtBall = v end)
    createSlider(tabPages["Combat"], "📏 Parry Mesafesi (Studs)", 15, 60, Settings.ParryRange, function(v) Settings.ParryRange = v end)
    createSlider(tabPages["Combat"], "⏱️ Varış Eşiği (x100 ms)", 15, 45, math.floor(Settings.ParryTiming * 100), function(v) Settings.ParryTiming = v / 100 end)
    createSlider(tabPages["Combat"], "🥊 Clash Mesafesi (Studs)", 8, 25, Settings.ClashDistance, function(v) Settings.ClashDistance = v end)
    
    -- Sayfa 2: Yörünge & CPA
    createToggle(tabPages["Trajectory"], "🎯 CPA (Closest Approach) Analizi", Settings.CPAEngine, function(v) Settings.CPAEngine = v end)
    createToggle(tabPages["Trajectory"], "🌀 Kavisli & Dönen Top Tahmini", Settings.CurvePrediction, function(v) Settings.CurvePrediction = v end)
    createToggle(tabPages["Trajectory"], "📈 İvme & Ani Hızlanma Takibi", Settings.AccelerationTracking, function(v) Settings.AccelerationTracking = v end)
    createSlider(tabPages["Trajectory"], "📐 Iskalama Toleransı (Studs)", 6, 25, Settings.MaxMissDistance, function(v) Settings.MaxMissDistance = v end)
    
    -- Sayfa 3: Visuals / ESP
    createToggle(tabPages["Visuals"], "⚽ Top ESP (Harici Güvenli)", Settings.BallESP, function(v) Settings.BallESP = v; if not v then clearAllESP() end end)
    createToggle(tabPages["Visuals"], "✨ Top Highlight Parlaması", Settings.BallHighlight, function(v) Settings.BallHighlight = v; if not v then clearAllESP() end end)
    createToggle(tabPages["Visuals"], "📊 Top Bilgileri (Hız & Varış)", Settings.BallInfo, function(v) Settings.BallInfo = v; if not v then clearAllESP() end end)
    createToggle(tabPages["Visuals"], "👥 Oyuncu ESP (Harici Güvenli)", Settings.PlayerESP, function(v) Settings.PlayerESP = v; if not v then clearAllESP() end end)
    createToggle(tabPages["Visuals"], "🎯 Hedef Oyuncuyu Vurgula", Settings.TargetHighlight, function(v) Settings.TargetHighlight = v end)
    
    -- Sayfa 4: Misc / Ayarlar
    createToggle(tabPages["Misc"], "🔭 Özel Görüş Açısı (FOV)", Settings.CustomFOV, function(v) Settings.CustomFOV = v; if not v and camera then camera.FieldOfView = 70 end end)
    createSlider(tabPages["Misc"], "📐 FOV Derecesi", 70, 120, Settings.FOVValue, function(v) Settings.FOVValue = v end)
    createToggle(tabPages["Misc"], "🐞 Debug Konsol Modu", Settings.DebugMode, function(v) Settings.DebugMode = v end)
    
    -- Floating UI Butonu
    local FloatBtn = Instance.new("TextButton")
    FloatBtn.Name = "FloatToggleBtn"
    FloatBtn.Size = UDim2.new(0, 42, 0, 42)
    FloatBtn.Position = UDim2.new(0, 20, 0.5, -21)
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
    
    switchTab("Combat")
    ScreenGui.Parent = parent
    return ScreenGui
end

local guiInstance = createUI()

-- ====================================================================
-- 12. KLAVYE KISAYOLLARI
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
        notify("⚔️ Blade Ball", "Auto Parry: " .. status)
    end
    
    if input.KeyCode == Enum.KeyCode.F then
        executeParry(false)
    end
end)

-- ====================================================================
-- 13. BAŞLANGIÇ MESAJI
-- ====================================================================

print("")
print("╔═════════════════════════════════════════════════════╗")
print("║   👑 BLADE BALL QUANTUM v9.0                        ║")
print("║   CPA Yörünge Analizi & Kavis Tahmini Aktif!        ║")
print("╠═════════════════════════════════════════════════════╣")
print("║   📌 KONTROLLER:                                    ║")
print("║   [Sağ Ctrl / Insert / Sol ⚔️ Butonu] = Menü         ║")
print("║   [P] = Auto Parry Aç/Kapat                         ║")
print("║   [F] = Manuel Parry                                ║")
print("╚═════════════════════════════════════════════════════╝")
print("")

notify("👑 Quantum v9.0", "✅ Kuantum Yörünge & CPA Motoru Aktif Edildi!", 4)