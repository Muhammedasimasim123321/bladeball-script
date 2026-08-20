-- bladeball.lua
-- ⚔️ BLADE BALL - XENO & ALL EXECUTORS COMPATIBLE AUTO PARRY (V11.0)
-- 🛡️ Xeno / Solara / Wave / Delta Tam Uyumlu Çoklu Giriş (mouse1click + keypress + VirtualInputManager)
-- 🎯 Evrensel Tehdit Tespiti & Sıfır Iskalamalı Kesin Vuruş Motoru

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local VirtualInputManager = nil
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)

local VirtualUser = nil
pcall(function() VirtualUser = game:GetService("VirtualUser") end)

local player = Players.LocalPlayer
local getTime = os.clock or tick
local renderSignal = RunService.RenderStepped or RunService.Heartbeat
local clamp = math.clamp or function(v, min, max) return math.max(min, math.min(max, v)) end
local typeCheck = typeof or type

-- ====================================================================
-- 1. SAVAŞ AYARLARI
-- ====================================================================

local Config = {
    AutoParry = true,
    BaseRange = 40,              -- Temel vuruş mesafesi (Studs)
    EmergencyDistance = 25,      -- Acil durum mesafesi (25 studs içinde her yaklaşan topa vurur)
    ParryWindow = 0.35,          -- Temel varış süresi eşiği (sn)
    
    ParryCooldown = 0.16,        -- Normal parry bekleme süresi
    ClashCooldown = 0.085,       -- Yakın temas clash bekleme süresi (BAC Güvenli)
}

local State = {
    lastParryTime = -999,
    parryCount = 0
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
-- 3. CANLI KARAKTER BULUCU (RESPAWN KORUMASI)
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
-- 4. EVRENSEL HEDEF VE TOP TESPİTİ
-- ====================================================================

local function isTargetMatch(targetVal)
    if not targetVal then return false end
    local myName = player.Name and player.Name:lower() or ""
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
    
    local searchContainers = {}
    local ballsFolder = workspace:FindFirstChild("Balls")
    if ballsFolder then table.insert(searchContainers, ballsFolder) end
    local trainingBalls = workspace:FindFirstChild("TrainingBalls")
    if trainingBalls then table.insert(searchContainers, trainingBalls) end
    table.insert(searchContainers, workspace)
    
    for _, container in ipairs(searchContainers) do
        if container and container.GetChildren then
            for _, obj in ipairs(container:GetChildren()) do
                local isOtherPlayer = false
                if Players.GetPlayerFromCharacter then
                    pcall(function() isOtherPlayer = (Players:GetPlayerFromCharacter(obj) ~= nil) end)
                end
                
                if obj ~= player.Character and not isOtherPlayer then
                    local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                    if part and part.Name ~= "HumanoidRootPart" then
                        local isReal = obj:GetAttribute("realBall") or part:GetAttribute("realBall") or
                                       obj.Name == "Ball" or obj.Name:lower():find("ball") or (container ~= workspace)
                        
                        if isReal then
                            local bPos = part.Position
                            local dist = (bPos - myPos).Magnitude
                            local vel = part.AssemblyLinearVelocity or part.Velocity or Vector3.new(0, 0, 0)
                            
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
                                isMovingTowards = (dot > 0.05) -- Bize doğru yönelen her top
                            end
                            
                            -- TEHDİT KONTROLÜ (Garantili Savunma):
                            -- 1. Hedef doğrudan bizdeysek -> TRUE
                            -- 2. Hedef belirlenmemişse ama top bize geliyorsa -> TRUE
                            -- 3. Hedef başkasındaysa ama top 14 studs içindeyse (Clash) -> TRUE
                            local threat = false
                            if targetedToMe then
                                threat = true
                            elseif not hasOtherTarget and isMovingTowards and dist <= Config.BaseRange then
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
-- 5. XENO & TÜM EXECUTORLAR İÇİN ÇOKLU GİRİŞ MOTORU (MULTI-ENGINE INPUT)
-- ====================================================================

local function sendParrySignal()
    -- Kanal 1: mouse1click / mouse1press (Xeno'da %100 Çalışır)
    pcall(function()
        if mouse1click then
            mouse1click()
        elseif mouse1press and mouse1release then
            mouse1press()
            task.wait(0.008)
            mouse1release()
        end
    end)
    
    -- Kanal 2: keypress / keyrelease (F tuşu = 70)
    pcall(function()
        if keypress and keyrelease then
            keypress(70)
            task.wait(0.008)
            keyrelease(70)
        end
    end)
    
    -- Kanal 3: keyclick (Xeno / UNC)
    pcall(function()
        if keyclick then
            keyclick(Enum.KeyCode.F)
        end
    end)
    
    -- Kanal 4: VirtualInputManager Klavye F Tuşu
    pcall(function()
        if VirtualInputManager then
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
            task.wait(0.01)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
        end
    end)
    
    -- Kanal 5: VirtualInputManager Sol Tık (Mouse 1)
    pcall(function()
        if VirtualInputManager then
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            task.wait(0.008)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        end
    end)
    
    -- Kanal 6: VirtualUser Tıklaması
    pcall(function()
        if VirtualUser then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton1(Vector2.new(500, 500))
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
    
    -- Yaklaşma Hızı Hesabı
    local approachSpeed = speed
    if distance > 0 and speed > 0 then
        local dot = velocity:Dot(dirToMe.Unit)
        if dot > 0 then
            approachSpeed = dot
        end
    end
    
    local effectiveSpeed = math.max(approachSpeed, speed, 1)
    local timeToHit = distance / effectiveSpeed
    
    -- A) YAKIN TEMAS / CLASH: 16 studs altındaysa anında vur
    if distance <= 16 then
        executeParry(true)
        return
    end
    
    -- B) HIZA GÖRE DİNAMİK VURUŞ HESABI (Whiff & Geç Kalma Korumalı)
    local dynamicTargetTime = clamp(0.32 + (speed / 1000), 0.32, 0.48)
    local dynamicMaxDistance = clamp(speed * dynamicTargetTime, 20, 55)
    
    -- Vuruş Koşulu: Varış süresi veya mesafe eşiğindeyse vur
    if timeToHit <= dynamicTargetTime or distance <= dynamicMaxDistance or distance <= Config.EmergencyDistance then
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
print("║   👑 BLADE BALL - XENO COMPATIBLE AUTO PARRY v11.0  ║")
print("║   mouse1click + keypress + VirtualInput Aktif!      ║")
print("╠═════════════════════════════════════════════════════╣")
print("║   📌 KONTROLLER:                                    ║")
print("║   [P] = Auto Parry Aç/Kapat                         ║")
print("║   [F] = Manuel Parry                                ║")
print("╚═════════════════════════════════════════════════════╝")
print("")

notify("👑 Blade Ball v11.0", "✅ Xeno Uyumlu Parry Devrede!")