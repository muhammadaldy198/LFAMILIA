-- =============================================================================
-- LFAMILIA MONITOR V1 - ROBUST FIXED LOADER
-- =============================================================================
-- Source utama LFAMILIA_MONITORV1.lua TIDAK dihapus / ditimpa.
-- Loader ini hanya memasang perbaikan kecil sebelum source utama dijalankan.
--
-- FIX:
--   1. Shiny bukan Variant/Mutation.
--   2. Big/Small/Shiny dapat bertumpuk.
--   3. Big Shiny Astralune -> lookup AssetId Astralune.
--   4. Shiny Giant Squid -> lookup Giant Squid (nama asli tetap aman).
--   5. Big Shiny Gemstone Ruby -> Ruby + Variant Gemstone + AssetId Ruby.
--   6. Filter khusus RUBY + GEMSTONE.
--   7. UI filter lebih rapi + border/divider lebih jelas.
--   8. Patch UI bersifat OPTIONAL supaya script tidak gagal execute.
-- =============================================================================

local SOURCE_URL = "https://raw.githubusercontent.com/muhammadaldy198/LFAMILIA/refs/heads/main/LFAMILIA_MONITORV1.lua"

local source = game:HttpGet(SOURCE_URL)
assert(type(source) == "string" and source ~= "", "[LFAMILIA FIX] Source original gagal diambil")

local patchStats = {
    Applied = 0,
    Skipped = 0,
}

local function replaceOnce(oldText, newText, label, required)
    local startPos, endPos = string.find(source, oldText, 1, true)

    if not startPos then
        patchStats.Skipped = patchStats.Skipped + 1
        warn("[LFAMILIA FIX] Patch tidak ditemukan: " .. tostring(label))

        -- Required tidak langsung menghentikan script. Source original masih
        -- lebih baik dijalankan daripada seluruh monitor gagal execute.
        return false
    end

    source = source:sub(1, startPos - 1)
        .. newText
        .. source:sub(endPos + 1)

    patchStats.Applied = patchStats.Applied + 1
    return true
end

local function replaceAll(oldText, newText, label)
    local count = 0
    local cursor = 1
    local pieces = {}

    while true do
        local startPos, endPos = string.find(source, oldText, cursor, true)
        if not startPos then
            pieces[#pieces + 1] = source:sub(cursor)
            break
        end

        pieces[#pieces + 1] = source:sub(cursor, startPos - 1)
        pieces[#pieces + 1] = newText
        cursor = endPos + 1
        count = count + 1
    end

    if count > 0 then
        source = table.concat(pieces)
        patchStats.Applied = patchStats.Applied + 1
    else
        patchStats.Skipped = patchStats.Skipped + 1
        warn("[LFAMILIA FIX] Patch tidak ditemukan: " .. tostring(label))
    end

    return count
end

-- =============================================================================
-- 1. CONFIG FILTER KHUSUS
-- =============================================================================

replaceOnce(
    [[    BANNER_URL = "https://i.imgur.com/42wd0m0.png",
}]],
    [[    BANNER_URL = "https://i.imgur.com/42wd0m0.png",
    SPECIAL_FILTERS = {
        RUBY_GEMSTONE = true,
    },
}]],
    "CONFIG SPECIAL_FILTERS",
    false
)

replaceOnce(
    [[            WEBHOOK_USERNAME = CONFIG.WEBHOOK_USERNAME,
        },]],
    [[            WEBHOOK_USERNAME = CONFIG.WEBHOOK_USERNAME,
            SPECIAL_FILTERS = CONFIG.SPECIAL_FILTERS,
        },]],
    "SAVE SPECIAL_FILTERS",
    false
)

replaceOnce(
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
    "LOAD SPECIAL_FILTERS",
    false
)

-- =============================================================================
-- 2. SHINY / BIG / SMALL = DISPLAY MODIFIER, BUKAN MUTATION
-- =============================================================================

replaceOnce(
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

    local count = 0
    for word in value:gmatch("%S+") do
        count = count + 1
        if not DISPLAY_ONLY_CATCH_MODIFIERS[word] then
            return false
        end
    end

    return count > 0
end

-- Variant dapat berada sesudah modifier display:
--   Big Shiny Gemstone Ruby
-- atau di depan:
--   Gemstone Big Shiny Ruby
local function getVariantFromCatchName(text)
    local requested = trim(text)

    -- Format variant langsung di depan.
    local directName, directFish, directData = getVariantFromName(requested)
    if directName then
        return directName, directFish, directData
    end

    -- Lewati Big/Shiny/dll di depan, lalu cek Variant.
    local displayWords = {}
    local current = requested

    while true do
        local firstWord, remainder = current:match("^(%S+)%s+(.+)$")
        if not firstWord or not remainder then break end
        if not DISPLAY_ONLY_CATCH_MODIFIERS[firstWord:lower()] then break end

        displayWords[#displayWords + 1] = firstWord
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
    "DISPLAY MODIFIER HELPERS",
    true
)

replaceOnce(
    [[        variantName, cleanFish = getVariantFromName(caughtText)]],
    [[        variantName, cleanFish = getVariantFromCatchName(caughtText)]],
    "PARSECATCH VARIANT ORDER",
    true
)

replaceOnce(
    [[            if index > 1 and not span.Text:find("%([^)]-%)") then]],
    [[            if index > 1
                and not span.Text:find("%([^)]-%)")
                and not isDisplayOnlyCatchModifier(span.Text) then]],
    "RICH TEXT DISPLAY GUARD",
    false
)

-- =============================================================================
-- 3. RESOLVER BARU
--    Tidak mengganti resolver lama. Resolver baru hanya dipakai oleh webhook.
-- =============================================================================

replaceOnce(
    [[local function sendWebhook(data)]],
    [[-- -------------------------------------------------------------------------
-- FIXED LOOKUP RESOLVER
-- -------------------------------------------------------------------------
local function stripDisplayPrefixesForLookup(name)
    local requested = trim(name)
    if requested == "" then return requested end

    -- Exact database match selalu dilindungi.
    -- Jadi "Giant Squid" tetap Giant Squid.
    local _, exactName = findFishExact(requested)
    if exactName then
        return exactName
    end

    local current = requested

    while true do
        local firstWord, remainder = current:match("^(%S+)%s+(.+)$")
        if not firstWord or not remainder then break end

        if not DISPLAY_ONLY_CATCH_MODIFIERS[firstWord:lower()] then
            break
        end

        current = trim(remainder)

        local _, exactAfterStrip = findFishExact(current)
        if exactAfterStrip then
            return exactAfterStrip
        end
    end

    return current
end

local function resolveFishFixed(name)
    local requested = trim(name)
    if requested == "" then return nil, requested, nil end

    -- 1. Exact nama catchable.
    local data, realName = findFishExact(requested)
    if data then
        return data, realName, nil
    end

    -- 2. Cari Variant, termasuk sesudah Big/Shiny.
    local variantName, cleanFish, variantData = getVariantFromCatchName(requested)

    if variantName then
        local lookupName = stripDisplayPrefixesForLookup(cleanFish)
        data, realName = findFishExact(lookupName)

        if data then
            return data, realName, variantData
        end
    end

    -- 3. Tidak ada Variant: lepas Big/Shiny/dll hanya untuk lookup.
    local lookupName = stripDisplayPrefixesForLookup(requested)
    data, realName = findFishExact(lookupName)

    if data then
        return data, realName, nil
    end

    -- 4. Fallback resolver original agar kompatibilitas lama tetap ada.
    return resolveFish(requested)
end

local function getEffectiveCatchVariant(data)
    if not data then return nil end

    local existing = data.Variant or data.Mutation
    if existing and tostring(existing) ~= "" then
        return tostring(existing)
    end

    local raw = trim(data.RawFish or data.Fish or "")
    if raw == "" then return nil end

    local variantName = getVariantFromCatchName(raw)
    return variantName
end

local function isRubyGemstoneCatch(data)
    if not data then return false end

    local fishData, realName = resolveFishFixed(data.Fish or data.RawFish or "")
    if not fishData or not realName or tostring(realName):lower() ~= "ruby" then
        return false
    end

    local variantName = getEffectiveCatchVariant(data)
    return variantName and tostring(variantName):lower() == "gemstone"
end

local function sendWebhook(data)]],
    "FIXED WEBHOOK RESOLVER",
    true
)

-- Dua tempat di sendWebhook menggunakan resolver database: rarity + AssetId.
replaceAll(
    [[        local fishData = resolveFish(data.Fish)]],
    [[        local fishData = resolveFishFixed(data.Fish)]],
    "SENDWEBHOOK DATABASE LOOKUP"
)

replaceOnce(
    [[    -- PRIORITAS 1: Rarity dari WARNA CHAT
    local rarity = nil]],
    [[    local specialRubyGemstone = isRubyGemstoneCatch(data)

    -- PRIORITAS 1: Rarity dari WARNA CHAT
    local rarity = nil]],
    "SPECIAL RUBY STATE",
    false
)

replaceOnce(
    [[        else
            -- Jika ikan tidak dikenal, catat log dan batalkan
            logError("⚠️ Ikan tidak dikenal: " .. data.Fish .. " (tidak dikirim)")
            return false
        end
    end]],
    [[        elseif specialRubyGemstone then
            -- Ruby + Gemstone tetap diproses walaupun rarity tidak berhasil
            -- dipetakan dari database.
            rarityName = "RUBY GEMSTONE"
            embedColor = 0xE0115F
        else
            -- Jika ikan tidak dikenal, catat log dan batalkan
            logError("⚠️ Ikan tidak dikenal: " .. data.Fish .. " (tidak dikirim)")
            return false
        end
    end]],
    "SPECIAL RUBY RARITY FALLBACK",
    false
)

replaceOnce(
    [[    -- FILTER kelangkaan
    if not CONFIG.ALLOW_RARITY[rarityName] and not CONFIG.ALLOW_RARITY[string.upper(rarityName)] then 
        return false 
    end
    if data.Weight < CONFIG.MIN_WEIGHT then return false end]],
    [[    -- FILTER kelangkaan + filter khusus Ruby Gemstone.
    if specialRubyGemstone then
        CONFIG.SPECIAL_FILTERS = CONFIG.SPECIAL_FILTERS or {RUBY_GEMSTONE = true}

        if CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE ~= true then
            return false
        end
    elseif not CONFIG.ALLOW_RARITY[rarityName]
        and not CONFIG.ALLOW_RARITY[string.upper(rarityName)] then
        return false
    end

    if data.Weight < CONFIG.MIN_WEIGHT then return false end]],
    "SPECIAL RUBY FILTER GATE",
    false
)

replaceOnce(
    [[    local variant = data.Variant or data.Mutation]],
    [[    local variant = getEffectiveCatchVariant(data)]],
    "EFFECTIVE VARIANT",
    false
)

-- =============================================================================
-- 4. UI FILTER RUBY + GEMSTONE
--    Semua patch di bagian UI OPTIONAL supaya monitor tetap execute meski
--    struktur UI original berubah sedikit.
-- =============================================================================

replaceOnce(
    [[local filterCard = card(filtersPage, 232, THEME.Orange)]],
    [[local filterCard = card(filtersPage, 294, THEME.Orange)]],
    "FILTER CARD HEIGHT",
    false
)

replaceOnce(
    [[local minWeightInput = Instance.new("TextBox")
minWeightInput.Position = UDim2.new(0, 13, 0, 164)]],
    [[CONFIG.SPECIAL_FILTERS = CONFIG.SPECIAL_FILTERS or {RUBY_GEMSTONE = true}

local specialFilterLabel = text(filterCard, "SPECIAL CATCH", 141, 9, THEME.Muted, true)
specialFilterLabel.Size = UDim2.new(1, -26, 0, 18)

local specialRubyGemstoneButton = makeButton(
    filterCard,
    "RUBY + GEMSTONE  " .. (CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE and "✓" or "×"),
    UDim2.new(0, 13, 0, 163),
    UDim2.new(1, -26, 0, 34),
    CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE and THEME.Pink or THEME.Surface2
)

specialRubyGemstoneButton.Activated:Connect(function()
    CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE = not (CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE == true)

    local enabled = CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE == true
    specialRubyGemstoneButton.Text = "RUBY + GEMSTONE  " .. (enabled and "✓" or "×")
    specialRubyGemstoneButton.BackgroundColor3 = enabled and THEME.Pink or THEME.Surface2
end)

local minWeightInput = Instance.new("TextBox")
minWeightInput.Position = UDim2.new(0, 13, 0, 229)]],
    "SPECIAL FILTER UI",
    false
)

replaceOnce(
    [[local minWeightLabel = text(filterCard, "MIN WEIGHT (KG)", 143, 9, THEME.Muted, true)
minWeightLabel.Position = UDim2.new(0.5, 4, 0, 168)]],
    [[local minWeightLabel = text(filterCard, "MIN WEIGHT (KG)", 208, 9, THEME.Muted, true)
minWeightLabel.Position = UDim2.new(0.5, 4, 0, 233)]],
    "MIN WEIGHT UI POSITION",
    false
)

-- =============================================================================
-- 5. BORDER + DIVIDER UI
-- =============================================================================

replaceOnce(
    [[outline.Thickness = 1.4]],
    [[outline.Thickness = 1.8]],
    "MAIN BORDER",
    false
)

replaceOnce(
    [[tabStroke.Transparency = 0.45]],
    [[tabStroke.Transparency = 0.12
tabStroke.Thickness = 1.35]],
    "SIDEBAR BORDER",
    false
)

replaceOnce(
    [[    addStroke(frame, THEME.Border, 0.35)]],
    [[    addStroke(frame, THEME.Border, 0.10)]],
    "CARD BORDER",
    false
)

replaceOnce(
    [[    addCorner(stripe, 2)

    return frame]],
    [[    addCorner(stripe, 2)

    local divider = Instance.new("Frame")
    divider.Name = "CardDivider"
    divider.Position = UDim2.new(0, 12, 0, 31)
    divider.Size = UDim2.new(1, -24, 0, 1)
    divider.BackgroundColor3 = THEME.Border
    divider.BackgroundTransparency = 0.18
    divider.BorderSizePixel = 0
    divider.Parent = frame

    return frame]],
    "CARD DIVIDER",
    false
)

-- =============================================================================
-- COMPILE + EXECUTE
-- =============================================================================

local compiled, compileError = loadstring(source)

if not compiled then
    warn("[LFAMILIA FIX] Source hasil patch gagal compile: " .. tostring(compileError))
    warn("[LFAMILIA FIX] Menjalankan source ORIGINAL sebagai fallback agar UI tetap hidup.")

    local originalCompiled, originalError = loadstring(game:HttpGet(SOURCE_URL))
    assert(originalCompiled, "[LFAMILIA FIX] Source original juga gagal compile: " .. tostring(originalError))
    return originalCompiled()
end

print(
    "[LFAMILIA FIX] Ready | Applied="
    .. tostring(patchStats.Applied)
    .. " | Skipped="
    .. tostring(patchStats.Skipped)
)

return compiled()
