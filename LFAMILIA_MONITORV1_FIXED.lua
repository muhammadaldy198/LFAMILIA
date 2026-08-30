-- =============================================================================
-- LFAMILIA MONITOR V1 - FAIL-SAFE FIXED LOADER
-- =============================================================================
-- Semua fungsi LFAMILIA_MONITORV1.lua tetap utuh.
-- Patch tambahan:
--   • Shiny bukan Variant/Mutation.
--   • Big/Small/Tiny/Huge/Massive/Large/Giant/Mini/Shiny dapat bertumpuk.
--   • Big Shiny Astralune -> lookup AssetId Astralune.
--   • Shiny Giant Squid -> lookup Giant Squid.
--   • Gemstone Big Shiny Ruby / Big Shiny Gemstone Ruby -> Ruby + Gemstone.
--   • Filter khusus RUBY + GEMSTONE.
--   • Border/divider UI lebih jelas.
--
-- FAIL SAFE:
-- Jika salah satu patch penting gagal / compile error / runtime error,
-- monitor ORIGINAL otomatis dijalankan agar UI tidak mati total.
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
local failedRequired = false
local applied = 0
local skipped = 0

local function replaceRequired(oldText, newText, label)
    local s, e = string.find(source, oldText, 1, true)
    if not s then
        failedRequired = true
        skipped = skipped + 1
        warn("[LFAMILIA FIX] REQUIRED PATCH MISSING: " .. tostring(label))
        return false
    end

    source = source:sub(1, s - 1) .. newText .. source:sub(e + 1)
    applied = applied + 1
    return true
end

local function replaceOptional(oldText, newText, label)
    local s, e = string.find(source, oldText, 1, true)
    if not s then
        skipped = skipped + 1
        warn("[LFAMILIA FIX] Optional patch skipped: " .. tostring(label))
        return false
    end

    source = source:sub(1, s - 1) .. newText .. source:sub(e + 1)
    applied = applied + 1
    return true
end

local function runOriginal(reason)
    warn("[LFAMILIA FIX] Fallback ORIGINAL: " .. tostring(reason or "unknown"))

    local compiledOriginal, originalCompileError = loadstring(originalSource)
    if not compiledOriginal then
        warn("[LFAMILIA FIX] Original compile error: " .. tostring(originalCompileError))
        return
    end

    local okRun, runError = pcall(compiledOriginal)
    if not okRun then
        warn("[LFAMILIA FIX] Original runtime error: " .. tostring(runError))
    end
end

-- =============================================================================
-- 1. SPECIAL FILTER CONFIG
-- =============================================================================

replaceRequired(
    '    BANNER_URL = "https://i.imgur.com/42wd0m0.png",\n}',
    '    BANNER_URL = "https://i.imgur.com/42wd0m0.png",\n    SPECIAL_FILTERS = {\n        RUBY_GEMSTONE = true,\n    },\n}',
    "SPECIAL_FILTERS config"
)

-- =============================================================================
-- 2. DISPLAY MODIFIERS
-- =============================================================================

local displayHelper = [[local DISPLAY_ONLY_CATCH_MODIFIERS = {
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

local function getVariantFromCatchName(text)
    local requested = trim(text)

    -- Variant langsung di depan, contoh: Gemstone Big Shiny Ruby.
    local directName, directFish, directData = getVariantFromName(requested)
    if directName then
        return directName, directFish, directData
    end

    -- Display modifier di depan, contoh: Big Shiny Gemstone Ruby.
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

replaceRequired(
    "local function parseCatch(message)",
    displayHelper,
    "display modifier helpers"
)

replaceRequired(
    "        variantName, cleanFish = getVariantFromName(caughtText)",
    "        variantName, cleanFish = getVariantFromCatchName(caughtText)",
    "variant parser"
)

replaceOptional(
    '            if index > 1 and not span.Text:find("%([^)]-%)") then',
    '            if index > 1\n                and not span.Text:find("%([^)]-%)")\n                and not isDisplayOnlyCatchModifier(span.Text) then',
    "Shiny RGB guard"
)

-- =============================================================================
-- 3. FIXED LOOKUP RESOLVER
-- =============================================================================

local resolverHelper = [[local function stripDisplayPrefixesForLookup(name)
    local requested = trim(name)
    if requested == "" then return requested end

    -- Exact database match selalu menang.
    -- Giant Squid tetap Giant Squid, bukan Squid.
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

    -- Exact catchable.
    local data, realName = findFishExact(requested)
    if data then return data, realName, nil end

    -- Variant, termasuk variant setelah Big/Shiny.
    local variantName, cleanFish, variantData = getVariantFromCatchName(requested)
    if variantName then
        local lookupName = stripDisplayPrefixesForLookup(cleanFish)
        data, realName = findFishExact(lookupName)
        if data then return data, realName, variantData end
    end

    -- Shiny/Big tanpa variant.
    local lookupName = stripDisplayPrefixesForLookup(requested)
    data, realName = findFishExact(lookupName)
    if data then return data, realName, nil end

    -- Seluruh behavior original tetap sebagai fallback.
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

    local fishData, realName = resolveFishFixed(data.Fish or data.RawFish or "")
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

replaceRequired(
    "local function sendWebhook(data)",
    resolverHelper,
    "fixed resolver"
)

-- sendWebhook punya dua lookup database: rarity dan AssetId.
local lookupNeedle = "        local fishData = resolveFish(data.Fish)"
local lookupReplacement = "        local fishData = resolveFishFixed(data.Fish)"

for _ = 1, 2 do
    local s, e = string.find(source, lookupNeedle, 1, true)
    if s then
        source = source:sub(1, s - 1) .. lookupReplacement .. source:sub(e + 1)
        applied = applied + 1
    else
        skipped = skipped + 1
        break
    end
end

replaceRequired(
    "    -- PRIORITAS 1: Rarity dari WARNA CHAT\n    local rarity = nil",
    "    local specialRubyGemstone = isRubyGemstoneCatch(data)\n\n    -- PRIORITAS 1: Rarity dari WARNA CHAT\n    local rarity = nil",
    "special Ruby state"
)

replaceRequired(
    "    -- FILTER kelangkaan\n    if not CONFIG.ALLOW_RARITY[rarityName] and not CONFIG.ALLOW_RARITY[string.upper(rarityName)] then \n        return false \n    end\n    if data.Weight < CONFIG.MIN_WEIGHT then return false end",
    "    -- FILTER kelangkaan + RUBY GEMSTONE SPECIAL FILTER\n    if specialRubyGemstone then\n        CONFIG.SPECIAL_FILTERS = CONFIG.SPECIAL_FILTERS or {RUBY_GEMSTONE = true}\n        if CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE ~= true then\n            return false\n        end\n    elseif not CONFIG.ALLOW_RARITY[rarityName]\n        and not CONFIG.ALLOW_RARITY[string.upper(rarityName)] then\n        return false\n    end\n\n    if data.Weight < CONFIG.MIN_WEIGHT then return false end",
    "Ruby Gemstone filter gate"
)

replaceRequired(
    "    local variant = data.Variant or data.Mutation",
    "    local variant = getEffectiveCatchVariant(data)",
    "effective variant"
)

-- =============================================================================
-- 4. UI SPECIAL FILTER
-- Semua styling UI optional, jadi tidak dapat mematikan monitor.
-- =============================================================================

replaceOptional(
    "local filterCard = card(filtersPage, 232, THEME.Orange)",
    "local filterCard = card(filtersPage, 294, THEME.Orange)",
    "filter card height"
)

local specialUI = [[CONFIG.SPECIAL_FILTERS = CONFIG.SPECIAL_FILTERS or {RUBY_GEMSTONE = true}

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
minWeightInput.Position = UDim2.new(0, 13, 0, 229)]]

replaceOptional(
    'local minWeightInput = Instance.new("TextBox")\nminWeightInput.Position = UDim2.new(0, 13, 0, 164)',
    specialUI,
    "special filter UI"
)

replaceOptional(
    'local minWeightLabel = text(filterCard, "MIN WEIGHT (KG)", 143, 9, THEME.Muted, true)\nminWeightLabel.Position = UDim2.new(0.5, 4, 0, 168)',
    'local minWeightLabel = text(filterCard, "MIN WEIGHT (KG)", 208, 9, THEME.Muted, true)\nminWeightLabel.Position = UDim2.new(0.5, 4, 0, 233)',
    "min weight UI"
)

-- =============================================================================
-- 5. BORDER + DIVIDER
-- =============================================================================

replaceOptional("outline.Thickness = 1.4", "outline.Thickness = 1.8", "main border")
replaceOptional(
    "tabStroke.Transparency = 0.45",
    "tabStroke.Transparency = 0.12\ntabStroke.Thickness = 1.35",
    "sidebar border"
)
replaceOptional(
    "    addStroke(frame, THEME.Border, 0.35)",
    "    addStroke(frame, THEME.Border, 0.10)",
    "card border"
)
replaceOptional(
    "    addCorner(stripe, 2)\n\n    return frame",
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
    "card divider"
)

-- =============================================================================
-- COMPILE + RUN WITH FALLBACK
-- =============================================================================

if failedRequired then
    runOriginal("required patch missing")
    return
end

local compiled, compileError = loadstring(source)
if not compiled then
    warn("[LFAMILIA FIX] Patched compile error: " .. tostring(compileError))
    runOriginal("patched source compile error")
    return
end

print(
    "[LFAMILIA FIX] Patched source ready | Applied="
    .. tostring(applied)
    .. " | Skipped="
    .. tostring(skipped)
)

local okRun, runError = pcall(compiled)
if not okRun then
    warn("[LFAMILIA FIX] Patched runtime error: " .. tostring(runError))
    runOriginal("patched source runtime error")
end
