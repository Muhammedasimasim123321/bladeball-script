-- bladeball.lua
-- ⚔️ BLADE BALL - INSTANT MILLISECOND AUTO SPAM PARRY
-- ⚡ Top sana yöneldiğinde veya menzile girdiğinde 0 gecikmeyle milisaniyelik aralıksız vuruş yapar.

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local renderSignal = RunService.RenderStepped or RunService.Heartbeat

-- ====================================================================
-- 1. AYARLAR (MİLİSANİYELİK SPAM VE ALAN AYARLARI)
-- ====================================================================

local AutoParryEnabled = true
local ParryZone = 36           -- Savunma Alanı Mesafesi (Studs) - Bu alana girdiği an seri vuruş başlar
local MaxTimeToHit = 0.35      -- Hızlı toplar için algılama süresi (sn)

-- ====================================================================
-- 2. BİLDİRİM
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
-- 4. TOP VE HEDEF TESPİTİ
-- ====================================================================

local function getTargetBall()
    local balls = workspace:FindFirstChild("Balls") or workspace
    local myChar = character
    if not myChar or not humanoidRootPart then return nil, false, 0 end
    
    local myName = player.Name
    local charName = myChar.Name
    
    local closestBall = nil
    local minDistance = math.huge
    local isTargetedToMe = false
    
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
                    local vel = part.AssemblyLinearVelocity or part.Velocity or Vector3.new(0, 0, 0)
                    local dir = (humanoidRootPart.Position - part.Position)
                    if dir.Magnitude > 0 and vel.Magnitude > 0 then
                        targeted = (vel.Unit:Dot(dir.Unit) > 0.25)
                    end
                end
                
                if dist < minDistance then
                    minDistance = dist
                    closestBall = part
                    isTargetedToMe = targeted
                end
            end
        end
    end
    
    return closestBall, isTargetedToMe, minDistance
end

-- ====================================================================
-- 5. MİLİSANİYELİK ANINDA VURUŞ (INSTANT PARRY)
-- ====================================================================

local function instantParry()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
    task.wait(0.01)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
end

-- ====================================================================
-- 6. ÇEKİRDEK İŞLEMCİ DÖNGÜSÜ (RENDERSTEPPED - 0 MS GECİKME)
-- ====================================================================

renderSignal:Connect(function()
    if not AutoParryEnabled then return end
    if not character or not humanoidRootPart or not humanoidRootPart.Parent then return end
    
    local ball, isTargeted, distance = getTargetBall()
    if not ball then return end
    
    -- Eğer top bize hedeflenmişse veya bize doğru geliyorsa
    if isTargeted then
        local velocity = ball.AssemblyLinearVelocity or ball.Velocity or Vector3.new(0, 0, 0)
        local speed = velocity.Magnitude
        local timeToHit = speed > 5 and (distance / speed) or math.huge
        
        -- ALAN VE VARIRLIK KONTROLÜ:
        -- Top senin alanındaysa (distance <= ParryZone) veya sana çarpmak üzereyse (timeToHit <= MaxTimeToHit)
        -- Anında milisaniyelik tam gaz tıklar!
        if distance <= ParryZone or timeToHit <= MaxTimeToHit then
            task.spawn(instantParry)
        end
    end
end)

-- ====================================================================
-- 7. KONTROLLER
-- ====================================================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- P Tuşu: Aç / Kapat
    if input.KeyCode == Enum.KeyCode.P then
        AutoParryEnabled = not AutoParryEnabled
        local status = AutoParryEnabled and "✅ AÇIK (Milisaniyelik Spam)" or "❌ KAPALI"
        notify("⚔️ Auto Parry", status)
    end
    
    -- F Tuşu: Manuel Test Vuruşu
    if input.KeyCode == Enum.KeyCode.F then
        instantParry()
    end
end)

print("")
print("╔═════════════════════════════════════════════════════╗")
print("║   ⚡ BLADE BALL INSTANT SPAM PARRY (0 MS)           ║")
print("║   Top alanına girdiğinde milisaniyelik tıklar!     ║")
print("╠═════════════════════════════════════════════════════╣")
print("║   📌 KONTROLLER:                                    ║")
print("║   [P] = Auto Parry Aç/Kapat                         ║")
print("║   [F] = Manuel Parry                                ║")
print("╚═════════════════════════════════════════════════════╝")
print("")

notify("⚡ Instant Parry", "✅ Milisaniyelik alan koruması aktif!")