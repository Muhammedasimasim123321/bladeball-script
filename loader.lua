-- loader.lua
-- ⚔️ Blade Ball Ultimate Loader v5.1

local load_string = loadstring or load

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer

local function sendLoaderNotify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title or "Blade Ball Loader",
            Text = tostring(text or ""),
            Duration = duration or 3
        })
    end)
end

-- Blade Ball Universe ID (Tüm harita, ranked, 1v1 ve etkinlik modlarını kapsar)
local BLADE_BALL_UNIVERSE_ID = 4777817887

-- Blade Ball Bilinen Place ID'leri (Yedek doğrulama)
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
    -- 1. Universe ID kontrolü
    if game.GameId == BLADE_BALL_UNIVERSE_ID then
        return true
    end
    
    -- 2. Place ID yedek kontrolü
    local pid = game.PlaceId
    for _, id in ipairs(BLADE_BALL_IDS) do
        if pid == id then return true end
    end
    return false
end

if not isBladeBall() then
    warn("[Loader] Bu oyun Blade Ball değil! (GameId: " .. tostring(game.GameId) .. ", PlaceId: " .. tostring(game.PlaceId) .. ")")
    return
end

local SCRIPT_URL = "https://raw.githubusercontent.com/Muhammedasimasim123321/bladeball-script/main/bladeball.lua"

local success, result = pcall(function()
    return game:HttpGet(SCRIPT_URL)
end)

if success and result and #result > 0 then
    local chunk, loadErr = load_string(result)
    if chunk then
        local runSuccess, runErr = pcall(chunk)
        if not runSuccess then
            warn("[Loader] Script çalışırken hata oluştu: " .. tostring(runErr))
            sendLoaderNotify("❌ Yükleme Hatası", "Script başlatılamadı: " .. tostring(runErr), 5)
        end
    else
        warn("[Loader] Kod derleme hatası: " .. tostring(loadErr))
        sendLoaderNotify("❌ Derleme Hatası", "loadstring başarısız oldu!", 5)
    end
else
    warn("[Loader] Script indirilemedi! Lütfen internet bağlantısını veya URL'yi kontrol edin.")
    sendLoaderNotify("❌ Bağlantı Hatası", "Script indirilemedi!", 5)
end