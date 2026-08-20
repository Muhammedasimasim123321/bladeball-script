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

if not isBladeBall() then return end

local SCRIPT_URL = "https://raw.githubusercontent.com/Muhammedasimasim123321/bladeball-script/main/bladeball.lua"

local success, result = pcall(function()
    return game:HttpGet(SCRIPT_URL)
end)

if success and result and #result > 0 then
    local chunk = load_string(result)
    if chunk then pcall(chunk) end
end