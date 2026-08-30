-- LFAMILIA MONITOR V1 - FIXED LOADER
-- Menjaga semua fungsi LFAMILIA_MONITORV1.lua tetap utuh, lalu memasang patch:
-- 1) Shiny / Big / Small / dst bukan mutation/variant.
-- 2) Kombinasi modifier bertumpuk tetap bisa lookup Id/AssetId.
-- 3) Filter khusus RUBY + GEMSTONE.
-- 4) UI lebih rapi dengan border dan divider yang lebih jelas.

local SOURCE_URL = "https://raw.githubusercontent.com/muhammadaldy198/LFAMILIA/refs/heads/main/LFAMILIA_MONITORV1.lua"

local source = game:HttpGet(SOURCE_URL)
assert(type(source) == "string" and source ~= "", "[LFAMILIA FIX] Gagal mengambil source monitor asli")

local function replacePlain(text, oldText, newText, label)
    local startPos, endPos = string.find(text, oldText, 1, true)
    if not startPos then
        error("[LFAMILIA FIX] Patch gagal menemukan bagian: " .. tostring(label))
    end

    return text:sub(1, startPos - 1)
        .. newText
        .. text:sub(endPos + 1)
end

-- =============================================================================
-- PATCH A : CONFIG + SAVE/LOAD FILTER RUBY GEMSTONE
-- =============================================================================
source = replacePlain(
    source,
    [[    BANNER_URL = "https://i.imgur.com/42wd0m0.png",
}]],
    [[    BANNER_URL = "https://i.imgur.com/42wd0m0.png",
    SPECIAL_FILTERS = {
        RUBY_GEMSTONE = true,
    },
}]],
    "special filter config"
)

source = replacePlain(
    source,
    [[            WEBHOOK_USERNAME = CONFIG.WEBHOOK_USERNAME,
        },]],
    [[            WEBHOOK_USERNAME = CONFIG.WEBHOOK_USERNAME,
            SPECIAL_FILTERS = CONFIG.SPECIAL_FILTERS,
        },]],
    "save special filter"
)

source = replacePlain(
    source,
    [[        if type(data.CONFIG.WEBHOOK_USERNAME) == "string" then
            CONFIG.WEBHOOK_USERNAME = data.CONFIG.WEBHOOK_USERNAME
        end

        -- Hanya empat rarity yang diizinkan; rarity lama tidak dimuat kembali.]],
    [[        if type(data.CONFIG.WEBHOOK_USERNAME) == "string" then
            CONFIG.WEBHOOK_USERNAME = data.CONFIG.WEBHOOK_USERNAME
        end

        if type(data.CONFIG.SPECIAL_FILTERS) == "table" then
            CONFIG.SPECIAL_FILTERS = CONFIG.SPECIAL_FILTERS or {}
            CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE = data.CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE ~= false
        end

        -- Hanya empat rarity yang diizinkan; rarity lama tidak dimuat kembali.]],
    "load special filter"
)

-- =============================================================================
-- PATCH B : DISPLAY-ONLY MODIFIERS + VARIANT PARSER
-- =============================================================================
source = replacePlain(
    source,
    [[local function parseCatch(message)]],
    [[local DISPLAY_ONLY_CATCH_MODIFIERS = {
    shiny = true,
    big = true,
    small = true,
    tiny = true,
    huge = true,
    massive = true,
    large = true,
    giant = true,
    mini = true,
}

local function isDisplayOnlyCatchModifier(text)
    local value = trim(text):lower()
    if value == "" then return false end

    local total = 0
    for word in value:gmatch("%S+") do
        total = total + 1
        if not DISPLAY_ONLY_CATCH_MODIFIERS[word] then
            return false
        end
    end

    return total > 0
end

-- Variant boleh muncul setelah modifier tampilan.
-- Gemstone Big Shiny Ruby -> Big Shiny Ruby + variant Gemstone
-- Big Shiny Gemstone Ruby -> Big Shiny Ruby + variant Gemstone
local function getVariantFromCatchName(text)
    local requested = trim(text)

    local directName, directFish, directData = getVariantFromName(requested)
    if directName then
        return directName, directFish, directData
    end

    local displayWords = {}
    local current = requested

    while true do
        local firstWord, remainder = current:match("^(%S+)%s+(.+)$")
        if not firstWord or not remainder then break end
        if not DISPLAY_ONLY_CATCH_MODIFIERS[firstWord:lower()] then break end

        table.insert(displayWords, firstWord)
        current = trim(remainder)
    end

    local variantName, strippedFish, variantData = getVariantFromName(current)
    if variantName then
        local cleanFish = strippedFish
        if #displayWords > 0 then
            cleanFish = table.concat(displayWords, " ") .. " " .. strippedFish
        end
        return variantName, trim(cleanFish), variantData
    end

    return nil, requested, nil
end

local function parseCatch(message)]],
    "display modifier helpers"
)

source = replacePlain(
    source,
    [[        variantName, cleanFish = getVariantFromName(caughtText)]],
    [[        variantName, cleanFish = getVariantFromCatchName(caughtText)]],
    "variant after display modifier"
)

source = replacePlain(
    source,
    [[            if index > 1 and not span.Text:find("%([^)]-%)") then]],
    [[            if index > 1
                and not span.Text:find("%([^)]-%)")
                and not isDisplayOnlyCatchModifier(span.Text) then]],
    "variant fallback display guard"
)

-- =============================================================================
-- PATCH C : RESOLVER ASSET UNTUK SHINY + STACKED MODIFIERS
-- =============================================================================
source = replacePlain(
    source,
    [[local FISH_SIZE_PREFIXES = {
    "big",
    "small",
    "tiny",
    "huge",
    "massive",
    "large",
    "giant",
    "mini",
}]],
    [[local FISH_SIZE_PREFIXES = {
    "big",
    "small",
    "tiny",
    "huge",
    "massive",
    "large",
    "giant",
    "mini",
    "shiny",
}]],
    "Shiny lookup modifier"
)

source = replacePlain(
    source,
    [[local function getDatabaseFishNameWithoutSize(name)
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
end]],
    [[local function isSizeOrDisplayPrefix(word)
    local wanted = tostring(word or ""):lower()
    for _, sizePrefix in ipairs(FISH_SIZE_PREFIXES) do
        if wanted == sizePrefix then
            return true
        end
    end
    return false
end

local function getDatabaseFishNameWithoutSize(name)
    local requested = trim(name)
    if requested == "" then return requested end

    -- Exact match selalu nomor satu. Ini melindungi nama asli seperti Giant Squid.
    local _, exactRealName = findFishExact(requested)
    if exactRealName then
        return exactRealName
    end

    local current = requested

    while true do
        local firstWord, remainder = current:match("^(%S+)%s+(.+)$")
        if not firstWord or not remainder then break end
        if not isSizeOrDisplayPrefix(firstWord) then break end
        current = trim(remainder)

        local _, realName = findFishExact(current)
        if realName then
            return realName
        end
    end

    -- Kembalikan candidate yang sudah dibuang modifier depan supaya resolver
    -- masih bisa mendeteksi Variant sesudah Big/Shiny.
    return current
end

local function resolveFish(name)
    local requested = trim(name)
    local data, realName = findFishExact(requested)
    if data then return data, realName, nil end

    local displayStripped = getDatabaseFishNameWithoutSize(requested)
    if displayStripped ~= requested then
        data, realName = findFishExact(displayStripped)
        if data then return data, realName, nil end
    end

    -- Coba variant pada nama asli DAN nama setelah Big/Shiny/dll dilepas.
    local candidates = {requested}
    if displayStripped ~= requested then
        table.insert(candidates, displayStripped)
    end

    for _, candidate in ipairs(candidates) do
        local candidateLower = candidate:lower()

        for _, v in pairs(VariantDatabase) do
            if type(v) == "table" and v.Name then
                local prefix = tostring(v.Name):lower() .. " "

                if candidateLower:sub(1, #prefix) == prefix then
                    local stripped = trim(candidate:sub(#prefix + 1))

                    data, realName = findFishExact(stripped)
                    if data then return data, realName, v end

                    local strippedBase = getDatabaseFishNameWithoutSize(stripped)
                    data, realName = findFishExact(strippedBase)
                    if data then return data, realName, v end
                end
            end
        end
    end

    return nil, requested, nil
end]],
    "stacked modifier asset resolver"
)

-- =============================================================================
-- PATCH D : RUBY + GEMSTONE DETECTOR/FILTER
-- =============================================================================
source = replacePlain(
    source,
    [[local function sendWebhook(data)]],
    [[local function getEffectiveCatchVariant(data)
    local existing = data and (data.Variant or data.Mutation)
    if existing and tostring(existing) ~= "" then
        return tostring(existing)
    end

    local raw = trim(data and (data.RawFish or data.Fish) or "")
    if raw == "" then return nil end

    local variantName = getVariantFromCatchName(raw)
    return variantName
end

local function isRubyGemstoneCatch(data)
    if not data then return false end

    local _, realName = resolveFish(data.Fish or data.RawFish or "")
    if not realName or tostring(realName):lower() ~= "ruby" then
        return false
    end

    local variantName = getEffectiveCatchVariant(data)
    return variantName and tostring(variantName):lower() == "gemstone"
end

local function sendWebhook(data)]],
    "ruby gemstone detector"
)

source = replacePlain(
    source,
    [[    -- PRIORITAS 1: Rarity dari WARNA CHAT
    local rarity = nil]],
    [[    local specialRubyGemstone = isRubyGemstoneCatch(data)

    -- PRIORITAS 1: Rarity dari WARNA CHAT
    local rarity = nil]],
    "ruby gemstone state"
)

source = replacePlain(
    source,
    [[        else
            -- Jika ikan tidak dikenal, catat log dan batalkan
            logError("⚠️ Ikan tidak dikenal: " .. data.Fish .. " (tidak dikirim)")
            return false
        end
    end]],
    [[        elseif specialRubyGemstone then
            -- Ruby + Gemstone tetap boleh diproses walau tier tidak terpetakan.
            rarityName = "RUBY GEMSTONE"
            embedColor = 0xE0115F
        else
            -- Jika ikan tidak dikenal, catat log dan batalkan
            logError("⚠️ Ikan tidak dikenal: " .. data.Fish .. " (tidak dikirim)")
            return false
        end
    end]],
    "ruby gemstone rarity fallback"
)

source = replacePlain(
    source,
    [[    -- FILTER kelangkaan
    if not CONFIG.ALLOW_RARITY[rarityName] and not CONFIG.ALLOW_RARITY[string.upper(rarityName)] then 
        return false 
    end
    if data.Weight < CONFIG.MIN_WEIGHT then return false end]],
    [[    -- FILTER kelangkaan + filter khusus Ruby Gemstone.
    if specialRubyGemstone then
        if not CONFIG.SPECIAL_FILTERS or CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE ~= true then
            return false
        end
    elseif not CONFIG.ALLOW_RARITY[rarityName]
        and not CONFIG.ALLOW_RARITY[string.upper(rarityName)] then
        return false
    end

    if data.Weight < CONFIG.MIN_WEIGHT then return false end]],
    "ruby gemstone special filter gate"
)

source = replacePlain(
    source,
    [[    local variant = data.Variant or data.Mutation]],
    [[    local variant = getEffectiveCatchVariant(data)]],
    "effective variant display"
)

-- =============================================================================
-- PATCH E : UI BORDER + DIVIDER LEBIH JELAS
-- =============================================================================
source = replacePlain(
    source,
    [[outline.Thickness = 1.4]],
    [[outline.Thickness = 1.8]],
    "main outline"
)

source = replacePlain(
    source,
    [[tabStroke.Transparency = 0.45]],
    [[tabStroke.Transparency = 0.12
    tabStroke.Thickness = 1.35]],
    "tab border"
)

source = replacePlain(
    source,
    [[    addStroke(frame, THEME.Border, 0.35)

    local stripe = Instance.new("Frame")]],
    [[    addStroke(frame, THEME.Border, 0.10)

    local stripe = Instance.new("Frame")]],
    "card border"
)

source = replacePlain(
    source,
    [[    addCorner(stripe, 2)

    return frame]],
    [[    addCorner(stripe, 2)

    -- Divider horizontal agar setiap card punya struktur visual yang jelas.
    local divider = Instance.new("Frame")
    divider.Name = "CardDivider"
    divider.Position = UDim2.new(0, 12, 0, 31)
    divider.Size = UDim2.new(1, -24, 0, 1)
    divider.BackgroundColor3 = THEME.Border
    divider.BackgroundTransparency = 0.20
    divider.BorderSizePixel = 0
    divider.Parent = frame

    return frame]],
    "card divider"
)

source = replacePlain(
    source,
    [[local filterCard = card(filtersPage, 232, THEME.Orange)]],
    [[local filterCard = card(filtersPage, 292, THEME.Orange)]],
    "filter card height"
)

source = replacePlain(
    source,
    [[local minWeightInput = Instance.new("TextBox")
minWeightInput.Position = UDim2.new(0, 13, 0, 164)]],
    [[local specialFilterLabel = text(filterCard, "SPECIAL CATCH", 139, 9, THEME.Muted, true)
specialFilterLabel.Size = UDim2.new(1, -26, 0, 18)

local specialRubyGemstoneButton = makeButton(
    filterCard,
    "RUBY + GEMSTONE  " .. ((CONFIG.SPECIAL_FILTERS and CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE) and "✓" or "×"),
    UDim2.new(0, 13, 0, 160),
    UDim2.new(1, -26, 0, 32),
    (CONFIG.SPECIAL_FILTERS and CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE) and THEME.Pink or THEME.Surface2
)

specialRubyGemstoneButton.Activated:Connect(function()
    CONFIG.SPECIAL_FILTERS = CONFIG.SPECIAL_FILTERS or {}
    CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE = not (CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE == true)

    local enabled = CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE == true
    specialRubyGemstoneButton.Text = "RUBY + GEMSTONE  " .. (enabled and "✓" or "×")
    specialRubyGemstoneButton.BackgroundColor3 = enabled and THEME.Pink or THEME.Surface2
end)

local minWeightInput = Instance.new("TextBox")
minWeightInput.Position = UDim2.new(0, 13, 0, 223)]],
    "ruby gemstone ui filter"
)

source = replacePlain(
    source,
    [[local minWeightLabel = text(filterCard, "MIN WEIGHT (KG)", 143, 9, THEME.Muted, true)
minWeightLabel.Position = UDim2.new(0.5, 4, 0, 168)]],
    [[local minWeightLabel = text(filterCard, "MIN WEIGHT (KG)", 202, 9, THEME.Muted, true)
minWeightLabel.Position = UDim2.new(0.5, 4, 0, 227)]],
    "weight filter position"
)

source = replacePlain(
    source,
    [[    updateWebhookToggleUI()
end]],
    [[    if specialRubyGemstoneButton then
        CONFIG.SPECIAL_FILTERS = CONFIG.SPECIAL_FILTERS or {RUBY_GEMSTONE = true}
        local specialEnabled = CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE == true
        specialRubyGemstoneButton.Text = "RUBY + GEMSTONE  " .. (specialEnabled and "✓" or "×")
        specialRubyGemstoneButton.BackgroundColor3 = specialEnabled and THEME.Pink or THEME.Surface2
    end

    updateWebhookToggleUI()
end]],
    "sync special filter ui"
)

local compiled, compileError = loadstring(source)
assert(compiled, "[LFAMILIA FIX] Compile error setelah patch: " .. tostring(compileError))

print("[LFAMILIA FIX] Shiny + stacked modifier + Ruby Gemstone filter + UI borders aktif")
return compiled()
