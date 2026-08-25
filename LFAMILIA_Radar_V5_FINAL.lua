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

local mappings = {}

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

    local allowed = CONFIG.ALLOW_RARITY[rarityName] or CONFIG.ALLOW_RARITY[string.upper(rarityName or "")]
    if not allowed then return false end
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
        local mappedDiscord = nil
    for roblox, discordId in pairs(mappings or {}) do
        if tostring(roblox):lower() == tostring(data.Player):lower() then
            mappedDiscord = discordId
            break
        end
    end
    local content = CONFIG.MENTION or ""
    if mappedDiscord and mappedDiscord ~= "" then
        content = (content ~= "" and (content .. " ") or "") .. "<@" .. tostring(mappedDiscord) .. ">"
    end

    local payload = {
        username = CONFIG.WEBHOOK_USERNAME,
        content = content,
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
-- MOBILE UI - 5 TABS
-- Home | Players | Monitor | Filters | Webhook
-- Touch-first: draggable + minimize
-- =========================

local gui = Instance.new("ScreenGui")
gui.Name = "LFAMILIA_Radar_V5"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
pcall(function() gui.Parent = CoreGui end)
if not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(350, 520)
main.Position = UDim2.new(0.5, -175, 0.5, -260)
main.BackgroundColor3 = Color3.fromRGB(15,16,21)
main.BorderSizePixel = 0
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0,16)

local outline = Instance.new("UIStroke", main)
outline.Color = Color3.fromRGB(65,68,80)
outline.Transparency = 0.25

local header = Instance.new("TextButton")
header.Size = UDim2.new(1,-58,0,58)
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

local tabbar = Instance.new("Frame")
tabbar.Position = UDim2.new(0,8,1,-56)
tabbar.Size = UDim2.new(1,-16,0,48)
tabbar.BackgroundColor3 = Color3.fromRGB(22,24,31)
tabbar.Parent = main
Instance.new("UICorner",tabbar).CornerRadius = UDim.new(0,12)

local pages = {}
local tabs = {}
local activeTab = "Home"

local function makePage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.Position = UDim2.new(0,10,0,62)
    page.Size = UDim2.new(1,-20,1,-125)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new()
    page.Visible = false
    page.Parent = main
    local layout = Instance.new("UIListLayout",page)
    layout.Padding = UDim.new(0,8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    pages[name] = page
    return page
end

local function card(parent, height)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,0,0,height)
    f.BackgroundColor3 = Color3.fromRGB(23,25,32)
    f.BorderSizePixel = 0
    f.Parent = parent
    Instance.new("UICorner",f).CornerRadius = UDim.new(0,12)
    return f
end

local function text(parent, value, y, size, color, bold)
    local t = Instance.new("TextLabel")
    t.Position = UDim2.fromOffset(14,y or 10)
    t.Size = UDim2.new(1,-28,0,28)
    t.BackgroundTransparency = 1
    t.Text = value
    t.TextColor3 = color or Color3.fromRGB(220,221,228)
    t.TextSize = size or 13
    t.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextWrapped = true
    t.Parent = parent
    return t
end

-- HOME
local home = makePage("Home")
local homeStatus = card(home,78)
text(homeStatus,"●  MONITOR ACTIVE",10,14,Color3.fromRGB(95,225,145),true)
local homeStats = text(homeStatus,"Players 0   •   Detected 0   •   Sent 0",39,12,Color3.fromRGB(185,188,200))

local homeLast = card(home,145)
local homeLastText = text(homeLast,"LAST CATCH\n\nNo catch detected yet.",12,14,Color3.fromRGB(230,231,236),false)
homeLastText.Size = UDim2.new(1,-28,1,-24)
homeLastText.TextYAlignment = Enum.TextYAlignment.Top

local homeWebhook = card(home,72)
text(homeWebhook,"WEBHOOK",10,12,Color3.fromRGB(150,154,170),true)
local homeWebhookStatus = text(homeWebhook,"● Not configured",35,12,Color3.fromRGB(230,190,95),false)

-- PLAYERS
local playersPage = makePage("Players")
local playerInfo = card(playersPage,62)
local playerInfoText = text(playerInfo,"PLAYER MAPPING\nMap multiple Roblox accounts to one Discord ID.",9,12,Color3.fromRGB(190,193,204),false)
playerInfoText.Size = UDim2.new(1,-28,1,-18)

local mappingBox = card(playersPage,220)
text(mappingBox,"DISCORD MAPPINGS",10,12,Color3.fromRGB(150,154,170),true)
local mappingText = text(mappingBox,"No mappings added yet.",40,12,Color3.fromRGB(215,216,224),false)
mappingText.Size = UDim2.new(1,-28,1,-50)

local addMapping = Instance.new("TextButton")
addMapping.Size = UDim2.new(1,-28,0,40)
addMapping.Position = UDim2.new(0,14,1,-52)
addMapping.Text = "+ ADD / EDIT MAPPING"
addMapping.TextSize = 12
addMapping.Font = Enum.Font.GothamBold
addMapping.TextColor3 = Color3.fromRGB(235,237,242)
addMapping.BackgroundColor3 = Color3.fromRGB(45,48,60)
addMapping.Parent = mappingBox
Instance.new("UICorner",addMapping).CornerRadius = UDim.new(0,9)

-- MONITOR
local monitorPage = makePage("Monitor")
local monitorCard = card(monitorPage,300)
local monitorLog = text(monitorCard,"DETECTION LOG\n\nWaiting for catch...",10,12,Color3.fromRGB(215,216,224),false)
monitorLog.Size = UDim2.new(1,-28,1,-20)
monitorLog.TextYAlignment = Enum.TextYAlignment.Top

-- FILTERS
local filtersPage = makePage("Filters")
local filterCard = card(filtersPage,270)
text(filterCard,"RARITY FILTER",10,12,Color3.fromRGB(150,154,170),true)

local rarityOrder = {"SECRET","FORGOTTEN","Mythic","Legendary","Epic","Rare","Uncommon","Common"}
for i,name in ipairs(rarityOrder) do
    local b = Instance.new("TextButton")
    local row = math.floor((i-1)/2)
    local col = (i-1)%2
    b.Size = UDim2.new(0.5,-18,0,36)
    b.Position = UDim2.new(col*0.5, col==0 and 10 or 8, 0, 40+row*40)
    b.BackgroundColor3 = CONFIG.ALLOW_RARITY[name] and Color3.fromRGB(42,75,57) or Color3.fromRGB(34,36,44)
    b.Text = name .. (CONFIG.ALLOW_RARITY[name] and "  ✓" or "  ×")
    b.TextColor3 = Color3.fromRGB(230,232,238)
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 11
    b.Parent = filterCard
    Instance.new("UICorner",b).CornerRadius = UDim.new(0,9)
    b.Activated:Connect(function()
        CONFIG.ALLOW_RARITY[name] = not CONFIG.ALLOW_RARITY[name]
        b.BackgroundColor3 = CONFIG.ALLOW_RARITY[name] and Color3.fromRGB(42,75,57) or Color3.fromRGB(34,36,44)
        b.Text = name .. (CONFIG.ALLOW_RARITY[name] and "  ✓" or "  ×")
    end)
end

local weightBox = card(filtersPage,76)
text(weightBox,"MINIMUM WEIGHT (KG)",10,11,Color3.fromRGB(150,154,170),true)
local weightInput = Instance.new("TextBox")
weightInput.Position = UDim2.fromOffset(14,34)
weightInput.Size = UDim2.new(1,-28,0,30)
weightInput.Text = tostring(CONFIG.MIN_WEIGHT)
weightInput.PlaceholderText = "0"
weightInput.TextSize = 12
weightInput.Font = Enum.Font.Gotham
weightInput.TextColor3 = Color3.fromRGB(235,236,242)
weightInput.BackgroundColor3 = Color3.fromRGB(32,34,42)
weightInput.ClearTextOnFocus = false
weightInput.Parent = weightBox
Instance.new("UICorner",weightInput).CornerRadius = UDim.new(0,8)
weightInput.FocusLost:Connect(function()
    CONFIG.MIN_WEIGHT = tonumber(weightInput.Text) or 0
    weightInput.Text = tostring(CONFIG.MIN_WEIGHT)
end)

-- WEBHOOK
local webhookPage = makePage("Webhook")
local webhookCard = card(webhookPage,230)
text(webhookCard,"DISCORD WEBHOOK",10,12,Color3.fromRGB(150,154,170),true)

local webhookInput = Instance.new("TextBox")
webhookInput.Position = UDim2.fromOffset(14,42)
webhookInput.Size = UDim2.new(1,-28,0,48)
webhookInput.Text = CONFIG.WEBHOOK_URL
webhookInput.PlaceholderText = "Paste Discord webhook URL"
webhookInput.TextSize = 12
webhookInput.Font = Enum.Font.Gotham
webhookInput.TextColor3 = Color3.fromRGB(235,236,242)
webhookInput.BackgroundColor3 = Color3.fromRGB(32,34,42)
webhookInput.ClearTextOnFocus = false
webhookInput.TextWrapped = true
webhookInput.Parent = webhookCard
Instance.new("UICorner",webhookInput).CornerRadius = UDim.new(0,9)

local saveWebhook = Instance.new("TextButton")
saveWebhook.Position = UDim2.fromOffset(14,100)
saveWebhook.Size = UDim2.new(0.48,-8,0,40)
saveWebhook.Text = "SAVE"
saveWebhook.TextSize = 12
saveWebhook.Font = Enum.Font.GothamBold
saveWebhook.TextColor3 = Color3.fromRGB(235,237,242)
saveWebhook.BackgroundColor3 = Color3.fromRGB(45,48,60)
saveWebhook.Parent = webhookCard
Instance.new("UICorner",saveWebhook).CornerRadius = UDim.new(0,9)

local testWebhook = saveWebhook:Clone()
testWebhook.Position = UDim2.new(0.52,0,0,100)
testWebhook.Text = "TEST"
testWebhook.Parent = webhookCard

local mentionInput = webhookInput:Clone()
mentionInput.Position = UDim2.fromOffset(14,152)
mentionInput.Size = UDim2.new(1,-28,0,38)
mentionInput.Text = CONFIG.MENTION
mentionInput.PlaceholderText = "Optional mention: <@&ROLE_ID>"
mentionInput.Parent = webhookCard

saveWebhook.Activated:Connect(function()
    CONFIG.WEBHOOK_URL = trim(webhookInput.Text)
    homeWebhookStatus.Text = CONFIG.WEBHOOK_URL ~= "" and "● Configured" or "● Not configured"
    homeWebhookStatus.TextColor3 = CONFIG.WEBHOOK_URL ~= "" and Color3.fromRGB(95,225,145) or Color3.fromRGB(230,190,95)
end)

mentionInput.FocusLost:Connect(function()
    CONFIG.MENTION = trim(mentionInput.Text)
end)

testWebhook.Activated:Connect(function()
    if CONFIG.WEBHOOK_URL == "" then return end
    local req = requestFn()
    if not req then return end
    pcall(function()
        req({
            Url = CONFIG.WEBHOOK_URL,
            Method = "POST",
            Headers = {["Content-Type"]="application/json"},
            Body = HttpService:JSONEncode({
                username = CONFIG.WEBHOOK_USERNAME,
                embeds = {{
                    title = "✦ LFAMILIA RADAR",
                    description = "Webhook test berhasil.",
                    color = 0x5865F2,
                    footer = {text="LFAMILIA Radar V5 • Fish It"}
                }}
            })
        })
    end)
end)

-- Tab buttons
local tabNames = {
    {"⌂","Home"}, {"♟","Players"}, {"◈","Monitor"}, {"⚙","Filters"}, {"🔔","Webhook"}
}
for i,item in ipairs(tabNames) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.2,-4,1,-6)
    b.Position = UDim2.new((i-1)*0.2,2,0,3)
    b.BackgroundTransparency = 1
    b.Text = item[1] .. "\n" .. item[2]
    b.TextSize = 9
    b.Font = Enum.Font.GothamSemibold
    b.TextColor3 = Color3.fromRGB(135,138,150)
    b.Parent = tabbar
    tabs[item[2]] = b
    Instance.new("UICorner",b).CornerRadius = UDim.new(0,9)
    b.Activated:Connect(function()
        activeTab = item[2]
        for n,p in pairs(pages) do p.Visible = (n == activeTab) end
        for n,t in pairs(tabs) do t.TextColor3 = (n == activeTab) and Color3.fromRGB(235,237,242) or Color3.fromRGB(135,138,150) end
    end)
end
pages.Home.Visible = true
tabs.Home.TextColor3 = Color3.fromRGB(235,237,242)

-- Mapping dialog: multiple Roblox accounts can share one Discord ID.
local dialog = Instance.new("Frame")
dialog.Size = UDim2.fromOffset(310,230)
dialog.Position = UDim2.new(0.5,-155,0.5,-115)
dialog.BackgroundColor3 = Color3.fromRGB(20,21,27)
dialog.Visible = false
dialog.ZIndex = 20
dialog.Parent = gui
Instance.new("UICorner",dialog).CornerRadius = UDim.new(0,14)
Instance.new("UIStroke",dialog).Color = Color3.fromRGB(70,73,85)

local dt = text(dialog,"ADD PLAYER → DISCORD",12,14,Color3.fromRGB(240,241,246),true)
dt.ZIndex = 21
local robloxBox = Instance.new("TextBox")
robloxBox.Position = UDim2.fromOffset(14,52)
robloxBox.Size = UDim2.new(1,-28,0,42)
robloxBox.PlaceholderText = "Roblox username"
robloxBox.Text = ""
robloxBox.TextSize = 12
robloxBox.Font = Enum.Font.Gotham
robloxBox.TextColor3 = Color3.fromRGB(235,236,242)
robloxBox.BackgroundColor3 = Color3.fromRGB(32,34,42)
robloxBox.ZIndex = 21
robloxBox.Parent = dialog
Instance.new("UICorner",robloxBox).CornerRadius = UDim.new(0,9)

local discordBox = robloxBox:Clone()
discordBox.Position = UDim2.fromOffset(14,102)
discordBox.PlaceholderText = "Discord User ID (same ID may be reused)"
discordBox.Parent = dialog

local mapSave = Instance.new("TextButton")
mapSave.Position = UDim2.fromOffset(14,156)
mapSave.Size = UDim2.new(0.48,-8,0,40)
mapSave.Text = "SAVE"
mapSave.TextSize = 12
mapSave.Font = Enum.Font.GothamBold
mapSave.TextColor3 = Color3.fromRGB(235,237,242)
mapSave.BackgroundColor3 = Color3.fromRGB(45,48,60)
mapSave.ZIndex = 21
mapSave.Parent = dialog
Instance.new("UICorner",mapSave).CornerRadius = UDim.new(0,9)

local mapCancel = mapSave:Clone()
mapCancel.Position = UDim2.new(0.52,0,0,156)
mapCancel.Text = "CANCEL"
mapCancel.Parent = dialog

local function refreshMappings()
    local lines = {}
    for roblox,discord in pairs(mappings) do
        lines[#lines+1] = "👤 "..roblox.."  →  "..discord
    end
    table.sort(lines)
    mappingText.Text = #lines > 0 and table.concat(lines,"\n") or "No mappings added yet."
end

addMapping.Activated:Connect(function()
    dialog.Visible = true
end)

mapCancel.Activated:Connect(function()
    dialog.Visible = false
end)

mapSave.Activated:Connect(function()
    local r,d = trim(robloxBox.Text), trim(discordBox.Text)
    if r ~= "" and d ~= "" then
        mappings[r] = d
        refreshMappings()
        robloxBox.Text = ""
        discordBox.Text = ""
        dialog.Visible = false
    end
end)

-- Minimize
local minimized = false
min.Activated:Connect(function()
    minimized = not minimized
    contentVisible = not minimized
    tabbar.Visible = not minimized
    for _,p in pairs(pages) do p.Visible = not minimized and (_ == activeTab) or false end
    main.Size = minimized and UDim2.fromOffset(250,58) or UDim2.fromOffset(350,520)
    min.Text = minimized and "+" or "−"
end)

-- Touch drag
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
        main.Position = UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
    end
end)
UIS.InputEnded:Connect(function(input)
    if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

local function updateUI(data, fishData, rarity, variant)
    state.Detected += 1
    state.Last = data
    local r = rarity and rarity.Name or "Unknown"
    local v = variant and variant.Name or ""
    local line = string.format("✦ %s\n%s%s\n⚖ %.2f kg  •  🎲 1 in %s\n👤 %s",
        tostring(fishData.Name or data.Fish), r, v ~= "" and ("  •  "..v) or "",
        data.Weight, tostring(data.Chance), tostring(data.Player))
    homeLastText.Text = "LAST CATCH\n\n"..line
    monitorLog.Text = "DETECTION LOG\n\n"..line.."\n\n"..monitorLog.Text:sub(17, math.min(#monitorLog.Text,1800))
    homeStats.Text = string.format("Players %d   •   Detected %d   •   Sent %d",
        #Players:GetPlayers(), state.Detected, state.Sent)
end


-- Main detector.
if TextChatService.MessageReceived then
    TextChatService.MessageReceived:Connect(function(msg)
        local text = msg and msg.Text
        if text then handleMessage(text) end
    end)
end

print("[LFAMILIA] Radar V5 final loaded.")
