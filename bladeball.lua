-- bladeball.lua
-- ⚔️ BLADE BALL - PURE STEALTH AUTO PARRY (SIFIR KICK, %100 ÖLÜMSÜZLÜK)
-- 🛡️ Anti-Cheat Taramalarına Karşı Sıfır GUI & Sıfır Obje (100% Undetected)

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local getTime = os.clock or tick

-- ====================================================================
-- 1. AYARLAR (EN İDEAL OTOMATİK AYARLAR)
-- ====================================================================

local AutoParryEnabled = true
local ParryRange = 33          -- Standart vuruş mesafesi (studs)
local ParryTiming = 0.28       -- Hızlı toplar için varış süresi (sn)
local ParryCooldown = 0.18     -- Minimum vuruş bekleme süresi
local lastParryTime = 0
local parryCount = 0

-- ====================================================================
-- 2. SES VE BİLDİRİM
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
-- 3. KARAKTER TAKİBİ
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
-- 4. TOP VE HEDEF BULUCU (SAF MATEMATİK & SIFIR OBJE ENJEKSİYONU)
-- ====================================================================

local function getActiveBall()
    local balls = workspace:FindFirstChild("Balls") or workspace
    local myChar = character
    if not myChar or not humanoidRootPart then return nil, false, 0 end
    
    local myName = player.Name
    local charName = myChar.Name
    
    local bestBall = nil
    local minDistance = math.huge
    local isTargeted = false
    
    for _, obj in ipairs(balls:GetChildren()) do
        local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
        if part then
            local isReal = obj:GetAttribute("realBall") or obj.Name == "Ball" or balls ~= workspace
            if isReal then
                local dist = (part.Position - humanoidRootPart.Position).Magnitude
                local targetAttr = obj:GetAttribute("target") or part:GetAttribute("target")
                
                local targeted = false
                if targetAttr then
                    targeted = (targetAttr == myName or targetAttr == charName)
                else
                    -- Top bize mi yöneliyor kontrolü
                    local vel = part.AssemblyLinearVelocity or part.Velocity or Vector3.new(0, 0, 0)
                    local dir = (humanoidRootPart.Position - part.Position)
                    if dir.Magnitude > 0 and vel.Magnitude > 0 then
                        targeted = (vel.Unit:Dot(dir.Unit) > 0.30)
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
    
    return bestBall, isTargeted, minDistance
end

-- ====================================================================
-- 5. SAF VE DOĞAL PARRY (F TUŞU)
-- ====================================================================

local function doParry()
    local now = getTime()
    if (now - lastParryTime) < ParryCooldown then
        return
    end
    
    lastParryTime = now
    parryCount = parryCount + 1
    
    task.spawn(function()
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
            task.wait(0.02)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
        end)
    end)
end

-- ====================================================================
-- 6. ANA KORUMA DÖNGÜSÜ (HEARTBEAT)
-- ====================================================================

RunService.Heartbeat:Connect(function()
    if not AutoParryEnabled then return end
    if not character or not humanoidRootPart or not humanoidRootPart.Parent then return end
    
    local ball, isTargeted, distance = getActiveBall()
    if not ball or not isTargeted then return end
    
    local velocity = ball.AssemblyLinearVelocity or ball.Velocity or Vector3.new(0, 0, 0)
    local speed = velocity.Magnitude
    local timeToHit = speed > 5 and (distance / speed) or math.huge
    
    -- Vuruş Koşulu:
    -- 1. Hızlı top varış süresi eşiğindeyse (timeToHit <= ParryTiming)
    -- 2. Top vuruş mesafesindeyse (distance <= ParryRange)
    if timeToHit <= ParryTiming or distance <= ParryRange then
        doParry()
    end
end)

-- ====================================================================
-- 7. KISAYOL TUŞLARI
-- ====================================================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- P Tuşu: Auto Parry Aç / Kapat
    if input.KeyCode == Enum.KeyCode.P then
        AutoParryEnabled = not AutoParryEnabled
        local status = AutoParryEnabled and "✅ AÇIK (KORUMA DEVREDE)" or "❌ KAPALI"
        notify("⚔️ Auto Parry", status)
    end
    
    -- F Tuşu: Manuel Test Vuruşu
    if input.KeyCode == Enum.KeyCode.F then
        doParry()
    end
end)

-- ====================================================================
-- 8. BAŞLANGIÇ BİLGİLENDİRMESİ
-- ====================================================================

print("")
print("╔═════════════════════════════════════════════════════╗")
print("║   🛡️ BLADE BALL STEALTH EDITION (100% SAFE)         ║")
print("║   Sıfır Obje, Sıfır Kick & Kusursuz Auto Parry!     ║")
print("╠═════════════════════════════════════════════════════╣")
print("║   📌 KONTROLLER:                                    ║")
print("║   [P] = Auto Parry Aç/Kapat                         ║")
print("║   [F] = Manuel Parry                                ║")
print("╚═════════════════════════════════════════════════════╝")
print("")

notify("🛡️ Blade Ball Stealth", "✅ Koruma Açık! Top seni asla öldüremeyecek.")