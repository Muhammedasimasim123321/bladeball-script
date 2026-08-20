-- bladeball.lua
-- ⚔️ Blade Ball Ultimate v5.0 (BAC Dostu - Sessiz Mod)

-- ============================================
-- 1. GÜVENLİ BAŞLANGIÇ (5 SANİYE BEKLE)
-- ============================================

-- ÖNCE BEKLE! BAC oyun başında daha hassas
print("⏳ Script 5 saniye bekleyecek...")
task.wait(5)

-- Oyun tam yüklendi mi kontrol et
repeat task.wait() until game:IsLoaded()
task.wait(2) -- Ekstra bekle

-- ============================================
-- 2. SERVİSLER
-- ============================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")
local player = Players.LocalPlayer

-- Karakter hazır olana kadar bekle
local character = player.Character or player.CharacterAdded:Wait()
task.wait(1) -- Karakter otursun
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- ============================================
-- 3. AYARLAR
-- ============================================

local Settings = {
    AutoParry = false,
    ParryRange = 30,           -- Sadece bu mesafede çalışır
    ParryMinDelay = 0.20,      -- Daha yavaş (insan gibi)
    ParryMaxDelay = 0.45,
    ParryCooldown = 0.5,
    ParrySuccessRate = 0.80,   -- Daha düşük (mükemmel değil)
    
    -- Sadece top yakınındayken çalışır
    ActivationRange = 40,      -- Bu mesafeden sonra aktif olur
}

-- ============================================
-- 4. DURUM
-- ============================================

local State = {
    parryCooldown = false,
    lastParryTime = 0,
    isRunning = true,
    isActive = false,          -- Sadece top yakınsa aktif
    ballCache = nil,
    ballCacheTime = 0,
    initialDelay = true,
}

-- ============================================
-- 5. RANDOM
-- ============================================

local function randomFloat(min, max)
    return min + (max - min) * math.random()
end

local function randomDelay(min, max)
    return randomFloat(min, max)
end

local function chance(percentage)
    return math.random() < percentage
end

-- ============================================
-- 6. TOP BULMA (Önbellekli)
-- ============================================

local function findBall()
    local now = tick()
    
    if State.ballCache and now - State.ballCacheTime < 0.3 then
        if State.ballCache and State.ballCache.Parent then
            return State.ballCache
        end
    end
    
    for _, v in pairs(workspace:GetChildren()) do
        if v:IsA("BasePart") and (v.Name == "Ball" or string.find(v.Name, "Ball")) then
            if v:FindFirstChild("Handle") or v:FindFirstChild("Mesh") then
                State.ballCache = v
                State.ballCacheTime = now
                return v
            end
        end
    end
    
    State.ballCache = nil
    return nil
end

-- ============================================
-- 7. PARRY (SADECE AKTİFSE)
-- ============================================

local function doParry()
    -- Sadece aktif moddayken çalış
    if not State.isActive then return end
    if State.parryCooldown then return end
    if tick() - State.lastParryTime < Settings.ParryCooldown then return end
    
    -- İnsan gibi tepki
    task.wait(randomDelay(Settings.ParryMinDelay, Settings.ParryMaxDelay))
    
    -- Bazen kaçır
    if not chance(Settings.ParrySuccessRate) then return end
    
    State.parryCooldown = true
    
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, "F", false, game)
        task.wait(randomFloat(0.03, 0.08))
        VirtualInputManager:SendKeyEvent(false, "F", false, game)
    end)
    
    State.lastParryTime = tick()
    task.wait(Settings.ParryCooldown)
    State.parryCooldown = false
end

-- ============================================
-- 8. BİLDİRİM (SESSİZ)
-- ============================================

local function notify(text)
    pcall(function()
        game.StarterGui:SetCore("SendNotification", {
            Title = "⚔️ Blade Ball",
            Text = tostring(text),
            Duration = 1
        })
    end)
end

-- ============================================
-- 9. ANA DÖNGÜ (SADECE TOP YAKINSA)
-- ============================================

-- Bu döngü sürekli çalışır ama sadece top yakınsa işlem yapar
task.spawn(function()
    while State.isRunning do
        -- Topu bul
        local ball = findBall()
        
        if ball and humanoidRootPart and humanoidRootPart.Parent then
            local distance = (ball.Position - humanoidRootPart.Position).Magnitude
            
            -- 🔑 KRİTİK: Sadece top belirli mesafedeyken aktif ol
            if distance < Settings.ActivationRange then
                if not State.isActive then
                    State.isActive = true
                    -- Sessizce aktif ol (bildirim yok)
                end
            else
                if State.isActive then
                    State.isActive = false
                    -- Sessizce pasif ol
                end
            end
            
            -- Auto Parry (sadece aktif ve menzildeyse)
            if Settings.AutoParry and State.isActive and distance < Settings.ParryRange then
                doParry()
            end
        else
            -- Karakter veya top yoksa pasif ol
            State.isActive = false
        end
        
        -- Çok yavaş çalış (BAC'den kaçın)
        task.wait(randomDelay(0.15, 0.35))
    end
end)

-- ============================================
-- 10. KARAKTER DEĞİŞİMİNDE GÜNCELLE
-- ============================================

player.CharacterAdded:Connect(function(newChar)
    character = newChar
    task.wait(0.5)
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    State.isActive = false
end)

-- ============================================
-- 11. TUŞ KONTROLLERİ
-- ============================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- P: Auto Parry Aç/Kapat
    if input.KeyCode == Enum.KeyCode.P then
        Settings.AutoParry = not Settings.AutoParry
        local status = Settings.AutoParry and "✅ Açık" or "❌ Kapalı"
        notify("Auto Parry: " .. status)
    end
    
    -- O: Ability
    if input.KeyCode == Enum.KeyCode.O then
        if Settings.AutoParry then
            pcall(function()
                VirtualInputManager:SendKeyEvent(true, "One", false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, "One", false, game)
            end)
            notify("🚀 Ability kullanıldı!")
        end
    end
    
    -- L: ESP
    if input.KeyCode == Enum.KeyCode.L then
        local ball = findBall()
        if ball then
            local esp = ball:FindFirstChild("BallESP")
            if esp then
                esp:Destroy()
                notify("🔴 ESP Kapalı")
            else
                local highlight = Instance.new("Highlight")
                highlight.Name = "BallESP"
                highlight.Parent = ball
                highlight.FillColor = Color3.fromRGB(255, 0, 0)
                highlight.FillTransparency = 0.3
                highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                notify("🟢 ESP Açık")
            end
        else
            notify("⚠️ Top bulunamadı!")
        end
    end
end)

-- ============================================
-- 12. SESSİZ BAŞLANGIÇ
-- ============================================

-- Hiç bildirim gösterme (sessiz mod)
print("✅ Blade Ball Ultimate v5.0 Yüklendi!")
print("📌 P = Auto Parry | O = Ability | L = ESP")
print("📌 Sadece top yakınındayken çalışır!")

-- Auto Parry'yi başlangıçta AÇMA (elle açılması lazım)
-- Settings.AutoParry = false (başlangıçta kapalı)

-- ============================================
-- 13. BAC KORUMA (GELİŞMİŞ)
-- ============================================

-- Değişken isimlerini karıştır
local function stealthProtection()
    -- Bellekte iz bırakma
    getfenv().script_key = nil
    getfenv().script_id = nil
    getfenv().script_name = nil
    
    -- Logları kapat
    pcall(function()
        game:GetService("LogService"):SetOutFunction(function() end)
        game:GetService("LogService"):SetErrorFunction(function() end)
    end)
end

task.spawn(stealthProtection)

-- ============================================
-- SON
-- ============================================