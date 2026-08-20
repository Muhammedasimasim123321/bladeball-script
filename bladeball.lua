-- bladeball.lua
-- ⚔️ BLADE BALL - ADVANCED AI AUTO-BOT (FULL TRACKING & PERFECT PARRY ENGINE)
-- 🤖 Akıllı Top Takibi, Otomatik Yüz Dönme, Whiff Koruması, Mesafe Koruma ve Kusursuz Zamanlama

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
-- 1. BOT VE SAVAŞ AYARLARI
-- ====================================================================

local BotSettings = {
    AutoParry = true,            -- Otomatik Kusursuz Parry
    AutoLookAtBall = true,       -- Topa otomatik yüzünü dön (Hitbox avantajı)
    AutoSpacing = false,         -- Otomatik mesafe koruma (Geriye/Güvenli alana çekilme)
    
    -- Zamanlama ve Mesafe Parametreleri
    BaseParryDistance = 32,      -- Standart vuruş menzili
    ClashDistance = 14,          -- Yakın temas clash menzili
    ParryWindow = 0.30,          -- Vuruş penceresi (Blade Ball parry aktif süresi)
    
    ParryCooldown = 0.22,        -- Normal parry bekleme süresi (Erken basıp kilitlenmeyi önler)
    ClashCooldown = 0.08,        -- Clash sırasında hızlı spam süresi
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
local humanoid = character and character:FindFirstChild("Humanoid")

local function onCharacterAdded(newChar)
    character = newChar
    humanoidRootPart = newChar:WaitForChild("HumanoidRootPart", 5)
    humanoid = newChar:FindFirstChild("Humanoid") or (newChar.FindFirstChildOfClass and newChar:FindFirstChildOfClass("Humanoid"))
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
-- 5. KUSURSUZ PARRY TETİKLEME MOTORU (WHIFF KORUMALI)
-- ====================================================================

local function performParry(isClash)
    local now = getTime()
    local cd = isClash and BotSettings.ClashCooldown or BotSettings.ParryCooldown
    
    if (now - BotState.lastParryTime) < cd then
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
-- 6. BOT TAKİP VE HAREKET ZEKİ DÖNGÜSÜ (RENDERSTEPPED)
-- ====================================================================

renderSignal:Connect(function()
    if not character or not humanoidRootPart or not humanoidRootPart.Parent then return end
    
    local ball, isTargeted, distance, velocity = getActiveBall()
    if not ball then 
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
    
    -- 1. OTOMATİK TOPA YÜZÜNÜ DÖNME (Auto-Aim / Hitbox Genişletme)
    if BotSettings.AutoLookAtBall and isTargeted and distance <= 50 then
        pcall(function()
            local targetPos = Vector3.new(ball.Position.X, humanoidRootPart.Position.Y, ball.Position.Z)
            if CFrame and CFrame.lookAt then
                humanoidRootPart.CFrame = CFrame.lookAt(humanoidRootPart.Position, targetPos)
            end
        end)
    end
    
    -- 2. OTOMATİK AKILLI MESAFE KORUMA (Auto-Spacing)
    if BotSettings.AutoSpacing and isTargeted and humanoid and humanoid.MoveTo then
        pcall(function()
            if distance <= 25 then
                local backDir = (humanoidRootPart.Position - ball.Position).Unit
                humanoid:MoveTo(humanoidRootPart.Position + Vector3.new(backDir.X * 10, 0, backDir.Z * 10))
            end
        end)
    end
    
    -- 3. KUSURSUZ VE HATASIZ PARRY KARAR MOTORU
    if not BotSettings.AutoParry or not isTargeted then return end
    
    -- A) CLASH / DİP DİBE SAVAŞ: Mesafe çok yakınsa hızlı vur
    if distance <= BotSettings.ClashDistance then
        performParry(true)
        return
    end
    
    -- B) HIZA GÖRE DİNAMİK VURUŞ EŞİĞİ (Parry Window Calculation)
    local dynamicTiming = BotSettings.ParryWindow
    if speed > 100 then
        dynamicTiming = clamp(0.28 + (speed / 1200), 0.28, 0.42)
    elseif speed < 45 then
        dynamicTiming = 0.24
    end
    
    -- Vuruş Koşulu: Top tam kılıcın parry penceresine girdiğinde vurur
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
        local status = BotSettings.AutoParry and "✅ AÇIK" or "❌ KAPALI"
        notify("⚔️ Auto Parry", status)
    end
    
    -- L Tuşu: Otomatik Top Takibi / Yüz Dönme Aç / Kapat
    if input.KeyCode == Enum.KeyCode.L then
        BotSettings.AutoLookAtBall = not BotSettings.AutoLookAtBall
        local status = BotSettings.AutoLookAtBall and "✅ AÇIK" or "❌ KAPALI"
        notify("👀 Top Takibi", status)
    end
    
    -- M Tuşu: Otomatik Mesafe Koruma Aç / Kapat
    if input.KeyCode == Enum.KeyCode.M then
        BotSettings.AutoSpacing = not BotSettings.AutoSpacing
        local status = BotSettings.AutoSpacing and "✅ AÇIK" or "❌ KAPALI"
        notify("🏃 Mesafe Koruma", status)
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
print("║   🤖 BLADE BALL AI AUTO-BOT (FULL TRACKING)        ║")
print("║   Akıllı Top Takibi & Kusursuz Parry Aktif!         ║")
print("╠═════════════════════════════════════════════════════╣")
print("║   📌 KONTROLLER:                                    ║")
print("║   [P] = Auto Parry Aç/Kapat                         ║")
print("║   [L] = Otomatik Topa Yüzünü Dönme (Auto-Aim)       ║")
print("║   [M] = Otomatik Mesafe Koruma (Geri Çekilme)       ║")
print("║   [F] = Manuel Parry                                ║")
print("╚═════════════════════════════════════════════════════╝")
print("")

notify("🤖 Blade Ball Bot", "✅ AI Takip & Kusursuz Parry Devrede!")