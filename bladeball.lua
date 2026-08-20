-- bladeball.lua
-- ⚔️ Blade Ball Auto Parry (Keysiz)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- ⚙️ AYARLAR
local Settings = {
    AutoParry = false,
    ParryRange = 35,
    Cooldown = 0.3
}

local state = {
    parryCooldown = false
}

-- 📌 TOP BUL
local function findBall()
    for _, v in pairs(workspace:GetChildren()) do
        if v.Name == "Ball" or string.find(v.Name, "Ball") then
            if v:FindFirstChild("Handle") then
                return v
            end
        end
    end
    return nil
end

-- 📌 PARRY
local function doParry()
    if state.parryCooldown then return end
    state.parryCooldown = true
    VirtualInputManager:SendKeyEvent(true, "F", false, game)
    task.wait(0.05)
    VirtualInputManager:SendKeyEvent(false, "F", false, game)
    task.wait(Settings.Cooldown)
    state.parryCooldown = false
end

-- 📌 BİLDİRİM
local function notify(text)
    game.StarterGui:SetCore("SendNotification", {
        Title = "⚔️ Blade Ball",
        Text = text,
        Duration = 2
    })
end

-- 📌 ANA DÖNGÜ
RunService.Heartbeat:Connect(function()
    local ball = findBall()
    if not ball then return end
    local distance = (ball.Position - humanoidRootPart.Position).Magnitude
    if Settings.AutoParry and distance < Settings.ParryRange then
        doParry()
    end
end)

-- 📌 TUŞ KONTROLÜ
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.P then
        Settings.AutoParry = not Settings.AutoParry
        notify("Auto Parry: " .. tostring(Settings.AutoParry))
    end
end)

print("✅ Blade Ball Script Yüklendi!")
notify("✅ P tuşu ile başlat!")