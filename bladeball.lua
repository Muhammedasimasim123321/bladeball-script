-- bladeball.lua
-- ⚔️ BLADE BALL - 100% SILENT STEALTH AUTO PARRY (ZERO DETECTION / ZERO KICK)
-- 🛡️ Sıfır Print, Sıfır Bildirim, Sıfır Hook, %100 Sessiz ve Kusursuz Vuruş Motoru

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local VirtualInputManager = nil
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)

local player = Players.LocalPlayer
local getTime = os.clock or tick
local renderSignal = RunService.RenderStepped or RunService.Heartbeat
local clamp = math.clamp or function(v, min, max) return math.max(min, math.min(max, v)) end
local typeCheck = typeof or type

-- ====================================================================
-- 1. SAVAŞ AYARLARI
-- ====================================================================

local Config = {
    AutoParry = true,
    ParryDistance = 40,          -- Vuruş menzili (Studs)
    EmergencyDistance = 24,      -- Acil durum mesafesi (Studs)
    ParryCooldown = 0.18,        -- Normal parry bekleme süresi
    ClashCooldown = 0.085,       -- Yakın temas clash bekleme süresi
}

local State = {
    lastParryTime = -999,
    parryCount = 0
}

-- ====================================================================
-- 2. DİNAMİK CANLI KARAKTER BULUCU (RESPAWN SAFE)
-- ====================================================================

local function getMyRootPart()
    local char = player.Character or workspace:FindFirstChild(player.Name)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or 
           char:FindFirstChild("Torso") or 
           char:FindFirstChild("UpperTorso") or 
           char:FindFirstChildWhichIsA("BasePart")
end

-- ====================================================================
-- 3. HEDEF VE TEHDİT KONTROLÜ
-- ====================================================================

local function isTargetMatch(targetVal)
    if not targetVal then return false end
    local myName = player.Name and player.Name:lower() or ""
    local myDisplay = player.DisplayName and player.DisplayName:lower() or myName
    
    if typeCheck(targetVal) == "Instance" then
        return targetVal == player or targetVal == player.Character or targetVal.Name:lower() == myName
    end
    
    local str = tostring(targetVal):lower()
    return str == myName or str == myDisplay or str:find(myName) ~= nil
end

local function findActiveBall(myPos)
    local bestBall = nil
    local minDistance = math.huge
    local isThreat = false
    local ballVel = Vector3.new(0, 0, 0)
    
    local searchContainers = {}
    local ballsFolder = workspace:FindFirstChild("Balls")
    if ballsFolder then table.insert(searchContainers, ballsFolder) end
    local trainingBalls = workspace:FindFirstChild("TrainingBalls")
    if trainingBalls then table.insert(searchContainers, trainingBalls) end
    table.insert(searchContainers, workspace)
    
    for _, container in ipairs(searchContainers) do
        if container and container.GetChildren then
            for _, obj in ipairs(container:GetChildren()) do
                local isOtherPlayer = false
                if Players.GetPlayerFromCharacter then
                    pcall(function() isOtherPlayer = (Players:GetPlayerFromCharacter(obj) ~= nil) end)
                end
                
                if obj ~= player.Character and not isOtherPlayer then
                    local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                    if part and part.Name ~= "HumanoidRootPart" then
                        local isReal = obj:GetAttribute("realBall") or part:GetAttribute("realBall") or
                                       obj.Name == "Ball" or obj.Name:lower():find("ball") or (container ~= workspace)
                        
                        if isReal then
                            local bPos = part.Position
                            local dist = (bPos - myPos).Magnitude
                            local vel = part.AssemblyLinearVelocity or part.Velocity or Vector3.new(0, 0, 0)
                            
                            local targetAttr = obj:GetAttribute("target") or part:GetAttribute("target") or
                                               obj:GetAttribute("Target") or part:GetAttribute("Target") or
                                               obj:GetAttribute("targetPlayer") or part:GetAttribute("targetPlayer")
                            
                            local targetedToMe = isTargetMatch(targetAttr)
                            local hasOtherTarget = (targetAttr ~= nil and not targetedToMe)
                            
                            -- Yaklaşma Açısı (Dot Product)
                            local dirToMe = (myPos - bPos)
                            local isMovingTowards = false
                            if dirToMe.Magnitude > 0 and vel.Magnitude > 0 then
                                local dot = vel.Unit:Dot(dirToMe.Unit)
                                isMovingTowards = (dot > 0.05)
                            end
                            
                            -- TEHDİT DEĞERLENDİRMESİ
                            local threat = false
                            if targetedToMe then
                                threat = true
                            elseif not hasOtherTarget and isMovingTowards and dist <= Config.ParryDistance then
                                threat = true
                            elseif hasOtherTarget and isMovingTowards and dist <= 16 then
                                threat = true
                            end
                            
                            if dist < minDistance then
                                minDistance = dist
                                bestBall = part
                                isThreat = threat
                                ballVel = vel
                            end
                        end
                    end
                end
            end
        end
    end
    
    return bestBall, isThreat, minDistance, ballVel
end

-- ====================================================================
-- 4. SESSİZ VE DOĞAL PARRY MOTORU (BAC KORUMALI)
-- ====================================================================

local function sendParrySignal()
    -- Roblox resmi VirtualInputManager (En güvenli ve tespit edilemez yöntem)
    if VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
            task.wait(0.012)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
        end)
    elseif mouse1click then
        pcall(function()
            mouse1click()
        end)
    end
end

local function executeParry(isClash)
    local now = getTime()
    local cooldown = isClash and Config.ClashCooldown or Config.ParryCooldown
    
    if (now - State.lastParryTime) < cooldown then
        return
    end
    
    State.lastParryTime = now
    State.parryCount = State.parryCount + 1
    
    task.spawn(sendParrySignal)
end

-- ====================================================================
-- 5. ANA İŞLEMCİ DÖNGÜSÜ (RENDERSTEPPED - 0 MS GECİKME)
-- ====================================================================

renderSignal:Connect(function()
    if not Config.AutoParry then return end
    
    local hrp = getMyRootPart()
    if not hrp then return end
    
    local myPos = hrp.Position
    local ball, isThreat, distance, velocity = findActiveBall(myPos)
    if not ball or not isThreat then return end
    
    local speed = velocity.Magnitude
    local dirToMe = (myPos - ball.Position)
    
    -- Yaklaşma Hızı
    local approachSpeed = speed
    if distance > 0 and speed > 0 then
        local dot = velocity:Dot(dirToMe.Unit)
        if dot > 0 then
            approachSpeed = dot
        end
    end
    
    local effectiveSpeed = math.max(approachSpeed, speed, 1)
    local timeToHit = distance / effectiveSpeed
    
    -- A) YAKIN TEMAS / CLASH: 16 studs altındaysa anında vur
    if distance <= 16 then
        executeParry(true)
        return
    end
    
    -- B) HIZA GÖRE DİNAMİK VURUŞ EŞİĞİ (Whiff & Geç Kalma Korumalı)
    local dynamicTargetTime = clamp(0.30 + (speed / 1100), 0.30, 0.46)
    local dynamicMaxDistance = clamp(speed * dynamicTargetTime, 18, 50)
    
    -- Vuruş Koşulu: Varış süresi veya mesafe eşiğindeyse vur
    if timeToHit <= dynamicTargetTime or distance <= dynamicMaxDistance then
        executeParry(false)
    end
end)

-- ====================================================================
-- 6. KISAYOL TUŞLARI
-- ====================================================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.P then
        Config.AutoParry = not Config.AutoParry
    end
    
    if input.KeyCode == Enum.KeyCode.F then
        executeParry(true)
    end
end)