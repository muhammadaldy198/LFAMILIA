--[[
LFAMILIA RADAR V5 - DELTA ANDROID FULL EDITION
[BAGIAN 1 DARI 10]
]]

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local HttpService = game:GetService("HttpService")
local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local CONFIG = {
    WEBHOOK_URL = "",
    FISH_DB_URL = "https://raw.githubusercontent.com/muhammadaldy198/LFAMILIA/refs/heads/main/FishDatabase.lua",
    RARITY_DB_URL = "https://raw.githubusercontent.com/muhammadaldy198/LFAMILIA/refs/heads/main/RarityDatabase.lua",
    VARIANT_DB_URL = "https://raw.githubusercontent.com/muhammadaldy198/LFAMILIA/refs/heads/main/VariantDatabase.lua",
    ALLOW_RARITY = {
        SECRET = true, FORGOTTEN = true, Mythic = true,
        Legendary = false, Epic = false, Rare = false,
        Uncommon = false, Common = false,
    },
    MIN_WEIGHT = 0,
    MENTION = "",
    WEBHOOK_USERNAME = "LFAMILIA Radar (Fish It)",
}

local mappings = {}
local state = { Running = true, Detected = 0, Sent = 0, Last = nil, Seen = {} }
local CONFIG_FILE = "LFAMILIA_Radar_Save.json"
--[[ [BAGIAN 2 DARI 10] ]]
local function getWriteFn() return writefile or (syn and syn.writefile) end
local function getReadFn()  return readfile  or (syn and syn.readfile)  end

local function saveConfig()
    local wf = getWriteFn()
    if not wf then return end
    local data = {
        CONFIG = {
            WEBHOOK_URL = CONFIG.WEBHOOK_URL,
            ALLOW_RARITY = CONFIG.ALLOW_RARITY,
            MIN_WEIGHT = CONFIG.MIN_WEIGHT,
            MENTION = CONFIG.MENTION,
            WEBHOOK_USERNAME = CONFIG.WEBHOOK_USERNAME,
        },
        mappings = mappings,
    }
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
    if ok then pcall(wf, CONFIG_FILE, encoded) end
end

local function loadConfig()
    local rf = getReadFn()
    if not rf then return end
    local ok, content = pcall(rf, CONFIG_FILE)
    if not ok or content == "" then return end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, content)
    if not ok or not data then return end
    if data.CONFIG then
        for k, v in pairs(data.CONFIG) do
            if CONFIG[k] ~= nil then
                if type(v) == "table" and type(CONFIG[k]) == "table" then
                    for k2, v2 in pairs(v) do CONFIG[k][k2] = v2 end
                else
                    CONFIG[k] = v
                end
            end
        end
    end
    if data.mappings then
        for k, v in pairs(data.mappings) do mappings[k] = v end
    end
end

loadConfig()
--[[ [BAGIAN 3 DARI 10] ]]
local function fetchLua(url)
    if not url or url == "" then return {} end
    local ok, result = pcall(function() return loadstring(game:HttpGet(url))() end)
    if ok and type(result) == "table" then return result end
    return {}
end

local FishDatabase = fetchLua(CONFIG.FISH_DB_URL)
local RarityDatabase = fetchLua(CONFIG.RARITY_DB_URL)
local VariantDatabase = fetchLua(CONFIG.VARIANT_DB_URL)

local function requestFn()
    return request or http_request or (syn and syn.request) or (fluxus and fluxus.request)
end

local function trim(s) return tostring(s or ""):gsub("^%s*(.-)%s*$", "%1") end

local function rgbInt(colors)
    if type(colors) == "table" and colors[1] then
        local c = colors[1]
        if type(c) == "table" then
            return (tonumber(c[1]) or 255) * 65536 + (tonumber(c[2]) or 255) * 256 + (tonumber(c[3]) or 255)
        end
    end
    return 0xFFFFFF
end

-- FITUR GAMBAR DIKEMBALIKAN: Mengambil asset gambar ikan asli
local function thumbnail(assetId)
    local id = tostring(assetId or ""):match("%d+")
    if not id then return nil end
    local url = "https://roblox.com" .. id .. "&size=420x420&format=Png&isCircular=false"
    local ok, response = pcall(function() return game:HttpGet(url) end)
    if not ok then return nil end
    local success, data = pcall(function() return HttpService:JSONDecode(response) end)
    if not success then return nil end
    local item = data.data and data.data[1]
    if item and item.imageUrl then return item.imageUrl end
    return nil
end
--[[ [BAGIAN 4 DARI 10] ]]
local function parseCatch(message)
    message = trim(message)
    if message == "" then return nil end
    
    -- POLA PERBAIKAN: Mendukung penulisan berat dengan huruf K (contoh: 4.53K) dan mengabaikan sisa teks di akhir
    local player, fish, weightStr, chance = message:match("([%w_]+)%s+obtained%s+a%s+(.-)%s+%(([%d%.%a]+)%s*kg%)%s+with%s+a%s+1%s+in%s+([%d%.,%s%a!]+)")
    
    if not player then
        player, fish, weightStr, chance = message:match("(.+)%s+obtained%s+a%s+(.-)%s+%(([%d%.%a]+)%s*kg%)%s+with%s+a%s+1%s+in%s+([%d%.,%s%a!]+)")
    end
    
    if player and fish then
        -- Bersihkan teks chance dari kata 'chance!' jika terbawa
        local cleanChance = trim(chance):gsub(" chance!", ""):gsub("!", "")
        
        -- Konversi satuan K jika berat ikan mencapai ribuan kilo (misal 4.53K -> 4530)
        local rawWeight = 0
        local numericPart, kIndicator = weightStr:upper():match("([%d%.]+)([K]?)")
        if numericPart then
            rawWeight = tonumber(numericPart) or 0
            if kIndicator == "K" then
                rawWeight = rawWeight * 1000
            end
        end

        return {
            Player = trim(player),
            Fish = trim(fish),
            Weight = rawWeight,
            Chance = cleanChance,
        }
    end
    return nil
end

local function resolveFish(name)
    local direct = FishDatabase[name]
    if direct then return direct, name end
    for _,v in pairs(VariantDatabase) do
        if type(v) == "table" and v.Name then
            local prefix = v.Name .. " "
            if name:sub(1, #prefix):lower() == prefix:lower() then
                local stripped = trim(name:sub(#prefix + 1))
                local item = FishDatabase[stripped]
                if item then return item, stripped, v end
            end
        end
    end
end

local function resolveVariant(name)
    for _,v in pairs(VariantDatabase) do
        if type(v) == "table" and v.Name and v.Name:lower() == tostring(name):lower() then return v end
    end
end

local function resolveRarity(fishData)
    if not fishData then return nil end
    if tonumber(fishData.Tier) then return RarityDatabase[tonumber(fishData.Tier)] end
    if fishData.Rarity then
        for _,tier in pairs(RarityDatabase) do
            if type(tier) == "table" and tostring(tier.Name):lower() == tostring(fishData.Rarity):lower() then return tier end
        end
    end
end

local function seenRecently(key)
    local now = os.clock()
    local old = state.Seen[key]
    state.Seen[key] = now
    return old and (now - old) < 5
end
--[[ [BAGIAN 5 DARI 10] ]]
local function sendWebhook(data)
    if CONFIG.WEBHOOK_URL == "" then return false end
    local req = requestFn()
    if not req then return false end

    local fishData, fishName, detectedVariant = resolveFish(data.Fish)
    local rarity = fishData and resolveRarity(fishData)
    local rarityName = rarity and rarity.Name or (fishData and tostring(fishData.Rarity) or "Unknown")

    if not CONFIG.ALLOW_RARITY[rarityName] and not CONFIG.ALLOW_RARITY[string.upper(rarityName)] then return false end
    if data.Weight < CONFIG.MIN_WEIGHT then return false end

    local variant = detectedVariant
    local variantName = variant and variant.Name or ""

    local key = data.Player .. "|" .. data.Fish .. "|" .. tostring(data.Weight)
    if seenRecently(key) then return false end

    local embed = {
        title = "✦ " .. string.upper(rarityName) .. " SERVER CATCH",
        description = "**" .. data.Player .. "** caught a **" .. data.Fish .. "**!",
        color = rarity and rgbInt(rarity.Colors) or 0xFFFFFF,
        fields = {
            { name = "👤 Player", value = "`" .. data.Player .. "`", inline = true },
            { name = "⚖ Weight", value = string.format("%.2f kg", data.Weight), inline = true },
            { name = "🎲 Chance", value = "1 in " .. tostring(data.Chance), inline = true },
        },
        footer = { text = "LFAMILIA Radar V5 • Delta Android" },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }

    -- FITUR GAMBAR DIKEMBALIKAN: Menambahkan link gambar ke embed Discord
    if fishData and fishData.AssetId then
        local imgUrl = thumbnail(fishData.AssetId)
        if imgUrl then embed.image = { url = imgUrl } end
    end

    -- FITUR MENTION DIKEMBALIKAN: Mencocokkan akun roblox dengan ID discord di database mapping
    local mappedDiscord = mappings[data.Player] or mappings[data.Player:lower()]
    local content = CONFIG.MENTION or ""
    if mappedDiscord and mappedDiscord ~= "" then
        content = (content ~= "" and (content .. " ") or "") .. "<@" .. tostring(mappedDiscord) .. ">"
    end

    local payload = { username = CONFIG.WEBHOOK_USERNAME, content = trim(content), embeds = {embed} }
    local ok = pcall(function()
        req({
            Url = CONFIG.WEBHOOK_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(payload),
        })
    end)
    if ok then state.Sent = state.Sent + 1 return true end
    return false
end

-- LOG NOTIFIKASI PLAYER CONNECT/RECONNECT KE WEBHOOK DISCORD
local function sendJoinLeaveWebhook(playerName, action)
    if CONFIG.WEBHOOK_URL == "" then return end
    local req = requestFn()
    if not req then return end
    
    local emoji = action == "JOINED" and "📥" or "📤"
    local color = action == "JOINED" and 0x55FF55 or "0xFF5555"
    
    local payload = {
        username = CONFIG.WEBHOOK_USERNAME,
        embeds = {{
            title = emoji .. " PLAYER " .. action,
            description = "Player **" .. playerName .. "** has " .. action:lower() .. " the server.",
            color = color,
            footer = { text = "LFAMILIA Server Monitor" },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }
    pcall(function()
        req({ Url = CONFIG.WEBHOOK_URL, Method = "POST", Headers = {["Content-Type"]="application/json"}, Body = HttpService:JSONEncode(payload) })
    end)
end
--[[ [BAGIAN 6 DARI 10] ]]
local gui = Instance.new("ScreenGui")
gui.Name = "LFAMILIA_Radar_V5"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
pcall(function() gui.Parent = CoreGui end)
if not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 340, 0, 320) -- Tetap diatur pas agar layout di HP rapi tidak melebar keluar batas layar
main.Position = UDim2.new(0.5, -170, 0.4, -160)
main.BackgroundColor3 = Color3.fromRGB(15,16,21)
main.BorderSizePixel = 0
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
local outline = Instance.new("UIStroke", main)
outline.Color = Color3.fromRGB(65,68,80)

local header = Instance.new("TextButton")
header.Size = UDim2.new(1, -40, 0, 40)
header.BackgroundTransparency = 1
header.Text = "✦  LFAMILIA RADAR"
header.TextColor3 = Color3.fromRGB(245,245,248)
header.TextSize = 13
header.Font = Enum.Font.GothamBold
header.TextXAlignment = Enum.TextXAlignment.Left
header.Parent = main
local hp = Instance.new("UIPadding", header)
hp.PaddingLeft = UDim.new(0, 10)

local min = Instance.new("TextButton")
min.Size = UDim2.fromOffset(35, 35)
min.Position = UDim2.new(1, -38, 0, 3)
min.BackgroundTransparency = 1
min.Text = "−"
min.TextSize = 18
min.TextColor3 = Color3.fromRGB(220,220,228)
min.Parent = main

local tabbar = Instance.new("Frame")
tabbar.Position = UDim2.new(0, 6, 1, -40)
tabbar.Size = UDim2.new(1, -12, 0, 34)
tabbar.BackgroundColor3 = Color3.fromRGB(22,24,31)
tabbar.Parent = main
Instance.new("UICorner", tabbar).CornerRadius = UDim.new(0, 6)

local pages = {} local tabs = {} local activeTab = "Home"
--[[ [BAGIAN 7 DARI 10] ]]
local function makePage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.Position = UDim2.new(0, 6, 0, 45)
    page.Size = UDim2.new(1, -12, 1, -90)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 2
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new()
    page.Visible = false
    page.Parent = main
    local layout = Instance.new("UIListLayout", page)
    layout.Padding = UDim.new(0, 5)
    pages[name] = page
    return page
end

local function card(parent, height)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, height)
    f.BackgroundColor3 = Color3.fromRGB(23,25,32)
    f.BorderSizePixel = 0
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    return f
end

local function text(parent, value, y, size, color, bold)
    local t = Instance.new("TextLabel")
    t.Position = UDim2.new(0, 8, 0, y or 6)
    t.Size = UDim2.new(1, -16, 0, 22)
    t.BackgroundTransparency = 1
    t.Text = value
    t.TextColor3 = color or Color3.fromRGB(220,221,228)
    t.TextSize = size or 11
    t.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextWrapped = true
    t.Parent = parent
    return t
end

-- PANEL HOME
local home = makePage("Home")
local homeStatus = card(home, 55)
text(homeStatus, "●  MONITOR ACTIVE", 4, 12, Color3.fromRGB(95,225,145), true)
local homeStats = text(homeStatus, "Players 0  •  Detected 0  •  Sent 0", 26, 11, Color3.fromRGB(185,188,200))

local homeLast = card(home, 85)
local homeLastText = text(homeLast, "LAST CATCH:\nWaiting for server activities...", 4, 11, Color3.fromRGB(230,231,236))
homeLastText.Size = UDim2.new(1, -16, 1, -8)

-- PANEL PLAYERS (FITUR MAPPING DAN INPUT DIKEMBALIKAN)
local playersPage = makePage("Players")
local playerInfo = card(playersPage, 45)
local playerInfoText = text(playerInfo, "PLAYER MAPPING: Map Roblox → Discord ID", 4, 11, Color3.fromRGB(190,193,204))
playerInfoText.Size = UDim2.new(1, -16, 1, -8)

local mappingBox = card(playersPage, 110)
text(mappingBox, "DISCORD MAPPINGS", 4, 10, Color3.fromRGB(150,154,170), true)
local mappingText = text(mappingBox, "No mappings added yet.", 24, 10, Color3.fromRGB(215,216,224))
mappingText.Size = UDim2.new(1, -16, 0, 45)

local addMapping = Instance.new("TextButton")
addMapping.Size = UDim2.new(0.9, 0, 0, 26)
addMapping.Position = UDim2.new(0, 15, 1, -32)
addMapping.Text = "+ ADD MAPPING"
addMapping.TextSize = 10
addMapping.Font = Enum.Font.GothamBold
addMapping.TextColor3 = Color3.fromRGB(235,237,242)
addMapping.BackgroundColor3 = Color3.fromRGB(45,48,60)
addMapping.Parent = mappingBox
Instance.new("UICorner", addMapping).CornerRadius = UDim.new(0, 5)
--[[ [BAGIAN 8 DARI 10] ]]
-- PANEL MONITOR LOG (FITUR LOG DIKEMBALIKAN SESUAI PERMINTAAN)
local monitorPage = makePage("Monitor")
local monitorCard = card(monitorPage, 160)
local monitorLog = text(monitorCard, "DETECTION LOG\n\nWaiting for catch/join events...", 4, 11, Color3.fromRGB(215,216,224))
monitorLog.Size = UDim2.new(1, -16, 1, -35)
monitorLog.TextYAlignment = Enum.TextYAlignment.Top

local clearLog = Instance.new("TextButton")
clearLog.Size = UDim2.new(0.4, 0, 0, 24)
clearLog.Position = UDim2.new(0.6, -10, 1, -28)
clearLog.Text = "🗑 CLEAR"
clearLog.TextSize = 10
clearLog.Font = Enum.Font.GothamBold
clearLog.TextColor3 = Color3.fromRGB(230,230,230)
clearLog.BackgroundColor3 = Color3.fromRGB(45,48,60)
clearLog.Parent = monitorCard
Instance.new("UICorner", clearLog).CornerRadius = UDim.new(0, 5)

-- PANEL FILTERS
local filtersPage = makePage("Filters")
local filterCard = card(filtersPage, 150)
text(filterCard, "RARITY FILTER", 4, 11, Color3.fromRGB(150,154,170), true)

local rarityOrder = {"SECRET","FORGOTTEN","Mythic","Legendary","Epic","Rare","Uncommon","Common"}
local filterButtons = {}
for i, name in ipairs(rarityOrder) do
    local b = Instance.new("TextButton")
    local row = math.floor((i-1)/2)
    local col = (i-1)%2
    b.Size = UDim2.new(0.5, -8, 0, 24)
    b.Position = UDim2.new(col*0.5, col==0 and 5 or 3, 0, 22 + row*28)
    b.BackgroundColor3 = CONFIG.ALLOW_RARITY[name] and Color3.fromRGB(42,75,57) or Color3.fromRGB(34,36,44)
    b.Text = name .. (CONFIG.ALLOW_RARITY[name] and "  ✓" or "  ×")
    b.TextColor3 = Color3.fromRGB(230,232,238)
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 9
    b.Parent = filterCard
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    
    b.Activated:Connect(function()
        CONFIG.ALLOW_RARITY[name] = not CONFIG.ALLOW_RARITY[name]
        b.BackgroundColor3 = CONFIG.ALLOW_RARITY[name] and Color3.fromRGB(42,75,57) or Color3.fromRGB(34,36,44)
        b.Text = name .. (CONFIG.ALLOW_RARITY[name] and "  ✓" or "  ×")
        saveConfig()
    end)
end
--[[ [BAGIAN 9 DARI 10] ]]
-- PANEL WEBHOOK
local webhookPage = makePage("Webhook")
local webhookCard = card(webhookPage, 140)
text(webhookCard, "DISCORD WEBHOOK URL", 4, 10, Color3.fromRGB(150,154,170), true)

local webhookInput = Instance.new("TextBox")
webhookInput.Position = UDim2.new(0, 8, 0, 22)
webhookInput.Size = UDim2.new(1, -16, 0, 30)
webhookInput.Text = CONFIG.WEBHOOK_URL
webhookInput.PlaceholderText = "Paste Discord Webhook Disini"
webhookInput.TextSize = 10
webhookInput.Font = Enum.Font.Gotham
webhookInput.TextColor3 = Color3.fromRGB(235,236,242)
webhookInput.BackgroundColor3 = Color3.fromRGB(32,34,42)
webhookInput.ClearTextOnFocus = false
webhookInput.Parent = webhookCard
Instance.new("UICorner", webhookInput).CornerRadius = UDim.new(0, 5)

local saveWebhook = Instance.new("TextButton")
saveWebhook.Position = UDim2.new(0, 8, 0, 60)
saveWebhook.Size = UDim2.new(0.45, 0, 0, 26)
saveWebhook.Text = "SIMPAN WEBHOOK"
saveWebhook.TextSize = 10
saveWebhook.Font = Enum.Font.GothamBold
saveWebhook.TextColor3 = Color3.fromRGB(235,237,242)
saveWebhook.BackgroundColor3 = Color3.fromRGB(45,48,60)
saveWebhook.Parent = webhookCard
Instance.new("UICorner", saveWebhook).CornerRadius = UDim.new(0, 5)

local testWebhook = saveWebhook:Clone()
testWebhook.Position = UDim2.new(0.55, 0, 0, 60)
testWebhook.Text = "TEST WEBHOOK"
testWebhook.Parent = webhookCard

local mentionInput = webhookInput:Clone()
mentionInput.Position = UDim2.new(0, 8, 0, 94)
mentionInput.Size = UDim2.new(1, -16, 0, 26)
mentionInput.Text = CONFIG.MENTION
mentionInput.PlaceholderText = "Mention Role (Optional: <@&RoleID>)"
mentionInput.Parent = webhookCard

-- DIALOG POPUP MAPPING (DIKEMBALIKAN UNTUK MEMUDAHKAN MAPPING USER HP)
local dialog = Instance.new("Frame")
dialog.Size = UDim2.fromOffset(260, 180)
dialog.Position = UDim2.new(0.5, -130, 0.4, -90)
dialog.BackgroundColor3 = Color3.fromRGB(20,21,27)
dialog.Visible = false
dialog.ZIndex = 20
dialog.Parent = gui
Instance.new("UICorner", dialog).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", dialog).Color = Color3.fromRGB(70,73,85)

local dt = text(dialog, "ADD PLAYER → DISCORD MAPPING", 8, 11, Color3.fromRGB(240,241,246), true)
dt.ZIndex = 21

local robloxBox = Instance.new("TextBox")
robloxBox.Position = UDim2.fromOffset(12, 36)
robloxBox.Size = UDim2.new(1, -24, 0, 28)
robloxBox.PlaceholderText = "Roblox Username"
robloxBox.TextSize = 11
robloxBox.TextColor3 = Color3.fromRGB(235,236,242)
robloxBox.BackgroundColor3 = Color3.fromRGB(32,34,42)
robloxBox.ZIndex = 21
robloxBox.Parent = dialog
Instance.new("UICorner", robloxBox).CornerRadius = UDim.new(0, 5)

local discordBox = robloxBox:Clone()
discordBox.Position = UDim2.fromOffset(12, 72)
discordBox.PlaceholderText = "Discord User ID (Angka)"
discordBox.Parent = dialog

local mapSave = Instance.new("TextButton")
mapSave.Position = UDim2.fromOffset(12, 115)
mapSave.Size = UDim2.new(0.45, 0, 0, 28)
mapSave.Text = "SAVE"
mapSave.TextSize = 10
mapSave.Font = Enum.Font.GothamBold
mapSave.TextColor3 = Color3.fromRGB(235,237,242)
mapSave.BackgroundColor3 = Color3.fromRGB(45,48,60)
mapSave.ZIndex = 21
mapSave.Parent = dialog
Instance.new("UICorner", mapSave).CornerRadius = UDim.new(0, 5)

local mapCancel = mapSave:Clone()
mapCancel.Position = UDim2.new(0.53, 0, 0, 115)
mapCancel.Text = "CANCEL"
mapCancel.Parent = dialog
--[[ [BAGIAN 10 DARI 10] ]]
local function refreshMappings()
    local lines = {}
    for roblox, discord in pairs(mappings) do lines[#lines+1] = "👤 "..roblox.." → "..discord end
    table.sort(lines)
    mappingText.Text = #lines > 0 and table.concat(lines, "\n") or "No mappings added yet."
end

addMapping.Activated:Connect(function() dialog.Visible = true end)
mapCancel.Activated:Connect(function() dialog.Visible = false end)
mapSave.Activated:Connect(function()
    local r, d = trim(robloxBox.Text), trim(discordBox.Text)
    if r ~= "" and d ~= "" then
        mappings[r] = d mappings[r:lower()] = d refreshMappings()
        robloxBox.Text = "" discordBox.Text = "" dialog.Visible = false saveConfig()
    end
end)

saveWebhook.Activated:Connect(function() CONFIG.WEBHOOK_URL = trim(webhookInput.Text) saveConfig() end)
mentionInput.FocusLost:Connect(function() CONFIG.MENTION = trim(mentionInput.Text) saveConfig() end)
clearLog.Activated:Connect(function() monitorLog.Text = "DETECTION LOG\n\nLog cleared." end)
testWebhook.Activated:Connect(function()
    if CONFIG.WEBHOOK_URL == "" then return end
    local req = requestFn() if not req then return end
    pcall(function() req({ Url = CONFIG.WEBHOOK_URL, Method = "POST", Headers = {["Content-Type"]="application/json"}, Body = HttpService:JSONEncode({ username = CONFIG.WEBHOOK_USERNAME, content = "Test Koneksi Webhook Oke! 🎣" }) }) end)
end)

local tabNames = { {"⌂", "Home"}, {"👥", "Players"}, {"◈", "Monitor"}, {"⚙", "Filters"}, {"🔔", "Webhook"} }
for i, item in ipairs(tabNames) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.2, -4, 1, -4)
    b.Position = UDim2.new((i-1)*0.2, 2, 0, 2)
    b.BackgroundTransparency = 1 b.Text = item[1] .. "\n" .. item[2] b.TextSize = 8 b.Font = Enum.Font.GothamSemibold b.TextColor3 = Color3.fromRGB(135,138,150) b.Parent = tabbar tabs[item[2]] = b Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    b.Activated:Connect(function()
        activeTab = item[2]
        for n, p in pairs(pages) do p.Visible = (n == activeTab) end
        for n, t in pairs(tabs) do t.TextColor3 = (n == activeTab) and Color3.fromRGB(235,237,242) or Color3.fromRGB(135,138,150) end
    end)
end
pages.Home.Visible = true tabs.Home.TextColor3 = Color3.fromRGB(235,237,242)

local minimized = false
min.Activated:Connect(function()
    minimized = not minimized tabbar.Visible = not minimized
    for _, p in pairs(pages) do p.Visible = not minimized and (_ == activeTab) or false end
    main.Size = minimized and UDim2.fromOffset(180, 40) or UDim2.fromOffset(340, 320)
    min.Text = minimized and "+" or "−"
end)

local dragging, dragInput, dragStart, startPos
header.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true dragInput = input dragStart = input.Position startPos = main.Position end end)
UIS.InputChanged:Connect(function(input) if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then local delta = input.Position - dragStart main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end end)
UIS.InputEnded:Connect(function(input) if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)

local function updateUI(data, lineInfo)
    state.Detected = state.Detected + 1
    homeLastText.Text = "LAST CATCH:\n" .. lineInfo
    local current = monitorLog.Text
    monitorLog.Text = "DETECTION LOG\n\n["..os.date("%X").."] "..lineInfo:gsub("\n", " | ").."\n\n"..current:sub(18)
    homeStats.Text = string.format("Players %d  •  Detected %d  •  Sent %d", #Players:GetPlayers(), state.Detected, state.Sent)
end

local function handleMessage(text)
    local data = parseCatch(text)
    if not data then return end
    local lineInfo = string.format("👤 %s caught %s (%s kg) [1 in %s]", data.Player, data.Fish, tostring(data.Weight), tostring(data.Chance))
    updateUI(data, lineInfo)
    sendWebhook(data)
end

if TextChatService.MessageReceived then TextChatService.MessageReceived:Connect(function(msg) if msg and msg.Text then handleMessage(msg.Text) end end) end

-- EVENT DETEKSI PLAYER MASUK/KELUAR SERVER (CONNECT/RECONNECT LOGS)
Players.PlayerAdded:Connect(function(player)
    local logLine = "📥 Player Masuk: " .. player.Name
    monitorLog.Text = "DETECTION LOG\n\n["..os.date("%X").."] " .. logLine .. "\n\n" .. monitorLog.Text:sub(18)
    sendJoinLeaveWebhook(player.Name, "JOINED")
end)

Players.PlayerRemoving:Connect(function(player)
    local logLine = "📤 Player Keluar: " .. player.Name
    monitorLog.Text = "DETECTION LOG\n\n["..os.date("%X").."] " .. logLine .. "\n\n" .. monitorLog.Text:sub(18)
    sendJoinLeaveWebhook(player.Name, "LEFT")
end)

refreshMappings()
print("[LFAMILIA Android Full Edition] Berhasil Dimuat Lengkap!")
