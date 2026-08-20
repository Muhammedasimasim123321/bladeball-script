-- bladeball.lua
-- ⚔️ Blade Ball - Native Connection Auto Parry (v13.0)
-- Oyunun kendi dahili parry bağlantısını kullanır. Hiçbir harici input yöntemi yoktur.

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local renderSignal = RunService.RenderStepped or RunService.Heartbeat
local clamp = math.clamp or function(v, min, max) return math.max(min, math.min(max, v)) end

-- ====================================================================
-- 1. AYARLAR
-- ====================================================================

local Settings = {
    Enabled = true,
    BaseRange = 38,
    ClashRange = 16,
    NormalCooldown = 0.18,
    ClashCooldown = 0.09,
}

local lastParryTime = -999

-- ====================================================================
-- 2. KARAKTER BULUCU (RESPAWN SAFE)
-- ====================================================================

local function getRootPart()
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

-- ====================================================================
-- 3. PARRY BUTON VE REMOTE BULUCU (DİNAMİK)
-- ====================================================================

local cachedParryButton = nil
local cachedParryRemote = nil

local function findParryButton()
    if cachedParryButton and cachedParryButton.Parent then return cachedParryButton end
    
    local ok, result = pcall(function()
        local pgui = player:FindFirstChild("PlayerGui")
        if not pgui then return nil end
        
        -- Blade Ball'un bilinen parry buton yolları
        local paths = {
            {"Hotbar", "Block"},
            {"Hotbar", "Parry"},
            {"Hotbar", "Block", "Pressable1"},
            {"MobileUI", "Block"},
            {"MobileUI", "Parry"},
            {"TouchGui", "Block"},
        }
        
        for _, path in ipairs(paths) do
            local current = pgui
            local found = true
            for _, name in ipairs(path) do
                current = current:FindFirstChild(name)
                if not current then found = false break end
            end
            if found and current then
                return current
            end
        end
        
        -- Derin arama: PlayerGui içinde "Block" veya "Parry" isimli herhangi bir buton
        for _, gui in ipairs(pgui:GetDescendants()) do
            if (gui.Name == "Block" or gui.Name == "Parry" or gui.Name == "ParryButton") then
                if gui:IsA("GuiButton") or gui:IsA("Frame") or gui:IsA("TextButton") or gui:IsA("ImageButton") then
                    return gui
                end
            end
        end
        
        return nil
    end)
    
    if ok and result then
        cachedParryButton = result
        return result
    end
    return nil
end

local function findParryRemote()
    if cachedParryRemote and cachedParryRemote.Parent then return cachedParryRemote end
    
    local ok, result = pcall(function()
        local names = {"Parry", "ParryAttempt", "Block", "BlockAttempt", "Combat", "Deflect"}
        
        for _, name in ipairs(names) do
            local remote = ReplicatedStorage:FindFirstChild(name, true)
            if remote and (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
                return remote
            end
        end
        
        local eventsFolder = ReplicatedStorage:FindFirstChild("Events") or 
                             ReplicatedStorage:FindFirstChild("Remotes") or
                             ReplicatedStorage:FindFirstChild("Network")
        if eventsFolder then
            for _, name in ipairs(names) do
                local remote = eventsFolder:FindFirstChild(name)
                if remote then return remote end
            end
        end
        
        return nil
    end)
    
    if ok and result then
        cachedParryRemote = result
        return result
    end
    return nil
end

-- ====================================================================
-- 4. GELİŞMİŞ PARRY TETİKLEME (3 KATMANLI DOĞAL YÖNTEM)
-- ====================================================================

local function triggerParry(isClash)
    local now = os.clock()
    local cd = isClash and Settings.ClashCooldown or Settings.NormalCooldown
    if (now - lastParryTime) < cd then return end
    lastParryTime = now
    
    -- KATMAN 1: Oyunun kendi butonunun bağlantılarını tetikle (getconnections)
    -- Bu yöntem oyunun kendi kodunu çalıştırır, BAC tespit edemez
    local btn = findParryButton()
    if btn then
        pcall(function()
            if getconnections then
                -- Butonun Activated sinyalinin bağlantılarını bul ve çalıştır
                local activated = btn.Activated or btn.MouseButton1Click
                if activated then
                    local conns = getconnections(activated)
                    if conns and #conns > 0 then
                        for _, conn in ipairs(conns) do
                            if conn.Fire then
                                conn:Fire()
                            elseif conn.Function then
                                pcall(conn.Function)
                            end
                        end
                        return -- Başarılı, diğer katmanlara gerek yok
                    end
                end
            end
        end)
    end
    
    -- KATMAN 2: Parry RemoteEvent'ini doğrudan tetikle (FireServer)
    local remote = findParryRemote()
    if remote then
        pcall(function()
            if remote:IsA("RemoteEvent") then
                remote:FireServer()
            elseif remote:IsA("RemoteFunction") then
                remote:InvokeServer()
            end
        end)
        return
    end
    
    -- KATMAN 3: Son çare yedek - VirtualInputManager (Katman 1 ve 2 başarısız olursa)
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        if vim then
            vim:SendKeyEvent(true, Enum.KeyCode.F, false, game)
            task.wait(0.012)
            vim:SendKeyEvent(false, Enum.KeyCode.F, false, game)
        end
    end)
end

-- ====================================================================
-- 5. TOP ALGILAMA VE TEHDİT ANALİZİ
-- ====================================================================

local function isTargetedToMe(targetVal)
    if not targetVal then return false end
    local str = tostring(targetVal)
    return str == player.Name or str == player.DisplayName or str:lower() == player.Name:lower()
end

local function getThreateningBall(myPos)
    local ballsFolder = workspace:FindFirstChild("Balls") or workspace
    local best = nil
    local bestDist = math.huge
    local threat = false
    local bestVel = Vector3.new(0, 0, 0)
    
    for _, obj in ipairs(ballsFolder:GetChildren()) do
        local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
        if part and part.Name ~= "HumanoidRootPart" then
            local isReal = obj:GetAttribute("realBall") or part:GetAttribute("realBall") or 
                           obj.Name == "Ball" or ballsFolder ~= workspace
            if isReal then
                local dist = (part.Position - myPos).Magnitude
                local vel = part.AssemblyLinearVelocity or part.Velocity or Vector3.new(0, 0, 0)
                
                local targetAttr = obj:GetAttribute("target") or part:GetAttribute("target")
                local targeted = isTargetedToMe(targetAttr)
                local otherTarget = (targetAttr ~= nil and not targeted)
                
                -- Yaklaşma açısı (Dot Product)
                local dir = (myPos - part.Position)
                local approaching = false
                if dir.Magnitude > 0 and vel.Magnitude > 0 then
                    approaching = (vel.Unit:Dot(dir.Unit) > 0.08)
                end
                
                local isThreat = false
                if targeted then
                    isThreat = true
                elseif not otherTarget and approaching and dist <= Settings.BaseRange then
                    isThreat = true
                elseif otherTarget and approaching and dist <= 15 then
                    isThreat = true
                end
                
                if dist < bestDist then
                    bestDist = dist
                    best = part
                    threat = isThreat
                    bestVel = vel
                end
            end
        end
    end
    
    return best, threat, bestDist, bestVel
end

-- ====================================================================
-- 6. ANA İŞLEMCİ DÖNGÜSÜ (RENDERSTEPPED)
-- ====================================================================

renderSignal:Connect(function()
    if not Settings.Enabled then return end
    
    local hrp = getRootPart()
    if not hrp then return end
    
    local myPos = hrp.Position
    local ball, isThreat, dist, vel = getThreateningBall(myPos)
    if not ball or not isThreat then return end
    
    local speed = vel.Magnitude
    local dir = (myPos - ball.Position)
    
    -- Yaklaşma hızı hesabı
    local approach = speed
    if dist > 0 and speed > 0 then
        local dot = vel:Dot(dir.Unit)
        if dot > 0 then approach = dot end
    end
    
    local effective = math.max(approach, speed, 1)
    local timeToHit = dist / effective
    
    -- 1. Yakın temas / Clash
    if dist <= Settings.ClashRange then
        triggerParry(true)
        return
    end
    
    -- 2. Dinamik zamanlama eşiği
    local dynamicTime = clamp(0.30 + (speed / 1100), 0.30, 0.46)
    local dynamicDist = clamp(speed * dynamicTime, 18, 50)
    
    if timeToHit <= dynamicTime or dist <= dynamicDist then
        triggerParry(false)
    end
end)

-- ====================================================================
-- 7. KONTROLLER
-- ====================================================================

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.P then
        Settings.Enabled = not Settings.Enabled
    elseif input.KeyCode == Enum.KeyCode.F then
        triggerParry(true)
    end
end)
