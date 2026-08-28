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
    WEBHOOK_ENABLED = true,
    FISH_DB_URL = "https://raw.githubusercontent.com/muhammadaldy198/LFAMILIA/refs/heads/main/FishDatabase.lua",
    RARITY_DB_URL = "https://raw.githubusercontent.com/muhammadaldy198/LFAMILIA/refs/heads/main/RarityDatabase.lua",
    VARIANT_DB_URL = "https://raw.githubusercontent.com/muhammadaldy198/LFAMILIA/refs/heads/main/VariantDatabase.lua",
    ALLOW_RARITY = {
        SECRET = true,
        FORGOTTEN = true,
        Mythic = true,
        Legendary = true,
    },
    MIN_WEIGHT = 0,
    WEBHOOK_USERNAME = "LFAMILIA Radar (Fish It)",
    BANNER_URL = "https://i.imgur.com/42wd0m0.png",
}

-- Format mapping baru: [DiscordUserId] = {"RobloxAccount1", "RobloxAccount2"}
local mappings = {}
local state = {
    Running = true,
    Detected = 0,
    Sent = 0,
    Last = nil,
    Seen = {},
    ServerPlayers = 0,
    WebhooksSent = 0,
}
local CONFIG_FILE_1 = "LFAMILIA_Slot1.json"
local CONFIG_FILE_2 = "LFAMILIA_Slot2.json"
local CONFIG_FILE_3 = "LFAMILIA_Slot3.json"

-- Forward references yang dipakai oleh storage sebelum UI dibuat.
local refreshMappings
local refreshPlayerList
local updateServerStats
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

local function trim(s)
    return tostring(s or ""):gsub("^%s*(.-)%s*$", "%1")
end

local function normalizeDiscordId(value)
    local id = tostring(value or ""):match("%d+")
    return id or ""
end

local function addMappingEntry(target, discordId, playerName)
    discordId = normalizeDiscordId(discordId)
    playerName = trim(playerName)

    if discordId == "" or playerName == "" then return end
    target[discordId] = target[discordId] or {}

    for _, existing in ipairs(target[discordId]) do
        if tostring(existing):lower() == playerName:lower() then
            return
        end
    end

    table.insert(target[discordId], playerName)
end

local function normalizeMappings(rawMappings)
    local normalized = {}

    for key, value in pairs(rawMappings or {}) do
        -- Format baru: [Discord ID] = { RobloxPlayer1, RobloxPlayer2 }
        if type(value) == "table" then
            local discordId = normalizeDiscordId(key)
            if discordId ~= "" then
                for _, playerName in ipairs(value) do
                    addMappingEntry(normalized, discordId, playerName)
                end
            end
        -- Migrasi format lama: [RobloxPlayer] = Discord ID
        elseif type(value) == "string" or type(value) == "number" then
            addMappingEntry(normalized, value, key)
        end
    end

    for _, playerList in pairs(normalized) do
        table.sort(playerList, function(a, b)
            return tostring(a):lower() < tostring(b):lower()
        end)
    end

    return normalized
end

local function manualSave(slot)
    local wf = getWriteFn()
    if not wf then return false, "Executor tidak mendukung file" end
    local namaFile = dapatkanNamaFile(slot)
    local data = {
        SchemaVersion = 2,
        SavedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        CONFIG = {
            WEBHOOK_URL = CONFIG.WEBHOOK_URL,
            JOIN_LEAVE_URL = CONFIG.JOIN_LEAVE_URL,
            WEBHOOK_ENABLED = CONFIG.WEBHOOK_ENABLED ~= false,
            ALLOW_RARITY = CONFIG.ALLOW_RARITY,
            MIN_WEIGHT = CONFIG.MIN_WEIGHT,
            WEBHOOK_USERNAME = CONFIG.WEBHOOK_USERNAME,
        },
        mappings = normalizeMappings(mappings),
    }
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
    if ok then 
        local ok2, err = pcall(wf, namaFile, encoded)
        return ok2, ok2 and ("Sukses: " .. namaFile) or tostring(err)
    end
    return false, "Gagal membuat JSON data"
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
        if type(data.CONFIG.WEBHOOK_URL) == "string" then
            CONFIG.WEBHOOK_URL = data.CONFIG.WEBHOOK_URL
        end

        if type(data.CONFIG.JOIN_LEAVE_URL) == "string" then
            CONFIG.JOIN_LEAVE_URL = data.CONFIG.JOIN_LEAVE_URL
        end

        if type(data.CONFIG.WEBHOOK_ENABLED) == "boolean" then
            CONFIG.WEBHOOK_ENABLED = data.CONFIG.WEBHOOK_ENABLED
        end

        if type(data.CONFIG.MIN_WEIGHT) == "number" then
            CONFIG.MIN_WEIGHT = data.CONFIG.MIN_WEIGHT
        end

        if type(data.CONFIG.WEBHOOK_USERNAME) == "string" then
            CONFIG.WEBHOOK_USERNAME = data.CONFIG.WEBHOOK_USERNAME
        end

        -- Hanya empat rarity yang diizinkan; rarity lama tidak dimuat kembali.
        if type(data.CONFIG.ALLOW_RARITY) == "table" then
            for _, rarityName in ipairs({"SECRET", "FORGOTTEN", "Mythic", "Legendary"}) do
                CONFIG.ALLOW_RARITY[rarityName] = data.CONFIG.ALLOW_RARITY[rarityName] == true
            end
        end
    end
    if data.mappings then
        table.clear(mappings)
        local normalized = normalizeMappings(data.mappings)
        for discordId, playerList in pairs(normalized) do
            mappings[discordId] = playerList
        end
    end

    if refreshMappings then refreshMappings() end
    if refreshPlayerList then refreshPlayerList() end
    if updateServerStats then updateServerStats() end

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

local FishDatabaseTotal = 0
for _ in pairs(FishDatabase or {}) do
    FishDatabaseTotal = FishDatabaseTotal + 1
end

local function requestFn()
    return request or http_request or (syn and syn.request) or (fluxus and fluxus.request)
end

local function rgbInt(colors)
    if type(colors) == "table" and colors then
        local c = colors
        if type(c) == "table" then
            return (tonumber(c[1]) or 255) * 65536 + (tonumber(c[2]) or 255) * 256 + (tonumber(c[3]) or 255)
        end
    end
    return 0xFFFFFF
end

-- Asset private Fish It tidak selalu punya URL publik yang bisa dibaca Discord.
-- Karena itu ID asli tetap dikirim, sedangkan thumbnail publik hanya dikirim
-- jika proxy berhasil mengembalikan imageUrl yang valid.
local AssetThumbnailCache = {}

local function normalizeAssetId(assetId)
    return tostring(assetId or ""):match("%d+")
end

local function thumbnail(assetId)
    local id = normalizeAssetId(assetId)
    if not id then return nil end

    if AssetThumbnailCache[id] ~= nil then
        return AssetThumbnailCache[id] or nil
    end

    local proxyUrl = "https://thumbnails.roproxy.com/v1/assets?assetIds=" .. id .. "&size=420x420&format=png"
    local req = requestFn()

    if not req then
        AssetThumbnailCache[id] = false
        return nil
    end

    local success, response = pcall(function()
        return req({
            Url = proxyUrl,
            Method = "GET",
        })
    end)

    if success and response and response.Body then
        local decodedOK, decoded = pcall(function()
            return HttpService:JSONDecode(response.Body)
        end)

        if decodedOK and decoded and decoded.data and decoded.data[1]
            and type(decoded.data[1].imageUrl) == "string"
            and decoded.data[1].imageUrl ~= "" then
            AssetThumbnailCache[id] = decoded.data[1].imageUrl
            return decoded.data[1].imageUrl
        end
    end

    -- Jangan mengirim URL assetdelivery palsu untuk asset private.
    AssetThumbnailCache[id] = false
    return nil
end

local function buildAssetInfo(assetId)
    local id = normalizeAssetId(assetId)
    if not id then return {} end

    local info = {
        asset_id = id,
        asset_uri = "rbxassetid://" .. id,
        asset_source = "Fish It private asset",
        asset_private = true,
    }

    local publicURL = thumbnail(id)
    if publicURL then
        info.thumbnail_url = publicURL
        info.asset_private = false
    end

    return info
end
-- =============================================================================
-- BAGIAN 4 : TEXT PARSER & FISH IDENTIFICATION LOGIC
-- =============================================================================
-- FUNGSI: Membaca chat RichText dan memisahkan player, variant/mutasi,
-- nama ikan, weight, chance, serta warna tier/rarity.
-- =============================================================================

local function stripRichText(text)
    text = tostring(text or "")
    text = text:gsub("<[^>]->", "")
    text = text:gsub("&lt;", "<")
    text = text:gsub("&gt;", ">")
    text = text:gsub("&amp;", "&")
    return text
end

local function extractRGBFromFont(text)
    text = tostring(text or "")

    local r, g, b = text:match(
        '<font[^>]-color%s*=%s*"rgb%((%d+)%s*,%s*(%d+)%s*,%s*(%d+)%)'
    )

    if not r then
        r, g, b = text:match(
            "<font[^>]-color%s*=%s*'rgb%((%d+)%s*,%s*(%d+)%s*,%s*(%d+)%)"
        )
    end

    if r and g and b then
        return tonumber(r), tonumber(g), tonumber(b)
    end

    -- Dukungan tambahan untuk format hex jika sewaktu-waktu dipakai game.
    local hex = text:match('<font[^>]-color%s*=%s*"#([%x]+)"')
    if not hex then
        hex = text:match("<font[^>]-color%s*=%s*'#([%x]+)'")
    end

    if hex and #hex == 6 then
        return tonumber(hex:sub(1, 2), 16),
            tonumber(hex:sub(3, 4), 16),
            tonumber(hex:sub(5, 6), 16)
    end

    return nil, nil, nil
end

local function collectRichTextSpans(message)
    local spans = {}
    local cursor = 1

    while true do
        local startPos, endPos, attributes, inside = message:find(
            "<font([^>]*)>(.-)</font>", cursor
        )

        if not startPos then
            break
        end

        local fullTag = "<font" .. attributes .. ">"
        local r, g, b = extractRGBFromFont(fullTag)

        table.insert(spans, {
            Text = trim(stripRichText(inside)),
            R = r,
            G = g,
            B = b,
            Start = startPos,
            Finish = endPos,
        })

        cursor = endPos + 1
    end

    return spans
end

local function parseWeightValue(weightText)
    local compact = trim(weightText):lower():gsub("%s+", "")
    local number = tonumber(compact:match("([%d%.]+)")) or 0

    -- "45kg" berarti 45 kilogram, bukan 45 x 1.000.
    if compact:sub(-2) == "kg" then
        local beforeKg = compact:sub(1, -3)
        local scale = beforeKg:sub(-1)

        if scale == "k" then
            return number * 1000
        elseif scale == "m" then
            return number * 1000000
        elseif scale == "b" then
            return number * 1000000000
        end

        return number
    end

    if compact:sub(-1) == "k" then
        return number * 1000
    elseif compact:sub(-1) == "m" then
        return number * 1000000
    elseif compact:sub(-1) == "b" then
        return number * 1000000000
    end

    return number
end

local function getVariantFromName(text)
    local lowerText = trim(text):lower()

    for _, variantData in pairs(VariantDatabase) do
        if type(variantData) == "table" and variantData.Name then
            local variantName = tostring(variantData.Name)
            local prefix = variantName:lower() .. " "

            if lowerText:sub(1, #prefix) == prefix then
                return variantName, trim(text:sub(#prefix + 1)), variantData
            end
        end
    end

    return nil, trim(text), nil
end

local function getVariantByExactName(text)
    local lowerText = trim(text):lower()

    for _, variantData in pairs(VariantDatabase) do
        if type(variantData) == "table" and variantData.Name
            and tostring(variantData.Name):lower() == lowerText then
            return tostring(variantData.Name), variantData
        end
    end

    return nil, nil
end

local function getVariantByColor(r, g, b)
    if not r or not g or not b then return nil, nil end

    for _, variantData in pairs(VariantDatabase) do
        if type(variantData) == "table" and variantData.Name
            and type(variantData.Colors) == "table" then
            for _, color in ipairs(variantData.Colors) do
                if type(color) == "table" then
                    local cr = tonumber(color[1]) or 0
                    local cg = tonumber(color[2]) or 0
                    local cb = tonumber(color[3]) or 0

                    if math.abs(cr - r) <= 5
                        and math.abs(cg - g) <= 5
                        and math.abs(cb - b) <= 5 then
                        return tostring(variantData.Name), variantData
                    end
                end
            end
        end
    end

    return nil, nil
end

-- Nama ikan lengkap harus diprioritaskan sebelum prefix variant.
-- Contoh: "Elemental Tempestray" adalah satu nama ikan di FishDatabase,
-- bukan variant "Elemental" + ikan "Tempestray".
local function hasExactFishName(name)
    local wanted = trim(name):lower()
    if wanted == "" then return false, nil end

    for realName in pairs(FishDatabase) do
        if tostring(realName):lower() == wanted then
            return true, realName
        end
    end

    return false, nil
end

local function parseCatch(message)
    local richText = trim(message)
    if richText == "" then return nil end

    local spans = collectRichTextSpans(richText)
    local cleanMessage = stripRichText(richText)
    cleanMessage = cleanMessage:gsub("!%s*$", "")
    cleanMessage = cleanMessage:gsub("%s+", " ")
    cleanMessage = trim(cleanMessage)

    local player, caughtText, weightText, chance

    -- Format: obtained a ...
    player, caughtText, weightText, chance = cleanMessage:match(
        "^(.+)%s+[Oo]btained%s+[Aa]%s+(.+)%s+%(([^)]+)%)%s+[Ww]ith%s+(.+)%s+[Cc]hance$"
    )

    -- Format: obtained an ...
    if not player then
        player, caughtText, weightText, chance = cleanMessage:match(
            "^(.+)%s+[Oo]btained%s+[Aa][Nn]%s+(.+)%s+%(([^)]+)%)%s+[Ww]ith%s+(.+)%s+[Cc]hance$"
        )
    end

    if not player then
        return nil
    end

    local isExactFishName, exactFishName = hasExactFishName(caughtText)
    local variantName, cleanFish

    if isExactFishName then
        variantName = nil
        cleanFish = exactFishName or trim(caughtText)
    else
        variantName, cleanFish = getVariantFromName(caughtText)
    end
    local variantColor = nil
    local rarityColor = nil
    local playerColor = nil

    -- Span yang berisi (weight) adalah span nama ikan dan warna rarity/tier.
    for _, span in ipairs(spans) do
        if span.Text:find("%([^)]-%)") then
            if span.R and span.G and span.B then
                rarityColor = {span.R, span.G, span.B}
            end
        end
    end

    -- Span pertama biasanya nama player; tidak dipakai sebagai rarity.
    for index, span in ipairs(spans) do
        if index == 1 and span.R and span.G and span.B then
            playerColor = {span.R, span.G, span.B}
        end

        if variantName and span.Text:lower() == variantName:lower()
            and span.R and span.G and span.B then
            variantColor = {span.R, span.G, span.B}
        end
    end

    -- Fallback jika variant tidak tertulis sebagai prefix yang cocok database.
    if not variantName and not isExactFishName then
        for index, span in ipairs(spans) do
            -- Lewati span player dan jangan memakai warna span fish sebagai variant.
            if index > 1 and not span.Text:find("%([^)]-%)") then
                local detectedName, detectedData = getVariantByExactName(span.Text)

                if not detectedName and span.R and span.G and span.B then
                    detectedName, detectedData = getVariantByColor(span.R, span.G, span.B)
                end

                if detectedName then
                    variantName = detectedName
                    if span.R and span.G and span.B then
                        variantColor = {span.R, span.G, span.B}
                    elseif detectedData and detectedData.Colors
                        and detectedData.Colors[1] then
                        variantColor = detectedData.Colors[1]
                    end
                    break
                end
            end
        end
    end

    chance = trim(chance):gsub("^[Aa]%s+", "")

    return {
        Player = trim(player),
        Fish = trim(cleanFish),
        RawFish = trim(caughtText),
        FishIsExactName = isExactFishName,
        Variant = variantName,
        Mutation = variantName,
        Weight = parseWeightValue(weightText),
        Chance = chance,
        PlayerColor = playerColor,
        VariantColor = variantColor,
        RarityColor = rarityColor,
        RawMessage = richText,
    }
end

local FISH_SIZE_PREFIXES = {
    "big",
    "small",
    "tiny",
    "huge",
    "massive",
    "large",
    "giant",
    "mini",
}

local function findFishExact(name)
    local wanted = trim(name):lower()
    if wanted == "" then return nil, nil end

    for realName, data in pairs(FishDatabase) do
        if tostring(realName):lower() == wanted then
            return data, realName
        end
    end

    return nil, nil
end

-- BIG/SMALL adalah modifier ukuran dari hasil tangkapan, bukan selalu nama
-- fish di FishDatabase. Hanya lepaskan prefix jika nama dasarnya benar-benar
-- ada di database agar fish asli seperti "Giant Squid" tetap aman.
local function getDatabaseFishNameWithoutSize(name)
    local requested = trim(name)
    local firstWord, remainder = requested:match("^(%S+)%s+(.+)$")
    if not firstWord or not remainder then return requested end

    local lowerFirst = firstWord:lower()
    for _, sizePrefix in ipairs(FISH_SIZE_PREFIXES) do
        if lowerFirst == sizePrefix then
            local _, realName = findFishExact(remainder)
            if realName then
                return realName
            end
            break
        end
    end

    return requested
end

local function resolveFish(name)
    local requested = trim(name)
    local data, realName = findFishExact(requested)
    if data then return data, realName, nil end

    -- Contoh: "Big Blob Shark" -> lookup "Blob Shark", tetapi teks asli
    -- tetap dipakai sebagai nama ikan yang ditampilkan di webhook.
    local baseName = getDatabaseFishNameWithoutSize(requested)
    if baseName ~= requested then
        data, realName = findFishExact(baseName)
        if data then return data, realName, nil end
    end

    -- Variant tetap didukung, termasuk format "STONE Big Blob Shark".
    local nameLower = requested:lower()
    for _, v in pairs(VariantDatabase) do
        if type(v) == "table" and v.Name then
            local prefix = tostring(v.Name):lower() .. " "
            if nameLower:sub(1, #prefix) == prefix then
                local stripped = trim(requested:sub(#prefix + 1))
                data, realName = findFishExact(stripped)
                if data then return data, realName, v end

                local strippedBase = getDatabaseFishNameWithoutSize(stripped)
                if strippedBase ~= stripped then
                    data, realName = findFishExact(strippedBase)
                    if data then return data, realName, v end
                end
            end
        end
    end

    return nil, requested, nil
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
local monitorLines = {}

local function appendMonitorLog(kind, message)
    local line = string.format("[%s] %s %s", os.date("%H:%M:%S"), kind, tostring(message or ""))
    table.insert(monitorLines, line)

    while #monitorLines > 60 do
        table.remove(monitorLines, 1)
    end

    if monitorLog then
        monitorLog.Text = "DETECTION LOG\n\n" .. table.concat(monitorLines, "\n")
    end
end

-- Fungsi untuk mencatat error ke tab Monitor.
local function logError(errMsg)
    appendMonitorLog("❌", errMsg)
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

local function normalizePlayerName(value)
    return trim(tostring(value or "")):gsub("^@", ""):lower()
end

local function playerNamesMatch(firstName, secondName, playerObject)
    local first = normalizePlayerName(firstName)
    local second = normalizePlayerName(secondName)
    if first == "" or second == "" then return false end
    if first == second then return true end

    -- Mapping menyimpan player.Name, sedangkan sebagian game menampilkan
    -- player.DisplayName di pengumuman chat. Cocokkan keduanya.
    if playerObject then
        local username = normalizePlayerName(playerObject.Name)
        local displayName = normalizePlayerName(playerObject.DisplayName)
        if (first == username and second == displayName)
            or (first == displayName and second == username) then
            return true
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        local username = normalizePlayerName(player.Name)
        local displayName = normalizePlayerName(player.DisplayName)
        if (first == username and second == displayName)
            or (first == displayName and second == username) then
            return true
        end
    end

    return false
end

local function getMentionsForPlayer(playerName, playerObject)
    local mentions = {}
    local seenDiscord = {}

    for discordId, playerList in pairs(mappings) do
        if type(playerList) == "table" then
            for _, mappedPlayer in ipairs(playerList) do
                if playerNamesMatch(mappedPlayer, playerName, playerObject) then
                    local id = normalizeDiscordId(discordId)
                    if id ~= "" and not seenDiscord[id] then
                        seenDiscord[id] = true
                        table.insert(mentions, "<@" .. id .. ">")
                    end
                    break
                end
            end
        end
    end

    table.sort(mentions)
    return table.concat(mentions, " ")
end

-- Avatar Roblox untuk webhook join/leave. Ini terpisah dari resolver gambar
-- ikan agar sistem thumbnail ikan yang sudah berhasil tidak berubah.
local AvatarThumbnailCache = {}

local function getRobloxAvatarThumbnail(userId)
    local id = tostring(userId or ""):match("%d+")
    if not id then return nil end

    if AvatarThumbnailCache[id] ~= nil then
        return AvatarThumbnailCache[id] or nil
    end

    local req = requestFn()
    if not req then
        AvatarThumbnailCache[id] = false
        return nil
    end

    local endpoint = "https://thumbnails.roblox.com/v1/users/avatar-headshot"
        .. "?userIds=" .. id
        .. "&size=150x150&format=Png&isCircular=false"

    local ok, response = pcall(function()
        return req({Url = endpoint, Method = "GET"})
    end)

    if ok and response and response.Body then
        local decodedOK, decoded = pcall(function()
            return HttpService:JSONDecode(response.Body)
        end)

        if decodedOK and decoded and decoded.data and decoded.data[1]
            and type(decoded.data[1].imageUrl) == "string"
            and decoded.data[1].imageUrl:match("^https://") then
            AvatarThumbnailCache[id] = decoded.data[1].imageUrl
            return decoded.data[1].imageUrl
        end
    end

    AvatarThumbnailCache[id] = false
    return nil
end

local function sendWebhook(data)
    if CONFIG.WEBHOOK_ENABLED == false then
        return false
    end

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
    local rarityName = "Unknown"
    local embedColor = 0xFFFFFF
    
    if data.RarityColor then
        local r, g, b = data.RarityColor[1], data.RarityColor[2], data.RarityColor[3]
        if r and g and b then
            embedColor = r * 65536 + g * 256 + b
        end
        rarity = resolveRarityByColor(r, g, b)
        if rarity then
            rarityName = rarity.Name
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

    -- Jika RichText tidak membawa warna rarity, pakai warna pertama dari
    -- database sebagai fallback untuk accent_color Components V2.
    if not data.RarityColor and rarity and type(rarity.Colors) == "table"
        and type(rarity.Colors[1]) == "table" then
        local color = rarity.Colors[1]
        local r = tonumber(color[1]) or 255
        local g = tonumber(color[2]) or 255
        local b = tonumber(color[3]) or 255
        data.RarityColor = {r, g, b}
        embedColor = r * 65536 + g * 256 + b
    end

    -- FILTER kelangkaan
    if not CONFIG.ALLOW_RARITY[rarityName] and not CONFIG.ALLOW_RARITY[string.upper(rarityName)] then 
        return false 
    end
    if data.Weight < CONFIG.MIN_WEIGHT then return false end

    local key = data.Player .. "|" .. data.Fish .. "|" .. tostring(data.Weight)
    if seenRecently(key) then return false end

    -- Ambil asset ID untuk thumbnail/private-asset bridge.
    -- PRIORITAS 1: Asset ID dari metadata/thumbnail yang tertangkap.
    local assetId = data._assetId

    -- PRIORITAS 2: Asset ID dari database
    if not assetId then
        local fishData = resolveFish(data.Fish)
        if fishData and fishData.AssetId then
            assetId = tostring(fishData.AssetId):match("%d+")
        end
    end

    local assetInfo = buildAssetInfo(assetId)
    assetId = assetInfo.asset_id or assetId

    if assetId then
        print("[DEBUG] Asset ID terkirim:", assetId)
    else
        print("[DEBUG] Asset ID TIDAK ditemukan untuk:", data.Fish)
    end
    
    -- Ambil varian/mutasi dari parser RichText terlebih dahulu.
    local variant = data.Variant or data.Mutation
    if not data.FishIsExactName and not variant and data.RawFish then
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
    local time_str = os.date("%H:%M WIB • %d %b %Y")

    -- Mention hanya berasal dari akun yang dipetakan ke player tersebut.
    local mention = getMentionsForPlayer(data.Player, Players:FindFirstChild(data.Player))
    if mention ~= "" then
        appendMonitorLog("🔔", "Catch mention: " .. mention)
    else
        appendMonitorLog("ℹ️", "Tidak ada mapping untuk player: " .. tostring(data.Player))
    end
    -- Bentuk data embed mentah disamakan dengan card final. Relay Python tetap
    -- membangun Components V2 sendiri; thumbnail ikan tidak diubah.
    local embed = {
        description = table.concat({
            "Player    : " .. tostring(data.Player),
            "Fish      : " .. tostring(data.Fish),
            "Rarity    : " .. tostring(rarityName),
            "Mutation  : " .. tostring(variant or "—"),
            "Weight    : " .. tostring(data.Weight) .. " kg",
            "Chance    : " .. tostring(data.Chance or "unknown"),
        }, "\n"),
        footer = {text = "LFAMILIA MONITOR • Fish It | " .. time_str},
        image = {url = CONFIG.BANNER_URL},
    }

    if assetInfo.thumbnail_url then
        embed.thumbnail = {url = assetInfo.thumbnail_url}
    end

    -- Payload untuk server PythonAnywhere
    local payload = {
        discord_url = CONFIG.WEBHOOK_URL,   -- URL Discord tetap dari UI
        webhook_username = CONFIG.WEBHOOK_USERNAME,
        content = mention,
        allowed_mentions = {parse = {"users"}},
        player = data.Player,
        fish = data.Fish,
        weight = data.Weight,
        chance = data.Chance,
        rarity = rarityName,
        color = embedColor,
        asset_id = assetId,
        asset_uri = assetInfo.asset_uri,
        asset_source = assetInfo.asset_source,
        asset_private = assetInfo.asset_private,
        thumbnail_url = assetInfo.thumbnail_url,
        variant = variant,
        mutation = data.Mutation or variant,
        variant_color = data.VariantColor,
        rarity_color = data.RarityColor,
        player_color = data.PlayerColor,
        server_id = server_id,
        time = time_str,
        banner_url = CONFIG.BANNER_URL,
        mention = mention,
        embeds = {embed},
    }

    -- Kirim ke SERVER (bukan langsung ke Discord)
    local server_url = "https://Aldayyy.pythonanywhere.com/api/catch"  -- <-- GANTI dengan URL-mu
    local response
    local ok, err = pcall(function()
        response = req({
            Url = server_url,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(payload),
        })
    end)

    local statusCode = response and tonumber(response.StatusCode)
    local accepted = ok and response and response.Success ~= false
        and (not statusCode or (statusCode >= 200 and statusCode < 300))

    if accepted then
        state.Sent = state.Sent + 1
        state.WebhooksSent = (state.WebhooksSent or 0) + 1
        if updateServerStats then pcall(updateServerStats) end
        return true 
    else
        logError("Gagal kirim ke server: " .. tostring(err or (statusCode and ("HTTP " .. statusCode) or "respons kosong")))
        return false
    end
end

local function sendJoinLeaveWebhook(playerOrName, action)
    -- Join/leave memakai URL terpisah dan embed biasa.
    if CONFIG.WEBHOOK_ENABLED == false or CONFIG.JOIN_LEAVE_URL == "" then return end

    local req = requestFn()
    if not req then
        logError("Tidak ada fungsi request untuk join/leave")
        return
    end

    local playerObject = nil
    local playerName = "Unknown player"
    local userId = nil

    if typeof(playerOrName) == "Instance" and playerOrName:IsA("Player") then
        playerObject = playerOrName
        playerName = playerObject.Name
        userId = playerObject.UserId
    else
        playerName = trim(playerOrName)
        playerObject = Players:FindFirstChild(playerName)
        userId = playerObject and playerObject.UserId or nil
    end

    local mention = getMentionsForPlayer(playerName, playerObject)
    local actionText = action == "JOINED"
        and "has joined the server!"
        or "has left the server!"
    local footerText = "LFAMILIA V1 • Fish It | " .. os.date("%H:%M:%S")

    local embed = {
        description = "**" .. tostring(playerName) .. "** " .. actionText,
        color = action == "JOINED" and 0x2ECC71 or 0xE74C3C,
        footer = {text = footerText},
    }

    local avatarURL = getRobloxAvatarThumbnail(userId)
    if avatarURL then
        embed.thumbnail = {url = avatarURL}
    end

    local payload = {
        username = CONFIG.WEBHOOK_USERNAME,
        embeds = {embed},
        allowed_mentions = {parse = {"users"}},
    }

    -- Mention berada di luar embed, sesuai format: <@ID> Ping!
    if mention ~= "" then
        payload.content = mention .. " Ping!"
        appendMonitorLog("🔔", "Join/leave mention: " .. mention)
    else
        appendMonitorLog("ℹ️", "Tidak ada mapping join/leave untuk: " .. tostring(playerName))
    end

    local response
    local ok, err = pcall(function()
        response = req({
            Url = CONFIG.JOIN_LEAVE_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(payload),
        })
    end)

    local statusCode = response and tonumber(response.StatusCode)
    local accepted = ok and response and response.Success ~= false
        and (not statusCode or (statusCode >= 200 and statusCode < 300))
    if not accepted then
        logError("Webhook join/leave gagal: " .. tostring(
            err or (statusCode and ("HTTP " .. statusCode) or "respons kosong")
        ))
    else
        state.WebhooksSent = (state.WebhooksSent or 0) + 1
        if updateServerStats then pcall(updateServerStats) end
    end
end
-- =============================================================================
-- BAGIAN 6 : GUI – LAYOUT DASAR (FRAME, HEADER, HIDE)
-- =============================================================================
-- FUNGSI: Membuat UI utama modern, colorfull, responsive, dan modular.
-- =============================================================================

local function getGuiParent()
    local ok, parent = pcall(function()
        if type(gethui) == "function" then
            return gethui()
        end
        if type(get_hidden_gui) == "function" then
            return get_hidden_gui()
        end
        return CoreGui
    end)

    return (ok and parent) or CoreGui
end

local guiParent = getGuiParent()
pcall(function()
    local oldGui = guiParent:FindFirstChild("LFAMILIA_Radar_V5")
    if oldGui then oldGui:Destroy() end
end)
pcall(function()
    local oldGui = CoreGui:FindFirstChild("LFAMILIA_Radar_V5")
    if oldGui then oldGui:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "LFAMILIA_Radar_V5"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 99999
pcall(function() gui.Parent = guiParent end)
if not gui.Parent and LocalPlayer then
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local THEME = {
    Background = Color3.fromRGB(9, 11, 18),
    Surface = Color3.fromRGB(17, 20, 31),
    Surface2 = Color3.fromRGB(23, 27, 42),
    Border = Color3.fromRGB(63, 72, 105),
    Text = Color3.fromRGB(242, 245, 255),
    Muted = Color3.fromRGB(155, 164, 188),
    Cyan = Color3.fromRGB(67, 211, 255),
    Purple = Color3.fromRGB(148, 93, 255),
    Pink = Color3.fromRGB(255, 91, 178),
    Green = Color3.fromRGB(65, 222, 139),
    Orange = Color3.fromRGB(255, 174, 74),
    Red = Color3.fromRGB(246, 86, 108),
}

local main = Instance.new("Frame")
-- Ukuran mengikuti layar aktual. Delta Android sering memakai viewport
-- landscape yang tingginya pendek, jadi tinggi tidak dikunci 535px.
local function getViewportSize()
    local camera = workspace.CurrentCamera
    if camera then
        local viewport = camera.ViewportSize
        if viewport.X > 0 and viewport.Y > 0 then
            return viewport
        end
    end
    return Vector2.new(1280, 720)
end

local function getResponsiveMainSize()
    local viewport = getViewportSize()
    local landscape = viewport.X >= viewport.Y
    local width = math.floor(math.min(viewport.X * 0.94, landscape and 1440 or 440))
    local height = math.floor(math.min(viewport.Y * 0.88, landscape and 660 or 720))

    -- Isi tiap halaman tetap dapat di-scroll jika tinggi layar pendek.
    width = math.max(320, width)
    height = math.max(300, height)
    return UDim2.fromOffset(width, height)
end

local normalMainSize = getResponsiveMainSize()
main.Size = normalMainSize
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Position = UDim2.new(0.5, 0, 0.5, 0)
main.BackgroundColor3 = THEME.Background
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
local outline = Instance.new("UIStroke", main)
outline.Color = THEME.Border
outline.Thickness = 1.4

local mainGradient = Instance.new("UIGradient")
mainGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 19, 39)),
    ColorSequenceKeypoint.new(0.55, Color3.fromRGB(10, 17, 29)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(32, 14, 42)),
})
mainGradient.Rotation = 35
mainGradient.Parent = main

local header = Instance.new("TextButton")
header.Size = UDim2.new(1, -260, 0, 48)
header.Position = UDim2.fromOffset(12, 4)
header.BackgroundTransparency = 1
header.Text = "LFAMILIA MONITOR"
header.TextColor3 = THEME.Text
header.TextSize = 12
header.Font = Enum.Font.GothamBold
header.TextXAlignment = Enum.TextXAlignment.Left
header.TextYAlignment = Enum.TextYAlignment.Center
header.TextTruncate = Enum.TextTruncate.AtEnd
header.AutoButtonColor = false
header.Parent = main

local headerStatus = Instance.new("TextLabel")
headerStatus.Size = UDim2.fromOffset(82, 24)
headerStatus.Position = UDim2.new(1, -164, 0, 16)
headerStatus.BackgroundColor3 = Color3.fromRGB(22, 52, 48)
headerStatus.Text = "●  LIVE"
headerStatus.TextColor3 = THEME.Green
headerStatus.TextSize = 10
headerStatus.Font = Enum.Font.GothamBold
headerStatus.Parent = main
Instance.new("UICorner", headerStatus).CornerRadius = UDim.new(1, 0)

-- Tombol HIDE tetap berada di header; panel kecil pengganti dibuat sebagai
-- sibling agar tetap terlihat ketika panel utama disembunyikan.
local hideButton = Instance.new("TextButton")
hideButton.Size = UDim2.fromOffset(70, 30)
hideButton.Position = UDim2.new(1, -78, 0, 13)
hideButton.BackgroundColor3 = THEME.Cyan
hideButton.BorderSizePixel = 0
hideButton.Text = "HIDE"
hideButton.TextColor3 = Color3.fromRGB(8, 15, 25)
hideButton.TextSize = 10
hideButton.Font = Enum.Font.GothamBold
hideButton.AutoButtonColor = true
hideButton.Parent = main
Instance.new("UICorner", hideButton).CornerRadius = UDim.new(0, 8)

local hideIcon = Instance.new("TextButton")
hideIcon.Size = UDim2.fromOffset(56, 56)
hideIcon.Position = UDim2.new(0.5, -28, 0.5, -28)
hideIcon.BackgroundColor3 = THEME.Purple
hideIcon.BorderSizePixel = 0
hideIcon.Text = "LFM"
hideIcon.TextColor3 = THEME.Text
hideIcon.TextSize = 14
hideIcon.Font = Enum.Font.GothamBold
hideIcon.Visible = false
hideIcon.ZIndex = 20
hideIcon.Parent = gui
Instance.new("UICorner", hideIcon).CornerRadius = UDim.new(0, 16)
local hideIconStroke = Instance.new("UIStroke", hideIcon)
hideIconStroke.Color = THEME.Cyan
hideIconStroke.Thickness = 1.5
local hideIconGradient = Instance.new("UIGradient", hideIcon)
hideIconGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(67, 211, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(148, 93, 255)),
})
hideIconGradient.Rotation = 35

local tabbar = Instance.new("Frame")
local navWidth = getViewportSize().X < 760 and 108 or 132
tabbar.Position = UDim2.fromOffset(10, 60)
tabbar.Size = UDim2.new(0, navWidth, 1, -70)
tabbar.BackgroundColor3 = THEME.Surface2
tabbar.BorderSizePixel = 0
tabbar.Parent = main
Instance.new("UICorner", tabbar).CornerRadius = UDim.new(0, 10)
local tabStroke = Instance.new("UIStroke", tabbar)
tabStroke.Color = THEME.Border
tabStroke.Transparency = 0.45
local tabLayout = Instance.new("UIListLayout")
tabLayout.Padding = UDim.new(0, 7)
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabbar

local pages = {}
local tabs = {}
local activeTab = "Home"

local function addCorner(object, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = object
    return corner
end

local function addStroke(object, color, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or THEME.Border
    stroke.Transparency = transparency or 0
    stroke.Thickness = 1
    stroke.Parent = object
    return stroke
end

local function makePage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.Position = UDim2.new(0, navWidth + 20, 0, 60)
    page.Size = UDim2.new(1, -navWidth - 32, 1, -72)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.Active = true
    page.ScrollBarThickness = 5
    page.ScrollBarImageColor3 = THEME.Purple
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new()
    page.Visible = false
    page.Parent = main

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 9)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Parent = page

    pages[name] = page
    return page
end

local function card(parent, height, accent)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -2, 0, height)
    frame.BackgroundColor3 = THEME.Surface
    frame.BorderSizePixel = 0
    frame.Parent = parent
    addCorner(frame, 10)
    addStroke(frame, THEME.Border, 0.35)

    local stripe = Instance.new("Frame")
    stripe.Size = UDim2.new(0, 3, 1, -18)
    stripe.Position = UDim2.fromOffset(0, 9)
    stripe.BackgroundColor3 = accent or THEME.Purple
    stripe.BorderSizePixel = 0
    stripe.Parent = frame
    addCorner(stripe, 2)

    return frame
end

local function text(parent, value, y, size, color, bold)
    local label = Instance.new("TextLabel")
    label.Position = UDim2.new(0, 13, 0, y or 6)
    label.Size = UDim2.new(1, -26, 0, 22)
    label.BackgroundTransparency = 1
    label.Text = value
    label.TextColor3 = color or THEME.Text
    label.TextSize = size or 11
    label.Font = bold and Enum.Font.GothamBold or Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.Parent = parent
    return label
end

local function makeButton(parent, caption, position, size, color)
    local button = Instance.new("TextButton")
    button.Position = position
    button.Size = size
    button.BackgroundColor3 = color or THEME.Surface2
    button.BorderSizePixel = 0
    button.Text = caption
    button.TextColor3 = THEME.Text
    button.TextSize = 10
    button.Font = Enum.Font.GothamBold
    button.Parent = parent
    addCorner(button, 7)
    addStroke(button, THEME.Border, 0.45)
    return button
end
-- =============================================================================
-- BAGIAN 7 : GUI – HALAMAN HOME & STORAGE (SLOT SAVE/LOAD)
-- =============================================================================
-- FUNGSI: Dashboard utama, jumlah pemain aktif, server ID, last activity,
-- serta profile save/load yang lebih aman.
-- =============================================================================

local home = makePage("Home")
local configPage = makePage("Config")
local homeStatus = card(home, 96, THEME.Green)
text(homeStatus, "●  MONITOR ACTIVE", 10, 13, THEME.Green, true)
local homeStats = text(homeStatus, "Detected 0  •  Sent 0", 36, 11, THEME.Text)
homeStats.Size = UDim2.new(0.62, -18, 0, 22)
local homeRuntime = text(homeStatus, "Runtime: starting...", 61, 9, THEME.Muted)
homeRuntime.Size = UDim2.new(0.58, -18, 0, 22)
local homeWebhookToggle = makeButton(
    homeStatus,
    "WEBHOOK ON",
    UDim2.new(0.64, 0, 0, 53),
    UDim2.new(0.36, -13, 0, 30),
    THEME.Green
)

local homeMetrics = card(home, 148, THEME.Cyan)
text(homeMetrics, "OVERVIEW", 10, 11, THEME.Cyan, true)

local function makeHomeMetric(parent, title, value, position, accent)
    local box = Instance.new("Frame")
    box.Position = position
    box.Size = UDim2.new(0.5, -18, 0, 54)
    box.BackgroundColor3 = THEME.Surface2
    box.BorderSizePixel = 0
    box.Parent = parent
    addCorner(box, 8)
    addStroke(box, accent or THEME.Border, 0.55)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Position = UDim2.fromOffset(10, 6)
    titleLabel.Size = UDim2.new(1, -20, 0, 16)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = THEME.Muted
    titleLabel.TextSize = 8
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = box

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Position = UDim2.fromOffset(10, 23)
    valueLabel.Size = UDim2.new(1, -20, 0, 23)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = value
    valueLabel.TextColor3 = accent or THEME.Text
    valueLabel.TextSize = 16
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextXAlignment = Enum.TextXAlignment.Left
    valueLabel.TextTruncate = Enum.TextTruncate.AtEnd
    valueLabel.Parent = box
    return valueLabel
end

local homePlayersMetric = makeHomeMetric(
    homeMetrics, "TOTAL PLAYERS", "0", UDim2.fromOffset(12, 34), THEME.Cyan
)
local homeFishMetric = makeHomeMetric(
    homeMetrics, "FISH DATABASE", tostring(FishDatabaseTotal), UDim2.new(0.5, 6, 0, 34), THEME.Purple
)
local homeWebhookMetric = makeHomeMetric(
    homeMetrics, "WEBHOOKS SENT", "0", UDim2.fromOffset(12, 94), THEME.Green
)
local homeDetectedMetric = makeHomeMetric(
    homeMetrics, "CATCH DETECTED", "0", UDim2.new(0.5, 6, 0, 94), THEME.Orange
)

-- Panel Storage (3 slot, schema version, timestamp, dan migrasi mapping lama)
local storageCard = card(home, 92)
text(storageCard, "💽 PROFILE DATA MANAGEMENT", 8, 11, THEME.Purple, true)

local activeSlot = 1
local slotBtn = makeButton(storageCard, "📁 SLOT 1  ▼", UDim2.new(0, 13, 0, 32), UDim2.new(0.29, -5, 0, 28), THEME.Surface2)
local saveBtn = makeButton(storageCard, "💾 SAVE", UDim2.new(0.31, 3, 0, 32), UDim2.new(0.30, -5, 0, 28), THEME.Green)
local loadBtn = makeButton(storageCard, "📂 LOAD", UDim2.new(0.63, 2, 0, 32), UDim2.new(0.30, -5, 0, 28), THEME.Orange)
local storageMsg = text(storageCard, "Slot kosong sampai kamu menyimpan profile.", 65, 9, THEME.Muted)
storageCard.Parent = configPage

-- Panel Last Activity
local homeLast = card(home, 92, THEME.Pink)
text(homeLast, "📋 LAST ACTIVITY", 10, 10, THEME.Pink, true)
local homeLastText = text(homeLast, "Menunggu tangkapan dari server...", 34, 11, THEME.Text)
homeLastText.Size = UDim2.new(1, -26, 0, 48)
-- =============================================================================
-- BAGIAN 8 : GUI – HALAMAN LOG, CONFIG, DAN WEBHOOK
-- =============================================================================
-- FUNGSI: Membuat halaman log pemain, mapping multi-akun, filter tier,
-- URL webhook terpisah, serta kontrol webhook.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 8A. SERVER PLAYERS + MAPPING DISCORD MULTI-AKUN
-- -----------------------------------------------------------------------------
local logPage = makePage("Log")
local playerPresenceCard = card(logPage, 255, THEME.Cyan)
text(playerPresenceCard, "👥 ACTIVE PLAYERS IN THIS SERVER", 10, 11, THEME.Cyan, true)
local playersCountText = text(playerPresenceCard, "0 pemain terdeteksi", 34, 20, THEME.Text, true)
local playersJobText = text(playerPresenceCard, "JobId: loading...", 64, 9, THEME.Muted)

local playersListScroll = Instance.new("ScrollingFrame")
playersListScroll.Position = UDim2.new(0, 13, 0, 91)
playersListScroll.Size = UDim2.new(1, -26, 0, 151)
playersListScroll.BackgroundColor3 = Color3.fromRGB(11, 15, 26)
playersListScroll.BorderSizePixel = 0
playersListScroll.ScrollBarThickness = 3
playersListScroll.ScrollBarImageColor3 = THEME.Cyan
playersListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
playersListScroll.CanvasSize = UDim2.new()
playersListScroll.Parent = playerPresenceCard
addCorner(playersListScroll, 8)
local playersListLayout = Instance.new("UIListLayout")
playersListLayout.Padding = UDim.new(0, 3)
playersListLayout.Parent = playersListScroll

local mappingBox = card(logPage, 300, THEME.Purple)
text(mappingBox, "🔗 DISCORD ACCOUNT MAPPING", 10, 11, THEME.Purple, true)
local mappingHint = text(mappingBox, "Masukkan ID Discord, pilih player, lalu simpan manual di CONFIG.", 35, 9, THEME.Muted)
mappingHint.Size = UDim2.new(1, -26, 0, 18)

local mappingIdInput = Instance.new("TextBox")
mappingIdInput.Position = UDim2.new(0, 13, 0, 58)
mappingIdInput.Size = UDim2.new(0.62, -8, 0, 29)
mappingIdInput.Text = ""
mappingIdInput.PlaceholderText = "Discord User ID (angka saja)"
mappingIdInput.ClearTextOnFocus = false
mappingIdInput.BackgroundColor3 = THEME.Surface2
mappingIdInput.BorderSizePixel = 0
mappingIdInput.TextColor3 = THEME.Text
mappingIdInput.PlaceholderColor3 = THEME.Muted
mappingIdInput.TextSize = 10
mappingIdInput.Font = Enum.Font.Code
mappingIdInput.TextXAlignment = Enum.TextXAlignment.Left
mappingIdInput.Parent = mappingBox
addCorner(mappingIdInput, 7)
addStroke(mappingIdInput, THEME.Border, 0.45)

local listPlayersButton = makeButton(
    mappingBox,
    "LIST PLAYER",
    UDim2.new(0.64, 4, 0, 58),
    UDim2.new(0.36, -17, 0, 29),
    THEME.Purple
)

local mappingScroll = Instance.new("ScrollingFrame")
mappingScroll.Position = UDim2.new(0, 13, 0, 96)
mappingScroll.Size = UDim2.new(1, -26, 0, 162)
mappingScroll.BackgroundColor3 = Color3.fromRGB(11, 15, 26)
mappingScroll.BorderSizePixel = 0
mappingScroll.ScrollBarThickness = 3
mappingScroll.ScrollBarImageColor3 = THEME.Purple
mappingScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
mappingScroll.CanvasSize = UDim2.new()
mappingScroll.Parent = mappingBox
addCorner(mappingScroll, 8)

local mappingRows = Instance.new("Frame")
mappingRows.Position = UDim2.fromOffset(8, 8)
mappingRows.Size = UDim2.new(1, -16, 0, 0)
mappingRows.AutomaticSize = Enum.AutomaticSize.Y
mappingRows.BackgroundTransparency = 1
mappingRows.Parent = mappingScroll

local mappingRowsLayout = Instance.new("UIListLayout")
mappingRowsLayout.Padding = UDim.new(0, 4)
mappingRowsLayout.SortOrder = Enum.SortOrder.LayoutOrder
mappingRowsLayout.Parent = mappingRows

local addMapping = listPlayersButton
local mappingLogStatus = text(
    mappingBox,
    "Mapping belum disimpan ke file. Gunakan CONFIG → SAVE.",
    270,
    8,
    THEME.Muted
)
mappingLogStatus.Size = UDim2.new(1, -26, 0, 18)

-- -----------------------------------------------------------------------------
-- 8B. MONITOR GABUNGAN: CATCH + PLAYER JOIN/LEAVE + ERROR
-- -----------------------------------------------------------------------------
local monitorPage = logPage
local monitorCard = card(monitorPage, 350, THEME.Pink)
text(monitorCard, "◈ LIVE ACTIVITY LOG", 10, 11, THEME.Pink, true)
local monitorHint = text(monitorCard, "Tangkapan, player join/leave, dan error berada di log yang sama.", 34, 9, THEME.Muted)
monitorHint.Size = UDim2.new(1, -26, 0, 18)

local monitorScroll = Instance.new("ScrollingFrame")
monitorScroll.Position = UDim2.new(0, 13, 0, 60)
monitorScroll.Size = UDim2.new(1, -26, 1, -105)
monitorScroll.BackgroundColor3 = Color3.fromRGB(8, 11, 19)
monitorScroll.BorderSizePixel = 0
monitorScroll.ScrollBarThickness = 3
monitorScroll.ScrollBarImageColor3 = THEME.Pink
monitorScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
monitorScroll.CanvasSize = UDim2.new()
monitorScroll.Parent = monitorCard
addCorner(monitorScroll, 8)

monitorLog = Instance.new("TextLabel")
monitorLog.Position = UDim2.fromOffset(10, 9)
monitorLog.Size = UDim2.new(1, -20, 0, 250)
monitorLog.AutomaticSize = Enum.AutomaticSize.Y
monitorLog.BackgroundTransparency = 1
monitorLog.Text = "DETECTION LOG\n\nMenunggu aktivitas server..."
monitorLog.TextColor3 = THEME.Text
monitorLog.TextSize = 10
monitorLog.Font = Enum.Font.Code
monitorLog.TextXAlignment = Enum.TextXAlignment.Left
monitorLog.TextYAlignment = Enum.TextYAlignment.Top
monitorLog.TextWrapped = true
monitorLog.Parent = monitorScroll

local clearLog = makeButton(
    monitorCard,
    "🗑  CLEAR LOG",
    UDim2.new(0.62, 0, 1, -37),
    UDim2.new(0.38, -13, 0, 28),
    THEME.Surface2
)
clearLog.Activated:Connect(function()
    table.clear(monitorLines)
    monitorLog.Text = "DETECTION LOG\n\nLog dibersihkan. Menunggu aktivitas..."
end)

-- -----------------------------------------------------------------------------
-- 8C. FILTER TIER DAN BERAT MINIMUM
-- -----------------------------------------------------------------------------
local filtersPage = configPage
local filterCard = card(filtersPage, 232, THEME.Orange)
text(filterCard, "⚙  CATCH FILTERS", 10, 11, THEME.Orange, true)
local filterHint = text(filterCard, "Hanya tier tinggi yang tersedia di menu ini.", 35, 9, THEME.Muted)
filterHint.Size = UDim2.new(1, -26, 0, 18)

local rarityOrder = {"SECRET", "FORGOTTEN", "Mythic", "Legendary"}
local rarityButtons = {}
for i, name in ipairs(rarityOrder) do
    local b = Instance.new("TextButton")
    local row = math.floor((i-1)/2)
    local col = (i-1)%2
    b.Size = UDim2.new(0.5, -20, 0, 30)
    b.Position = UDim2.new(col*0.5, col == 0 and 13 or 7, 0, 62 + row*37)
    b.BackgroundColor3 = CONFIG.ALLOW_RARITY[name] and THEME.Green or THEME.Surface2
    b.BorderSizePixel = 0
    b.Text = name .. (CONFIG.ALLOW_RARITY[name] and "  ✓" or "  ×")
    b.TextColor3 = THEME.Text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 10
    b.Parent = filterCard
    addCorner(b, 7)
    addStroke(b, THEME.Border, 0.45)
    rarityButtons[name] = b
    
    b.Activated:Connect(function()
        CONFIG.ALLOW_RARITY[name] = not CONFIG.ALLOW_RARITY[name]
        b.BackgroundColor3 = CONFIG.ALLOW_RARITY[name] and THEME.Green or THEME.Surface2
        b.Text = name .. (CONFIG.ALLOW_RARITY[name] and "  ✓" or "  ×")
    end)
end

local minWeightInput = Instance.new("TextBox")
minWeightInput.Position = UDim2.new(0, 13, 0, 164)
minWeightInput.Size = UDim2.new(0.48, -16, 0, 30)
minWeightInput.Text = tostring(CONFIG.MIN_WEIGHT or 0)
minWeightInput.PlaceholderText = "0"
minWeightInput.ClearTextOnFocus = false
minWeightInput.BackgroundColor3 = THEME.Surface2
minWeightInput.BorderSizePixel = 0
minWeightInput.TextColor3 = THEME.Text
minWeightInput.TextSize = 10
minWeightInput.Font = Enum.Font.Code
minWeightInput.Parent = filterCard
addCorner(minWeightInput, 7)
addStroke(minWeightInput, THEME.Border, 0.45)

local minWeightLabel = text(filterCard, "MIN WEIGHT (KG)", 143, 9, THEME.Muted, true)
minWeightLabel.Position = UDim2.new(0.5, 4, 0, 168)
minWeightLabel.Size = UDim2.new(0.5, -17, 0, 22)
minWeightLabel.Text = "Weight filter aktif saat angka > 0"
minWeightLabel.TextXAlignment = Enum.TextXAlignment.Left

-- -----------------------------------------------------------------------------
-- 8D. WEBHOOK URL, NAMA, TOGGLE, DAN MAPPING DISCORD
-- -----------------------------------------------------------------------------
local webhookPage = makePage("Webhook")
local webhookCard = card(webhookPage, 226, THEME.Green)
text(webhookCard, "🔔 WEBHOOK ROUTING", 10, 11, THEME.Green, true)
local webhookHint = text(webhookCard, "URL catch dan join/leave terpisah; test dikirim ke URL catch.", 34, 9, THEME.Muted)
webhookHint.Size = UDim2.new(1, -26, 0, 18)

local function makeInput(parent, y, value, placeholder)
    local input = Instance.new("TextBox")
    input.Position = UDim2.new(0, 13, 0, y)
    input.Size = UDim2.new(1, -26, 0, 27)
    input.Text = value or ""
    input.PlaceholderText = placeholder
    input.ClearTextOnFocus = false
    input.BackgroundColor3 = THEME.Surface2
    input.BorderSizePixel = 0
    input.TextColor3 = THEME.Text
    input.PlaceholderColor3 = THEME.Muted
    input.TextSize = 10
    input.Font = Enum.Font.Code
    input.TextXAlignment = Enum.TextXAlignment.Left
    input.Parent = parent
    addCorner(input, 7)
    addStroke(input, THEME.Border, 0.45)
    return input
end

local webhookInput = makeInput(webhookCard, 57, CONFIG.WEBHOOK_URL, "Discord webhook URL (catch)")
local logWebhookInput = makeInput(webhookCard, 89, CONFIG.JOIN_LEAVE_URL, "Discord webhook URL (join/leave)")
local usernameInput = makeInput(webhookCard, 121, CONFIG.WEBHOOK_USERNAME, "Nama webhook")

local saveWebhook = makeButton(
    webhookCard,
    "✓  APPLY SETTINGS",
    UDim2.new(0, 13, 1, -35),
    UDim2.new(0.48, -17, 0, 28),
    THEME.Green
)
local testWebhook = makeButton(
    webhookCard,
    "✈  TEST WEBHOOK",
    UDim2.new(0.52, 4, 1, -35),
    UDim2.new(0.48, -17, 0, 28),
    THEME.Cyan
)
local infoUI = text(webhookCard, "Relay server sudah tertanam; isi URL Discord di atas.", 159, 9, THEME.Muted)

-- Preview lokal dihapus dari UI sesuai keputusan terakhir. Webhook asli tetap
-- dapat diuji dari tombol TEST WEBHOOK di atas.
mappingBox.Parent = webhookPage

-- -----------------------------------------------------------------------------
-- 8E. DIALOG MAPPING: SATU DISCORD ID, BANYAK AKUN ROBLOX
-- -----------------------------------------------------------------------------
local dialog = Instance.new("Frame")
local dialogViewport = getViewportSize()
local dialogWidth = math.floor(math.min(dialogViewport.X * 0.90, 560))
local dialogHeight = math.floor(math.min(dialogViewport.Y * 0.88, 455))
dialogWidth = math.max(320, dialogWidth)
dialogHeight = math.max(300, dialogHeight)
dialog.Size = UDim2.fromOffset(dialogWidth, dialogHeight)
dialog.AnchorPoint = Vector2.new(0.5, 0.5)
dialog.Position = UDim2.new(0.5, 0, 0.5, 0)
dialog.BackgroundColor3 = THEME.Surface
dialog.BorderSizePixel = 0
dialog.Visible = false
dialog.ZIndex = 50
dialog.Parent = gui
addCorner(dialog, 12)
addStroke(dialog, THEME.Purple, 0.15)

local dialogTitle = text(dialog, "SAMBUNGKAN AKUN KE DISCORD", 13, 13, THEME.Text, true)
dialogTitle.Position = UDim2.fromOffset(18, 12)
dialogTitle.Size = UDim2.new(1, -36, 0, 24)
dialogTitle.ZIndex = 51

local dialogSubtitle = text(dialog, "Pilih beberapa player aktif untuk satu Discord ID.", 43, 9, THEME.Muted)
dialogSubtitle.Position = UDim2.fromOffset(18, 41)
dialogSubtitle.Size = UDim2.new(1, -36, 0, 18)
dialogSubtitle.ZIndex = 51

local discordBox = mappingIdInput
local dialogIdLabel = text(dialog, "Discord ID: belum dipilih", 67, 10, THEME.Cyan, true)
dialogIdLabel.Position = UDim2.fromOffset(18, 67)
dialogIdLabel.Size = UDim2.new(1, -36, 0, 18)
dialogIdLabel.ZIndex = 51

local mappingSearch = Instance.new("TextBox")
mappingSearch.Position = UDim2.fromOffset(18, 94)
mappingSearch.Size = UDim2.new(0.62, -8, 0, 28)
mappingSearch.PlaceholderText = "Cari nama player..."
mappingSearch.Text = ""
mappingSearch.ClearTextOnFocus = false
mappingSearch.TextSize = 10
mappingSearch.Font = Enum.Font.Gotham
mappingSearch.TextColor3 = THEME.Text
mappingSearch.PlaceholderColor3 = THEME.Muted
mappingSearch.BackgroundColor3 = THEME.Surface2
mappingSearch.BorderSizePixel = 0
mappingSearch.ZIndex = 51
mappingSearch.Parent = dialog
addCorner(mappingSearch, 7)
addStroke(mappingSearch, THEME.Border, 0.45)

local selectedCountText = text(dialog, "0 akun dipilih", 108, 9, THEME.Cyan, true)
selectedCountText.Position = UDim2.new(0.64, 4, 0, 97)
selectedCountText.Size = UDim2.new(0.36, -22, 0, 22)
selectedCountText.TextXAlignment = Enum.TextXAlignment.Right
selectedCountText.ZIndex = 51

local dropdownList = Instance.new("ScrollingFrame")
dropdownList.Size = UDim2.new(1, -36, 0, math.max(90, dialogHeight - 194))
dropdownList.Position = UDim2.fromOffset(18, 128)
dropdownList.BackgroundColor3 = Color3.fromRGB(11, 15, 26)
dropdownList.BorderSizePixel = 0
dropdownList.Active = true
dropdownList.ScrollBarThickness = 3
dropdownList.ScrollBarImageColor3 = THEME.Cyan
dropdownList.ZIndex = 52
dropdownList.Visible = false
dropdownList.CanvasSize = UDim2.new()
dropdownList.AutomaticCanvasSize = Enum.AutomaticSize.Y
dropdownList.Parent = dialog
addCorner(dropdownList, 8)
local dropdownLayout = Instance.new("UIListLayout")
dropdownLayout.Padding = UDim.new(0, 4)
dropdownLayout.Parent = dropdownList

local mappingDialogStatus = text(dialog, "Pilih player dari daftar aktif.", dialogHeight - 65, 9, THEME.Muted)
mappingDialogStatus.Position = UDim2.fromOffset(18, dialogHeight - 65)
mappingDialogStatus.Size = UDim2.new(1, -36, 0, 18)
mappingDialogStatus.ZIndex = 51

local mapSave = makeButton(
    dialog,
    "✓  SAVE MAPPING",
    UDim2.fromOffset(18, dialogHeight - 37),
    UDim2.new(0.48, -22, 0, 30),
    THEME.Green
)
mapSave.ZIndex = 51
local mapCancel = makeButton(
    dialog,
    "CANCEL",
    UDim2.new(0.52, 4, 0, dialogHeight - 37),
    UDim2.new(0.48, -22, 0, 30),
    THEME.Red
)
mapCancel.ZIndex = 51
-- =============================================================================
-- BAGIAN 9 : INTERAKSI TAB, HIDE, DRAGGING, DAN MAPPING FUNGSI
-- =============================================================================
-- FUNGSI: Mengaktifkan refresh data, mapping multi-akun, manual save/load,
-- navigasi empat tab, hide, dan drag pada header/ikon.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 9A. SERVER PLAYER LIST DAN STATISTIK
-- -----------------------------------------------------------------------------
local uiStartedAt = os.clock()

local function clearPlayerRows(scroll)
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") or child:IsA("TextButton") then
            child:Destroy()
        end
    end
end

local function addPlayerRow(scroll, player, index, compact)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -6, 0, compact and 21 or 29)
    row.BackgroundColor3 = index % 2 == 0 and Color3.fromRGB(18, 23, 38) or Color3.fromRGB(14, 19, 32)
    row.BorderSizePixel = 0
    row.Parent = scroll
    addCorner(row, 5)

    local dot = Instance.new("Frame")
    dot.Position = UDim2.fromOffset(8, compact and 7 or 10)
    dot.Size = UDim2.fromOffset(7, 7)
    dot.BackgroundColor3 = THEME.Green
    dot.BorderSizePixel = 0
    dot.Parent = row
    addCorner(dot, 4)

    local label = Instance.new("TextLabel")
    label.Position = UDim2.fromOffset(23, compact and 2 or 5)
    label.Size = UDim2.new(1, -31, 1, -4)
    label.BackgroundTransparency = 1
    label.Text = compact
        and ("@" .. player.Name)
        or ("@" .. player.Name .. "   •   " .. tostring(player.DisplayName or player.Name))
    label.TextColor3 = THEME.Text
    label.TextSize = compact and 9 or 10
    label.Font = compact and Enum.Font.Code or Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.Parent = row
end

local function populatePlayerScroll(scroll, playerList, compact)
    clearPlayerRows(scroll)

    if #playerList == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, -12, 0, 25)
        empty.BackgroundTransparency = 1
        empty.Text = "Belum ada player aktif."
        empty.TextColor3 = THEME.Muted
        empty.TextSize = 9
        empty.Font = Enum.Font.Gotham
        empty.Parent = scroll
        return
    end

    for index, player in ipairs(playerList) do
        addPlayerRow(scroll, player, index, compact)
    end
end

refreshPlayerList = function()
    local playerList = Players:GetPlayers()
    table.sort(playerList, function(a, b)
        return a.Name:lower() < b.Name:lower()
    end)

    populatePlayerScroll(playersListScroll, playerList, false)
end

updateServerStats = function()
    local total = #Players:GetPlayers()
    state.ServerPlayers = total

    local jobId = tostring(game.JobId or "")
    if jobId == "" then jobId = "unavailable" end

    playersCountText.Text = string.format("%d pemain aktif", total)
    playersJobText.Text = "JobId: " .. jobId
    homeStats.Text = string.format(
        "Detected %d  •  Sent %d",
        state.Detected,
        state.Sent
    )
    homePlayersMetric.Text = tostring(total)
    homeFishMetric.Text = tostring(FishDatabaseTotal)
    homeWebhookMetric.Text = tostring(state.WebhooksSent or 0)
    homeDetectedMetric.Text = tostring(state.Detected)

    local elapsed = math.max(0, math.floor(os.clock() - uiStartedAt))
    local minutes = math.floor(elapsed / 60)
    local seconds = elapsed % 60
    homeRuntime.Text = string.format("Runtime: %02d:%02d  •  server live", minutes, seconds)
    headerStatus.Text = "● LIVE  " .. tostring(total)
end

-- -----------------------------------------------------------------------------
-- 9B. MAPPING: SATU DISCORD ID DAPAT MENTION BANYAK AKUN ROBLOX
-- -----------------------------------------------------------------------------
local selectedPlayers = {}

local function updateSelectedPlayerCount()
    local total = 0
    for _, selected in pairs(selectedPlayers) do
        if selected then total = total + 1 end
    end
    selectedCountText.Text = tostring(total) .. " akun dipilih"
end

local function refreshMappingPlayerList()
    for _, child in ipairs(dropdownList:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    local query = trim(mappingSearch.Text):lower()
    local currentDiscordId = normalizeDiscordId(discordBox.Text)
    local claimedPlayers = {}
    for mappedDiscordId, playerNames in pairs(mappings) do
        if tostring(mappedDiscordId) ~= currentDiscordId and type(playerNames) == "table" then
            for _, mappedName in ipairs(playerNames) do
                claimedPlayers[normalizePlayerName(mappedName)] = true
            end
        end
    end

    local playerList = Players:GetPlayers()
    table.sort(playerList, function(a, b)
        return a.Name:lower() < b.Name:lower()
    end)

    local displayed = 0
    local hiddenClaimed = 0
    for _, player in ipairs(playerList) do
        local selected = selectedPlayers[player.Name] == true
        local matchesQuery = query == "" or player.Name:lower():find(query, 1, true)
            or tostring(player.DisplayName or ""):lower():find(query, 1, true)
        local alreadyMapped = claimedPlayers[normalizePlayerName(player.Name)] == true

        if matchesQuery and (selected or not alreadyMapped) then
            displayed = displayed + 1

            local playerButton = Instance.new("TextButton")
            playerButton.Size = UDim2.new(1, -10, 0, 31)
            playerButton.BackgroundColor3 = selected and Color3.fromRGB(25, 75, 75) or THEME.Surface2
            playerButton.BorderSizePixel = 0
            playerButton.Text = (selected and "✓  " or "＋  ") .. player.Name
                .. "   •   " .. tostring(player.DisplayName or player.Name)
            playerButton.TextColor3 = selected and THEME.Green or THEME.Text
            playerButton.TextSize = 10
            playerButton.Font = Enum.Font.GothamSemibold
            playerButton.TextXAlignment = Enum.TextXAlignment.Left
            playerButton.TextTruncate = Enum.TextTruncate.AtEnd
            playerButton.ZIndex = 53
            playerButton.Parent = dropdownList
            addCorner(playerButton, 6)

            playerButton.Activated:Connect(function()
                selectedPlayers[player.Name] = not selectedPlayers[player.Name]
                updateSelectedPlayerCount()
                refreshMappingPlayerList()
            end)
        elseif matchesQuery and alreadyMapped then
            hiddenClaimed = hiddenClaimed + 1
        end
    end

    if displayed == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, -10, 0, 30)
        empty.BackgroundTransparency = 1
        empty.Text = #playerList == 0
            and "Tidak ada player aktif."
            or (hiddenClaimed == #playerList and "Semua player sudah terhubung ke ID lain."
                or "Player tidak ditemukan.")
        empty.TextColor3 = THEME.Muted
        empty.TextSize = 10
        empty.Font = Enum.Font.Gotham
        empty.ZIndex = 53
        empty.Parent = dropdownList
    end

    updateSelectedPlayerCount()
end

local function loadExistingMappingSelection()
    local discordId = normalizeDiscordId(discordBox.Text)
    if discordId == "" then return end

    table.clear(selectedPlayers)
    local existing = mappings[discordId]
    if type(existing) == "table" then
        for _, mappedName in ipairs(existing) do
            for _, player in ipairs(Players:GetPlayers()) do
                if playerNamesMatch(mappedName, player.Name, player) then
                    selectedPlayers[player.Name] = true
                end
            end
        end
    end
    refreshMappingPlayerList()
end

refreshMappings = function()
    for _, child in ipairs(mappingRows:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    local normalized = normalizeMappings(mappings)
    local discordIds = {}

    for discordId, playerList in pairs(normalized) do
        table.sort(playerList, function(a, b)
            return tostring(a):lower() < tostring(b):lower()
        end)
        table.insert(discordIds, tostring(discordId))
    end

    table.sort(discordIds)

    if #discordIds == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, 0, 0, 30)
        empty.BackgroundTransparency = 1
        empty.Text = "Belum ada mapping. Isi Discord ID lalu klik LIST PLAYER."
        empty.TextColor3 = THEME.Muted
        empty.TextSize = 9
        empty.Font = Enum.Font.Gotham
        empty.TextXAlignment = Enum.TextXAlignment.Left
        empty.TextYAlignment = Enum.TextYAlignment.Center
        empty.TextWrapped = true
        empty.LayoutOrder = 1
        empty.Parent = mappingRows
        return
    end

    for index, discordId in ipairs(discordIds) do
        local playerList = normalized[discordId] or {}
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 38)
        row.BackgroundColor3 = index % 2 == 0
            and Color3.fromRGB(18, 23, 38)
            or Color3.fromRGB(14, 19, 32)
        row.BorderSizePixel = 0
        row.LayoutOrder = index
        row.Parent = mappingRows
        addCorner(row, 6)

        local label = Instance.new("TextLabel")
        label.Position = UDim2.fromOffset(9, 3)
        label.Size = UDim2.new(1, -62, 1, -6)
        label.BackgroundTransparency = 1
        label.Text = "<@" .. discordId .. ">  ←  " .. table.concat(playerList, ", ")
        label.TextColor3 = THEME.Text
        label.TextSize = 9
        label.Font = Enum.Font.Code
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.TextWrapped = true
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.Parent = row

        local removeButton = makeButton(
            row,
            "×",
            UDim2.new(1, -48, 0, 5),
            UDim2.fromOffset(40, 28),
            THEME.Red
        )
        removeButton.TextSize = 16
        removeButton.TextColor3 = Color3.fromRGB(255, 255, 255)

        removeButton.Activated:Connect(function()
            if mappings[discordId] == nil then return end

            mappings[discordId] = nil
            refreshMappings()
            mappingLogStatus.TextColor3 = THEME.Orange
            mappingLogStatus.Text = "Mapping dihapus. Tekan CONFIG → SAVE untuk menyimpan."
            appendMonitorLog("🗑", "Mapping dihapus: <@" .. discordId .. ">")
        end)
    end
end

mappingSearch:GetPropertyChangedSignal("Text"):Connect(function()
    if dialog.Visible then refreshMappingPlayerList() end
end)
discordBox.FocusLost:Connect(function()
    loadExistingMappingSelection()
end)

addMapping.Activated:Connect(function()
    table.clear(selectedPlayers)
    mappingSearch.Text = ""
    local discordId = normalizeDiscordId(discordBox.Text)
    if discordId == "" then
        mappingLogStatus.TextColor3 = THEME.Orange
        mappingLogStatus.Text = "Masukkan Discord ID terlebih dahulu."
        return
    end

    loadExistingMappingSelection()
    dialogIdLabel.Text = "Discord ID: " .. discordId
    mappingDialogStatus.Text = "Pilih satu atau beberapa player aktif."
    mappingDialogStatus.TextColor3 = THEME.Muted
    dialog.Visible = true
    dropdownList.Visible = true
    refreshMappingPlayerList()
end)

mapCancel.Activated:Connect(function()
    dialog.Visible = false
    dropdownList.Visible = false
    table.clear(selectedPlayers)
end)

mapSave.Activated:Connect(function()
    local discordId = normalizeDiscordId(discordBox.Text)
    local playerNames = {}

    for playerName, selected in pairs(selectedPlayers) do
        if selected then table.insert(playerNames, playerName) end
    end
    table.sort(playerNames, function(a, b) return a:lower() < b:lower() end)

    if discordId == "" then
        mappingDialogStatus.Text = "Discord ID wajib berupa angka."
        mappingDialogStatus.TextColor3 = THEME.Red
        return
    end
    if #playerNames == 0 then
        mappingDialogStatus.Text = "Pilih minimal satu akun Roblox."
        mappingDialogStatus.TextColor3 = THEME.Red
        return
    end

    mappings[discordId] = playerNames
    refreshMappings()
    mappingLogStatus.TextColor3 = THEME.Green
    mappingLogStatus.Text = "Mapping diperbarui. Tekan CONFIG → SAVE untuk menyimpan."
    mappingDialogStatus.Text = "Mapping tersimpan."
    mappingDialogStatus.TextColor3 = THEME.Green
    dialog.Visible = false
    dropdownList.Visible = false
    table.clear(selectedPlayers)
end)

-- -----------------------------------------------------------------------------
-- 9C. SAVE / LOAD SLOT DAN PENGATURAN INPUT
-- -----------------------------------------------------------------------------
local function updateWebhookToggleUI()
    local enabled = CONFIG.WEBHOOK_ENABLED ~= false
    homeWebhookToggle.Text = enabled and "WEBHOOK ON" or "WEBHOOK OFF"
    homeWebhookToggle.BackgroundColor3 = enabled and THEME.Green or THEME.Surface2
end

homeWebhookToggle.Activated:Connect(function()
    CONFIG.WEBHOOK_ENABLED = not (CONFIG.WEBHOOK_ENABLED ~= false)
    updateWebhookToggleUI()
    appendMonitorLog(
        CONFIG.WEBHOOK_ENABLED and "✅" or "⏸",
        CONFIG.WEBHOOK_ENABLED and "Webhook diaktifkan" or "Webhook dimatikan"
    )
end)

local function syncInputsFromConfig()
    webhookInput.Text = CONFIG.WEBHOOK_URL or ""
    logWebhookInput.Text = CONFIG.JOIN_LEAVE_URL or ""
    usernameInput.Text = CONFIG.WEBHOOK_USERNAME or ""
    minWeightInput.Text = tostring(CONFIG.MIN_WEIGHT or 0)

    for rarityName, button in pairs(rarityButtons) do
        local enabled = CONFIG.ALLOW_RARITY[rarityName] == true
        button.BackgroundColor3 = enabled and THEME.Green or THEME.Surface2
        button.Text = rarityName .. (enabled and "  ✓" or "  ×")
    end

    updateWebhookToggleUI()
end

local function slotFileName(slot)
    if slot == 1 then return CONFIG_FILE_1 end
    if slot == 2 then return CONFIG_FILE_2 end
    return CONFIG_FILE_3
end

slotBtn.Activated:Connect(function()
    activeSlot = activeSlot % 3 + 1
    slotBtn.Text = "📁 SLOT " .. tostring(activeSlot) .. "  ▼"
    storageMsg.Text = "Slot aktif: " .. slotFileName(activeSlot)
end)

saveBtn.Activated:Connect(function()
    local ok, message = manualSave(activeSlot)
    storageMsg.TextColor3 = ok and THEME.Green or THEME.Red
    storageMsg.Text = ok and ("✓ " .. message) or ("✕ " .. message)
end)

loadBtn.Activated:Connect(function()
    local ok, message = manualLoad(activeSlot)
    if ok then
        syncInputsFromConfig()
        refreshMappings()
    end
    storageMsg.TextColor3 = ok and THEME.Green or THEME.Red
    storageMsg.Text = ok and ("✓ " .. message) or ("✕ " .. message)
end)

minWeightInput.FocusLost:Connect(function()
    local number = tonumber(trim(minWeightInput.Text))
    if number and number >= 0 then
        CONFIG.MIN_WEIGHT = number
        minWeightInput.Text = tostring(number)
    else
        minWeightInput.Text = tostring(CONFIG.MIN_WEIGHT or 0)
    end
end)

-- -----------------------------------------------------------------------------
-- 9D. KONTROL WEBHOOK DAN TEST ROUTING
-- -----------------------------------------------------------------------------
local function formatWeightText(weight)
    local value = tonumber(weight) or 0
    if value >= 1000000000 then return string.format("%.2fB kg", value / 1000000000) end
    if value >= 1000000 then return string.format("%.2fM kg", value / 1000000) end
    if value >= 1000 then return string.format("%.2fK kg", value / 1000) end
    return string.format("%.2f kg", value)
end

local function formatChanceText(chance)
    local value = trim(chance)
    if value == "" then return "chance unknown" end
    if value:lower():sub(1, 4) == "1 in" then return value end
    return "1 in " .. value
end

local function applyWebhookSettings()
    CONFIG.WEBHOOK_URL = trim(webhookInput.Text)
    CONFIG.JOIN_LEAVE_URL = trim(logWebhookInput.Text)
    CONFIG.WEBHOOK_USERNAME = trim(usernameInput.Text)
end

saveWebhook.Activated:Connect(function()
    applyWebhookSettings()
    infoUI.TextColor3 = THEME.Green
    infoUI.Text = "✓ URL catch dan URL join/leave diterapkan sementara."
end)

testWebhook.Activated:Connect(function()
    applyWebhookSettings()

    local testData = {
        Player = LocalPlayer and LocalPlayer.Name or "AnnaaXcatto",
        Fish = "Outlaw Seahorse",
        RawFish = "STONE Outlaw Seahorse",
        Variant = "STONE",
        Mutation = "STONE",
        Weight = 5.5,
        Chance = "1 in 6K",
        VariantColor = {177, 177, 177},
        RarityColor = {255, 185, 43},
        _assetId = "124725082467333",
    }

    if CONFIG.WEBHOOK_URL == "" then
        infoUI.TextColor3 = THEME.Orange
        infoUI.Text = "URL catch masih kosong."
        return
    end

    local sent = sendWebhook(testData)
    infoUI.TextColor3 = sent and THEME.Green or THEME.Orange
    infoUI.Text = sent
        and "Pesan mention + card dikirim ke relay catch."
        or "Test webhook gagal atau sedang OFF."
end)

-- -----------------------------------------------------------------------------
-- 9E. EMPAT TAB, HIDE, DAN DRAG
-- -----------------------------------------------------------------------------
local function setActiveTab(name)
    activeTab = name
    for pageName, page in pairs(pages) do
        page.Visible = pageName == activeTab
    end
    for tabName, tab in pairs(tabs) do
        local active = tabName == activeTab
        tab.TextColor3 = active and THEME.Text or THEME.Muted
        tab.BackgroundTransparency = active and 0 or 1
        tab.BackgroundColor3 = active and Color3.fromRGB(45, 45, 75) or THEME.Surface2
    end
end

-- Hanya empat menu yang ditampilkan sesuai rancangan Android landscape.
local tabNames = { {"⌂", "Home"}, {"🔔", "Webhook"}, {"◈", "Log"}, {"⚙", "Config"} }
for i, item in ipairs(tabNames) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -16, 0, 42)
    b.LayoutOrder = i
    b.BackgroundTransparency = 1
    b.BackgroundColor3 = THEME.Surface2
    b.BorderSizePixel = 0
    -- Satu baris lebih mudah dibaca dan ditekan pada layar landscape.
    b.Text = item[1] .. "  " .. item[2]
    b.TextSize = 9
    b.Font = Enum.Font.GothamBold 
    b.TextColor3 = THEME.Muted
    b.TextTruncate = Enum.TextTruncate.AtEnd
    b.AutoButtonColor = true
    b.Parent = tabbar 
    tabs[item[2]] = b 
    addCorner(b, 7)
    addStroke(b, THEME.Border, 0.65)
    b.Activated:Connect(function()
        setActiveTab(item[2])
    end)
end
setActiveTab("Home")

-- Hide: panel utama tetap menyimpan posisi dan ukuran terakhir. Ikon kecil
-- berada di luar panel agar masih dapat ditekan dan digeser di Android.
local hidden = false
local expandedMainPosition = main.Position
local hideDragging, hideDragInput, hideDragStart, hideIconStart, hideDragMoved

local function showMainPanel()
    hidden = false
    main.Size = normalMainSize
    main.Position = expandedMainPosition
    main.Visible = true
    hideIcon.Visible = false
    tabbar.Visible = true
    for name, page in pairs(pages) do
        page.Visible = name == activeTab
    end
end

local function hideMainPanel()
    expandedMainPosition = main.Position
    hidden = true
    dialog.Visible = false
    dropdownList.Visible = false
    main.Visible = false
    hideIcon.Visible = true
end

hideButton.Activated:Connect(hideMainPanel)
hideIcon.Activated:Connect(function()
    -- Dragging a TextButton di touch screen juga dapat memicu Activated.
    -- Abaikan tap yang merupakan akhir dari gerakan drag.
    if hideDragMoved then
        hideDragMoved = false
        return
    end
    showMainPanel()
end)

-- Android dapat berpindah orientasi ketika game berjalan. Recalculate semua
-- ukuran utama dan dialog agar UI tidak terpotong setelah rotate ke landscape.
local function applyResponsiveLayout()
    normalMainSize = getResponsiveMainSize()
    main.Size = normalMainSize

    local viewport = getViewportSize()
    navWidth = viewport.X < 760 and 108 or 132
    tabbar.Size = UDim2.new(0, navWidth, 1, -70)
    for _, page in pairs(pages) do
        page.Position = UDim2.new(0, navWidth + 20, 0, 60)
        page.Size = UDim2.new(1, -navWidth - 32, 1, -72)
    end

    dialogWidth = math.floor(math.min(viewport.X * 0.90, 560))
    dialogHeight = math.floor(math.min(viewport.Y * 0.88, 455))
    dialogWidth = math.max(320, dialogWidth)
    dialogHeight = math.max(300, dialogHeight)
    dialog.Size = UDim2.fromOffset(dialogWidth, dialogHeight)

    dropdownList.Size = UDim2.new(1, -36, 0, math.max(90, dialogHeight - 206))
    mappingDialogStatus.Position = UDim2.fromOffset(18, dialogHeight - 65)
    mapSave.Position = UDim2.fromOffset(18, dialogHeight - 37)
    mapCancel.Position = UDim2.new(0.52, 4, 0, dialogHeight - 37)
end

local currentCamera = workspace.CurrentCamera
if currentCamera then
    currentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        task.defer(applyResponsiveLayout)
    end)
end

-- Dragging panel besar dan ikon HIDE.
local dragging, dragInput, dragStart, startPos
hideDragMoved = false
header.InputBegan:Connect(function(input) 
    if not hidden and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then 
        dragging = true 
        dragInput = input 
        dragStart = input.Position 
        startPos = main.Position 
    end 
end)
hideIcon.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        hideDragging = true
        hideDragInput = input
        hideDragStart = input.Position
        hideIconStart = hideIcon.Position
        hideDragMoved = false
    end
end)
UIS.InputChanged:Connect(function(input) 
    if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then 
        local delta = input.Position - dragStart 
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) 
    end 
    if hideDragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local delta = input.Position - hideDragStart
        if math.abs(delta.X) > 3 or math.abs(delta.Y) > 3 then
            hideDragMoved = true
        end
        hideIcon.Position = UDim2.new(
            hideIconStart.X.Scale,
            hideIconStart.X.Offset + delta.X,
            hideIconStart.Y.Scale,
            hideIconStart.Y.Offset + delta.Y
        )
    end
end)
UIS.InputEnded:Connect(function(input) 
    if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 then 
        dragging = false 
    end 
    if input == hideDragInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
        hideDragging = false
        hideDragInput = nil
        if hideDragMoved then
            task.delay(0.20, function()
                if not hideDragging then
                    hideDragMoved = false
                end
            end)
        end
    end
end)
-- =============================================================================
-- BAGIAN 10 : REAL-TIME INTERCEPTOR (DIPERBAIKI UNTUK CHAT SERVER)
-- =============================================================================
-- FUNGSI: Menangkap chat server RichText, menggabungkan log catch dengan
-- join/leave, memperbarui statistik player, dan menjalankan loop live.
-- =============================================================================

local function updateUI(data, lineInfo)
    state.Detected = state.Detected + 1
    state.Last = data
    homeLastText.Text = "📋 LAST ACTIVITY:\n" .. lineInfo
    appendMonitorLog("🎣", lineInfo)
    pcall(updateServerStats)
end

local function handleMessage(text)
    local data = parseCatch(text)
    if not data then return end
    local displayWeight = formatWeightText(data.Weight)
    local variantInfo = data.Variant and (" [" .. data.Variant .. "]") or ""
    local lineInfo = string.format(
        "👤 %s caught%s %s (%s) [%s]",
        data.Player,
        variantInfo,
        data.Fish,
        displayWeight,
        formatChanceText(data.Chance)
    )
    updateUI(data, lineInfo)
    sendWebhook(data)
    pcall(updateServerStats)
end

-- =============================================================================
-- [PERBAIKIAN UTAMA] Cara hook chat server yang lebih robust
-- =============================================================================
local function setupChatHook()
    -- MessageReceived adalah event pembaca pesan masuk.
    local success, connection = pcall(function()
        return TextChatService.MessageReceived:Connect(function(message)
            if message and message.Text and message.Text ~= "" then
                pcall(function()
                    handleMessage(message.Text)
                end)
            end
        end)
    end)

    if success and connection then
        print("[Radar] ✅ Hook ke TextChatService.MessageReceived")
        logError("✅ Hook chat aktif (TextChatService.MessageReceived)")
        return true
    end

    print("[Radar] ❌ Gagal memasang hook TextChatService.MessageReceived")
    logError("❌ Hook chat gagal dipasang")
    return false
end
    
-- Jalankan hook
setupChatHook()

-- =============================================================================
-- PLAYER JOIN / LEAVE: UI LOG GABUNG, WEBHOOK TETAP TERPISAH
-- =============================================================================
-- Saat client sendiri disconnect, Roblox dapat memicu PlayerRemoving untuk
-- banyak objek Player sekaligus. Tandai kondisi tersebut dan hanya kirim
-- webhook LEAVE untuk LocalPlayer agar tidak ada leave palsu massal.
local clientExiting = false
local localLeaveReported = false

pcall(function()
    if LocalPlayer then
        LocalPlayer.AncestryChanged:Connect(function(_, parent)
            if parent == nil then
                clientExiting = true
            end
        end)
    end
end)

Players.PlayerAdded:Connect(function(player)
    local logLine = "📥 Player Masuk: " .. player.Name
    homeLastText.Text = "📋 LAST ACTIVITY:\n" .. logLine
    appendMonitorLog("📥", logLine)
    pcall(refreshPlayerList)
    pcall(updateServerStats)
    pcall(function() sendJoinLeaveWebhook(player, "JOINED") end)
end)

Players.PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then
        clientExiting = true
        if localLeaveReported then return end
        localLeaveReported = true

        local logLine = "📤 Player Keluar: " .. player.Name
        homeLastText.Text = "📋 LAST ACTIVITY:\n" .. logLine
        appendMonitorLog("📤", logLine)
        pcall(refreshPlayerList)
        pcall(updateServerStats)
        pcall(function() sendJoinLeaveWebhook(player, "LEFT") end)
        return
    end

    -- Beri kesempatan event LocalPlayer.PlayerRemoving/AncestryChanged
    -- menandai disconnect sebelum memproses player lain.
    task.delay(0.10, function()
        if clientExiting or not LocalPlayer or not LocalPlayer.Parent then
            return
        end

        local logLine = "📤 Player Keluar: " .. player.Name
        homeLastText.Text = "📋 LAST ACTIVITY:\n" .. logLine
        appendMonitorLog("📤", logLine)
        pcall(refreshPlayerList)
        pcall(updateServerStats)
        pcall(function() sendJoinLeaveWebhook(player, "LEFT") end)
    end)
end)

-- =============================================================================
-- LOOP UPDATE STATISTIK
-- =============================================================================
task.spawn(function()
    while state.Running do
        pcall(function()
            refreshPlayerList()
            updateServerStats()
        end)
        task.wait(2)
    end
end)

refreshMappings()
refreshPlayerList()
updateServerStats()
print("[LFAMILIA MONITOR] Fully Fixed!")
