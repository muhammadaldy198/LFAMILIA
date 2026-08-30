-- LFAMILIA MONITOR V1 - DELTA ANDROID LOADER
-- Base: immutable corrected build. Patch only reduces top-level locals before compile.

local BASE_URL = "https://raw.githubusercontent.com/muhammadaldy198/LFAMILIA/e6c2623da85e3f1103f984ec3b1a6703a52c51c3/LFAMILIA_MONITORV1.lua"

local okHttp, source = pcall(function()
    return game:HttpGet(BASE_URL)
end)
if not okHttp or type(source) ~= "string" or source == "" then
    warn("[LFAMILIA] Gagal mengambil base script: " .. tostring(source))
    return
end

local function replaceOnce(oldText, newText, label)
    local s, e = string.find(source, oldText, 1, true)
    if not s then
        warn("[LFAMILIA] Patch missing: " .. tostring(label))
        return false
    end
    source = source:sub(1, s - 1) .. newText .. source:sub(e + 1)
    return true
end

replaceOnce(
[[-- Modifier display/cosmetic yang bukan bagian dari nama asli FishDatabase.
-- SHINY sengaja bukan Variant/Mutation. Nama aslinya tetap dicari untuk
-- mendapatkan Rarity dan AssetId, sedangkan teks webhook tetap menampilkan
-- nama catch lengkap seperti "Shiny Cryoshade Glider" / "Big Shiny ...".
local FISH_COSMETIC_PREFIXES = {
    shiny = true,
}

]],
[[-- SHINY adalah modifier display/cosmetic, bukan Variant/Mutation.

]],
"remove cosmetic table"
)

replaceOnce(
[[-- BIG/SMALL dan SHINY adalah modifier hasil tangkapan, bukan selalu nama
-- fish di FishDatabase. Prefix dilepas bertahap HANYA untuk lookup database.
-- Exact match tetap diprioritaskan agar fish asli seperti "Giant Squid" aman.
local function isFishLookupModifier(word)
    local lowerWord = trim(word):lower()
    if FISH_COSMETIC_PREFIXES[lowerWord] then return true end

    for _, sizePrefix in ipairs(FISH_SIZE_PREFIXES) do
        if lowerWord == sizePrefix then return true end
    end

    return false
end

]],
[[-- BIG/SMALL dan SHINY dilepas HANYA saat lookup database.
-- Exact match tetap diprioritaskan agar fish asli seperti "Giant Squid" aman.
]],
"remove lookup helper"
)

replaceOnce(
[[        local firstWord, remainder = candidate:match("^(%S+)%s+(.+)$")
        if not firstWord or not remainder or not isFishLookupModifier(firstWord) then
            break
        end

        candidate = trim(remainder)
]],
[[        local firstWord, remainder = candidate:match("^(%S+)%s+(.+)$")
        if not firstWord or not remainder then break end

        local lowerWord = trim(firstWord):lower()
        local removable = lowerWord == "shiny"
        if not removable then
            for _, sizePrefix in ipairs(FISH_SIZE_PREFIXES) do
                if lowerWord == sizePrefix then
                    removable = true
                    break
                end
            end
        end
        if not removable then break end

        candidate = trim(remainder)
]],
"inline shiny/size lookup"
)

replaceOnce(
[[-- Garis header solid supaya panel lebih tegas di layar Android.
local headerDivider = Instance.new("Frame")
headerDivider.Position = UDim2.fromOffset(10, 55)
headerDivider.Size = UDim2.new(1, -20, 0, 2)
headerDivider.BackgroundColor3 = THEME.Divider
headerDivider.BorderSizePixel = 0
headerDivider.Parent = main
]],
[[-- Garis header solid supaya panel lebih tegas di layar Android.
do
    local divider = Instance.new("Frame")
    divider.Position = UDim2.fromOffset(10, 55)
    divider.Size = UDim2.new(1, -20, 0, 2)
    divider.BackgroundColor3 = THEME.Divider
    divider.BorderSizePixel = 0
    divider.Parent = main
end
]],
"scope header divider"
)

replaceOnce(
[[local specialDivider = Instance.new("Frame")
specialDivider.Position = UDim2.new(0, 13, 0, 139)
specialDivider.Size = UDim2.new(1, -26, 0, 2)
specialDivider.BackgroundColor3 = THEME.Divider
specialDivider.BorderSizePixel = 0
specialDivider.Parent = filterCard

local specialFilterLabel = text(
    filterCard,
    "◆ SPECIAL RARITY BYPASS",
    146,
    9,
    THEME.Purple,
    true
)
specialFilterLabel.Size = UDim2.new(1, -26, 0, 18)

local gemstoneRubyButton = Instance.new("TextButton")
local gemstoneRubyEnabled = CONFIG.GEMSTONE_RUBY_FILTER == true
gemstoneRubyButton.Size = UDim2.new(1, -26, 0, 30)
gemstoneRubyButton.Position = UDim2.new(0, 13, 0, 169)
gemstoneRubyButton.BackgroundColor3 = gemstoneRubyEnabled and THEME.Purple or THEME.Surface2
gemstoneRubyButton.BorderSizePixel = 0
gemstoneRubyButton.Text = "GEMSTONE RUBY" .. (gemstoneRubyEnabled and "  ✓" or "  ×")
gemstoneRubyButton.TextColor3 = THEME.Text
gemstoneRubyButton.Font = Enum.Font.GothamBold
gemstoneRubyButton.TextSize = 10
gemstoneRubyButton.Parent = filterCard
addCorner(gemstoneRubyButton, 7)
addStroke(gemstoneRubyButton, THEME.Purple, 0.12)

gemstoneRubyButton.Activated:Connect(function()
    CONFIG.GEMSTONE_RUBY_FILTER = not (CONFIG.GEMSTONE_RUBY_FILTER == true)
    local active = CONFIG.GEMSTONE_RUBY_FILTER == true
    gemstoneRubyButton.BackgroundColor3 = active and THEME.Purple or THEME.Surface2
    gemstoneRubyButton.Text = "GEMSTONE RUBY" .. (active and "  ✓" or "  ×")
end)

local specialFilterHint = text(
    filterCard,
    "ON = Gemstone Ruby tetap terkirim walau Legendary OFF. Ruby lain tetap diblok.",
    205,
    8,
    THEME.Muted
)
specialFilterHint.Size = UDim2.new(1, -26, 0, 24)
]],
[[do
    local divider = Instance.new("Frame")
    divider.Position = UDim2.new(0, 13, 0, 139)
    divider.Size = UDim2.new(1, -26, 0, 2)
    divider.BackgroundColor3 = THEME.Divider
    divider.BorderSizePixel = 0
    divider.Parent = filterCard

    local label = text(
        filterCard,
        "◆ SPECIAL RARITY BYPASS",
        146,
        9,
        THEME.Purple,
        true
    )
    label.Size = UDim2.new(1, -26, 0, 18)

    state.GemstoneRubyButton = Instance.new("TextButton")
    state.GemstoneRubyButton.Size = UDim2.new(1, -26, 0, 30)
    state.GemstoneRubyButton.Position = UDim2.new(0, 13, 0, 169)
    state.GemstoneRubyButton.BackgroundColor3 = CONFIG.GEMSTONE_RUBY_FILTER == true and THEME.Purple or THEME.Surface2
    state.GemstoneRubyButton.BorderSizePixel = 0
    state.GemstoneRubyButton.Text = "GEMSTONE RUBY" .. (CONFIG.GEMSTONE_RUBY_FILTER == true and "  ✓" or "  ×")
    state.GemstoneRubyButton.TextColor3 = THEME.Text
    state.GemstoneRubyButton.Font = Enum.Font.GothamBold
    state.GemstoneRubyButton.TextSize = 10
    state.GemstoneRubyButton.Parent = filterCard
    addCorner(state.GemstoneRubyButton, 7)
    addStroke(state.GemstoneRubyButton, THEME.Purple, 0.12)

    state.GemstoneRubyButton.Activated:Connect(function()
        CONFIG.GEMSTONE_RUBY_FILTER = not (CONFIG.GEMSTONE_RUBY_FILTER == true)
        local active = CONFIG.GEMSTONE_RUBY_FILTER == true
        state.GemstoneRubyButton.BackgroundColor3 = active and THEME.Purple or THEME.Surface2
        state.GemstoneRubyButton.Text = "GEMSTONE RUBY" .. (active and "  ✓" or "  ×")
    end)

    local hint = text(
        filterCard,
        "ON = Gemstone Ruby tetap terkirim walau Legendary OFF. Ruby lain tetap diblok.",
        205,
        8,
        THEME.Muted
    )
    hint.Size = UDim2.new(1, -26, 0, 24)
end
]],
"scope gemstone ruby UI"
)

replaceOnce(
[[    local gemstoneRubyEnabled = CONFIG.GEMSTONE_RUBY_FILTER == true
    gemstoneRubyButton.BackgroundColor3 = gemstoneRubyEnabled and THEME.Purple or THEME.Surface2
    gemstoneRubyButton.Text = "GEMSTONE RUBY" .. (gemstoneRubyEnabled and "  ✓" or "  ×")
]],
[[    local gemstoneRubyEnabled = CONFIG.GEMSTONE_RUBY_FILTER == true
    if state.GemstoneRubyButton then
        state.GemstoneRubyButton.BackgroundColor3 = gemstoneRubyEnabled and THEME.Purple or THEME.Surface2
        state.GemstoneRubyButton.Text = "GEMSTONE RUBY" .. (gemstoneRubyEnabled and "  ✓" or "  ×")
    end
]],
"sync gemstone ruby UI"
)

local compiled, compileError = loadstring(source)
if not compiled then
    warn("[LFAMILIA] COMPILE ERROR: " .. tostring(compileError))
    return
end

local okRun, runError = pcall(compiled)
if not okRun then
    warn("[LFAMILIA] RUNTIME ERROR: " .. tostring(runError))
end
