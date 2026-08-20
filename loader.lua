-- loader.lua
repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Blade Ball Place ID'leri
local bladeBallIDs = {
    13772394625, 14368557094, 14732610803, 14915220621,
    15131065025, 15144787112, 15185247558, 15234596844,
    15264892126, 15509350986, 15517169103, 15552588346,
    15582821022, 15582823307, 16044264830, 16281300371,
    16331595046, 16331596518, 16331598816, 16331600459,
    16456370330, 16581637217, 16581648071, 17757592456,
    92458008626219, 111661204337143
}

local isBladeBall = false
for _, id in pairs(bladeBallIDs) do
    if game.PlaceId == id then
        isBladeBall = true
        break
    end
end

if not isBladeBall then
    game.StarterGui:SetCore("SendNotification", {
        Title = "❌ Hata",
        Text = "Bu oyun Blade Ball değil!",
        Duration = 3
    })
    return
end

-- Ana scripti yükle
local scriptUrl = "https://raw.githubusercontent.com/Muhammedasimasim123321/bladeball-script/main/bladeball.lua"
local success, result = pcall(function()
    return game:HttpGet(scriptUrl)
end)

if success and result then
    local chunk = loadstring(result)
    if chunk then
        chunk()
    else
        warn("Script derleme hatası!")
    end
else
    warn("Bağlantı hatası!")
end