-- LFAMILIA MONITOR V1 - SHINY / STACKED MODIFIER FIX
-- Loader ini TIDAK menghapus fitur dari LFAMILIA_MONITORV1.lua.
-- Ia mengambil source asli, memasang patch kecil pada resolver nama catch,
-- lalu menjalankan source yang sudah dipatch.
--
-- Tujuan:
--   Shiny Cryoshade Glider  -> lookup database: Cryoshade Glider
--   Big Shiny Astralune     -> lookup database: Astralune
--   Shiny Giant Squid       -> lookup database: Giant Squid
--   Giant Squid             -> tetap exact match Giant Squid
--
-- Shiny / Big / Small / dst. tetap tampil pada nama Fish di webhook.
-- Mereka hanya dibuang sementara untuk pencarian Id/AssetId database.

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

-- -----------------------------------------------------------------------------
-- PATCH 1
-- Tandai Shiny/size words sebagai modifier tampilan, BUKAN variant/mutation.
-- Helper diletakkan sebelum parseCatch supaya fallback warna tidak salah
-- menganggap span seperti "Shiny" sebagai mutation.
-- -----------------------------------------------------------------------------
local parseCatchMarker = "local function parseCatch(message)"
local parseCatchPatch = [[local DISPLAY_ONLY_CATCH_MODIFIERS = {
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
    return DISPLAY_ONLY_CATCH_MODIFIERS[trim(text):lower()] == true
end

local function parseCatch(message)]]

source = replacePlain(
    source,
    parseCatchMarker,
    parseCatchPatch,
    "display-only modifier helper"
)

-- -----------------------------------------------------------------------------
-- PATCH 2
-- Pada fallback deteksi variant lewat RichText/color, jangan pernah memakai
-- Shiny/Big/Small/dll sebagai variant atau mutation.
-- -----------------------------------------------------------------------------
local oldVariantFallback = [[if index > 1 and not span.Text:find("%([^)]-%)") then]]
local newVariantFallback = [[if index > 1
                and not span.Text:find("%([^)]-%)")
                and not isDisplayOnlyCatchModifier(span.Text) then]]

source = replacePlain(
    source,
    oldVariantFallback,
    newVariantFallback,
    "variant fallback modifier guard"
)

-- -----------------------------------------------------------------------------
-- PATCH 3
-- Resolver lama hanya dapat melepas SATU prefix ukuran.
-- Resolver baru dapat melepas beberapa modifier berurutan sampai menemukan
-- nama asli yang EXACT ada di FishDatabase.
--
-- Penting: exact match selalu diprioritaskan. Karena itu nama asli seperti
-- "Giant Squid" tidak akan berubah menjadi "Squid".
-- -----------------------------------------------------------------------------
local oldPrefixes = [[local FISH_SIZE_PREFIXES = {
    "big",
    "small",
    "tiny",
    "huge",
    "massive",
    "large",
    "giant",
    "mini",
}]]

local newPrefixes = [[local FISH_SIZE_PREFIXES = {
    "big",
    "small",
    "tiny",
    "huge",
    "massive",
    "large",
    "giant",
    "mini",
    "shiny",
}]]

source = replacePlain(
    source,
    oldPrefixes,
    newPrefixes,
    "Shiny modifier prefix"
)

local oldResolver = [[local function getDatabaseFishNameWithoutSize(name)
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
end]]

local newResolver = [[local function getDatabaseFishNameWithoutSize(name)
    local requested = trim(name)
    if requested == "" then return requested end

    -- Selalu lindungi nama asli database terlebih dahulu.
    -- Contoh "Giant Squid" memang nama ikan asli dan tidak boleh dipotong.
    local _, exactRealName = findFishExact(requested)
    if exactRealName then
        return exactRealName
    end

    local current = requested

    -- Lepas modifier satu per satu HANYA dari bagian depan.
    -- Setelah setiap pelepasan, langsung cek exact FishDatabase.
    -- Contoh:
    --   Big Shiny Astralune -> Shiny Astralune -> Astralune
    --   Shiny Giant Squid   -> Giant Squid (exact, stop)
    while true do
        local firstWord, remainder = current:match("^(%S+)%s+(.+)$")
        if not firstWord or not remainder then
            break
        end

        local lowerFirst = firstWord:lower()
        local isModifier = false

        for _, sizePrefix in ipairs(FISH_SIZE_PREFIXES) do
            if lowerFirst == sizePrefix then
                isModifier = true
                break
            end
        end

        if not isModifier then
            break
        end

        current = trim(remainder)

        local _, realName = findFishExact(current)
        if realName then
            return realName
        end
    end

    -- Kalau setelah melepas modifier tidak ada exact database match,
    -- jangan menebak. Kembalikan nama asli seperti sebelumnya.
    return requested
end]]

source = replacePlain(
    source,
    oldResolver,
    newResolver,
    "stacked Shiny/size resolver"
)

local compiled, compileError = loadstring(source)
assert(compiled, "[LFAMILIA FIX] Compile error setelah patch: " .. tostring(compileError))

print("[LFAMILIA FIX] Shiny + stacked modifier resolver aktif")
return compiled()
