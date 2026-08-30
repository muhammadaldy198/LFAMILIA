-- =============================================================================
-- LFAMILIA MONITOR V1 - FIXED
-- =============================================================================
-- Semua fungsi LFAMILIA_MONITORV1.lua tetap dipakai.
-- Patch:
--   • Shiny bukan Variant/Mutation.
--   • Big/Small/Tiny/Huge/Massive/Large/Giant/Mini/Shiny bisa bertumpuk.
--   • Big Shiny Astralune -> lookup AssetId Astralune.
--   • Shiny Giant Squid -> lookup Giant Squid.
--   • Big Shiny Gemstone Ruby -> Ruby + Mutation Gemstone + AssetId Ruby.
--   • Filter RUBY + GEMSTONE tampil di CONFIG > CATCH FILTERS.
--   • Filter ikut SAVE/LOAD slot.
--   • Border/divider UI lebih jelas.
-- =============================================================================

local SOURCE_URL = "https://raw.githubusercontent.com/muhammadaldy198/LFAMILIA/refs/heads/main/LFAMILIA_MONITORV1.lua"

local okHttp, originalSource = pcall(function()
    return game:HttpGet(SOURCE_URL)
end)

if not okHttp or type(originalSource) ~= "string" or originalSource == "" then
    warn("[LFAMILIA FIX] Gagal mengambil source original: " .. tostring(originalSource))
    return
end

local source = originalSource
local applied = 0
local missing = {}

local function replaceOnce(oldText, newText, label, required)
    local s, e = string.find(source, oldText, 1, true)
    if not s then
        table.insert(missing, tostring(label))
        warn("[LFAMILIA FIX] Patch tidak ditemukan: " .. tostring(label))
        return false
    end

    source = source:sub(1, s - 1) .. newText .. source:sub(e + 1)
    applied = applied + 1
    return true
end

local function replaceAll(oldText, newText)
    local count = 0
    while true do
        local s, e = string.find(source, oldText, 1, true)
        if not s then break end
        source = source:sub(1, s - 1) .. newText .. source:sub(e + 1)
        count = count + 1
    end
    if count > 0 then applied = applied + count end
    return count
end

-- =============================================================================
-- 1. CONFIG + SAVE/LOAD RUBY GEMSTONE FILTER
-- =============================================================================

replaceOnce(
    '    BANNER_URL = "https://i.imgur.com/42wd0m0.png",',
    [[    BANNER_URL = "https://i.imgur.com/42wd0m0.png",
    SPECIAL_FILTERS = {
        RUBY_GEMSTONE = true,
    },]],
    "SPECIAL_FILTERS config",
    true
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
        end]],
    [[        if type(data.CONFIG.WEBHOOK_USERNAME) == "string" then
            CONFIG.WEBHOOK_USERNAME = data.CONFIG.WEBHOOK_USERNAME
        end

        if type(data.CONFIG.SPECIAL_FILTERS) == "table" then
            CONFIG.SPECIAL_FILTERS = CONFIG.SPECIAL_FILTERS or {}
            CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE = data.CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE ~= false
        end]],
    "LOAD SPECIAL_FILTERS",
    false
)

-- =============================================================================
-- 2. SHINY / SIZE DISPLAY MODIFIERS
-- =============================================================================

local displayHelpers = [[local DISPLAY_ONLY_CATCH_MODIFIERS = {
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

-- Mendeteksi Variant walaupun berada setelah Big/Shiny.
-- Gemstone Big Shiny Ruby  -> Gemstone + Big Shiny Ruby
-- Big Shiny Gemstone Ruby  -> Gemstone + Big Shiny Ruby
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

local function parseCatch(message)]]

replaceOnce(
    "local function parseCatch(message)",
    displayHelpers,
    "display modifier helpers",
    true
)

replaceOnce(
    "        variantName, cleanFish = getVariantFromName(caughtText)",
    "        variantName, cleanFish = getVariantFromCatchName(caughtText)",
    "parseCatch variant order",
    true
)

replaceOnce(
    '            if index > 1 and not span.Text:find("%([^)]-%)") then',
    [[            if index > 1
                and not span.Text:find("%([^)]-%)")
                and not isDisplayOnlyCatchModifier(span.Text) then]],
    "Shiny RGB guard",
    false
)

-- =============================================================================
-- 3. FIXED DATABASE / ASSET LOOKUP
-- =============================================================================

local resolverHelpers = [[local function stripDisplayPrefixesForLookup(name)
    local requested = trim(name)
    if requested == "" then return requested end

    -- Exact DB match selalu menang; Giant Squid tidak akan dipotong.
    local _, exactName = findFishExact(requested)
    if exactName then return exactName end

    local current = requested

    while true do
        local firstWord, remainder = current:match("^(%S+)%s+(.+)$")
        if not firstWord or not remainder then break end
        if not DISPLAY_ONLY_CATCH_MODIFIERS[firstWord:lower()] then break end

        current = trim(remainder)

        local _, exactAfter = findFishExact(current)
        if exactAfter then return exactAfter end
    end

    return current
end

local function resolveFishFixed(name)
    local requested = trim(name)
    if requested == "" then return nil, requested, nil end

    -- 1. Exact fish/catchable.
    local data, realName = findFishExact(requested)
    if data then return data, realName, nil end

    -- 2. Variant, termasuk sesudah Big/Shiny.
    local variantName, cleanFish, variantData = getVariantFromCatchName(requested)
    if variantName then
        local lookupName = stripDisplayPrefixesForLookup(cleanFish)
        data, realName = findFishExact(lookupName)
        if data then return data, realName, variantData end
    end

    -- 3. Shiny/Big tanpa variant.
    local lookupName = stripDisplayPrefixesForLookup(requested)
    data, realName = findFishExact(lookupName)
    if data then return data, realName, nil end

    -- 4. Kompatibilitas resolver lama.
    return resolveFish(requested)
end

local function getEffectiveCatchVariant(data)
    if not data then return nil end

    local existing = data.Variant or data.Mutation
    if existing and trim(existing) ~= "" and not isDisplayOnlyCatchModifier(existing) then
        return tostring(existing)
    end

    local raw = trim(data.RawFish or data.Fish or "")
    if raw == "" then return nil end

    local variantName = getVariantFromCatchName(raw)
    return variantName
end

local function isRubyGemstoneCatch(data)
    if not data then return false end

    local fishData, realName = resolveFishFixed(data.Fish or "")
    if not fishData or not realName or tostring(realName):lower() ~= "ruby" then
        fishData, realName = resolveFishFixed(data.RawFish or "")
    end

    if not fishData or not realName or tostring(realName):lower() ~= "ruby" then
        return false
    end

    local variantName = getEffectiveCatchVariant(data)
    return variantName and tostring(variantName):lower() == "gemstone"
end

local function sendWebhook(data)]]

replaceOnce(
    "local function sendWebhook(data)",
    resolverHelpers,
    "fixed resolver",
    true
)

-- Ganti lookup DB pada sendWebhook untuk rarity + AssetId.
replaceAll(
    "        local fishData = resolveFish(data.Fish)",
    "        local fishData = resolveFishFixed(data.Fish)"
)

replaceOnce(
    "    -- PRIORITAS 1: Rarity dari WARNA CHAT",
    [[    local specialRubyGemstone = isRubyGemstoneCatch(data)

    -- PRIORITAS 1: Rarity dari WARNA CHAT]],
    "special Ruby state",
    true
)

-- Ruby + Gemstone jangan dibatalkan jika rarity DB tidak ditemukan.
replaceOnce(
    [[        if rarity then 
            rarityName = rarity.Name 
        else
            -- Jika ikan tidak dikenal, catat log dan batalkan
            logError("⚠️ Ikan tidak dikenal: " .. data.Fish .. " (tidak dikirim)")
            return false
        end]],
    [[        if rarity then 
            rarityName = rarity.Name
        elseif specialRubyGemstone then
            rarityName = "RUBY GEMSTONE"
            embedColor = 0xE0115F
        else
            -- Jika ikan tidak dikenal, catat log dan batalkan
            logError("⚠️ Ikan tidak dikenal: " .. data.Fish .. " (tidak dikirim)")
            return false
        end]],
    "Ruby rarity fallback",
    false
)

replaceOnce(
    "    -- FILTER kelangkaan",
    [[    -- FILTER KHUSUS RUBY + GEMSTONE
    if specialRubyGemstone then
        CONFIG.SPECIAL_FILTERS = CONFIG.SPECIAL_FILTERS or {RUBY_GEMSTONE = true}
        if CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE ~= true then
            return false
        end
    end

    -- FILTER kelangkaan]],
    "Ruby filter gate prelude",
    true
)

replaceOnce(
    "    if not CONFIG.ALLOW_RARITY[rarityName] and not CONFIG.ALLOW_RARITY[string.upper(rarityName)] then ",
    "    if not specialRubyGemstone and not CONFIG.ALLOW_RARITY[rarityName] and not CONFIG.ALLOW_RARITY[string.upper(rarityName)] then ",
    "Ruby bypass rarity filter",
    true
)

replaceOnce(
    "    local variant = data.Variant or data.Mutation",
    "    local variant = getEffectiveCatchVariant(data)",
    "effective variant",
    false
)

-- =============================================================================
-- 4. VISIBLE RUBY + GEMSTONE BUTTON IN CONFIG
-- =============================================================================

replaceOnce(
    "local filterCard = card(filtersPage, 232, THEME.Orange)",
    "local filterCard = card(filtersPage, 292, THEME.Orange)",
    "filter card height",
    true
)

-- Geser MIN WEIGHT ke bawah untuk memberi ruang tombol special filter.
replaceOnce(
    "minWeightInput.Position = UDim2.new(0, 13, 0, 164)",
    "minWeightInput.Position = UDim2.new(0, 13, 0, 224)",
    "min weight input position",
    true
)

replaceOnce(
    'local minWeightLabel = text(filterCard, "MIN WEIGHT (KG)", 143, 9, THEME.Muted, true)',
    'local minWeightLabel = text(filterCard, "MIN WEIGHT (KG)", 203, 9, THEME.Muted, true)',
    "min weight label y",
    true
)

replaceOnce(
    "minWeightLabel.Position = UDim2.new(0.5, 4, 0, 168)",
    "minWeightLabel.Position = UDim2.new(0.5, 4, 0, 228)",
    "min weight hint position",
    true
)

local specialFilterUI = [[CONFIG.SPECIAL_FILTERS = CONFIG.SPECIAL_FILTERS or {RUBY_GEMSTONE = true}

local specialFilterLabel = text(filterCard, "SPECIAL CATCH", 140, 9, THEME.Muted, true)
specialFilterLabel.Size = UDim2.new(1, -26, 0, 18)

local specialRubyGemstoneButton = makeButton(
    filterCard,
    "◆  RUBY + GEMSTONE  " .. (CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE and "✓" or "×"),
    UDim2.new(0, 13, 0, 161),
    UDim2.new(1, -26, 0, 34),
    CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE and THEME.Pink or THEME.Surface2
)

specialRubyGemstoneButton.Activated:Connect(function()
    CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE = not (CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE == true)

    local enabled = CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE == true
    specialRubyGemstoneButton.Text = "◆  RUBY + GEMSTONE  " .. (enabled and "✓" or "×")
    specialRubyGemstoneButton.BackgroundColor3 = enabled and THEME.Pink or THEME.Surface2

    appendMonitorLog(
        enabled and "✅" or "⏸",
        "Ruby + Gemstone filter " .. (enabled and "ON" or "OFF")
    )
end)

local minWeightInput = Instance.new("TextBox")]]

replaceOnce(
    'local minWeightInput = Instance.new("TextBox")',
    specialFilterUI,
    "VISIBLE Ruby Gemstone button",
    true
)

-- Saat LOAD slot, refresh keadaan tombol special filter juga.
replaceOnce(
    "    updateWebhookToggleUI()\nend",
    [[    if specialRubyGemstoneButton then
        CONFIG.SPECIAL_FILTERS = CONFIG.SPECIAL_FILTERS or {RUBY_GEMSTONE = true}
        local enabled = CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE == true
        specialRubyGemstoneButton.Text = "◆  RUBY + GEMSTONE  " .. (enabled and "✓" or "×")
        specialRubyGemstoneButton.BackgroundColor3 = enabled and THEME.Pink or THEME.Surface2
    end

    updateWebhookToggleUI()
end]],
    "sync Ruby filter button",
    false
)

-- =============================================================================
-- 5. UI BORDER / DIVIDER
-- =============================================================================

replaceOnce("outline.Thickness = 1.4", "outline.Thickness = 1.8", "main border", false)

replaceOnce(
    "tabStroke.Transparency = 0.45",
    [[tabStroke.Transparency = 0.12
tabStroke.Thickness = 1.35]],
    "sidebar border",
    false
)

replaceOnce(
    "    addStroke(frame, THEME.Border, 0.35)",
    "    addStroke(frame, THEME.Border, 0.10)",
    "card border",
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
    "card divider",
    false
)

-- =============================================================================
-- 6. COMPILE + RUN
-- =============================================================================

local compiled, compileError = loadstring(source)
if not compiled then
    warn("[LFAMILIA FIX] COMPILE ERROR: " .. tostring(compileError))
    warn("[LFAMILIA FIX] Missing patches: " .. table.concat(missing, ", "))
    return
end

print(
    "[LFAMILIA FIX] READY | Applied=" .. tostring(applied)
    .. " | Missing=" .. tostring(#missing)
)

local okRun, runError = pcall(compiled)
if not okRun then
    warn("[LFAMILIA FIX] RUNTIME ERROR: " .. tostring(runError))
end
