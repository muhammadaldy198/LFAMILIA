-- =============================================================================
-- BAGIAN 1 : HEADER, KONFIGURASI DASAR, DAN LAYANAN ROBLOX
-- =============================================================================
-- FUNGSI: Mendapatkan service, mendeklarasikan CONFIG, dan state global.
-- =============================================================================

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local HttpService = game:GetService("HttpService")
local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local CONFIG = {
    WEBHOOK_URL = "",
    JOIN_LEAVE_URL = "", -- TERPISAH: URL khusus untuk log masuk dan keluar pemain
    FISH_DB_URL = "https://raw.githubusercontent.com/muhammadaldy198/LFAMILIA/refs/heads/main/FishDatabase.lua",
    RARITY_DB_URL = "https://raw.githubusercontent.com/muhammadaldy198/LFAMILIA/refs/heads/main/RarityDatabase.lua",
    VARIANT_DB_URL = "https://raw.githubusercontent.com/muhammadaldy198/LFAMILIA/refs/heads/main/VariantDatabase.lua",
    ALLOW_RARITY = {
        SECRET = true, FORGOTTEN = true, Mythic = true,
        Legendary = true, Epic = true, Rare = true,
        Uncommon = true, Common = true,
    },
    MIN_WEIGHT = 0,
    MENTION = "", -- Berisi ID Role atau ID User murni
    WEBHOOK_USERNAME = "LFAMILIA Radar (Fish It)",
}

local mappings = {}
local state = { Running = true, Detected = 0, Sent = 0, Last = nil, Seen = {} }
local CONFIG_FILE_1 = "LFAMILIA_Slot1.json"
local CONFIG_FILE_2 = "LFAMILIA_Slot2.json"
local CONFIG_FILE_3 = "LFAMILIA_Slot3.json"
-- =============================================================================
-- BAGIAN 2 : MANUAL DATA STORAGE ENGINE (SLOT BASED)
-- =============================================================================
-- FUNGSI: Menyimpan dan memuat konfigurasi serta mapping ke file JSON.
-- =============================================================================

local function getWriteFn() return writefile or (syn and syn.writefile) end
local function getReadFn()  return readfile  or (syn and syn.readfile)  end

local function dapatkanNamaFile(slot)
    if slot == 2 then return CONFIG_FILE_2
    elseif slot == 3 then return CONFIG_FILE_3
    else return CONFIG_FILE_1 end
end

local function manualSave(slot)
    local wf = getWriteFn()
    if not wf then return false, "Executor tidak mendukung file" end
    local namaFile = dapatkanNamaFile(slot)
    local data = {
        CONFIG = {
            WEBHOOK_URL = CONFIG.WEBHOOK_URL,
            JOIN_LEAVE_URL = CONFIG.JOIN_LEAVE_URL,
            ALLOW_RARITY = CONFIG.ALLOW_RARITY,
            MIN_WEIGHT = CONFIG.MIN_WEIGHT,
            MENTION = CONFIG.MENTION,
            WEBHOOK_USERNAME = CONFIG.WEBHOOK_USERNAME,
        },
        mappings = mappings,
    }
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
    if ok then 
        local ok2, err = pcall(wf, namaFile, encoded)
        return ok2, err or "Sukses"
    end
    return false, "Gagal enkripsi data"
end

local function manualLoad(slot)
    local rf = getReadFn()
    if not rf then return false, "Executor tidak mendukung file" end
    local namaFile = dapatkanNamaFile(slot)
    local ok, content = pcall(rf, namaFile)
    if not ok or content == "" then return false, "File slot kosong atau tidak ditemukan" end
    local ok2, data = pcall(HttpService.JSONDecode, HttpService, content)
    if not ok2 or not data then return false, "Gagal membaca format JSON" end
    
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
        table.clear(mappings)
        for k, v in pairs(data.mappings) do mappings[k] = v end
    end
    return true, "Sukses memuat data"
end
-- =============================================================================
-- BAGIAN 3 : DATABASE PARSER, UTILITIES, & THUMBNAIL (FIX)
-- =============================================================================
-- FUNGSI: Mengunduh database dari GitHub, konversi warna, dan thumbnail.
-- =============================================================================

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
    if type(colors) == "table" and colors then
        local c = colors
        if type(c) == "table" then
            return (tonumber(c[1]) or 255) * 65536 + (tonumber(c[2]) or 255) * 256 + (tonumber(c[3]) or 255)
        end
    end
    return 0xFFFFFF
end

-- [PERBAIKAN] Fungsi thumbnail menggunakan endpoint assetdelivery.roblox.com
-- =============================================================================
-- [FINAL] Thumbnail menggunakan API Roblox via proxy (PASTI BISA)
-- =============================================================================
local function thumbnail(assetId)
    local id = tostring(assetId or ""):match("%d+")
    if not id then return nil end

    -- Gunakan proxy untuk mendapatkan URL gambar yang valid
    local proxyUrl = "https://thumbnails.roproxy.com/v1/assets?assetIds=" .. id .. "&size=420x420&format=png"
    
    local req = requestFn()
    if not req then return nil end

    local success, response = pcall(function()
        return req({
            Url = proxyUrl,
            Method = "GET",
        })
    end)

    if success and response and response.Body then
        local decoded = HttpService:JSONDecode(response.Body)
        if decoded and decoded.data and decoded.data[1] and decoded.data[1].imageUrl then
            -- Kirim URL gambar yang sudah valid
            return decoded.data[1].imageUrl
        end
    end

    -- Fallback: jika proxy gagal, coba assetdelivery (mungkin berhasil)
    return "https://assetdelivery.roblox.com/v1/asset?id=" .. id
end
-- =============================================================================
-- BAGIAN 4 : TEXT PARSER & FISH IDENTIFICATION LOGIC
-- =============================================================================
-- FUNGSI: Membaca string chat server dan mencocokkan parsial nama ikan ke database.
-- =============================================================================

local function parseCatch(message)
    message = trim(message)
    if message == "" then return nil end
    
    local player, fish, weightStr, chance = message:match("([%w_]+)%s+obtained%s+a%s+(.-)%s+%(([%d%.%a]+)%s*kg%)%s+with%s+a%s+1%s+in%s+([%d%.,%s%a!]+)")
    if not player then
        player, fish, weightStr, chance = message:match("(.+)%s+obtained%s+a%s+(.-)%s+%(([%d%.%a]+)%s*kg%)%s+with%s+a%s+1%s+in%s+([%d%.,%s%a!]+)")
    end
    
    if player and fish then
        local cleanFish = trim(fish)
        local r, g, b = nil, nil, nil
        
        -- =====================================================
        -- EKSTRAK WARNA DARI RichText
        -- =====================================================
        local colorHex, fishName = cleanFish:match('<font color="([^"]+)">(.-)</font>')
        if colorHex and fishName then
            local hex = colorHex:gsub("#", "")
            r = tonumber(hex:sub(1,2), 16)
            g = tonumber(hex:sub(3,4), 16)
            b = tonumber(hex:sub(5,6), 16)
            cleanFish = trim(fishName)
        else
            local cr, cg, cb, fishName = cleanFish:match('<font color="rgb%((%d+),%s*(%d+),%s*(%d+)%)">(.-)</font>')
            if cr and cg and cb and fishName then
                r, g, b = tonumber(cr), tonumber(cg), tonumber(cb)
                cleanFish = trim(fishName)
            end
        end
        
        -- Parsing Berat
        local rawWeight = 0
        local numericPart, kIndicator = weightStr:upper():match("([%d%.]+)([K]?)")
        if numericPart then
            rawWeight = tonumber(numericPart) or 0
            if kIndicator == "K" then rawWeight = rawWeight * 1000 end
        end

        return {
            Player = trim(player),
            Fish = cleanFish,                     -- Nama ikan bersih (tanpa tag HTML)
            Weight = rawWeight,
            Chance = trim(chance):gsub(" chance!", ""):gsub("!", ""),
            RawFish = trim(fish),                 -- (opsional untuk debug)
            RarityColor = (r and g and b) and {r, g, b} or nil,  -- <-- SIMPAN RGB
        }
    end
    return nil
end

local function resolveFish(name)
    local nameLower = name:lower()
    for realName, data in pairs(FishDatabase) do
        if realName:lower() == nameLower then return data, realName, nil end
    end
    for _, v in pairs(VariantDatabase) do
        if type(v) == "table" and v.Name then
            local prefix = v.Name:lower() .. " "
            if nameLower:sub(1, #prefix) == prefix then
                local stripped = trim(name:sub(#prefix + 1))
                for realName, data in pairs(FishDatabase) do
                    if realName:lower() == stripped:lower() or realName:lower():find(stripped:lower()) then
                        return data, realName, v
                    end
                end
            end
        end
    end
    return nil, name, nil
end

local function resolveRarity(fishData)
    if not fishData then return nil end
    if tonumber(fishData.Id) and RarityDatabase[tonumber(fishData.Id)] then 
        return RarityDatabase[tonumber(fishData.Id)] 
    end
    if fishData.Rarity then
        for _, tier in pairs(RarityDatabase) do
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
-- =============================================================================
-- BAGIAN 5 : WEBHOOK EMITTER & ERROR LOGGING (FIX)
-- =============================================================================
-- FUNGSI: Mengirim data tangkapan dan log join/leave. Ditambahkan log error ke UI.
-- =============================================================================

-- Variabel referensi ke UI (akan diisi nanti saat GUI dibuat)
local monitorLog = nil

-- Fungsi untuk mencatat error ke tab Monitor
local function logError(errMsg)
    if not monitorLog then return end
    local current = monitorLog.Text
    local time = os.date("%X")
    local lines = {}
    for line in (current:sub(18) or ""):gmatch("[^\n]*\n?") do
        table.insert(lines, line)
    end
    while #lines > 20 do table.remove(lines, 1) end
    local newLog = "DETECTION LOG\n\n["..time.."] ❌ ERROR: " .. errMsg .. "\n" .. table.concat(lines)
    monitorLog.Text = newLog
end
-- =============================================================================
-- [TAMBAHAN] Mencari rarity berdasarkan warna RGB (dari chat)
-- =============================================================================
local function resolveRarityByColor(r, g, b)
    if not r or not g or not b then return nil end
    
    for _, tier in pairs(RarityDatabase) do
        if tier.Colors then
            for _, color in ipairs(tier.Colors) do
                if type(color) == "table" then
                    local cr, cg, cb = color[1], color[2], color[3]
                    -- Toleransi ±5 karena server kadang beda tipis
                    if math.abs(cr - r) <= 5 and math.abs(cg - g) <= 5 and math.abs(cb - b) <= 5 then
                        return tier
                    end
                end
            end
        end
    end
    return nil
end

local function sendWebhook(data)
    if CONFIG.WEBHOOK_URL == "" then 
        logError("Webhook URL kosong")
        return false 
    end

    local req = requestFn()
    if not req then 
        logError("Tidak ada fungsi request di executor")
        return false 
    end

    -- PRIORITAS 1: Rarity dari WARNA CHAT
    local rarity = nil
    local rarityName = "Legendary"
    local embedColor = 0xFFFFFF
    
    if data.RarityColor then
        local r, g, b = data.RarityColor[1], data.RarityColor[2], data.RarityColor[3]
        rarity = resolveRarityByColor(r, g, b)
        if rarity then
            rarityName = rarity.Name
            embedColor = r * 65536 + g * 256 + b
        end
    end
    
    -- PRIORITAS 2: Fallback ke FishDatabase (jika warna tidak ditemukan)
    if not rarity then
        local fishData = resolveFish(data.Fish)
        rarity = resolveRarity(fishData)
        if rarity then 
            rarityName = rarity.Name 
        else
            -- Jika ikan tidak dikenal, catat log dan batalkan
            logError("⚠️ Ikan tidak dikenal: " .. data.Fish .. " (tidak dikirim)")
            return false
        end
    end

    -- FILTER kelangkaan
    if not CONFIG.ALLOW_RARITY[rarityName] and not CONFIG.ALLOW_RARITY[string.upper(rarityName)] then 
        return false 
    end
    if data.Weight < CONFIG.MIN_WEIGHT then return false end

    local key = data.Player .. "|" .. data.Fish .. "|" .. tostring(data.Weight)
    if seenRecently(key) then return false end

    -- Ambil asset ID untuk thumbnail
    local fishData = resolveFish(data.Fish)
    local assetId = nil
    if fishData and fishData.AssetId then
        assetId = tostring(fishData.AssetId):match("%d+")
    end

    -- Ambil varian (jika ada)
    local variant = nil
    if data.RawFish then
        for _, v in pairs(VariantDatabase) do
            if type(v) == "table" and v.Name then
                local prefix = v.Name:lower() .. " "
                if data.RawFish:lower():sub(1, #prefix) == prefix then
                    variant = v.Name
                    break
                end
            end
        end
    end

    -- Server ID dan waktu
    local server_id = game.JobId or ""
    local time_str = os.date("%H:%M WIB")

    -- Mention
    local mention = ""
    local rawMention = trim(CONFIG.MENTION)
    if rawMention ~= "" then
        if tonumber(rawMention) then
            mention = "<@&" .. rawMention .. ">"
        else
            mention = rawMention
        end
    end
    local mappedDiscord = mappings[data.Player] or mappings[data.Player:lower()]
    if mappedDiscord and mappedDiscord ~= "" then
        mention = (mention ~= "" and (mention .. " ") or "") .. "<@" .. tostring(mappedDiscord) .. ">"
    end

    -- Payload untuk server PythonAnywhere
    local payload = {
        discord_url = CONFIG.WEBHOOK_URL,   -- URL Discord tetap dari UI
        player = data.Player,
        fish = data.Fish,
        weight = data.Weight,
        chance = data.Chance,
        rarity = rarityName,
        color = embedColor,
        asset_id = assetId,
        variant = variant,
        server_id = server_id,
        time = time_str,
        mention = mention
    }

    -- Kirim ke SERVER (bukan langsung ke Discord)
    local server_url = "https://Aldayyy.pythonanywhere.com/api/catch"  -- <-- GANTI dengan URL-mu
    local ok, err = pcall(function()
        req({
            Url = server_url,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(payload),
        })
    end)

    if ok then 
        state.Sent = state.Sent + 1 
        return true 
    else
        logError("Gagal kirim ke server: " .. tostring(err))
        return false
    end
end

local function sendJoinLeaveWebhook(playerName, action)
    -- =====================================================
    -- [PERUBAHAN] TIDAK ADA FALLBACK KE WEBHOOK UTAMA
    -- Hanya kirim jika JOIN_LEAVE_URL diisi.
    -- =====================================================
    if CONFIG.JOIN_LEAVE_URL == "" then return end
    
    local req = requestFn()
    if not req then 
        logError("Tidak ada fungsi request untuk join/leave")
        return 
    end
    
    local emoji = action == "JOINED" and "📥" or "📤"
    local color = action == "JOINED" and 0x2ECC71 or 0xE74C3C
    
    local payload = {
        username = CONFIG.WEBHOOK_USERNAME .. " [Server Logs]",
        embeds = {{
            title = emoji .. " PLAYER " .. action,
            description = "Pemain **" .. playerName .. "** telah " .. action:lower() .. " server.",
            color = color,
            footer = { text = "LFAMILIA Server Logs Channel" },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }
    local ok, err = pcall(function() 
        req({ 
            Url = CONFIG.JOIN_LEAVE_URL,  -- LANGSUNG PAKAI URL INI, TANPA FALLBACK
            Method = "POST", 
            Headers = {["Content-Type"]="application/json"}, 
            Body = HttpService:JSONEncode(payload) 
        }) 
    end)
    if not ok then
        logError("Webhook join/leave gagal: " .. tostring(err))
    end
end
-- =============================================================================
-- BAGIAN 6 : GUI – LAYOUT DASAR (FRAME, HEADER, MINIMIZE)
-- =============================================================================
-- FUNGSI: Membuat ScreenGui, Frame utama, header, dan tombol minimize.
-- =============================================================================

local gui = Instance.new("ScreenGui")
gui.Name = "LFAMILIA_Radar_V5"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
pcall(function() gui.Parent = CoreGui end)
if not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(340, 320)
main.Position = UDim2.new(0.5, -170, 0.4, -160)
main.BackgroundColor3 = Color3.fromRGB(10,11,14)
main.BorderSizePixel = 0
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
local outline = Instance.new("UIStroke", main)
outline.Color = Color3.fromRGB(30,32,40)
outline.Thickness = 1.5

local header = Instance.new("TextButton")
header.Size = UDim2.new(1, -40, 0, 40)
header.BackgroundTransparency = 1
header.Text = "  ✦  LFAMILIA RADAR  •  V5"
header.TextColor3 = Color3.fromRGB(255,255,255)
header.TextSize = 12
header.Font = Enum.Font.GothamBold
header.TextXAlignment = Enum.TextXAlignment.Left
header.Parent = main

local min = Instance.new("TextButton")
min.Size = UDim2.fromOffset(35, 35)
min.Position = UDim2.new(1, -38, 0, 3)
min.BackgroundTransparency = 1
min.Text = "−"
min.TextSize = 16
min.TextColor3 = Color3.fromRGB(150,155,170)
min.Parent = main

local tabbar = Instance.new("Frame")
tabbar.Position = UDim2.new(0, 8, 1, -42)
tabbar.Size = UDim2.new(1, -16, 0, 34)
tabbar.BackgroundColor3 = Color3.fromRGB(16,18,23)
tabbar.Parent = main
Instance.new("UICorner", tabbar).CornerRadius = UDim.new(0, 8)

local pages = {} 
local tabs = {} 
local activeTab = "Home"
-- =============================================================================
-- BAGIAN 7 : GUI – HALAMAN HOME & STORAGE (SLOT SAVE/LOAD)
-- =============================================================================
-- FUNGSI: Membuat halaman Home, statistik, dan panel save/load manual.
-- =============================================================================

local function makePage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.Position = UDim2.new(0, 8, 0, 45)
    page.Size = UDim2.new(1, -16, 1, -95)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 0
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new()
    page.Visible = false
    page.Parent = main
    local layout = Instance.new("UIListLayout", page)
    layout.Padding = UDim.new(0, 6)
    pages[name] = page
    return page
end

local function card(parent, height)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, height)
    f.BackgroundColor3 = Color3.fromRGB(18,20,26)
    f.BorderSizePixel = 0
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
    local s = Instance.new("UIStroke", f)
    s.Color = Color3.fromRGB(26,28,36)
    return f
end

local function text(parent, value, y, size, color, bold)
    local t = Instance.new("TextLabel")
    t.Position = UDim2.new(0, 10, 0, y or 6)
    t.Size = UDim2.new(1, -20, 0, 22)
    t.BackgroundTransparency = 1
    t.Text = value
    t.TextColor3 = color or Color3.fromRGB(200,205,220)
    t.TextSize = size or 11
    t.Font = bold and Enum.Font.GothamBold or Enum.Font.GothamMedium
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextWrapped = true
    t.Parent = parent
    return t
end

-- Halaman Home
local home = makePage("Home")
local homeStatus = card(home, 55)
text(homeStatus, "●  MONITOR ACTIVE", 5, 12, Color3.fromRGB(46,204,113), true)
local homeStats = text(homeStatus, "Players 0  •  Detected 0  •  Sent 0", 26, 11, Color3.fromRGB(140,145,160))

-- Panel Storage (Save/Load 3 Slot)
local storageCard = card(home, 75)
text(storageCard, "💽 PROFILE DATA MANAGEMENT (MANUAL ONLY)", 4, 10, Color3.fromRGB(52,152,219), true)

local activeSlot = 1
local slotBtn = Instance.new("TextButton")
slotBtn.Size = UDim2.new(0.3, 0, 0, 26)
slotBtn.Position = UDim2.new(0, 10, 0, 24)
slotBtn.Text = "📁 SLOT: [ 1 ] ▼"
slotBtn.TextSize = 10
slotBtn.Font = Enum.Font.GothamBold
slotBtn.BackgroundColor3 = Color3.fromRGB(30,34,45)
slotBtn.TextColor3 = Color3.fromRGB(255,255,255)
slotBtn.Parent = storageCard
Instance.new("UICorner", slotBtn).CornerRadius = UDim.new(0, 5)

local saveBtn = Instance.new("TextButton")
saveBtn.Size = UDim2.new(0.3, -4, 0, 26)
saveBtn.Position = UDim2.new(0.32, 4, 0, 24)
saveBtn.Text = "💾 SAVE"
saveBtn.TextSize = 10
saveBtn.Font = Enum.Font.GothamBold
saveBtn.BackgroundColor3 = Color3.fromRGB(46,204,113)
saveBtn.TextColor3 = Color3.fromRGB(255,255,255)
saveBtn.Parent = storageCard
Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0, 5)

local loadBtn = saveBtn:Clone()
loadBtn.Position = UDim2.new(0.64, 4, 0, 24)
loadBtn.Text = "📂 LOAD"
loadBtn.BackgroundColor3 = Color3.fromRGB(230,126,34)
loadBtn.Parent = storageCard

local storageMsg = text(storageCard, "Pilih nomor slot lalu klik tombol Save atau Load.", 53, 9, Color3.fromRGB(130,135,150))

slotBtn.Activated:Connect(function()
    activeSlot = activeSlot + 1
    if activeSlot > 3 then activeSlot = 1 end
    slotBtn.Text = "📁 SLOT: [ " .. tostring(activeSlot) .. " ] ▼"
end)
saveBtn.Activated:Connect(function()
    local ok, msg = manualSave(activeSlot)
    storageMsg.Text = ok and "✅ Berhasil menyimpan pengaturan ke Slot " .. activeSlot or "❌ Gagal: " .. msg
end)
loadBtn.Activated:Connect(function()
    local ok, msg = manualLoad(activeSlot)
    storageMsg.Text = ok and "✅ Berhasil memuat seluruh data dari Slot " .. activeSlot or "❌ Gagal: " .. msg
end)

-- Panel Last Activity
local homeLast = card(home, 70)
local homeLastText = text(homeLast, "📋 LAST ACTIVITY:\nWaiting for server catches...", 6, 11, Color3.fromRGB(220,225,235))
homeLastText.Size = UDim2.new(1, -20, 1, -12)
-- =============================================================================
-- BAGIAN 8 : GUI – HALAMAN PLAYERS (MAPPING), MONITOR, FILTERS, WEBHOOK
-- =============================================================================
-- FUNGSI: Membuat halaman mapping, monitor log, filter rarity, dan webhook.
-- =============================================================================

-- Halaman Players (Mapping)
local playersPage = makePage("Players")
local playerInfo = card(playersPage, 45)
local playerInfoText = text(playerInfo, "🔗 MAPPING: Hubungkan Roblox ke ID Discord", 4, 11, Color3.fromRGB(160,165,180))
playerInfoText.Size = UDim2.new(1, -16, 1, -8)

local mappingBox = card(playersPage, 110)
text(mappingBox, "DAFTAR MAPPING SAAT INI", 4, 10, Color3.fromRGB(110,115,130), true)
local mappingText = text(mappingBox, "Belum ada user yang di-mapping.", 24, 10, Color3.fromRGB(180,185,200))
mappingText.Size = UDim2.new(1, -20, 0, 45)

local addMapping = Instance.new("TextButton")
addMapping.Size = UDim2.new(1, -20, 0, 28)
addMapping.Position = UDim2.new(0, 10, 1, -34)
addMapping.Text = "+ HUBUNGKAN AKUN PLAYER"
addMapping.TextSize = 10
addMapping.Font = Enum.Font.GothamBold
addMapping.TextColor3 = Color3.fromRGB(255,255,255)
addMapping.BackgroundColor3 = Color3.fromRGB(35,38,50)
addMapping.Parent = mappingBox
Instance.new("UICorner", addMapping).CornerRadius = UDim.new(0, 6)

-- Halaman Monitor (dengan error logging)
local monitorPage = makePage("Monitor")
local monitorCard = card(monitorPage, 160)
monitorLog = text(monitorCard, "DETECTION LOG\n\nMenunggu aktivitas server...", 4, 11, Color3.fromRGB(180,185,200))
monitorLog.Size = UDim2.new(1, -20, 1, -40)
monitorLog.TextYAlignment = Enum.TextYAlignment.Top

local clearLog = Instance.new("TextButton")
clearLog.Size = UDim2.new(0.35, 0, 0, 24)
clearLog.Position = UDim2.new(0.65, -10, 1, -30)
clearLog.Text = "🗑 CLEAR"
clearLog.TextSize = 10
clearLog.Font = Enum.Font.GothamBold
clearLog.TextColor3 = Color3.fromRGB(200,200,200)
clearLog.BackgroundColor3 = Color3.fromRGB(35,38,50)
clearLog.Parent = monitorCard
Instance.new("UICorner", clearLog).CornerRadius = UDim.new(0, 5)
clearLog.Activated:Connect(function()
    monitorLog.Text = "DETECTION LOG\n\nMenunggu aktivitas server..."
end)

-- Halaman Filters
local filtersPage = makePage("Filters")
local filterCard = card(filtersPage, 150)
text(filterCard, "PENYARING KELANGKAHAN", 4, 11, Color3.fromRGB(120,125,140), true)

local rarityOrder = {"SECRET","FORGOTTEN","Mythic","Legendary","Epic","Rare","Uncommon","Common"}
for i, name in ipairs(rarityOrder) do
    local b = Instance.new("TextButton")
    local row = math.floor((i-1)/2)
    local col = (i-1)%2
    b.Size = UDim2.new(0.5, -8, 0, 24)
    b.Position = UDim2.new(col*0.5, col==0 and 5 or 3, 0, 24 + row*28)
    b.BackgroundColor3 = CONFIG.ALLOW_RARITY[name] and Color3.fromRGB(39,174,96) or Color3.fromRGB(30,32,40)
    b.Text = name .. (CONFIG.ALLOW_RARITY[name] and "  ✓" or "  ×")
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 9
    b.Parent = filterCard
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    
    b.Activated:Connect(function()
        CONFIG.ALLOW_RARITY[name] = not CONFIG.ALLOW_RARITY[name]
        b.BackgroundColor3 = CONFIG.ALLOW_RARITY[name] and Color3.fromRGB(39,174,96) or Color3.fromRGB(30,32,40)
        b.Text = name .. (CONFIG.ALLOW_RARITY[name] and "  ✓" or "  ×")
    end)
end

-- Halaman Webhook
local webhookPage = makePage("Webhook")
local webhookCard = card(webhookPage, 185)
text(webhookCard, "MANAJEMEN WEBHOOK JARINGAN", 4, 10, Color3.fromRGB(120,125,140), true)

local webhookInput = Instance.new("TextBox")
webhookInput.Position = UDim2.new(0, 10, 0, 22)
webhookInput.Size = UDim2.new(1, -20, 0, 26)
webhookInput.Text = CONFIG.WEBHOOK_URL
webhookInput.PlaceholderText = "Paste URL Webhook Ikan Utama"
webhookInput.TextSize = 10
webhookInput.Font = Enum.Font.GothamMedium
webhookInput.TextColor3 = Color3.fromRGB(255,255,255)
webhookInput.BackgroundColor3 = Color3.fromRGB(24,26,33)
webhookInput.ClearTextOnFocus = false
webhookInput.Parent = webhookCard
Instance.new("UICorner", webhookInput).CornerRadius = UDim.new(0, 5)
Instance.new("UIStroke", webhookInput).Color = Color3.fromRGB(35,38,48)

local logWebhookInput = webhookInput:Clone()
logWebhookInput.Position = UDim2.new(0, 10, 0, 52)
logWebhookInput.Text = CONFIG.JOIN_LEAVE_URL
logWebhookInput.PlaceholderText = "Paste URL Webhook Logs Join/Leave (Opsional)"
logWebhookInput.Parent = webhookCard

local mentionInput = webhookInput:Clone()
mentionInput.Position = UDim2.new(0, 10, 0, 82)
mentionInput.Text = CONFIG.MENTION
mentionInput.PlaceholderText = "Ketik Angka Role ID Discord (Misal: 1234567890)"
mentionInput.Parent = webhookCard

local saveWebhook = Instance.new("TextButton")
saveWebhook.Position = UDim2.new(0, 10, 0, 114)
saveWebhook.Size = UDim2.new(0.46, 0, 0, 26)
saveWebhook.Text = "TERAPKAN INPUT"
saveWebhook.TextSize = 10
saveWebhook.Font = Enum.Font.GothamBold
saveWebhook.TextColor3 = Color3.fromRGB(255,255,255)
saveWebhook.BackgroundColor3 = Color3.fromRGB(46,204,113)
saveWebhook.Parent = webhookCard
Instance.new("UICorner", saveWebhook).CornerRadius = UDim.new(0, 6)

local testWebhook = saveWebhook:Clone()
testWebhook.Position = UDim2.new(0.54, 0, 0, 114)
testWebhook.Text = "👁 PREVIEW EMBED"
testWebhook.BackgroundColor3 = Color3.fromRGB(52,152,219)
testWebhook.Parent = webhookCard

local infoUI = text(webhookCard, "⚠️ Klik tombol 'SAVE' di menu Home agar data permanen.", 146, 9, Color3.fromRGB(150,150,160))

-- Dialog Mapping
local dialog = Instance.new("Frame")
dialog.Size = UDim2.fromOffset(270, 200)
dialog.Position = UDim2.new(0.5, -135, 0.4, -100)
dialog.BackgroundColor3 = Color3.fromRGB(14,16,22)
dialog.Visible = false
dialog.ZIndex = 20
dialog.Parent = gui
Instance.new("UICorner", dialog).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", dialog).Color = Color3.fromRGB(50,55,70)

text(dialog, "SAMBUNGKAN ROBLOX → DISCORD ID", 8, 10, Color3.fromRGB(255,255,255), true).ZIndex = 21

local playerSelectBtn = Instance.new("TextButton")
playerSelectBtn.Position = UDim2.fromOffset(12, 38)
playerSelectBtn.Size = UDim2.new(1, -24, 0, 30)
playerSelectBtn.Text = " pilih akun Roblox (Aktif) ▼"
playerSelectBtn.TextSize = 11
playerSelectBtn.Font = Enum.Font.GothamBold
playerSelectBtn.TextColor3 = Color3.fromRGB(150,155,170)
playerSelectBtn.BackgroundColor3 = Color3.fromRGB(24,26,33)
playerSelectBtn.ZIndex = 21
playerSelectBtn.Parent = dialog
Instance.new("UICorner", playerSelectBtn).CornerRadius = UDim.new(0, 6)

local dropdownList = Instance.new("ScrollingFrame")
dropdownList.Size = UDim2.new(1, -24, 0, 80)
dropdownList.Position = UDim2.fromOffset(12, 68)
dropdownList.BackgroundColor3 = Color3.fromRGB(20,22,28)
dropdownList.BorderSizePixel = 0
dropdownList.ZIndex = 30
dropdownList.Visible = false
dropdownList.CanvasSize = UDim2.new()
dropdownList.AutomaticCanvasSize = Enum.AutomaticSize.Y
dropdownList.Parent = dialog
Instance.new("UIListLayout", dropdownList)

local targetSelectedPlayer = ""
playerSelectBtn.Activated:Connect(function()
    dropdownList.Visible = not dropdownList.Visible
    if dropdownList.Visible then
        for _, obj in pairs(dropdownList:GetChildren()) do if obj:IsA("TextButton") then obj:Destroy() end end
        for _, p in pairs(Players:GetPlayers()) do
            local pBtn = Instance.new("TextButton")
            pBtn.Size = UDim2.new(1, 0, 0, 24)
            pBtn.Text = " " .. p.Name
            pBtn.TextSize = 10
            pBtn.Font = Enum.Font.GothamSemibold
            pBtn.TextColor3 = Color3.fromRGB(220,220,220)
            pBtn.BackgroundTransparency = 1
            pBtn.ZIndex = 31
            pBtn.Parent = dropdownList
            pBtn.Activated:Connect(function()
                targetSelectedPlayer = p.Name
                playerSelectBtn.Text = "👤 " .. p.Name
                dropdownList.Visible = false
            end)
        end
    end
end)

local discordBox = Instance.new("TextBox")
discordBox.Position = UDim2.fromOffset(12, 80)
discordBox.Size = UDim2.new(1, -24, 0, 30)
discordBox.PlaceholderText = "Ketik User ID Discord Target (Angka)"
discordBox.TextSize = 11
discordBox.TextColor3 = Color3.fromRGB(255,255,255)
discordBox.BackgroundColor3 = Color3.fromRGB(24,26,33)
discordBox.ZIndex = 21
discordBox.Parent = dialog
Instance.new("UICorner", discordBox).CornerRadius = UDim.new(0, 6)

local mapSave = Instance.new("TextButton")
mapSave.Position = UDim2.fromOffset(12, 145)
mapSave.Size = UDim2.new(0.45, 0, 0, 30)
mapSave.Text = "SIMPAN"
mapSave.TextSize = 10
mapSave.Font = Enum.Font.GothamBold
mapSave.TextColor3 = Color3.fromRGB(255,255,255)
mapSave.BackgroundColor3 = Color3.fromRGB(46,204,113)
mapSave.ZIndex = 21
mapSave.Parent = dialog
Instance.new("UICorner", mapSave).CornerRadius = UDim.new(0, 6)

local mapCancel = mapSave:Clone()
mapCancel.Position = UDim2.new(0.53, 0, 0, 145)
mapCancel.Text = "BATAL"
mapCancel.BackgroundColor3 = Color3.fromRGB(192,57,43)
mapCancel.Parent = dialog
-- =============================================================================
-- BAGIAN 9 : INTERAKSI TAB, DRAGGING, DAN MAPPING FUNGSI
-- =============================================================================
-- FUNGSI: Mengaktifkan tab, drag header, serta fungsi tombol mapping dan webhook.
-- =============================================================================

local function refreshMappings()
    local lines = {}
    for roblox, discord in pairs(mappings) do lines[#lines+1] = "👤 "..roblox.." → "..discord end
    table.sort(lines)
    mappingText.Text = #lines > 0 and table.concat(lines, "\n") or "Belum ada user yang di-mapping."
end

addMapping.Activated:Connect(function() 
    playerSelectBtn.Text = " pilih akun Roblox (Aktif) ▼" 
    targetSelectedPlayer = "" 
    dialog.Visible = true 
end)
mapCancel.Activated:Connect(function() 
    dialog.Visible = false 
    dropdownList.Visible = false 
end)
mapSave.Activated:Connect(function()
    local r, d = trim(targetSelectedPlayer), trim(discordBox.Text)
    if r ~= "" and d ~= "" then
        mappings[r] = d 
        mappings[r:lower()] = d 
        refreshMappings()
        discordBox.Text = "" 
        dialog.Visible = false 
        dropdownList.Visible = false
    end
end)

saveWebhook.Activated:Connect(function() 
    CONFIG.WEBHOOK_URL = trim(webhookInput.Text) 
    CONFIG.JOIN_LEAVE_URL = trim(logWebhookInput.Text)
    CONFIG.MENTION = trim(mentionInput.Text)
    infoUI.Text = "✅ Input berhasil diterapkan ke memori sementara."
end)

testWebhook.Activated:Connect(function()
    if CONFIG.WEBHOOK_URL == "" then 
        infoUI.Text = "⚠️ Isi URL webhook terlebih dahulu!"
        return 
    end

    -- =====================================================
    -- PREVIEW DATA SESUAI ASLI (Astralune = FORGOTTEN)
    -- =====================================================
    local previewData = {
        Player = LocalPlayer.Name,
        Fish = "Astralune",                     -- Nama ikan
        RawFish = "Gemstone Astralune",         -- Dengan varian di depan
        Weight = 1200000,                       -- 1.24M kg
        Chance = "20,000,000",                  -- Peluang
        RarityColor = {255, 255, 255},          -- Warna putih (FORGOTTEN)
        -- Opsional: kita bisa langsung set rarityName agar tidak bergantung deteksi
        -- tapi kita biarkan deteksi otomatis berdasarkan warna.
    }
    
    sendWebhook(previewData)
    infoUI.Text = "👁 Preview FORGOTTEN dikirim (cek channel Discord)"
end)

-- Tab Navigation
local tabNames = { {"⌂", "Home"}, {"👥", "Players"}, {"◈", "Monitor"}, {"⚙", "Filters"}, {"🔔", "Webhook"} }
for i, item in ipairs(tabNames) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.2, -4, 1, -4)
    b.Position = UDim2.new((i-1)*0.2, 2, 0, 2)
    b.BackgroundTransparency = 1 
    b.Text = item[1] .. "\n" .. item[2] 
    b.TextSize = 8 
    b.Font = Enum.Font.GothamBold 
    b.TextColor3 = Color3.fromRGB(100,105,120) 
    b.Parent = tabbar 
    tabs[item[2]] = b 
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.Activated:Connect(function()
        activeTab = item[2]
        for n, p in pairs(pages) do p.Visible = (n == activeTab) end
        for n, t in pairs(tabs) do t.TextColor3 = (n == activeTab) and Color3.fromRGB(255,255,255) or Color3.fromRGB(100,105,120) end
    end)
end
pages.Home.Visible = true 
tabs.Home.TextColor3 = Color3.fromRGB(255,255,255)

-- Minimize
local minimized = false
min.Activated:Connect(function()
    minimized = not minimized 
    tabbar.Visible = not minimized
    for _, p in pairs(pages) do p.Visible = not minimized and (_ == activeTab) or false end
    main.Size = minimized and UDim2.fromOffset(180, 40) or UDim2.fromOffset(340, 320)
    min.Text = minimized and "+" or "−"
end)

-- Dragging
local dragging, dragInput, dragStart, startPos
header.InputBegan:Connect(function(input) 
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then 
        dragging = true 
        dragInput = input 
        dragStart = input.Position 
        startPos = main.Position 
    end 
end)
UIS.InputChanged:Connect(function(input) 
    if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then 
        local delta = input.Position - dragStart 
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) 
    end 
end)
UIS.InputEnded:Connect(function(input) 
    if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 then 
        dragging = false 
    end 
end)
-- =============================================================================
-- BAGIAN 10 : REAL-TIME INTERCEPTOR (DIPERBAIKI UNTUK CHAT SERVER)
-- =============================================================================
-- FUNGSI: Menangkap chat server, join/leave, memperbarui statistik, dan refresh mapping.
-- =============================================================================

local function updateUI(data, lineInfo)
    state.Detected = state.Detected + 1
    homeLastText.Text = "📋 LAST ACTIVITY:\n" .. lineInfo
    local current = monitorLog.Text
    local lines = {}
    for line in (current:sub(18) or ""):gmatch("[^\n]*\n?") do
        table.insert(lines, line)
    end
    while #lines > 19 do table.remove(lines, 1) end
    local newLog = "DETECTION LOG\n\n["..os.date("%X").."] "..lineInfo:gsub("\n", " | ").."\n"..table.concat(lines)
    monitorLog.Text = newLog
end

local function handleMessage(text)
    local data = parseCatch(text)
    if not data then return end
    local displayWeight = data.Weight >= 1000 and string.format("%.2fK kg", data.Weight/1000) or string.format("%.2f kg", data.Weight)
    local lineInfo = string.format("👤 %s caught %s (%s) [1 in %s]", data.Player, data.Fish, displayWeight, tostring(data.Chance))
    updateUI(data, lineInfo)
    sendWebhook(data)
end

-- =============================================================================
-- [PERBAIKIAN UTAMA] Cara hook chat server yang lebih robust
-- =============================================================================
local function setupChatHook()
    -- Opsi 1: Hook langsung ke TextChannel.ROBLOX (paling akurat untuk pesan server)
    local success, channel = pcall(function()
        return TextChatService:WaitForChild("TextChannels"):WaitForChild("ROBLOX")
    end)
    
    if success and channel then
        channel.OnIncomingMessage = function(message)
            if message and message.Text and message.Text ~= "" then
                pcall(function() handleMessage(message.Text) end)
            end
        end
        print("[Radar] Berhasil hook ke TextChannel.ROBLOX")
        return true
    end
    
    -- Opsi 2: Fallback ke TextChatService.OnIncomingMessage
    if TextChatService and TextChatService.OnIncomingMessage then
        TextChatService.OnIncomingMessage = function(message)
            if message and message.Text and message.Text ~= "" then
                pcall(function() handleMessage(message.Text) end)
            end
        end
        print("[Radar] Berhasil hook ke TextChatService.OnIncomingMessage")
        return true
    end
    
    -- Opsi 3: Fallback terakhir – pakai Chat service (jika game lawas)
    local ChatService = game:GetService("Chat")
    if ChatService then
        ChatService.OnIncomingMessage = function(message)
            if message and message.Text and message.Text ~= "" then
                pcall(function() handleMessage(message.Text) end)
            end
        end
        print("[Radar] Berhasil hook ke Chat service lawas")
        return true
    end
    
    logError("Tidak ada sistem chat yang bisa di-hook!")
    return false
end

-- Jalankan hook
setupChatHook()

-- =============================================================================
-- PLAYER JOIN / LEAVE (tetap sama seperti sebelumnya)
-- =============================================================================
Players.PlayerAdded:Connect(function(player)
    local logLine = "📥 Player Masuk: " .. player.Name
    pcall(function()
        local current = monitorLog.Text
        local lines = {}
        for line in (current:sub(18) or ""):gmatch("[^\n]*\n?") do
            table.insert(lines, line)
        end
        while #lines > 19 do table.remove(lines, 1) end
        monitorLog.Text = "DETECTION LOG\n\n["..os.date("%X").."] " .. logLine .. "\n" .. table.concat(lines)
    end)
    pcall(function() sendJoinLeaveWebhook(player.Name, "JOINED") end)
end)

Players.PlayerRemoving:Connect(function(player)
    local logLine = "📤 Player Keluar: " .. player.Name
    pcall(function()
        local current = monitorLog.Text
        local lines = {}
        for line in (current:sub(18) or ""):gmatch("[^\n]*\n?") do
            table.insert(lines, line)
        end
        while #lines > 19 do table.remove(lines, 1) end
        monitorLog.Text = "DETECTION LOG\n\n["..os.date("%X").."] " .. logLine .. "\n" .. table.concat(lines)
    end)
    pcall(function() sendJoinLeaveWebhook(player.Name, "LEFT") end)
end)

-- =============================================================================
-- LOOP UPDATE STATISTIK
-- =============================================================================
task.spawn(function()
    while true do
        pcall(function()
            local totalPemain = #Players:GetPlayers()
            homeStats.Text = string.format("Players %d  •  Detected %d  •  Sent %d", totalPemain, state.Detected, state.Sent)
        end)
        task.wait(2)
    end
end)

refreshMappings()
print("[LFAMILIA Radar • Modern Minimalist Profile Slotted Edition] Fully Fixed!")
