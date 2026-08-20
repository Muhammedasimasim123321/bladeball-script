-- bladeball.lua
-- ⚔️ Blade Ball - Standart ve Temiz Auto Parry

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local clamp = math.clamp or function(v, min, max) return math.max(min, math.min(max, v)) end

-- ====================================================================
-- 1. AYARLAR
-- ====================================================================

local AutoParryEnabled = true
local BaseDistance = 35
local ParryWindow = 0.33
local LastParry = 0
local Cooldown = 0.18

-- ====================================================================
-- 2. KARAKTER VE TOP BULMA
-- ====================================================================

local function getRootPart()
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function getBall()
    local hrp = getRootPart()
    if not hrp then return nil, false, 0, Vector3.new() end
    
    local myPos = hrp.Position
    local myName = player.Name
    local myDisplay = player.DisplayName
    
    local balls = workspace:FindFirstChild("Balls") or workspace
    local bestBall = nil
    local bestDist = math.huge
    local isTargeted = false
    local bestVel = Vector3.new()
    
    for _, obj in ipairs(balls:GetChildren()) do
        local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
        if part and part.Name ~= "HumanoidRootPart" then
            local isReal = obj:GetAttribute("realBall") or part:GetAttribute("realBall") or obj.Name == "Ball" or balls ~= workspace
            if isReal then
                local bPos = part.Position
                local dist = (bPos - myPos).Magnitude
                local vel = part.AssemblyLinearVelocity or part.Velocity or Vector3.new()
                
                local targetAttr = obj:GetAttribute("target") or part:GetAttribute("target")
                local targetStr = targetAttr and tostring(targetAttr) or ""
                
                local targeted = (targetStr == myName or targetStr == myDisplay)
                local hasOtherTarget = (targetAttr ~= nil and not targeted)
                
                local dir = (myPos - bPos)
                local movingToMe = false
                if dir.Magnitude > 0 and vel.Magnitude > 0 then
                    movingToMe = (vel.Unit:Dot(dir.Unit) > 0.1)
                end
                
                local isThreat = false
                if targeted then
                    isThreat = true
                elseif not hasOtherTarget and movingToMe and dist <= BaseDistance then
                    isThreat = true
                elseif hasOtherTarget and movingToMe and dist <= 14 then
                    isThreat = true
                end
                
                if dist < bestDist then
                    bestDist = dist
                    bestBall = part
                    isTargeted = isThreat
                    bestVel = vel
                end
            end
        end
    end
    
    return bestBall, isTargeted, bestDist, bestVel
end

-- ====================================================================
-- 3. PARRY VURUŞU
-- ====================================================================

local function parry()
    local now = os.clock()
    if (now - LastParry) < Cooldown then return end
    LastParry = now
    
    task.spawn(function()
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
            task.wait(0.015)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
        end)
    end)
end

-- ====================================================================
-- 4. DÖNGÜ (RENDERSTEPPED)
-- ====================================================================

local renderSignal = RunService.RenderStepped or RunService.Heartbeat
renderSignal:Connect(function()
    if not AutoParryEnabled then return end
    
    local ball, isTargeted, dist, vel = getBall()
    if not ball or not isTargeted then return end
    
    local speed = vel.Magnitude
    local hrp = getRootPart()
    if not hrp then return end
    
    local dir = (hrp.Position - ball.Position)
    local approachSpeed = speed
    if dist > 0 and speed > 0 then
        local dot = vel:Dot(dir.Unit)
        if dot > 0 then
            approachSpeed = dot
        end
    end
    
    local effectiveSpeed = math.max(approachSpeed, speed, 1)
    local timeToHit = dist / effectiveSpeed
    
    if dist <= 15 then
        parry()
        return
    end
    
    local dynamicTime = clamp(0.30 + (speed / 1200), 0.30, 0.45)
    local dynamicDist = clamp(speed * dynamicTime, 18, 48)
    
    if timeToHit <= dynamicTime or dist <= dynamicDist then
        parry()
    end
end)

-- ====================================================================
-- 5. KONTROLLER
-- ====================================================================

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.P then
        AutoParryEnabled = not AutoParryEnabled
    elseif input.KeyCode == Enum.KeyCode.F then
        parry()
    end
end)