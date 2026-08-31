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

replaceOnce(
[[    pcall(function() sendJoinLeaveWebhook(player, "JOINED") end)
]],
[[    -- Webhook JOIN dinonaktifkan. Log JOIN/UI tetap berjalan seperti sebelumnya.
]],
"disable join webhook only"
)


-- =============================================================================
-- PATCH: PER-DISCORD-ID FISH / LEAVE WEBHOOK SUBSCRIPTION + MAPPING UI
-- Hanya menambah kontrol routing pada mapping Discord. Webhook JOIN tetap OFF.
-- =============================================================================

replaceOnce(
[[-- Format mapping baru: [DiscordUserId] = {"RobloxAccount1", "RobloxAccount2"}
local mappings = {}
]],
[[-- Format mapping tetap: [DiscordUserId] = {"RobloxAccount1", "RobloxAccount2"}
local mappings = {}

-- Pengaturan routing per Discord ID.
-- Mapping/profile lama yang belum punya data ini otomatis dianggap ON/ON.
local mappingWebhookPrefs = {}
]],
"add per-id webhook preferences"
)

replaceOnce(
[[local function addMappingEntry(target, discordId, playerName)
]],
[[local function ensureMappingWebhookPrefs(discordId)
    discordId = normalizeDiscordId(discordId)
    if discordId == "" then
        return {fish = true, leave = true}
    end

    local prefs = mappingWebhookPrefs[discordId]
    if type(prefs) ~= "table" then
        prefs = {fish = true, leave = true}
        mappingWebhookPrefs[discordId] = prefs
    end

    if type(prefs.fish) ~= "boolean" then prefs.fish = true end
    if type(prefs.leave) ~= "boolean" then prefs.leave = true end
    return prefs
end

local function addMappingEntry(target, discordId, playerName)
]],
"add preference helper"
)

replaceOnce(
[[        SchemaVersion = 2,
]],
[[        SchemaVersion = 3,
]],
"bump profile schema for mapping webhook prefs"
)

replaceOnce(
[[        mappings = normalizeMappings(mappings),
]],
[[        mappings = normalizeMappings(mappings),
        mappingWebhookPrefs = mappingWebhookPrefs,
]],
"save per-id webhook prefs"
)

replaceOnce(
[[    if data.mappings then
        table.clear(mappings)
        local normalized = normalizeMappings(data.mappings)
        for discordId, playerList in pairs(normalized) do
            mappings[discordId] = playerList
        end
    end
    if refreshMappings then refreshMappings() end
]],
[[    if data.mappings then
        table.clear(mappings)
        local normalized = normalizeMappings(data.mappings)
        for discordId, playerList in pairs(normalized) do
            mappings[discordId] = playerList
        end
    end

    table.clear(mappingWebhookPrefs)
    if type(data.mappingWebhookPrefs) == "table" then
        for rawDiscordId, rawPrefs in pairs(data.mappingWebhookPrefs) do
            local discordId = normalizeDiscordId(rawDiscordId)
            if discordId ~= "" and type(rawPrefs) == "table" then
                mappingWebhookPrefs[discordId] = {
                    fish = rawPrefs.fish ~= false,
                    leave = rawPrefs.leave ~= false,
                }
            end
        end
    end

    -- Kompatibilitas profile lama: setiap mapping yang belum punya prefs = ON/ON.
    for discordId in pairs(mappings) do
        ensureMappingWebhookPrefs(discordId)
    end

    if refreshMappings then refreshMappings() end
]],
"load per-id webhook prefs"
)

replaceOnce(
[[local function getMentionsForPlayer(playerName, playerObject)
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
]],
[[local function getMappingDeliveryState(playerName, playerObject, webhookKind)
    local hasMapping = false
    local hasEnabledMapping = false

    for discordId, playerList in pairs(mappings) do
        if type(playerList) == "table" then
            for _, mappedPlayer in ipairs(playerList) do
                if playerNamesMatch(mappedPlayer, playerName, playerObject) then
                    hasMapping = true
                    local prefs = ensureMappingWebhookPrefs(discordId)
                    if webhookKind ~= "fish" and webhookKind ~= "leave" then
                        hasEnabledMapping = true
                    elseif prefs[webhookKind] ~= false then
                        hasEnabledMapping = true
                    end
                    break
                end
            end
        end
    end

    return hasMapping, hasEnabledMapping
end

local function getMentionsForPlayer(playerName, playerObject, webhookKind)
    local mentions = {}
    local seenDiscord = {}

    for discordId, playerList in pairs(mappings) do
        if type(playerList) == "table" then
            for _, mappedPlayer in ipairs(playerList) do
                if playerNamesMatch(mappedPlayer, playerName, playerObject) then
                    local id = normalizeDiscordId(discordId)
                    local prefs = ensureMappingWebhookPrefs(id)
                    local enabled = webhookKind ~= "fish" and webhookKind ~= "leave"
                        or prefs[webhookKind] ~= false

                    if enabled and id ~= "" and not seenDiscord[id] then
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
]],
"filter mentions by per-id webhook prefs"
)

replaceOnce(
[[    -- Mention hanya berasal dari akun yang dipetakan ke player tersebut.
    local mention = getMentionsForPlayer(data.Player, Players:FindFirstChild(data.Player))
]],
[[    -- Routing per Discord ID: jika player mempunyai mapping tetapi semua mapping
    -- untuk FISH dimatikan, catch tersebut tidak dikirim ke webhook.
    local mappedPlayerObject = Players:FindFirstChild(data.Player)
    local hasFishMapping, hasFishEnabled = getMappingDeliveryState(data.Player, mappedPlayerObject, "fish")
    if hasFishMapping and not hasFishEnabled then
        appendMonitorLog("⏸", "Fish webhook OFF untuk mapping player: " .. tostring(data.Player))
        return false
    end

    local mention = getMentionsForPlayer(data.Player, mappedPlayerObject, "fish")
]],
"apply fish routing per mapping"
)

replaceOnce(
[[    local mention = getMentionsForPlayer(playerName, playerObject)
    local actionText = action == "JOINED"
]],
[[    -- Webhook JOIN sudah dinonaktifkan oleh patch sebelumnya.
    -- Untuk LEFT, hormati toggle LEAVE per Discord ID.
    if action == "LEFT" then
        local hasLeaveMapping, hasLeaveEnabled = getMappingDeliveryState(playerName, playerObject, "leave")
        if hasLeaveMapping and not hasLeaveEnabled then
            appendMonitorLog("⏸", "Leave webhook OFF untuk mapping player: " .. tostring(playerName))
            return
        end
    end

    local mention = getMentionsForPlayer(
        playerName,
        playerObject,
        action == "LEFT" and "leave" or nil
    )
    local actionText = action == "JOINED"
]],
"apply leave routing per mapping"
)

replaceOnce(
[[local mappingBox = card(logPage, 300, THEME.Purple)
text(mappingBox, "🔗 DISCORD ACCOUNT MAPPING", 10, 11, THEME.Purple, true)
local mappingHint = text(mappingBox, "Masukkan ID Discord, pilih player, lalu simpan manual di CONFIG.", 35, 9, THEME.Muted)
]],
[[local mappingBox = card(logPage, 390, THEME.Purple)
text(mappingBox, "🔗 DISCORD ACCOUNT & WEBHOOK ROUTING", 10, 11, THEME.Purple, true)
local mappingHint = text(mappingBox, "Setiap Discord ID punya kontrol FISH dan LEAVE sendiri.", 35, 9, THEME.Muted)
]],
"redesign mapping card header"
)

replaceOnce(
[[mappingScroll.Position = UDim2.new(0, 13, 0, 96)
mappingScroll.Size = UDim2.new(1, -26, 0, 162)
]],
[[mappingScroll.Position = UDim2.new(0, 13, 0, 96)
mappingScroll.Size = UDim2.new(1, -26, 0, 244)
]],
"enlarge mapping scroll"
)

replaceOnce(
[[    270,
]],
[[    350,
]],
"move mapping status lower"
)

replaceOnce(
[[local webhookHint = text(webhookCard, "URL catch dan join/leave terpisah; test dikirim ke URL catch.", 34, 9, THEME.Muted)
]],
[[local webhookHint = text(webhookCard, "URL catch dan leave terpisah; test dikirim ke URL catch.", 34, 9, THEME.Muted)
]],
"update webhook routing hint"
)

replaceOnce(
[[local logWebhookInput = makeInput(webhookCard, 89, CONFIG.JOIN_LEAVE_URL, "Discord webhook URL (join/leave)")
]],
[[local logWebhookInput = makeInput(webhookCard, 89, CONFIG.JOIN_LEAVE_URL, "Discord webhook URL (leave)")
]],
"update leave webhook placeholder"
)

replaceOnce(
[[    for index, discordId in ipairs(discordIds) do
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
]],
[[    for index, discordId in ipairs(discordIds) do
        local playerList = normalized[discordId] or {}
        local prefs = ensureMappingWebhookPrefs(discordId)

        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 92)
        row.BackgroundColor3 = index % 2 == 0
            and Color3.fromRGB(18, 23, 38)
            or Color3.fromRGB(14, 19, 32)
        row.BorderSizePixel = 0
        row.LayoutOrder = index
        row.Parent = mappingRows
        addCorner(row, 8)
        addStroke(row, THEME.Border, 0.55)

        local idLabel = Instance.new("TextLabel")
        idLabel.Position = UDim2.fromOffset(10, 7)
        idLabel.Size = UDim2.new(1, -20, 0, 20)
        idLabel.BackgroundTransparency = 1
        idLabel.Text = "DISCORD  <@" .. discordId .. ">"
        idLabel.TextColor3 = THEME.Cyan
        idLabel.TextSize = 10
        idLabel.Font = Enum.Font.GothamBold
        idLabel.TextXAlignment = Enum.TextXAlignment.Left
        idLabel.Parent = row

        local playerLabel = Instance.new("TextLabel")
        playerLabel.Position = UDim2.fromOffset(10, 29)
        playerLabel.Size = UDim2.new(1, -20, 0, 20)
        playerLabel.BackgroundTransparency = 1
        playerLabel.Text = "ROBLOX  •  " .. table.concat(playerList, ", ")
        playerLabel.TextColor3 = THEME.Text
        playerLabel.TextSize = 9
        playerLabel.Font = Enum.Font.Code
        playerLabel.TextXAlignment = Enum.TextXAlignment.Left
        playerLabel.TextYAlignment = Enum.TextYAlignment.Center
        playerLabel.TextTruncate = Enum.TextTruncate.AtEnd
        playerLabel.Parent = row

        local function updateRoutingButton(button, kind, title)
            local enabled = ensureMappingWebhookPrefs(discordId)[kind] ~= false
            button.Text = title .. (enabled and "  ON" or "  OFF")
            button.BackgroundColor3 = enabled and THEME.Green or THEME.Surface2
            button.TextColor3 = enabled and Color3.fromRGB(8, 20, 15) or THEME.Muted
        end

        local fishButton = makeButton(
            row,
            "FISH",
            UDim2.new(0, 10, 0, 56),
            UDim2.new(0.31, -7, 0, 27),
            THEME.Green
        )

        local leaveButton = makeButton(
            row,
            "LEAVE",
            UDim2.new(0.33, 3, 0, 56),
            UDim2.new(0.31, -7, 0, 27),
            THEME.Green
        )

        local removeButton = makeButton(
            row,
            "DELETE",
            UDim2.new(0.66, 3, 0, 56),
            UDim2.new(0.34, -13, 0, 27),
            THEME.Red
        )

        updateRoutingButton(fishButton, "fish", "FISH")
        updateRoutingButton(leaveButton, "leave", "LEAVE")

        fishButton.Activated:Connect(function()
            local current = ensureMappingWebhookPrefs(discordId)
            current.fish = not (current.fish ~= false)
            updateRoutingButton(fishButton, "fish", "FISH")
            mappingLogStatus.TextColor3 = THEME.Orange
            mappingLogStatus.Text = "Routing FISH diubah. CONFIG → SAVE untuk menyimpan."
            appendMonitorLog(
                current.fish and "✅" or "⏸",
                "FISH " .. (current.fish and "ON" or "OFF") .. " untuk <@" .. discordId .. ">"
            )
        end)

        leaveButton.Activated:Connect(function()
            local current = ensureMappingWebhookPrefs(discordId)
            current.leave = not (current.leave ~= false)
            updateRoutingButton(leaveButton, "leave", "LEAVE")
            mappingLogStatus.TextColor3 = THEME.Orange
            mappingLogStatus.Text = "Routing LEAVE diubah. CONFIG → SAVE untuk menyimpan."
            appendMonitorLog(
                current.leave and "✅" or "⏸",
                "LEAVE " .. (current.leave and "ON" or "OFF") .. " untuk <@" .. discordId .. ">"
            )
        end)

        removeButton.Activated:Connect(function()
            if mappings[discordId] == nil then return end
            mappings[discordId] = nil
            mappingWebhookPrefs[discordId] = nil
            refreshMappings()
            mappingLogStatus.TextColor3 = THEME.Orange
            mappingLogStatus.Text = "Mapping dihapus. Tekan CONFIG → SAVE untuk menyimpan."
            appendMonitorLog("🗑", "Mapping dihapus: <@" .. discordId .. ">")
        end)
    end
]],
"redesign mapping rows with fish and leave toggles"
)

replaceOnce(
[[    mappings[discordId] = playerNames
    refreshMappings()
]],
[[    mappings[discordId] = playerNames
    ensureMappingWebhookPrefs(discordId)
    refreshMappings()
]],
"initialize prefs for new mapping"
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
