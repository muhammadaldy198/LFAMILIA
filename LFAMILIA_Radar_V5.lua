--[[
LFAMILIA RADAR V5 - FINAL MOBILE
Target: Delta Android / touch-first

Files:
  LFAMILIA_Radar_V5.lua
  FishDatabase.lua
  RarityDatabase.lua
  VariantDatabase.lua

IMPORTANT:
1) Host the 3 database files somewhere accessible via raw HTTPS.
2) Put your Discord webhook URL below.
3) The monitor is designed for real-time catch notifications.
4) This version intentionally does NOT contain moderator/admin/developer
   evasion logic. I can help with a privacy-safe pause/stop control instead.
]]

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local HttpService = game:GetService("HttpService")
local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local CONFIG = {
    WEBHOOK_URL = "",
    FISH_DB_URL = "https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/FishDatabase.lua",
    RARITY_DB_URL = "https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/RarityDatabase.lua",
    VARIANT_DB_URL = "https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/VariantDatabase.lua",

    -- Notification filters
    ALLOW_RARITY = {
        SECRET = true,
        FORGOTTEN = true,
        Mythic = true,
        Legendary = false,
        Epic = false,
        Rare = false,
        Uncommon = false,
        Common = false,
    },
    MIN_WEIGHT = 0,

    -- Discord
    MENTION = "",
    WEBHOOK_USERNAME = "LFAMILIA Radar",
}

local function fetchLua(url)
    if not url or url == "" then return {} end
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    if ok and type(result) == "table" then return result end
    return {}
end

local FishDatabase = fetchLua(CONFIG.FISH_DB_URL)
local RarityDatabase = fetchLua(CONFIG.RARITY_DB_URL)
local VariantDatabase = fetchLua(CONFIG.VARIANT_DB_URL)

local function requestFn()
    return request or http_request or (syn and syn.request)
end

local function trim(s)
    return tostring(s or ""):gsub("^%s*(.-)%s*$", "%1")
end

local function firstRGB(colors)
    local c = colors and colors[1]
    if type(c) == "table" then
        return tonumber(c[1]) or 255, tonumber(c[2]) or 255, tonumber(c[3]) or 255
    end
    return 255, 255, 255
end

local function rgbInt(colors)
    local r,g,b = firstRGB(colors)
    return r * 65536 + g * 256 + b
end

local function parseCatch(message)
    message = trim(message)
    if message == "" then return nil end

    -- Common format:
    -- Player obtained a Fish (123kg) with a 1 in 5K chance!
    local player, fish, weight, chance =
        message:match("(.+) obtained a (.+) %(([%d%.]+)kg%) with a 1 in (.+) chance!")
    if player and fish then
        return {
            Player = trim(player),
            Fish = trim(fish),
            Weight = tonumber(weight) or 0,
            Chance = trim(chance),
        }
    end

    -- Variant format:
    -- Player obtained a Variant Fish (123kg) with a 1 in 5K chance!
    player, fish, weight, chance =
        message:match("(.+) obtained a (.+) %(([%d%.]+)kg%) with a 1 in (.+) chance!")
    if player and fish then
        local db = FishDatabase[trim(fish)]
        if db then
            return {
                Player = trim(player),
                Fish = trim(fish),
                Weight = tonumber(weight) or 0,
                Chance = trim(chance),
            }
        end
    end

    return nil
end

-- Resolve a fish entry. Exact match first, then a variant-prefixed name.
local function resolveFish(name)
    local direct = FishDatabase[name]
    if direct then return direct, name end

    -- Try stripping known variant prefixes.
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
        if type(v) == "table" and v.Name and v.Name:lower() == tostring(name):lower() then
            return v
        end
    end
end

local function resolveRarity(fishData)
    if not fishData then return nil end

    -- Accept either a numeric tier or a rarity name from the fish DB.
    if tonumber(fishData.Tier) then
        return RarityDatabase[tonumber(fishData.Tier)]
    end
    if fishData.Rarity then
        for _,tier in pairs(RarityDatabase) do
            if type(tier) == "table" and tostring(tier.Name):lower() == tostring(fishData.Rarity):lower() then
                return tier
            end
        end
    end
end

local state = {
    Running = true,
    Detected = 0,
    Sent = 0,
    Last = nil,
    Seen = {},
}

local function seenRecently(key)
    local now = os.clock()
    local old = state.Seen[key]
    state.Seen[key] = now

    -- Keep the dedupe window short enough to allow legitimate repeated catches.
    return old and (now - old) < 8
end

local function thumbnail(assetId)
    local id = tostring(assetId or ""):match("%d+")
    if not id then return nil end
    return "https://www.roblox.com/asset-thumbnail/image?assetId=" ..
        id .. "&width=420&height=420&format=png"
end

local function sendWebhook(data)
    if CONFIG.WEBHOOK_URL == "" then return false end

    local req = requestFn()
    if not req then return false end

    local fishData, fishName, detectedVariant = resolveFish(data.Fish)
    if not fishData then return false end

    local rarity = resolveRarity(fishData)
    local rarityName = rarity and rarity.Name or tostring(fishData.Rarity or "Unknown")

    if not CONFIG.ALLOW_RARITY[rarityName] then return false end
    if data.Weight < CONFIG.MIN_WEIGHT then return false end

    local variant = data.Variant and resolveVariant(data.Variant) or detectedVariant
    local variantName = variant and variant.Name or data.Variant

    local key = table.concat({
        data.Player or "", fishName or data.Fish or "",
        variantName or "", tostring(data.Weight or ""),
        data.Chance or "", game.JobId or ""
    }, "|")

    if seenRecently(key) then return false end

    local embed = {
        title = "✦ " .. string.upper(rarityName) .. " CATCH",
        description = "**" .. tostring(fishName or data.Fish) .. "**" ..
            (variantName and ("\n`" .. tostring(variantName) .. "`") or ""),
        color = rarity and rgbInt(rarity.Colors) or 0xFFFFFF,
        fields = {
            { name = "👤 Player", value = tostring(data.Player), inline = true },
            { name = "⚖ Weight", value = string.format("%.2f kg", data.Weight), inline = true },
            { name = "🎲 Chance", value = "1 in " .. tostring(data.Chance), inline = true },
            { name = "⭐ Rarity", value = tostring(rarityName), inline = true },
        },
        footer = { text = "LFAMILIA Radar V5 • Fish It" },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }

    if variantName then
        embed.fields[#embed.fields + 1] = {
            name = "◆ Variant",
            value = tostring(variantName),
            inline = true
        }
    end

    local image = thumbnail(fishData.AssetId)
    if image then
        embed.image = { url = image }
    end

    embed.fields[#embed.fields + 1] = {
        name = "🌐 Server",
        value = "`" .. tostring(game.JobId):sub(1, 18) .. "...`",
        inline = false
    }

    local payload = {
        username = CONFIG.WEBHOOK_USERNAME,
        content = CONFIG.MENTION or "",
        embeds = {embed},
    }

    local ok = pcall(function()
        req({
            Url = CONFIG.WEBHOOK_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(payload),
        })
    end)

    if ok then state.Sent += 1 end
    return ok
end

-- =========================
-- MOBILE UI
-- =========================

local gui = Instance.new("ScreenGui")
gui.Name = "LFAMILIA_Radar_V5"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
pcall(function() gui.Parent = CoreGui end)
if not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(342, 500)
main.Position = UDim2.new(0.5, -171, 0.5, -250)
main.BackgroundColor3 = Color3.fromRGB(16, 17, 22)
main.BorderSizePixel = 0
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 16)

local outline = Instance.new("UIStroke", main)
outline.Color = Color3.fromRGB(65, 68, 80)
outline.Transparency = 0.25

local header = Instance.new("TextButton")
header.Size = UDim2.new(1, -58, 0, 58)
header.BackgroundTransparency = 1
header.Text = "✦  LFAMILIA RADAR V5"
header.TextColor3 = Color3.fromRGB(245,245,248)
header.TextSize = 17
header.Font = Enum.Font.GothamBold
header.TextXAlignment = Enum.TextXAlignment.Left
header.AutoButtonColor = false
header.Parent = main
local hp = Instance.new("UIPadding", header)
hp.PaddingLeft = UDim.new(0,18)

local min = Instance.new("TextButton")
min.Size = UDim2.fromOffset(52,52)
min.Position = UDim2.new(1,-56,0,3)
min.BackgroundTransparency = 1
min.Text = "−"
min.TextSize = 25
min.TextColor3 = Color3.fromRGB(220,220,228)
min.Parent = main

local content = Instance.new("ScrollingFrame")
content.Position = UDim2.new(0, 10, 0, 62)
content.Size = UDim2.new(1,-20,1,-72)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 3
content.CanvasSize = UDim2.new()
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.Parent = main

local list = Instance.new("UIListLayout", content)
list.Padding = UDim.new(0,8)
list.SortOrder = Enum.SortOrder.LayoutOrder

local function addCard(height)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,0,0,height)
    f.BackgroundColor3 = Color3.fromRGB(23,25,32)
    f.BorderSizePixel = 0
    f.Parent = content
    Instance.new("UICorner", f).CornerRadius = UDim.new(0,12)
    return f
end

local statusCard = addCard(74)
local status = Instance.new("TextLabel")
status.Position = UDim2.fromOffset(14,10)
status.Size = UDim2.new(1,-28,0,25)
status.BackgroundTransparency = 1
status.Text = "●  MONITOR ACTIVE"
status.TextColor3 = Color3.fromRGB(95,225,145)
status.Font = Enum.Font.GothamBold
status.TextSize = 14
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = statusCard

local stats = Instance.new("TextLabel")
stats.Position = UDim2.fromOffset(14,38)
stats.Size = UDim2.new(1,-28,0,22)
stats.BackgroundTransparency = 1
stats.TextColor3 = Color3.fromRGB(185,188,200)
stats.Font = Enum.Font.Gotham
stats.TextSize = 12
stats.TextXAlignment = Enum.TextXAlignment.Left
stats.Parent = statusCard

local lastCard = addCard(132)
local lastText = Instance.new("TextLabel")
lastText.Position = UDim2.fromOffset(14,12)
lastText.Size = UDim2.new(1,-28,1,-24)
lastText.BackgroundTransparency = 1
lastText.Text = "LAST CATCH\n\nNo catch detected yet."
lastText.TextColor3 = Color3.fromRGB(230,231,236)
lastText.Font = Enum.Font.Gotham
lastText.TextSize = 14
lastText.TextWrapped = true
lastText.TextYAlignment = Enum.TextYAlignment.Top
lastText.TextXAlignment = Enum.TextXAlignment.Left
lastText.Parent = lastCard

local filtersCard = addCard(178)
local ft = Instance.new("TextLabel")
ft.Position = UDim2.fromOffset(14,10)
ft.Size = UDim2.new(1,-28,0,24)
ft.BackgroundTransparency = 1
ft.Text = "FILTERS"
ft.TextColor3 = Color3.fromRGB(150,154,170)
ft.Font = Enum.Font.GothamBold
ft.TextSize = 12
ft.TextXAlignment = Enum.TextXAlignment.Left
ft.Parent = filtersCard

local rarityOrder = {"SECRET","FORGOTTEN","Mythic","Legendary"}
for i,name in ipairs(rarityOrder) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.5,-10,0,38)
    b.Position = UDim2.new((i-1)%2*0.5, i%2==1 and 10 or 0, 0, 40 + math.floor((i-1)/2)*44)
    b.BackgroundColor3 = CONFIG.ALLOW_RARITY[name] and Color3.fromRGB(42,75,57) or Color3.fromRGB(34,36,44)
    b.Text = name .. (CONFIG.ALLOW_RARITY[name] and "  ✓" or "  ×")
    b.TextColor3 = Color3.fromRGB(230,232,238)
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 12
    b.Parent = filtersCard
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,9)
    b.Activated:Connect(function()
        CONFIG.ALLOW_RARITY[name] = not CONFIG.ALLOW_RARITY[name]
        b.BackgroundColor3 = CONFIG.ALLOW_RARITY[name] and Color3.fromRGB(42,75,57) or Color3.fromRGB(34,36,44)
        b.Text = name .. (CONFIG.ALLOW_RARITY[name] and "  ✓" or "  ×")
    end)
end

local info = addCard(72)
local infoText = Instance.new("TextLabel")
infoText.Position = UDim2.fromOffset(14,10)
infoText.Size = UDim2.new(1,-28,1,-20)
infoText.BackgroundTransparency = 1
infoText.Text = "Webhook: " .. (CONFIG.WEBHOOK_URL ~= "" and "configured" or "not configured") ..
    "\nDrag the top bar • tap − to minimize"
infoText.TextColor3 = Color3.fromRGB(145,148,160)
infoText.Font = Enum.Font.Gotham
infoText.TextSize = 11
infoText.TextWrapped = true
infoText.TextXAlignment = Enum.TextXAlignment.Left
infoText.Parent = info

local minimized = false
min.Activated:Connect(function()
    minimized = not minimized
    content.Visible = not minimized
    main.Size = minimized and UDim2.fromOffset(250,58) or UDim2.fromOffset(342,500)
    min.Text = minimized and "+" or "−"
end)

-- Touch-friendly dragging.
local dragging = false
local dragInput, dragStart, startPos

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
        dragInput = input
    end
end)

UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

UIS.InputEnded:Connect(function(input)
    if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

local function updateUI(data, fishData, rarity, variant)
    state.Detected += 1
    state.Last = data

    stats.Text = string.format(
        "Players %d   •   Detected %d   •   Sent %d",
        #Players:GetPlayers(), state.Detected, state.Sent
    )

    lastText.Text = string.format(
        "LAST CATCH\n\n✦ %s\n%s%s\n⚖ %.2f kg   •   🎲 1 in %s\n👤 %s",
        tostring(fishData.Name or data.Fish),
        rarity and rarity.Name or "Unknown",
        variant and ("  •  " .. variant.Name) or "",
        data.Weight,
        tostring(data.Chance),
        tostring(data.Player)
    )
end

local function handleMessage(message)
    if not state.Running then return end

    local data = parseCatch(message)
    if not data then return end

    local fishData, fishName, detectedVariant = resolveFish(data.Fish)
    if not fishData then return end

    local rarity = resolveRarity(fishData)
    local variant = detectedVariant or (data.Variant and resolveVariant(data.Variant))

    updateUI(data, fishData, rarity, variant)
    sendWebhook(data)

    stats.Text = string.format(
        "Players %d   •   Detected %d   •   Sent %d",
        #Players:GetPlayers(), state.Detected, state.Sent
    )
end

-- Main detector.
if TextChatService.MessageReceived then
    TextChatService.MessageReceived:Connect(function(msg)
        local text = msg and msg.Text
        if text then handleMessage(text) end
    end)
end

print("[LFAMILIA] Radar V5 final loaded.")
