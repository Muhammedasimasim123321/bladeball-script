-- loader.lua
-- ⚔️ Blade Ball Ultimate Loader (v13.0)

local load_string = loadstring or load

repeat task.wait() until game:IsLoaded()

local BLADE_BALL_UNIVERSE_ID = 4777817887
local BLADE_BALL_IDS = {
    13772394625, 14368557094, 14732610803, 14915220621,
    15131065025, 15144787112, 15185247558, 15234596844,
    15264892126, 15509350986, 15517169103, 15552588346,
    15582821022, 15582823307, 16044264830, 16281300371,
    16331595046, 16331596518, 16331598816, 16331600459,
    16456370330, 16581637217, 16581648071, 17757592456,
    92458008626219, 111661204337143
}

local function isBladeBall()
    if game.GameId == BLADE_BALL_UNIVERSE_ID then return true end
    local pid = game.PlaceId
    for _, id in ipairs(BLADE_BALL_IDS) do
        if pid == id then return true end
    end
    return false
end

if not isBladeBall() then 
    print("❌ Bu script sadece Blade Ball oyununda çalışır!")
    return 
end

-- DOĞRUDAN SCRİPT (loader olmadan çalıştır)
local scriptContent = [[
-- bladeball.lua (gömülü)
-- ⚔️ Blade Ball Ultimate v6.0

repeat task.wait() until game:IsLoaded()
task.wait(3)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer

local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")

local Settings = {
    AutoParry = true,
    ParryRange = 35,
    ParryCooldown = 0.3,
    DebugMode = false,
}

local State = {
    parryCooldown = false,
    lastParryTime = 0,
    parryCount = 0,
}

local function notify(text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "⚔️ Blade Ball",
            Text = tostring(text),
            Duration = 2
        })
    end)
end

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

local function doParry()
    if State.parryCooldown then return end
    
    local now = tick()
    if now - State.lastParryTime < Settings.ParryCooldown then return end
    
    State.parryCooldown = true
    State.parryCount = State.parryCount + 1
    
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
    end)
    
    State.lastParryTime = tick()
    task.wait(Settings.ParryCooldown)
    State.parryCooldown = false
end

RunService.Heartbeat:Connect(function()
    if not Settings.AutoParry then return end
    
    if not character or not character.Parent then
        character = player.Character or player.CharacterAdded:Wait()
        humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
        return
    end
    
    if not humanoidRootPart then return end
    
    local ball = findBall()
    if not ball then return end
    
    local distance = (ball.Position - humanoidRootPart.Position).Magnitude
    
    if distance < Settings.ParryRange then
        doParry()
    end
end)

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

print("╔═══════════════════════════════════════╗")
print("║   ⚔️ BLADE BALL ULTIMATE v6.0        ║")
print("║   Auto Parry AKTİF!                  ║")
print("╠═══════════════════════════════════════╣")
print("║   P = Auto Parry Aç/Kapat           ║")
print("║   F = Manuel Parry                  ║")
print("║   D = Debug Modu Aç/Kapat           ║")
print("╚═══════════════════════════════════════╝")

notify("✅ Script yüklendi! Auto Parry AÇIK!")
]]

-- Scripti çalıştır
local chunk = load_string(scriptContent)
if chunk then 
    pcall(chunk)
    print("✅ Blade Ball script çalıştırıldı!")
else
    print("❌ Script yüklenirken hata oluştu!")
end