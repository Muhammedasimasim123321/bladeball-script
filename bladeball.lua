-- bladeball.lua
-- ⚔️ Blade Ball Ultimate v4.1 (Kararlı Sürüm)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")
local player = Players.LocalPlayer

-- ============================================
-- 1. GÜVENLİ BAŞLANGIÇ
-- ============================================

local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- ============================================
-- 2. AYARLAR (Dengeli)
-- ============================================

local Settings = {
    AutoParry = false,
    ParryRange = 28,
    ParryMinDelay = 0.15,
    ParryMaxDelay = 0.30,
    ParryCooldown = 0.4,
    ParrySuccessRate = 0.85,
    
    AutoAbility = false,
    AbilityRange = 18,
    AbilityCooldown = 2.5,
    
    AutoBlock = false,
    BlockRange = 25,
    BlockCooldown = 1.2,
    
    ESP = false,
    ESPColor = Color3.fromRGB(255, 0, 0),
}

-- ============================================
-- 3. DURUM YÖNETİCİSİ (Güvenli)
-- ============================================

local State = {
    parryCooldown = false,
    abilityCooldown = false,
    blockCooldown = false,
    lastParryTime = 0,
    lastAbilityTime = 0,
    lastBlockTime = 0,
    isRunning = true,
    ballCache = nil,
    ballCacheTime = 0,
}

-- ============================================
-- 4. RANDOM FONKSİYONLAR
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
-- 5. TOP BULMA (Önbellekli ve Güvenli)
-- ============================================

local function findBall()
    local now = tick()
    
    -- Önbellekten dön
    if State.ballCache and now - State.ballCacheTime < 0.5 then
        if State.ballCache and State.ballCache.Parent then
            return State.ballCache
        end
    end
    
    -- Yeni top ara
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
-- 6. PARRY (Güvenli ve Yavaş)
-- ============================================

local function doParry()
    -- Cooldown kontrolü
    if State.parryCooldown then return end
    if tick() - State.lastParryTime < Settings.ParryCooldown then return end
    
    -- İnsan gibi tepki
    local delay = randomDelay(Settings.ParryMinDelay, Settings.ParryMaxDelay)
    task.wait(delay)
    
    -- Bazen kaçır
    if not chance(Settings.ParrySuccessRate) then return end
    
    State.parryCooldown = true
    
    -- Parry yap
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, "F", false, game)
        task.wait(randomFloat(0.03, 0.07))
        VirtualInputManager:SendKeyEvent(false, "F", false, game)
    end)
    
    State.lastParryTime = tick()
    
    -- Cooldown bekle
    task.wait(Settings.ParryCooldown)
    State.parryCooldown = false
end

-- ============================================
-- 7. ABILITY (Güvenli)
-- ============================================

local function doAbility()
    if State.abilityCooldown then return end
    if tick() - State.lastAbilityTime < Settings.AbilityCooldown then return end
    
    State.abilityCooldown = true
    
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, "One", false, game)
        task.wait(randomFloat(0.03, 0.06))
        VirtualInputManager:SendKeyEvent(false, "One", false, game)
    end)
    
    State.lastAbilityTime = tick()
    task.wait(Settings.AbilityCooldown)
    State.abilityCooldown = false
end

-- ============================================
-- 8. BLOCK (Güvenli)
-- ============================================

local function doBlock()
    if State.blockCooldown then return end
    if tick() - State.lastBlockTime < Settings.BlockCooldown then return end
    
    State.blockCooldown = true
    
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, "G", false, game)
        task.wait(randomFloat(0.05, 0.1))
        VirtualInputManager:SendKeyEvent(false, "G", false, game)
    end)
    
    State.lastBlockTime = tick()
    task.wait(Settings.BlockCooldown)
    State.blockCooldown = false
end

-- ============================================
-- 9. ESP (Güvenli)
-- ============================================

local function toggleESP()
    Settings.ESP = not Settings.ESP
    
    local ball = findBall()
    if not ball then
        notify("⚠️ Top bulunamadı!")
        return
    end
    
    -- Eski ESP'yi temizle
    local oldESP = ball:FindFirstChild("BallESP")
    if oldESP then oldESP:Destroy() end
    local oldGlow = ball:FindFirstChild("Glow")
    if oldGlow then oldGlow:Destroy() end
    
    if Settings.ESP then
        local highlight = Instance.new("Highlight")
        highlight.Name = "BallESP"
        highlight.Parent = ball
        highlight.FillColor = Settings.ESPColor
        highlight.FillTransparency = 0.3
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.OutlineTransparency = 0
        highlight.Adornee = ball
        notify("🟢 ESP Açık")
    else
        notify("🔴 ESP Kapalı")
    end
end

-- ============================================
-- 10. BİLDİRİM
-- ============================================

local function notify(text)
    pcall(function()
        game.StarterGui:SetCore("SendNotification", {
            Title = "⚔️ Blade Ball",
            Text = tostring(text),
            Duration = 2
        })
    end)
end

-- ============================================
-- 11. HUD (HAFİF)
-- ============================================

local function createHUD()
    -- Eski HUD'u temizle
    local oldHUD = CoreGui:FindFirstChild("BladeBallHUD")
    if oldHUD then oldHUD:Destroy() end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BladeBallHUD"
    screenGui.Parent = CoreGui
    screenGui.ResetOnSpawn = false
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Parent = screenGui
    mainFrame.Size = UDim2.new(0, 180, 0, 90)
    mainFrame.Position = UDim2.new(0, 10, 0.5, -45)
    mainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
    mainFrame.BackgroundTransparency = 0.2
    mainFrame.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.Parent = mainFrame
    corner.CornerRadius = UDim.new(0, 8)
    
    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.Parent = mainFrame
    status.Size = UDim2.new(1, -20, 0, 20)
    status.Position = UDim2.new(0, 10, 0, 10)
    status.BackgroundTransparency = 1
    status.Text = "🔴 Auto Parry: Kapalı"
    status.TextColor3 = Color3.fromRGB(200, 200, 200)
    status.TextSize = 12
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Font = Enum.Font.Gotham
    
    local controls = Instance.new("TextLabel")
    controls.Parent = mainFrame
    controls.Size = UDim2.new(1, -20, 0, 50)
    controls.Position = UDim2.new(0, 10, 0, 35)
    controls.BackgroundTransparency = 1
    controls.Text = "P: Parry | O: Ability\nL: ESP | K: Block"
    controls.TextColor3 = Color3.fromRGB(150, 150, 150)
    controls.TextSize = 10
    controls.TextXAlignment = Enum.TextXAlignment.Left
    controls.TextYAlignment = Enum.TextYAlignment.Top
    controls.Font = Enum.Font.Gotham
    
    return { MainFrame = mainFrame, Status = status }
end

local hud = createHUD()

-- HUD güncelleme (yavaş)
task.spawn(function()
    while hud and hud.MainFrame and hud.MainFrame.Parent do
        pcall(function()
            if hud.Status then
                hud.Status.Text = (Settings.AutoParry and "🟢" or "🔴") .. 
                    " Auto Parry: " .. (Settings.AutoParry and "Açık" or "Kapalı")
            end
        end)
        task.wait(1)
    end
end)

-- ============================================
-- 12. ANA DÖNGÜ (ÇOK YAVAŞ - BAC DOSTU)
-- ============================================

-- Parry döngüsü (sadece belirli aralıklarla)
task.spawn(function()
    while State.isRunning do
        if Settings.AutoParry then
            local ball = findBall()
            if ball and humanoidRootPart and humanoidRootPart.Parent then
                local distance = (ball.Position - humanoidRootPart.Position).Magnitude
                if distance < Settings.ParryRange then
                    doParry()
                end
            end
        end
        
        -- Döngü hızını yavaş tut
        task.wait(randomDelay(0.2, 0.4))
    end
end)

-- Ability döngüsü
task.spawn(function()
    while State.isRunning do
        if Settings.AutoAbility then
            local ball = findBall()
            if ball and humanoidRootPart and humanoidRootPart.Parent then
                local distance = (ball.Position - humanoidRootPart.Position).Magnitude
                if distance < Settings.AbilityRange then
                    doAbility()
                end
            end
        end
        task.wait(randomDelay(0.5, 1.0))
    end
end)

-- Block döngüsü
task.spawn(function()
    while State.isRunning do
        if Settings.AutoBlock then
            local ball = findBall()
            if ball and humanoidRootPart and humanoidRootPart.Parent then
                local distance = (ball.Position - humanoidRootPart.Position).Magnitude
                if distance < Settings.BlockRange and distance > 15 then
                    doBlock()
                end
            end
        end
        task.wait(randomDelay(0.5, 1.0))
    end
end)

-- ============================================
-- 13. TUŞ KONTROLLERİ
-- ============================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.P then
        Settings.AutoParry = not Settings.AutoParry
        notify("Auto Parry: " .. (Settings.AutoParry and "✅ Açık" or "❌ Kapalı"))
    end
    
    if input.KeyCode == Enum.KeyCode.O then
        if not Settings.AutoAbility then
            doAbility()
            notify("🚀 Ability kullanıldı!")
        else
            Settings.AutoAbility = false
            notify("❌ Auto Ability kapalı")
        end
    end
    
    if input.KeyCode == Enum.KeyCode.L then
        toggleESP()
    end
    
    if input.KeyCode == Enum.KeyCode.K then
        Settings.AutoBlock = not Settings.AutoBlock
        notify("Auto Block: " .. (Settings.AutoBlock and "✅ Açık" or "❌ Kapalı"))
    end
    
    if input.KeyCode == Enum.KeyCode.RightBracket then
        Settings.ParryRange = math.min(Settings.ParryRange + 5, 60)
        notify("📏 Parry Mesafesi: " .. Settings.ParryRange)
    end
    
    if input.KeyCode == Enum.KeyCode.LeftBracket then
        Settings.ParryRange = math.max(Settings.ParryRange - 5, 10)
        notify("📏 Parry Mesafesi: " .. Settings.ParryRange)
    end
end)

-- ============================================
-- 14. BAŞLANGIÇ MESAJI
-- ============================================

print("✅ Blade Ball Ultimate v4.1 Yüklendi!")
print("📌 P = Auto Parry | O = Ability | L = ESP | K = Block")
notify("✅ Script yüklendi! P tuşu ile başlat.")

-- Otomatik başlat (isteğe bağlı)
task.wait(0.5)
Settings.AutoParry = true
notify("⚔️ Auto Parry Aktif!")

-- ============================================
-- 15. HATA YAKALAMA (Oyun çökmemesi için)
-- ============================================

pcall(function()
    game:GetService("LogService"):SetOutFunction(function(...) end)
    game:GetService("LogService"):SetErrorFunction(function(...) end)
end)

-- ============================================
-- SON
-- ============================================