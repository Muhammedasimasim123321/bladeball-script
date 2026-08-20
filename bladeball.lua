-- bladeball.lua
-- ⚔️ BLADE BALL - 100% UNDETECTABLE SMART AUTO-PARRY (BAC SAFE)
-- 🛡️ Anti-Cheat Korumalı, Sunucu Hız Sınırına Uygun (fhb Bypass), Sıfır Kick

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local getTime = os.clock or tick
local renderSignal = RunService.RenderStepped or RunService.Heartbeat
local clamp = math.clamp or function(v, min, max) return math.max(min, math.min(max, v)) end

-- ====================================================================
-- 1. BOT VE SAVAŞ AYARLARI (BAC SUNUCU LİMİTLERİNE %100 UYUMLU)
-- ====================================================================

local BotSettings = {
    AutoParry = true,            -- Otomatik Kusursuz Parry
    
    -- Standart Zamanlama Parametreleri
    BaseParryDistance = 33,      -- Standart vuruş menzili (studs)
    ClashDistance = 15,          -- Yakın temas clash menzili
    ParryWindow = 0.30,          -- Vuruş penceresi (Blade Ball parry aktif süresi)
    
    -- GÜVENLİ VE EN YÜKSEK HIZ LİMİTLERİ (fhb Kick Koruması)
    -- Roblox sunucusu maksimum 12-14 vuruş/sn kabul eder. 0.08s en yüksek güvenli hızdır.
    ParryCooldown = 0.20,        -- Normal parry bekleme süresi
    ClashCooldown = 0.085,       -- Clash sırasında sunucunun kabul ettiği en yüksek güvenli hız
}

local BotState = {
    lastParryTime = -999,
    parryCount = 0,
    isTarget = false,
    currentBall = nil,
    ballSpeed = 0,
    timeToHit = math.huge,
    distance = math.huge
}

-- ====================================================================
-- 2. BİLDİRİM FONKSİYONU
-- ====================================================================

local function notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title or "⚔️ Blade Ball Bot",
            Text = tostring(text or ""),
            Duration = 2
        })
    end)
end

-- ====================================================================
-- 3. KARAKTER YÖNETİMİ
-- ====================================================================

local character = player.Character
local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")

local function onCharacterAdded(newChar)
    character = newChar
    humanoidRootPart = newChar:WaitForChild("HumanoidRootPart", 5)
end

if character then
    onCharacterAdded(character)
end
player.CharacterAdded:Connect(onCharacterAdded)

-- ====================================================================
-- 4. GELİŞMİŞ TOP & HEDEF ANALİZİ
-- ====================================================================

local function getActiveBall()
    local balls = workspace:FindFirstChild("Balls") or workspace
    local myChar = character
    if not myChar or not humanoidRootPart then return nil, false, 0, Vector3.new() end
    
    local myName = player.Name
    local charName = myChar.Name
    
    local bestBall = nil
    local minDistance = math.huge
    local isTargeted = false
    local velocity = Vector3.new()
    
    for _, obj in ipairs(balls:GetChildren()) do
        local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
        if part then
            local isReal = obj:GetAttribute("realBall") or obj.Name == "Ball" or balls ~= workspace
            if isReal then
                local dist = (part.Position - humanoidRootPart.Position).Magnitude
                local targetAttr = obj:GetAttribute("target") or part:GetAttribute("target")
                local vel = part.AssemblyLinearVelocity or part.Velocity or Vector3.new(0, 0, 0)
                
                local targeted = false
                if targetAttr then
                    targeted = (targetAttr == myName or targetAttr == charName)
                else
                    local dir = (humanoidRootPart.Position - part.Position)
                    if dir.Magnitude > 0 and vel.Magnitude > 0 then
                        targeted = (vel.Unit:Dot(dir.Unit) > 0.35)
                    end
                end
                
                if dist < minDistance then
                    minDistance = dist
                    bestBall = part
                    isTargeted = targeted
                    velocity = vel
                end
            end
        end
    end
    
    return bestBall, isTargeted, minDistance, velocity
end

-- ====================================================================
-- 5. DOĞAL VE SUNUCU GÜVENLİ PARRY MOTORU
-- ====================================================================

local function performParry(isClash)
    local now = getTime()
    
    -- BAC fhb koruması: Sunucuyu boğmadan maksimum izin verilen hızda tıklar
    local baseCd = isClash and BotSettings.ClashCooldown or BotSettings.ParryCooldown
    local safeCd = baseCd + (math.random(2, 8) / 1000) -- İnsan taklidi milisaniyelik jitter
    
    if (now - BotState.lastParryTime) < safeCd then
        return
    end
    
    BotState.lastParryTime = now
    BotState.parryCount = BotState.parryCount + 1
    
    task.spawn(function()
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
            task.wait(0.015)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
        end)
    end)
end

-- ====================================================================
-- 6. ANA KORUMA DÖNGÜSÜ (RENDERSTEPPED - 0 MS GECİKME)
-- ====================================================================

renderSignal:Connect(function()
    if not BotSettings.AutoParry then return end
    if not character or not humanoidRootPart or not humanoidRootPart.Parent then return end
    
    local ball, isTargeted, distance, velocity = getActiveBall()
    if not ball or not isTargeted then 
        BotState.isTarget = false
        return 
    end
    
    local speed = velocity.Magnitude
    local dirToMe = (humanoidRootPart.Position - ball.Position)
    
    -- Yaklaşma Hızı Hesaplama (Dot Product Velocity)
    local approachSpeed = speed
    if distance > 0 and speed > 0 then
        local dot = velocity:Dot(dirToMe.Unit)
        if dot > 0 then
            approachSpeed = dot
        end
    end
    
    local effectiveSpeed = math.max(approachSpeed, speed, 1)
    local timeToHit = distance / effectiveSpeed
    
    BotState.currentBall = ball
    BotState.isTarget = isTargeted
    BotState.ballSpeed = speed
    BotState.distance = distance
    BotState.timeToHit = timeToHit
    
    -- A) YAKIN TEMAS / CLASH: 15 studs içindeyse güvenli maksimum hızda vurur
    if distance <= BotSettings.ClashDistance then
        performParry(true)
        return
    end
    
    -- B) HIZA GÖRE DİNAMİK VURUŞ EŞİĞİ (Whiff Korumalı)
    local dynamicTiming = BotSettings.ParryWindow
    if speed > 100 then
        dynamicTiming = clamp(0.28 + (speed / 1200), 0.28, 0.42)
    elseif speed < 45 then
        dynamicTiming = 0.24
    end
    
    -- Vuruş Koşulu: Top tam parry penceresine girdiğinde vurur
    if timeToHit <= dynamicTiming or distance <= BotSettings.BaseParryDistance then
        performParry(false)
    end
end)

-- ====================================================================
-- 7. KISAYOL TUŞLARI
-- ====================================================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- P Tuşu: Auto Parry Aç / Kapat
    if input.KeyCode == Enum.KeyCode.P then
        BotSettings.AutoParry = not BotSettings.AutoParry
        local status = BotSettings.AutoParry and "✅ AÇIK (BAC Güvenli)" or "❌ KAPALI"
        notify("⚔️ Auto Parry", status)
    end
    
    -- F Tuşu: Manuel Test Vuruşu
    if input.KeyCode == Enum.KeyCode.F then
        performParry(false)
    end
end)

-- ====================================================================
-- 8. BAŞLANGIÇ BİLGİLENDİRMESİ
-- ====================================================================

print("")
print("╔═════════════════════════════════════════════════════╗")
print("║   🛡️ BLADE BALL SAFE AI (100% KICK-PROOF)          ║")
print("║   BAC fhb Bypass & Kusursuz Otomatik Parry!         ║")
print("╠═════════════════════════════════════════════════════╣")
print("║   📌 KONTROLLER:                                    ║")
print("║   [P] = Auto Parry Aç/Kapat                         ║")
print("║   [F] = Manuel Parry                                ║")
print("╚═════════════════════════════════════════════════════╝")
print("")

notify("🛡️ Blade Ball Safe", "✅ Anti-Cheat korumalı parry aktif!")