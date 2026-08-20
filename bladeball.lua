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

-- Karakter kontrolü (güvenli)
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")

-- ============================================
-- 2. AYARLAR
-- ============================================

local Settings = {
    AutoParry = true,
    ParryRange = 35,
    ParryCooldown = 0.3,
    DebugMode = false,
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
-- 4. BİLDİRİM FONKSİYONU
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
-- 5. TOP BULMA
-- ============================================

local function findBall()
    for _, v in pairs(workspace:GetChildren()) do
        if v:IsA("BasePart") then
            local name = v.Name:lower()
            if name:find("ball") or name:find("sphere") or name:find("projectile") then
                if v:FindFirstChild("Handle") or v:FindFirstChild("Mesh") then
                    return v
                end
                if v.Size.Magnitude < 10 and v.Size.Magnitude > 1 then
                    return v
                end
            end
        end
    end
    return nil
end

-- ============================================
-- 6. PARRY FONKSİYONU
-- ============================================

local function doParry()
    if State.parryCooldown then return end
    
    local now = tick()
    if now - State.lastParryTime < Settings.ParryCooldown then return end
    
    State.parryCooldown = true
    State.parryCount = State.parryCount + 1
    
    if Settings.DebugMode then
        print("🔥 PARRY #" .. State.parryCount)
    end
    
    -- F tuşuna bas (Parry)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
    end)
    
    State.lastParryTime = tick()
    task.wait(Settings.ParryCooldown)
    State.parryCooldown = false
end

-- ============================================
-- 7. ANA DÖNGÜ
-- ============================================

RunService.Heartbeat:Connect(function()
    if not Settings.AutoParry then return end
    
    -- Karakter kontrolü
    if not character or not character.Parent then
        character = player.Character or player.CharacterAdded:Wait()
        humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
        return
    end
    
    if not humanoidRootPart then return end
    
    -- Topu bul
    local ball = findBall()
    if not ball then return end
    
    -- Mesafe hesapla
    local distance = (ball.Position - humanoidRootPart.Position).Magnitude
    
    if distance < Settings.ParryRange then
        doParry()
    end
end)

-- ============================================
-- 8. TUŞ KONTROLLERİ
-- ============================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.P then
        Settings.AutoParry = not Settings.AutoParry
        local status = Settings.AutoParry and "✅ AÇIK" or "❌ KAPALI"
        notify("Auto Parry: " .. status)
    end
    
    if input.KeyCode == Enum.KeyCode.F then
        doParry()
    end
    
    if input.KeyCode == Enum.KeyCode.D then
        Settings.DebugMode = not Settings.DebugMode
        notify("Debug: " .. (Settings.DebugMode and "✅ Açık" or "❌ Kapalı"))
    end
end)

-- ============================================
-- 9. BAŞLANGIÇ MESAJI
-- ============================================

print("╔═══════════════════════════════════════╗")
print("║   ⚔️ BLADE BALL ULTIMATE v6.0        ║")
print("║   Auto Parry AKTİF!                  ║")
print("╠═══════════════════════════════════════╣")
print("║   P = Auto Parry Aç/Kapat           ║")
print("║   F = Manuel Parry                  ║")
print("║   D = Debug Modu Aç/Kapat           ║")
print("╚═══════════════════════════════════════╝")

notify("✅ Script yüklendi! Auto Parry AÇIK!")