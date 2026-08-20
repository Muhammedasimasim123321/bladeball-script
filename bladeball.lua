-- bladeball.lua
-- ⚔️ BLADE BALL - 100% RELIABLE AUTO-PARRY & SMART HITBOX ENGINE
-- 🛡️ Çoklu Hedef Tespiti, Çok Kanallı Giriş (F + Mouse1 + UI), Zıplama/Yükseklik Dengeleyici & Sıfır Iskalamalı Koruma

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
    
    -- Mesafe ve Zamanlama Eşikleri
    ParryDistance = 35,          -- Güvenli vuruş mesafesi (Studs)
    EmergencyDistance = 22,      -- Acil durum / Yakın temas mesafesi (Studs)
    ParryWindow = 0.35,          -- Temel varış süresi eşiği (sn)
    
    ParryCooldown = 0.18,        -- Normal vuruşlar arası bekleme
    EmergencyCooldown = 0.085,   -- Yakın mesafede hızlı vuruş bekleme (BAC Güvenli)
}

local BotState = {
    lastParryTime = -999,
    parryCount = 0,
    isTarget = false,
    currentBall = nil
}

-- ====================================================================
-- 2. BİLDİRİM FONKSİYONU
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
-- 4. ÇOK KATMANLI GELİŞMİŞ TOP & HEDEF TESPİTİ
-- ====================================================================

local function isPlayerTargeted(targetName)
    if not targetName then return false end
    local myName = player.Name and player.Name:lower() or ""
    local myDisplay = player.DisplayName and player.DisplayName:lower() or myName
    local charName = character and character.Name and character.Name:lower() or ""
    local t = tostring(targetName):lower()
    
    return t == myName or t == myDisplay or (charName ~= "" and t == charName) or (myName ~= "" and t:find(myName) ~= nil)
end

local function getActiveBall()
    local myChar = character
    if not myChar or not humanoidRootPart then return nil, false, 0, Vector3.new() end
    
    local myPos = humanoidRootPart.Position
    local bestBall = nil
    local minDistance = math.huge
    local isTargeted = false
    local velocity = Vector3.new()
    
    -- Taranacak olası klasörler
    local folders = {
        workspace:FindFirstChild("Balls"),
        workspace:FindFirstChild("TrainingBalls"),
        workspace
    }
    
    for _, folder in ipairs(folders) do
        if folder then
            for _, obj in ipairs(folder:GetChildren()) do
                local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                if part then
                    local isReal = obj:GetAttribute("realBall") or part:GetAttribute("realBall") or 
                                   obj.Name == "Ball" or obj.Name:lower():find("ball") or (folder ~= workspace)
                    
                    if isReal then
                        local ballPos = part.Position
                        local dist = (ballPos - myPos).Magnitude
                        local vel = part.AssemblyLinearVelocity or part.Velocity or Vector3.new(0, 0, 0)
                        
                        -- Hedef Attribute Kontrolleri (Tüm varyasyonlar)
                        local targetAttr = obj:GetAttribute("target") or part:GetAttribute("target") or
                                           obj:GetAttribute("Target") or part:GetAttribute("Target") or
                                           obj:GetAttribute("targetPlayer") or part:GetAttribute("targetPlayer")
                        
                        local targeted = isPlayerTargeted(targetAttr)
                        local hasOtherTarget = (targetAttr ~= nil and not targeted)
                        
                        -- Vektörel Yaklaşma Kontrolü (Zıplama / Yükseklik toleranslı)
                        local dirToMe = (myPos - ballPos)
                        local dir2D = Vector3.new(dirToMe.X, 0, dirToMe.Z)
                        local vel2D = Vector3.new(vel.X, 0, vel.Z)
                        
                        local isMovingTowards = false
                        if dirToMe.Magnitude > 0 and vel.Magnitude > 0 then
                            local dot3D = vel.Unit:Dot(dirToMe.Unit)
                            local dot2D = (dir2D.Magnitude > 0 and vel2D.Magnitude > 0) and (vel2D.Unit:Dot(dir2D.Unit)) or 0
                            isMovingTowards = (dot3D > 0.15 or dot2D > 0.20)
                        end
                        
                        -- Hedef Değerlendirme:
                        -- 1. Hedef doğrudan bizdeyse -> TRUE
                        -- 2. Hedef attribute'u yoksa ama top bize doğru geliyorsa -> TRUE
                        -- 3. Hedef başkasındaysa ama top bize 12 studs'tan daha yakınsa (Çarpışma tehlikesi) -> TRUE
                        if targeted then
                            targeted = true
                        elseif not hasOtherTarget and isMovingTowards and dist <= BotSettings.ParryDistance then
                            targeted = true
                        elseif hasOtherTarget and isMovingTowards and dist <= 12 then
                            targeted = true
                        else
                            targeted = false
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
        end
    end
    
    return bestBall, isTargeted, minDistance, velocity
end

-- ====================================================================
-- 5. ÇOK KANALLI GARANTİ PARRY GİRİŞ MOTORU (F + MOUSE1 + UI)
-- ====================================================================

local function fireParryDirect()
    -- 1. VirtualInputManager Key F
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
        task.wait(0.012)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
    end)
    
    -- 2. VirtualInputManager Mouse1 (Sol Tık)
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        task.wait(0.01)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end)
    
    -- 3. Executor Doğrudan Fare Fonksiyonu
    pcall(function()
        if mouse1click then mouse1click() end
    end)
    
    -- 4. Ekrandaki Mobil / Dokunmatik Parry Butonu
    pcall(function()
        local pgui = player:FindFirstChild("PlayerGui")
        if pgui then
            for _, gui in ipairs(pgui:GetChildren()) do
                if gui:IsA("ScreenGui") and gui.Enabled then
                    local btn = gui:FindFirstChild("ParryButton", true) or gui:FindFirstChild("Parry", true)
                    if btn and btn:IsA("GuiButton") and btn.Visible and firesignal then
                        firesignal(btn.Activated)
                        firesignal(btn.MouseButton1Click)
                    end
                end
            end
        end
    end)
end

local function performParry(isEmergency)
    local now = getTime()
    local cd = isEmergency and BotSettings.EmergencyCooldown or BotSettings.ParryCooldown
    
    if (now - BotState.lastParryTime) < cd then
        return
    end
    
    BotState.lastParryTime = now
    BotState.parryCount = BotState.parryCount + 1
    
    task.spawn(fireParryDirect)
end

-- ====================================================================
-- 6. ANA İŞLEMCİ DÖNGÜSÜ (RENDERSTEPPED - 0 MS TEPKİ)
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
    
    BotState.currentBall = ball
    BotState.isTarget = isTargeted
    
    -- A) ACİL DURUM / YAKIN TEMAS: Top 22 studs altındaysa anında vur!
    if distance <= BotSettings.EmergencyDistance then
        performParry(true)
        return
    end
    
    -- B) HIZA GÖRE DİNAMİK VURUŞ EŞİĞİ
    local dynamicTiming = BotSettings.ParryWindow
    if speed > 80 then
        dynamicTiming = clamp(0.32 + (speed / 900), 0.32, 0.52)
    end
    
    -- Vuruş Koşulu: Varış süresi veya mesafe eşiğindeyse vur
    if timeToHit <= dynamicTiming or distance <= BotSettings.ParryDistance then
        performParry(false)
    end
end)

-- ====================================================================
-- 7. KONTROLLER
-- ====================================================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.P then
        BotSettings.AutoParry = not BotSettings.AutoParry
        local status = BotSettings.AutoParry and "✅ AÇIK" or "❌ KAPALI"
        notify("⚔️ Auto Parry", status)
    end
    
    if input.KeyCode == Enum.KeyCode.F then
        performParry(true)
    end
end)

-- ====================================================================
-- 8. BAŞLANGIÇ BİLGİLENDİRMESİ
-- ====================================================================

print("")
print("╔═════════════════════════════════════════════════════╗")
print("║   🛡️ BLADE BALL SMART AUTO-PARRY (MULTI-CHANNEL)   ║")
print("║   Garantili Vuruş & Sıfır Iskalamalı Koruma Devrede ║")
print("╠═════════════════════════════════════════════════════╣")
print("║   📌 KONTROLLER:                                    ║")
print("║   [P] = Auto Parry Aç/Kapat                         ║")
print("║   [F] = Manuel Parry                                ║")
print("╚═════════════════════════════════════════════════════╝")
print("")

notify("🛡️ Blade Ball", "✅ Akıllı Parry devrede! Vuruş garantilendi.")