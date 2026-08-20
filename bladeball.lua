-- bladeball.lua
-- ⚔️ Blade Ball Ultimate v6.0 (ÇALIŞAN PARRY)

-- ============================================
-- 1. BAŞLANGIÇ
-- ============================================

repeat task.wait() until game:IsLoaded()
task.wait(3)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer

-- Karakter kontrolü
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- ============================================
-- 2. AYARLAR
-- ============================================

local Settings = {
    AutoParry = true,           -- Başlangıçta AÇIK
    ParryRange = 35,            -- Kaç birimde parry yapacağı
    ParryCooldown = 0.3,        -- Kaç saniye bekleyecek
    DebugMode = false,          -- Hata ayıklama mesajları
}

-- ============================================
-- 3. DURUM
-- ============================================

local State = {
    parryCooldown = false,
    lastParryTime = 0,
    parryCount = 0,
}

-- ============================================
-- 4. TOP BULMA (GELİŞMİŞ)
-- ============================================

local function findBall()
    -- Tüm çocukları tara
    for _, v in pairs(workspace:GetChildren()) do
        -- Top ismi aranıyor
        if v:IsA("BasePart") then
            local name = v.Name:lower()
            -- Top ile ilgili herhangi bir isim
            if name:find("ball") or name:find("sphere") or name:find("projectile") then
                -- Handle veya Mesh varsa top olabilir
                if v:FindFirstChild("Handle") or v:FindFirstChild("Mesh") then
                    return v
                end
                -- Veya sadece topa benzeyen bir cisim
                if v.Size.Magnitude < 10 and v.Size.Magnitude > 1 then
                    return v
                end
            end
        end
    end
    return nil
end

-- ============================================
-- 5. PARRY FONKSİYONU (GÜVENLİ)
-- ============================================

local function doParry()
    -- Cooldown kontrolü
    if State.parryCooldown then 
        if Settings.DebugMode then
            print("⏳ Cooldown bekleniyor...")
        end
        return 
    end
    
    local now = tick()
    if now - State.lastParryTime < Settings.ParryCooldown then 
        if Settings.DebugMode then
            print("⏳ Parry cooldown: " .. (now - State.lastParryTime))
        end
        return 
    end
    
    State.parryCooldown = true
    State.parryCount = State.parryCount + 1
    
    if Settings.DebugMode then
        print("🔥 PARRY YAPILIYOR! #" .. State.parryCount)
    end
    
    -- F tuşuna bas (Parry)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
    end)
    
    State.lastParryTime = tick()
    
    -- Cooldown bekle
    task.wait(Settings.ParryCooldown)
    State.parryCooldown = false
end

-- ============================================
-- 6. ANA DÖNGÜ (HIZLI VE SÜREKLİ)
-- ============================================

-- Heartbeat ile sürekli kontrol
RunService.Heartbeat:Connect(function()
    -- Auto Parry kapalıysa çık
    if not Settings.AutoParry then return end
    
    -- Karakter kontrolü
    if not character or not character.Parent then
        character = player.Character or player.CharacterAdded:Wait()
        humanoidRootPart = character:WaitForChild("HumanoidRootPart")
        return
    end
    
    -- Topu bul
    local ball = findBall()
    if not ball then 
        if Settings.DebugMode then
            -- print("❌ Top bulunamadı")
        end
        return 
    end
    
    -- Mesafe hesapla
    local distance = (ball.Position - humanoidRootPart.Position).Magnitude
    
    -- DEBUG: Mesafeyi göster
    if Settings.DebugMode and distance < 50 then
        print("📏 Mesafe: " .. string.format("%.1f", distance))
    end
    
    -- Mesafe kontrolü
    if distance < Settings.ParryRange then
        if Settings.DebugMode then
            print("🎯 PARRY TETİKLENDİ! Mesafe: " .. string.format("%.1f", distance))
        end
        doParry()
    end
end)

-- ============================================
-- 7. TUŞ KONTROLLERİ
-- ============================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- P tuşu: Auto Parry Aç/Kapat
    if input.KeyCode == Enum.KeyCode.P then
        Settings.AutoParry = not Settings.AutoParry
        local status = Settings.AutoParry and "✅ AÇIK" or "❌ KAPALI"
        notify("Auto Parry: " .. status)
        
        if Settings.DebugMode then
            print("Auto Parry: " .. status)
        end
    end
    
    -- F tuşu: Manuel Parry (test için)
    if input.KeyCode == Enum.KeyCode.F then
        doParry()
        if Settings.DebugMode then
            print("🔴 Manuel Parry yapıldı!")
        end
    end
    
    -- D tuşu: Debug modu aç/kapat
    if input.KeyCode == Enum.KeyCode.D then
        Settings.DebugMode = not Settings.DebugMode
        notify("Debug: " .. (Settings.DebugMode and "✅ Açık" or "❌ Kapalı"))
    end
end)

-- ============================================
-- 8. BİLDİRİM
-- ============================================

local function notify(text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "⚔️ Blade Ball",
            Text = tostring(text),
            Duration = 2
        })
    end)
end

-- ============================================
-- 9. BAŞLANGIÇ MESAJI
-- ============================================

print("")
print("╔═══════════════════════════════════════╗")
print("║   ⚔️ BLADE BALL ULTIMATE v6.0        ║")
print("║   Auto Parry AKTİF!                  ║")
print("╠═══════════════════════════════════════╣")
print("║   📌 KONTROLLER:                     ║")
print("║   P = Auto Parry Aç/Kapat           ║")
print("║   F = Manuel Parry (Test)           ║")
print("║   D = Debug Modu Aç/Kapat           ║")
print("╠═══════════════════════════════════════╣")
print("║   📏 Parry Mesafesi: " .. Settings.ParryRange .. " birim  ║")
print("╚═══════════════════════════════════════╝")
print("")

notify("✅ Script yüklendi! Auto Parry AÇIK!")

-- ============================================
-- SON
-- ============================================