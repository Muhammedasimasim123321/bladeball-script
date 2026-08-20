-- ============================================
-- ⚔️ BLADE BALL ULTIMATE SCRIPT v3.0
-- BAC Dostu | Keysiz | Xeno Uyumlu
-- ============================================

repeat task.wait() until game:IsLoaded()

-- ═══════════════════════════════════════════
-- 📦 SERVİSLER
-- ═══════════════════════════════════════════

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- ═══════════════════════════════════════════
-- ⚙️ AYARLAR (Kullanıcı Tarafından Değiştirilebilir)
-- ═══════════════════════════════════════════

local Settings = {
    -- 🎯 Auto Parry Ayarları
    AutoParry = false,
    ParryRange = 30,
    ParryMinDelay = 0.08,
    ParryMaxDelay = 0.25,
    ParrySuccessRate = 0.88,
    ParryCooldown = 0.3,
    
    -- 🚀 Auto Ability Ayarları
    AutoAbility = false,
    AbilityRange = 20,
    AbilityCooldown = 2.0,
    
    -- 🛡️ Auto Block Ayarları
    AutoBlock = false,
    BlockRange = 25,
    BlockCooldown = 1.0,
    
    -- 👁️ ESP Ayarları
    ESP = false,
    ESPColor = Color3.fromRGB(255, 0, 0),
    ESPTransparency = 0.3,
    
    -- 🕵️‍♂️ Güvenlik Ayarları (BAC Kaçınma)
    StealthMode = true,
    HumanReactionMin = 0.12,
    HumanReactionMax = 0.35,
    RandomMissChance = 0.12,
    JitterAmount = 0.05,
    
    -- 📊 HUD Ayarları
    ShowHUD = true,
    HUDPosition = {X = 10, Y = 10}
}

-- ═══════════════════════════════════════════
-- 🛠️ DURUM YÖNETİMİ
-- ═══════════════════════════════════════════

local State = {
    parryCooldown = false,
    abilityCooldown = false,
    blockCooldown = false,
    isRunning = true,
    lastParryTime = 0,
    lastAbilityTime = 0,
    lastBlockTime = 0,
    parryCount = 0,
    totalAttempts = 0,
    sessionStart = tick()
}

-- ═══════════════════════════════════════════
-- 🎲 RANDOM FONKSİYONLAR
-- ═══════════════════════════════════════════

local function randomFloat(min, max)
    return min + (max - min) * math.random()
end

local function randomDelay(min, max)
    return randomFloat(min or 0.05, max or 0.15)
end

local function randomInt(min, max)
    return math.random(min, max)
end

local function randomChance(probability)
    return math.random() < probability
end

-- ═══════════════════════════════════════════
-- 📌 TOP BULMA (Gelişmiş)
-- ═══════════════════════════════════════════

local ballCache = nil
local ballCacheTime = 0
local BALL_CACHE_DURATION = 0.5

local function findBall()
    local now = tick()
    if ballCache and now - ballCacheTime < BALL_CACHE_DURATION then
        return ballCache
    end
    
    for _, v in pairs(workspace:GetChildren()) do
        if v:IsA("BasePart") and (v.Name == "Ball" or string.find(v.Name, "Ball")) then
            if v:FindFirstChild("Handle") or v:FindFirstChild("Mesh") then
                ballCache = v
                ballCacheTime = now
                return v
            end
        end
    end
    
    ballCache = nil
    return nil
end

-- ═══════════════════════════════════════════
-- 📊 TOP BİLGİLERİ
-- ═══════════════════════════════════════════

local function getBallInfo(ball)
    if not ball then return nil end
    
    local info = {
        position = ball.Position,
        velocity = Vector3.new(0, 0, 0),
        speed = 0,
        direction = Vector3.new(0, 0, 0)
    }
    
    -- Velocity kontrolü
    local velocity = ball:FindFirstChild("Velocity")
    if velocity then
        info.velocity = velocity.Value
        info.speed = velocity.Value.Magnitude
        if info.speed > 0 then
            info.direction = velocity.Value.Unit
        end
    end
    
    return info
end

-- ═══════════════════════════════════════════
-- 🎯 PARRY SİSTEMİ (BAC Dostu)
-- ═══════════════════════════════════════════

local function doParry()
    -- Cooldown kontrolü
    if State.parryCooldown then return false end
    if tick() - State.lastParryTime < Settings.ParryCooldown then return false end
    
    State.parryCooldown = true
    State.totalAttempts = State.totalAttempts + 1
    
    -- 🔄 İnsan gibi tepki süresi
    if Settings.StealthMode then
        local reactionTime = randomFloat(Settings.HumanReactionMin, Settings.HumanReactionMax)
        task.wait(reactionTime)
    end
    
    -- 🎲 Rastgele başarısızlık (mükemmel görünme)
    local success = randomChance(Settings.ParrySuccessRate)
    
    if success then
        -- Parry tuşuna bas
        VirtualInputManager:SendKeyEvent(true, "F", false, game)
        local holdTime = randomFloat(0.03, 0.08)
        task.wait(holdTime)
        VirtualInputManager:SendKeyEvent(false, "F", false, game)
        
        State.parryCount = State.parryCount + 1
        State.lastParryTime = tick()
        
        -- Rastgele jitter (insan hareketi taklidi)
        if Settings.StealthMode and randomChance(0.3) then
            local jitter = randomFloat(-Settings.JitterAmount, Settings.JitterAmount)
            task.wait(jitter)
        end
        
        State.parryCooldown = false
        return true
    else
        -- Başarısız oldu (insan gibi)
        State.parryCooldown = false
        return false
    end
end

-- ═══════════════════════════════════════════
-- 🚀 ABILITY SİSTEMİ
-- ═══════════════════════════════════════════

local function doAbility()
    if State.abilityCooldown then return false end
    if tick() - State.lastAbilityTime < Settings.AbilityCooldown then return false end
    
    State.abilityCooldown = true
    
    if Settings.StealthMode then
        task.wait(randomDelay(0.05, 0.15))
    end
    
    VirtualInputManager:SendKeyEvent(true, "One", false, game)
    task.wait(randomFloat(0.03, 0.06))
    VirtualInputManager:SendKeyEvent(false, "One", false, game)
    
    State.lastAbilityTime = tick()
    State.abilityCooldown = false
    return true
end

-- ═══════════════════════════════════════════
-- 🛡️ BLOCK SİSTEMİ
-- ═══════════════════════════════════════════

local function doBlock()
    if State.blockCooldown then return false end
    if tick() - State.lastBlockTime < Settings.BlockCooldown then return false end
    
    State.blockCooldown = true
    
    if Settings.StealthMode then
        task.wait(randomDelay(0.05, 0.12))
    end
    
    VirtualInputManager:SendKeyEvent(true, "G", false, game)
    task.wait(randomFloat(0.03, 0.06))
    VirtualInputManager:SendKeyEvent(false, "G", false, game)
    
    State.lastBlockTime = tick()
    State.blockCooldown = false
    return true
end

-- ═══════════════════════════════════════════
-- 👁️ ESP SİSTEMİ
-- ═══════════════════════════════════════════

local function toggleESP()
    Settings.ESP = not Settings.ESP
    
    local ball = findBall()
    if not ball then
        notify("⚠️ Top bulunamadı!")
        return
    end
    
    local esp = ball:FindFirstChild("BallESP")
    if esp then
        esp:Destroy()
        notify("👁️ ESP Kapalı")
    else
        local highlight = Instance.new("Highlight")
        highlight.Name = "BallESP"
        highlight.Parent = ball
        highlight.FillColor = Settings.ESPColor
        highlight.FillTransparency = Settings.ESPTransparency
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.OutlineTransparency = 0
        highlight.Adornee = ball
        notify("👁️ ESP Açık")
    end
end

-- ═══════════════════════════════════════════
-- 📊 HUD SİSTEMİ (Gelişmiş)
-- ═══════════════════════════════════════════

local function createHUD()
    -- Eski HUD'u temizle
    local oldHUD = CoreGui:FindFirstChild("BladeBallHUD")
    if oldHUD then oldHUD:Destroy() end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BladeBallHUD"
    screenGui.Parent = CoreGui
    screenGui.ResetOnSpawn = false
    
    -- Ana çerçeve
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 220, 0, 160)
    frame.Position = UDim2.new(0, Settings.HUDPosition.X, 0, Settings.HUDPosition.Y)
    frame.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(50, 50, 80)
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    stroke.Parent = frame
    
    -- Başlık
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 25)
    title.Position = UDim2.new(0, 0, 0, 5)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = "⚔️ Blade Ball"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 14
    title.Parent = frame
    
    -- Çizgi
    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, -20, 0, 1)
    line.Position = UDim2.new(0, 10, 0, 32)
    line.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
    line.BorderSizePixel = 0
    line.Parent = frame
    
    -- Bilgiler
    local labels = {}
    local infoTexts = {
        {"Auto Parry", "P", "❌"},
        {"Parry Count", "0", ""},
        {"Success Rate", "0%", ""},
        {"Status", "⏸️", ""}
    }
    
    for i, data in ipairs(infoTexts) do
        local yPos = 40 + (i - 1) * 28
        
        -- Label
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0, 120, 0, 22)
        label.Position = UDim2.new(0, 10, 0, yPos)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.Gotham
        label.Text = data[1]
        label.TextColor3 = Color3.fromRGB(180, 180, 200)
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame
        
        -- Tuş
        local key = Instance.new("TextLabel")
        key.Size = UDim2.new(0, 30, 0, 18)
        key.Position = UDim2.new(0, 135, 0, yPos + 2)
        key.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
        key.BackgroundTransparency = 0.3
        key.Font = Enum.Font.GothamBold
        key.Text = data[2]
        key.TextColor3 = Color3.fromRGB(255, 200, 100)
        key.TextSize = 11
        key.Parent = frame
        
        local keyCorner = Instance.new("UICorner")
        keyCorner.CornerRadius = UDim.new(0, 4)
        keyCorner.Parent = key
        
        -- Değer
        local value = Instance.new("TextLabel")
        value.Size = UDim2.new(0, 50, 0, 22)
        value.Position = UDim2.new(0, 170, 0, yPos)
        value.BackgroundTransparency = 1
        value.Font = Enum.Font.GothamBold
        value.Text = data[3]
        value.TextColor3 = data[3] == "✅" and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
        value.TextSize = 12
        value.TextXAlignment = Enum.TextXAlignment.Right
        value.Parent = frame
        
        table.insert(labels, value)
    end
    
    -- HUD güncelleme
    task.spawn(function()
        while screenGui and screenGui.Parent do
            pcall(function()
                -- Auto Parry durumu
                labels[1].Text = Settings.AutoParry and "✅" or "❌"
                labels[1].TextColor3 = Settings.AutoParry and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
                
                -- Parry sayısı
                labels[2].Text = tostring(State.parryCount)
                
                -- Başarı oranı
                local successRate = State.totalAttempts > 0 and math.floor((State.parryCount / State.totalAttempts) * 100) or 0
                labels[3].Text = successRate .. "%"
                labels[3].TextColor3 = successRate > 80 and Color3.fromRGB(100, 255, 100) or 
                                       successRate > 50 and Color3.fromRGB(255, 200, 100) or 
                                       Color3.fromRGB(255, 100, 100)
                
                -- Durum
                labels[4].Text = State.isRunning and "▶️ Çalışıyor" or "⏸️ Durduruldu"
                labels[4].TextColor3 = State.isRunning and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 200, 100)
            end)
            task.wait(0.5)
        end
    end)
    
    return screenGui
end

-- ═══════════════════════════════════════════
-- 📢 BİLDİRİM SİSTEMİ
-- ═══════════════════════════════════════════

local function notify(text, duration)
    duration = duration or 2
    pcall(function()
        game.StarterGui:SetCore("SendNotification", {
            Title = "⚔️ Blade Ball",
            Text = tostring(text),
            Duration = duration
        })
    end)
end

-- ═══════════════════════════════════════════
-- 🎮 ANA DÖNGÜ (BAC Dostu)
-- ═══════════════════════════════════════════

local function mainLoop()
    RunService.Heartbeat:Connect(function()
        if not State.isRunning then return end
        
        -- Karakter kontrolü
        if not character or not character.Parent then
            character = player.Character or player.CharacterAdded:Wait()
            humanoidRootPart = character:WaitForChild("HumanoidRootPart")
            return
        end
        
        -- Top bul
        local ball = findBall()
        if not ball then return end
        
        -- Mesafe hesapla
        local distance = (ball.Position - humanoidRootPart.Position).Magnitude
        
        -- 🎯 Auto Parry
        if Settings.AutoParry and distance < Settings.ParryRange and distance > 5 then
            -- Sadece belli aralıklarla parry yap (BAC dostu)
            if tick() - State.lastParryTime > Settings.ParryCooldown then
                -- Rastgele ihtimal (her zaman yapma)
                if randomChance(0.85) then
                    doParry()
                end
            end
        end
        
        -- 🚀 Auto Ability
        if Settings.AutoAbility and distance < Settings.AbilityRange then
            if tick() - State.lastAbilityTime > Settings.AbilityCooldown then
                doAbility()
            end
        end
        
        -- 🛡️ Auto Block
        if Settings.AutoBlock and distance < Settings.BlockRange and distance > 15 then
            if tick() - State.lastBlockTime > Settings.BlockCooldown then
                if randomChance(0.7) then
                    doBlock()
                end
            end
        end
    end)
end

-- ═══════════════════════════════════════════
-- ⌨️ TUŞ KONTROLLERİ
-- ═══════════════════════════════════════════

local function setupKeybinds()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        local key = input.KeyCode
        
        -- P: Auto Parry Aç/Kapat
        if key == Enum.KeyCode.P then
            Settings.AutoParry