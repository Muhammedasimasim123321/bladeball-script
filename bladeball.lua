-- bladeball.lua
-- ⚔️ Blade Ball Ultimate Auto Parry (v12.0 Clean & Advanced)
-- %100 Güvenli, Anti-Cheat Korumalı (Zero-Kick), Dinamik Hız & Mesafe Hesaplamalı

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local VirtualInputManager = nil
pcall(function()
    VirtualInputManager = game:GetService("VirtualInputManager")
end)

local player = Players.LocalPlayer
local renderSignal = RunService.RenderStepped or RunService.Heartbeat

-- ====================================================================
-- 1. SAVAŞ AYARLARI
-- ====================================================================

local Settings = {
    AutoParry = true,            -- Otomatik Parry Açık/Kapalı
    BaseRange = 40,              -- Temel algılama mesafesi (Studs)
    ClashDistance = 16,          -- Yakın temas clash mesafesi (Studs)
    ParryCooldown = 0.18,        -- Normal vuruşlar arası güvenli bekleme süresi
    ClashCooldown = 0.085,       -- Yakın temas clash vuruş hızı (BAC fhb korumalı)
}

local State = {
    lastParry = -999,
    parryCount = 0
}

-- ====================================================================
-- 2. DİNAMİK CANLI KARAKTER TESPİTİ (RESPAWN KORUMASI)
-- ====================================================================

local function getLiveRootPart()
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
end

-- ====================================================================
-- 3. HEDEF VE TOP ANALİZ MOTORU
-- ====================================================================

local function isPlayerTarget(targetVal)
    if not targetVal then return false end
    local myName = player.Name
    local myDisplay = player.DisplayName
    local str = tostring(targetVal)
    
    return str == myName or str == myDisplay or str:lower() == myName:lower()
end

local function getTargetBall(myPos)
    local ballsFolder = workspace:FindFirstChild("Balls") or workspace
    local bestBall = nil
    local bestDist = math.huge
    local isThreat = false
    local ballVel = Vector3.new(0, 0, 0)
    
    local myName = player.Name
    local myDisplay = player.DisplayName
    
    for _, obj in ipairs(ballsFolder:GetChildren()) do
        local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
        if part and part.Name ~= "HumanoidRootPart" then
            local isReal = obj:GetAttribute("realBall") or part:GetAttribute("realBall") or obj.Name == "Ball" or ballsFolder ~= workspace
            if isReal then
                local bPos = part.Position
                local dist = (bPos - myPos).Magnitude
                local vel = part.AssemblyLinearVelocity or part.Velocity or Vector3.new(0, 0, 0)
                
                local targetAttr = obj:GetAttribute("target") or part:GetAttribute("target")
                local targeted = isPlayerTarget(targetAttr)
                local hasOtherTarget = (targetAttr ~= nil and not targeted)
                
                -- Topun bize yaklaşma açısı (Dot Product)
                local dirToMe = (myPos - bPos)
                local movingToMe = false
                if dirToMe.Magnitude > 0 and vel.Magnitude > 0 then
                    movingToMe = (vel.Unit:Dot(dirToMe.Unit) > 0.08)
                end
                
                -- Tehdit Kararı:
                -- 1. Hedef doğrudan bizdeyse
                -- 2. Hedef belirlenmemişse ama top bize geliyorsa
                -- 3. Hedef başkasında görünse bile 15 studs içindeyse (Clash tehlikesi)
                local threat = false
                if targeted then
                    threat = true
                elseif not hasOtherTarget and movingToMe and dist <= Settings.BaseRange then
                    threat = true
                elseif hasOtherTarget and movingToMe and dist <= 15 then
                    threat = true
                end
                
                if dist < bestDist then
                    bestDist = dist
                    bestBall = part
                    isThreat = threat
                    ballVel = vel
                end
            end
        end
    end
    
    return bestBall, isThreat, bestDist, ballVel
end

-- ====================================================================
-- 4. PARRY TETİKLEME (TÜM EXECUTORLAR İÇİN DOĞAL VE GÜVENLİ)
-- ====================================================================

local function triggerParry(isClash)
    local now = os.clock()
    local cd = isClash and Settings.ClashCooldown or Settings.ParryCooldown
    
    if (now - State.lastParry) < cd then return end
    State.lastParry = now
    State.parryCount = State.parryCount + 1
    
    task.spawn(function()
        pcall(function()
            if VirtualInputManager then
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
                task.wait(0.012)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
            elseif mouse1click then
                mouse1click()
            end
        end)
    end)
end

-- ====================================================================
-- 5. ÇEKİRDEK İŞLEMCİ DÖNGÜSÜ (0 MS RENDERSTEPPED)
-- ====================================================================

renderSignal:Connect(function()
    if not Settings.AutoParry then return end
    
    local hrp = getLiveRootPart()
    if not hrp then return end
    
    local myPos = hrp.Position
    local ball, isThreat, dist, vel = getTargetBall(myPos)
    if not ball or not isThreat then return end
    
    local speed = vel.Magnitude
    local dirToMe = (myPos - ball.Position)
    
    -- Yaklaşma Hızı
    local approachSpeed = speed
    if dist > 0 and speed > 0 then
        local dot = vel:Dot(dirToMe.Unit)
        if dot > 0 then
            approachSpeed = dot
        end
    end
    
    local effectiveSpeed = math.max(approachSpeed, speed, 1)
    local timeToHit = dist / effectiveSpeed
    
    -- 1. Yakın Temas / Clash: 16 studs altındaysa anında vur
    if dist <= Settings.ClashDistance then
        triggerParry(true)
        return
    end
    
    -- 2. Hıza Göre Dinamik Eşik:
    -- Yavaş toplarda (speed < 50): 0.30s varışta vurur (Erken basıp kalkanı yakmaz / Whiff koruması)
    -- Hızlı toplarda (speed > 100): 0.35s - 0.46s varışta vurur (Geç kalmayı önler)
    local clampVal = math.clamp or function(v, min, max) return math.max(min, math.min(max, v)) end
    local dynamicTime = clampVal(0.30 + (speed / 1100), 0.30, 0.46)
    local dynamicDist = clampVal(speed * dynamicTime, 18, 50)
    
    -- Vuruş Koşulu
    if timeToHit <= dynamicTime or dist <= dynamicDist then
        triggerParry(false)
    end
end)

-- ====================================================================
-- 6. KLAVYE KONTROLLERİ
-- ====================================================================

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    -- [P] Tuşu: Auto Parry Aç / Kapat
    if input.KeyCode == Enum.KeyCode.P then
        Settings.AutoParry = not Settings.AutoParry
    end
    
    -- [F] Tuşu: Manuel Vuruş
    if input.KeyCode == Enum.KeyCode.F then
        triggerParry(true)
    end
end)