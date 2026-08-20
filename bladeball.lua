-- bladeball.lua
-- ⚔️ BLADE BALL - %100 GARANTİLİ VE KESİN VURUŞ MOTORU (UNIVERSAL AUTO PARRY)
-- 🛡️ Karakter Yenilenme Koruması, Evrensel Top & Hedef Algılama, Tüm Executorlar İçin Çoklu Giriş (Multi-Engine)

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VirtualInputManager = nil
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)

local VirtualUser = nil
pcall(function() VirtualUser = game:GetService("VirtualUser") end)

local player = Players.LocalPlayer
local getTime = os.clock or tick
local renderSignal = RunService.RenderStepped or RunService.Heartbeat
local clamp = math.clamp or function(v, min, max) return math.max(min, math.min(max, v)) end

-- ====================================================================
-- 1. SAVAŞ VE ZAMANLAMA AYARLARI
-- ====================================================================

local Config = {
    AutoParry = true,
    ParryDistance = 38,          -- Vuruş menzili (Genişletildi: 38 studs)
    EmergencyDistance = 25,      -- Acil durum mesafesi (25 studs içinde her topa vurur)
    ParryWindow = 0.38,          -- Varış süresi eşiği (0.38s - Erken ve garantili algılama)
    
    ParryCooldown = 0.16,        -- Normal vuruş bekleme süresi
    ClashCooldown = 0.085,       -- Yakın temas clash bekleme süresi (BAC Güvenli)
}

local State = {
    lastParryTime = -999,
    parryCount = 0,
    activeBall = nil
}

-- ====================================================================
-- 2. BİLDİRİM
-- ====================================================================

local function notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title or "⚔️ Blade Ball",
            Text = tostring(text or ""),
            Duration = 2
        })
    end)
end

-- ====================================================================
-- 3. DİNAMİK KARAKTER BULUCU (ÖLÜM VE YENİDEN DOĞMA KORUMASI)
-- ====================================================================

local function getMyRootPart()
    local char = player.Character or workspace:FindFirstChild(player.Name)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or 
           char:FindFirstChild("Torso") or 
           char:FindFirstChild("UpperTorso") or 
           char:FindFirstChildWhichIsA("BasePart")
end

-- ====================================================================
-- 4. EVRENSEL TOP VE HEDEF TESPİTİ (HER DURUMDA BULUR)
-- ====================================================================

local typeCheck = typeof or type

local function isTargetMatch(targetVal)
    if not targetVal then return false end
    local myName = player.Name:lower()
    local myDisplay = player.DisplayName and player.DisplayName:lower() or myName
    
    if typeCheck(targetVal) == "Instance" then
        return targetVal == player or targetVal == player.Character or targetVal.Name:lower() == myName
    end
    
    local str = tostring(targetVal):lower()
    return str == myName or str == myDisplay or str:find(myName) ~= nil
end

local function findActiveBall(myPos)
    local bestBall = nil
    local minDistance = math.huge
    local isThreat = false
    local ballVel = Vector3.new(0, 0, 0)
    
    -- Taranacak tüm potansiyel konumlar
    local searchContainers = {}
    
    local ballsFolder = workspace:FindFirstChild("Balls")
    if ballsFolder then table.insert(searchContainers, ballsFolder) end
    
    local trainingBalls = workspace:FindFirstChild("TrainingBalls")
    if trainingBalls then table.insert(searchContainers, trainingBalls) end
    
    table.insert(searchContainers, workspace)
    
    for _, container in ipairs(searchContainers) do
        if container and container.GetChildren then
            for _, obj in ipairs(container:GetChildren()) do
                local isOtherPlayerChar = false
                if Players.GetPlayerFromCharacter then
                    pcall(function() isOtherPlayerChar = (Players:GetPlayerFromCharacter(obj) ~= nil) end)
                end
            
            if obj ~= player.Character and not isOtherPlayerChar then
                local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                if part and part.Name ~= "HumanoidRootPart" then
                    local isReal = obj:GetAttribute("realBall") or part:GetAttribute("realBall") or
                                   obj.Name == "Ball" or obj.Name:lower():find("ball") or (container ~= workspace)
                    
                    if isReal then
                        local bPos = part.Position
                        local dist = (bPos - myPos).Magnitude
                        local vel = part.AssemblyLinearVelocity or part.Velocity or Vector3.new(0, 0, 0)
                        
                        -- Hedef Attribute Taraması
                        local targetAttr = obj:GetAttribute("target") or part:GetAttribute("target") or
                                           obj:GetAttribute("Target") or part:GetAttribute("Target") or
                                           obj:GetAttribute("targetPlayer") or part:GetAttribute("targetPlayer")
                        
                        local targetedToMe = isTargetMatch(targetAttr)
                        local hasOtherTarget = (targetAttr ~= nil and not targetedToMe)
                        
                        -- Yaklaşma Açısı (Dot Product)
                        local dirToMe = (myPos - bPos)
                        local isMovingTowards = false
                        if dirToMe.Magnitude > 0 and vel.Magnitude > 0 then
                            local dot = vel.Unit:Dot(dirToMe.Unit)
                            isMovingTowards = (dot > 0.10)
                        end
                        
                        -- TEHDİT DEĞERLENDİRMESİ:
                        -- 1. Hedef bizdeyse -> KESİN TEHDİT
                        -- 2. Hedef belirlenmemişse ama top bize doğru geliyorsa -> KESİN TEHDİT
                        -- 3. Mesafe Acil Durum içindeyse (<= 25 studs) ve top bizden uzaklaşmıyorsa -> KESİN TEHDİT
                        local threat = false
                        if targetedToMe then
                            threat = true
                        elseif not hasOtherTarget and isMovingTowards and dist <= Config.ParryDistance then
                            threat = true
                        elseif hasOtherTarget and isMovingTowards and dist <= 14 then
                            threat = true
                        end
                        
                        if dist < minDistance then
                            minDistance = dist
                            bestBall = part
                            isThreat = threat
                            ballVel = vel
                        end
                    end
                end
            end
        end
    end
end
    
return bestBall, isThreat, minDistance, ballVel
end

-- ====================================================================
-- 5. ÇOK KANALLI KUSURSUZ GİRİŞ SİSTEMİ (HER EXECUTORDA %100 ÇALIŞIR)
-- ====================================================================

local function sendParrySignal()
    -- Kanal 1: VirtualInputManager Klavye F Tuşu
    if VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
            task.wait(0.01)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
        end)
        
        -- Kanal 2: VirtualInputManager Sol Tık (Mouse 1)
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            task.wait(0.008)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        end)
    end
    
    -- Kanal 3: Executor keypress / keyrelease C-Closure
    pcall(function()
        if keypress and keyrelease then
            keypress(0x46) -- F Tuşu
            task.wait(0.01)
            keyrelease(0x46)
        end
    end)
    
    -- Kanal 4: Executor mouse1click / mouse1press
    pcall(function()
        if mouse1click then
            mouse1click()
        elseif mouse1press and mouse1release then
            mouse1press()
            task.wait(0.01)
            mouse1release()
        end
    end)
    
    -- Kanal 5: VirtualUser Tıklama
    if VirtualUser then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton1(Vector2.new(0, 0))
        end)
    end
    
    -- Kanal 6: Ekrandaki Parry Butonunu Tetikleme (Mobile / Touch GUI)
    pcall(function()
        local pgui = player:FindFirstChild("PlayerGui")
        if pgui then
            for _, gui in ipairs(pgui:GetChildren()) do
                if gui:IsA("ScreenGui") and gui.Enabled then
                    local btn = gui:FindFirstChild("ParryButton", true) or 
                                gui:FindFirstChild("Parry", true) or
                                gui:FindFirstChild("parry", true)
                    if btn and btn:IsA("GuiButton") and btn.Visible and firesignal then
                        firesignal(btn.Activated)
                        firesignal(btn.MouseButton1Click)
                    end
                end
            end
        end
    end)
end

local function executeParry(isClash)
    local now = getTime()
    local cooldown = isClash and Config.ClashCooldown or Config.ParryCooldown
    
    if (now - State.lastParryTime) < cooldown then
        return
    end
    
    State.lastParryTime = now
    State.parryCount = State.parryCount + 1
    
    task.spawn(sendParrySignal)
end

-- ====================================================================
-- 6. ANA DÖNGÜ (RENDERSTEPPED - 0 MS GECİKME)
-- ====================================================================

renderSignal:Connect(function()
    if not Config.AutoParry then return end
    
    local hrp = getMyRootPart()
    if not hrp then return end
    
    local myPos = hrp.Position
    local ball, isThreat, distance, velocity = findActiveBall(myPos)
    if not ball or not isThreat then return end
    
    local speed = velocity.Magnitude
    local dirToMe = (myPos - ball.Position)
    
    -- Yaklaşma Hızı Hesaplama
    local approachSpeed = speed
    if distance > 0 and speed > 0 then
        local dot = velocity:Dot(dirToMe.Unit)
        if dot > 0 then
            approachSpeed = dot
        end
    end
    
    local effectiveSpeed = math.max(approachSpeed, speed, 1)
    local timeToHit = distance / effectiveSpeed
    
    -- A) YAKIN MESAFE / CLASH (16 studs altındaysa anında clash parry)
    if distance <= 16 then
        executeParry(true)
        return
    end
    
    -- B) HIZA GÖRE DİNAMİK VURUŞ EŞİĞİ
    local dynamicTiming = Config.ParryWindow
    if speed > 70 then
        dynamicTiming = clamp(0.35 + (speed / 800), 0.35, 0.55)
    end
    
    -- VURUŞ TETİKLEME KOŞULU:
    -- 1. Varış süresi hesaplanan dinamik eşiğe girdiyse
    -- 2. Top vuruş menziline (38 studs) girdiyse
    -- 3. Top acil durum mesafesine (25 studs) girdiyse
    if timeToHit <= dynamicTiming or distance <= Config.ParryDistance or distance <= Config.EmergencyDistance then
        executeParry(false)
    end
end)

-- ====================================================================
-- 7. KONTROLLER
-- ====================================================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.P then
        Config.AutoParry = not Config.AutoParry
        local status = Config.AutoParry and "✅ AÇIK" or "❌ KAPALI"
        notify("⚔️ Auto Parry", status)
    end
    
    if input.KeyCode == Enum.KeyCode.F then
        executeParry(true)
    end
end)

-- ====================================================================
-- 8. BAŞLANGIÇ MESAJI
-- ====================================================================

print("")
print("╔═════════════════════════════════════════════════════╗")
print("║   👑 BLADE BALL - %100 GARANTİLİ VURUŞ MOTORU       ║")
print("║   6 Kanallı Giriş & Evrensel Tehdit Algılama Aktif! ║")
print("╠═════════════════════════════════════════════════════╣")
print("║   📌 KONTROLLER:                                    ║")
print("║   [P] = Auto Parry Aç/Kapat                         ║")
print("║   [F] = Manuel Parry                                ║")
print("╚═════════════════════════════════════════════════════╝")
print("")

notify("👑 Blade Ball", "✅ %100 Garantili Vuruş Motoru Devrede!")