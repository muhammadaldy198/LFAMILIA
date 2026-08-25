--[[
LFAMILIA RADAR V5 - DELTA ANDROID EDITION
[BAGIAN 1 DARI 10]
]]

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local HttpService = game:GetService("HttpService")
local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local CONFIG = {
    WEBHOOK_URL = "",
    FISH_DB_URL = "https://githubusercontent.com",
    RARITY_DB_URL = "https://githubusercontent.com",
    VARIANT_DB_URL = "https://githubusercontent.com",
    ALLOW_RARITY = {
        SECRET = true, FORGOTTEN = true, Mythic = true,
        Legendary = true, Epic = false, Rare = false,
        Uncommon = false, Common = false,
    },
    MIN_WEIGHT = 0,
    MENTION = "",
    WEBHOOK_USERNAME = "LFAMILIA Radar (Fish It)",
}

local mappings = {}
local state = { Running = true, Detected = 0, Sent = 0, Last = nil, Seen = {} }
local CONFIG_FILE = "LFAMILIA_Radar_Save.json"
--[[ [BAGIAN 2 DARI 10] ]]
local function getWriteFn() return writefile or (syn and syn.writefile) end
local function getReadFn()  return readfile  or (syn and syn.readfile)  end

local function saveConfig()
    local wf = getWriteFn()
    if not wf then return end
    local data = {
        CONFIG = {
            WEBHOOK_URL = CONFIG.WEBHOOK_URL,
            ALLOW_RARITY = CONFIG.ALLOW_RARITY,
            MIN_WEIGHT = CONFIG.MIN_WEIGHT,
            MENTION = CONFIG.MENTION,
            WEBHOOK_USERNAME = CONFIG.WEBHOOK_USERNAME,
        },
        mappings = mappings,
    }
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
    if ok then pcall(wf, CONFIG_FILE, encoded) end
end

local function loadConfig()
    local rf = getReadFn()
    if not rf then return end
    local ok, content = pcall(rf, CONFIG_FILE)
    if not ok or content == "" then return end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, content)
    if not ok or not data then return end
    if data.CONFIG then
        for k, v in pairs(data.CONFIG) do
            if CONFIG[k] ~= nil then
                if type(v) == "table" and type(CONFIG[k]) == "table" then
                    for k2, v2 in pairs(v) do CONFIG[k][k2] = v2 end
                else
                    CONFIG[k] = v
                end
            end
        end
    end
    if data.mappings then
        for k, v in pairs(data.mappings) do mappings[k] = v end
    end
end

loadConfig()
--[[ [BAGIAN 3 DARI 10] ]]
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
    return request or http_request or (syn and syn.request) or (fluxus and fluxus.request)
end

local function trim(s)
    return tostring(s or ""):gsub("^%s*(.-)%s*$", "%1")
end

local function rgbInt(colors)
    local c = colors and colors
    if type(c) == "table" then
        local r, g, b = tonumber(c[1]) or 255, tonumber(c[2]) or 255, tonumber(c[3]) or 255
        return r * 65536 + g * 256 + b
    end
    return 0xFFFFFF
end
--[[ [BAGIAN 4 DARI 10] ]]
local function parseCatch(message)
    message = trim(message)
    if message == "" then return nil end
    
    local player, fish, weight, chance = message:match("([%w_]+) obtained a (.+) %(([%d%.]+)kg%) with a 1 in (.+) chance!")
    
    if not player then
        player, fish, weight, chance = message:match("(.+) obtained a (.+) %(([%d%.]+)kg%) with a 1 in ([%d%.,%s%a]+) chance!")
    end
    
    if player and fish then
        return {
            Player = trim(player),
            Fish = trim(fish),
            Weight = tonumber(weight) or 0,
            Chance = trim(chance):gsub(" chance!", ""),
        }
    end
    return nil
end

local function resolveFish(name)
    local direct = FishDatabase[name]
    if direct then return direct, name end
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
--[[ [BAGIAN 5 DARI 10] ]]
local function resolveVariant(name)
    for _,v in pairs(VariantDatabase) do
        if type(v) == "table" and v.Name and v.Name:lower() == tostring(name):lower() then
            return v
        end
    end
end

local function resolveRarity(fishData)
    if not fishData then return nil end
    if tonumber(fishData.Tier) then return RarityDatabase[tonumber(fishData.Tier)] end
    if fishData.Rarity then
        for _,tier in pairs(RarityDatabase) do
            if type(tier) == "table" and tostring(tier.Name):lower() == tostring(fishData.Rarity):lower() then
                return tier
            end
        end
    end
end

local function seenRecently(key)
    local now = os.clock()
    local old = state.Seen[key]
    state.Seen[key] = now
    return old and (now - old) < 5
end

local function sendWebhook(data)
    if CONFIG.WEBHOOK_URL == "" then return false end
    local req = requestFn()
    if not req then return false end

    local fishData, fishName, detectedVariant = resolveFish(data.Fish)
    local rarity = fishData and resolveRarity(fishData)
    local rarityName = rarity and rarity.Name or (fishData and tostring(fishData.Rarity) or "Unknown")

    if not CONFIG.ALLOW_RARITY[rarityName] and not CONFIG.ALLOW_RARITY[string.upper(rarityName)] then
        return false
    end
    if data.Weight < CONFIG.MIN_WEIGHT then return false end

    local key = data.Player .. "|" .. data.Fish .. "|" .. tostring(data.Weight)
    if seenRecently(key) then return false end

    local embed = {
        title = "🎣 GLOBAL SERVER CATCH",
        description = "**" .. data.Player .. "** caught a **" .. data.Fish .. "**!",
        color = rarity and rgbInt(rarity.Colors) or 0x00FFAC,
        fields = {
            { name = "👤 Player", value = "`" .. data.Player .. "`", inline = true },
            { name = "🐟 Fish", value = tostring(data.Fish), inline = true },
            { name = "⚖ Weight", value = string.format("%.2f kg", data.Weight), inline = true },
            { name = "🎲 Chance", value = "1 in " .. tostring(data.Chance), inline = true },
        },
        footer = { text = "LFAMILIA Radar V5 • Delta Android" },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }

    local mappedDiscord = mappings[data.Player] or mappings[data.Player:lower()]
    local content = CONFIG.MENTION or ""
    if mappedDiscord then content = content .. " <@" .. tostring(mappedDiscord) .. ">" end

    local payload = { username = CONFIG.WEBHOOK_USERNAME, content = trim(content), embeds = {embed} }

    local ok = pcall(function()
        req({
            Url = CONFIG.WEBHOOK_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(payload),
        })
    end)
    if ok then state.Sent = state.Sent + 1 return true end
    return false
end
--[[ [BAGIAN 6 DARI 10] ]]
local gui = Instance.new("ScreenGui")
gui.Name = "LFAMILIA_Radar_V5"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
pcall(function() gui.Parent = CoreGui end)
if not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 340, 0, 320)
main.Position = UDim2.new(0.5, -170, 0.4, -160)
main.BackgroundColor3 = Color3.fromRGB(15,16,21)
main.BorderSizePixel = 0
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
local outline = Instance.new("UIStroke", main)
outline.Color = Color3.fromRGB(65,68,80)

local header = Instance.new("TextButton")
header.Size = UDim2.new(1, -40, 0, 40)
header.BackgroundTransparency = 1
header.Text = "✦  LFAMILIA RADAR (ANDROID)"
header.TextColor3 = Color3.fromRGB(245,245,248)
header.TextSize = 13
header.Font = Enum.Font.GothamBold
header.TextXAlignment = Enum.TextXAlignment.Left
header.Parent = main
local hp = Instance.new("UIPadding", header)
hp.PaddingLeft = UDim.new(0, 10)

local min = Instance.new("TextButton")
min.Size = UDim2.fromOffset(35, 35)
min.Position = UDim2.new(1, -38, 0, 3)
min.BackgroundTransparency = 1
min.Text = "−"
min.TextSize = 18
min.TextColor3 = Color3.fromRGB(220,220,228)
min.Parent = main

local tabbar = Instance.new("Frame")
tabbar.Position = UDim2.new(0, 6, 1, -40)
tabbar.Size = UDim2.new(1, -12, 0, 34)
tabbar.BackgroundColor3 = Color3.fromRGB(22,24,31)
tabbar.Parent = main
Instance.new("UICorner", tabbar).CornerRadius = UDim.new(0, 6)
--[[ [BAGIAN 7 DARI 10] ]]
local pages = {}
local tabs = {}
local activeTab = "Home"

local function makePage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.Position = UDim2.new(0, 6, 0, 45)
    page.Size = UDim2.new(1, -12, 1, -90)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 2
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new()
    page.Visible = false
    page.Parent = main
    local layout = Instance.new("UIListLayout", page)
    layout.Padding = UDim.new(0, 5)
    pages[name] = page
    return page
end

local function card(parent, height)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, height)
    f.BackgroundColor3 = Color3.fromRGB(23,25,32)
    f.BorderSizePixel = 0
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    return f
end

local function text(parent, value, y, size, color, bold)
    local t = Instance.new("TextLabel")
    t.Position = UDim2.new(0, 8, 0, y or 6)
    t.Size = UDim2.new(1, -16, 0, 22)
    t.BackgroundTransparency = 1
    t.Text = value
    t.TextColor3 = color or Color3.fromRGB(220,221,228)
    t.TextSize = size or 11
    t.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextWrapped = true
    t.Parent = parent
    return t
end

-- PANEL HOME
local home = makePage("Home")
local homeStatus = card(home, 55)
text(homeStatus, "●  MONITOR ACTIVE", 4, 12, Color3.fromRGB(95,225,145), true)
local homeStats = text(homeStatus, "Players 0  •  Detected 0  •  Sent 0", 26, 11, Color3.fromRGB(185,188,200))

local homeLast = card(home, 85)
local homeLastText = text(homeLast, "LAST CATCH:\nNo global logs captured yet.", 4, 11, Color3.fromRGB(230,231,236))
homeLastText.Size = UDim2.new(1, -16, 1, -8)
--[[ [BAGIAN 8 DARI 10] ]]
local filtersPage = makePage("Filters")
local filterCard = card(filtersPage, 160)
text(filterCard, "RARITY FILTER", 4, 11, Color3.fromRGB(150,154,170), true)

local rarityOrder = {"SECRET","FORGOTTEN","Mythic","Legendary","Epic","Rare","Uncommon","Common"}
local filterButtons = {}
for i, name in ipairs(rarityOrder) do
    local b = Instance.new("TextButton")
    local row = math.floor((i-1)/2)
    local col = (i-1)%2
    b.Size = UDim2.new(0.5, -8, 0, 26)
    b.Position = UDim2.new(col*0.5, col==0 and 5 or 3, 0, 25 + row*30)
    b.BackgroundColor3 = CONFIG.ALLOW_RARITY[name] and Color3.fromRGB(42,75,57) or Color3.fromRGB(34,36,44)
    b.Text = name .. (CONFIG.ALLOW_RARITY[name] and "  ✓" or "  ×")
    b.TextColor3 = Color3.fromRGB(230,232,238)
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 10
    b.Parent = filterCard
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    
    b.Activated:Connect(function()
        CONFIG.ALLOW_RARITY[name] = not CONFIG.ALLOW_RARITY[name]
        b.BackgroundColor3 = CONFIG.ALLOW_RARITY[name] and Color3.fromRGB(42,75,57) or Color3.fromRGB(34,36,44)
        b.Text = name .. (CONFIG.ALLOW_RARITY[name] and "  ✓" or "  ×")
        saveConfig()
    end)
end
--[[ [BAGIAN 9 DARI 10] ]]
local webhookPage = makePage("Webhook")
local webhookCard = card(webhookPage, 140)
text(webhookCard, "DISCORD WEBHOOK URL", 4, 10, Color3.fromRGB(150,154,170), true)

local webhookInput = Instance.new("TextBox")
webhookInput.Position = UDim2.new(0, 8, 0, 24)
webhookInput.Size = UDim2.new(1, -16, 0, 32)
webhookInput.Text = CONFIG.WEBHOOK_URL
webhookInput.PlaceholderText = "Paste Discord Webhook Disini"
webhookInput.TextSize = 10
webhookInput.Font = Enum.Font.Gotham
webhookInput.TextColor3 = Color3.fromRGB(235,236,242)
webhookInput.BackgroundColor3 = Color3.fromRGB(32,34,42)
webhookInput.ClearTextOnFocus = false
webhookInput.Parent = webhookCard
Instance.new("UICorner", webhookInput).CornerRadius = UDim.new(0, 6)

local saveWebhook = Instance.new("TextButton")
saveWebhook.Position = UDim2.new(0, 8, 0, 64)
saveWebhook.Size = UDim2.new(0.45, 0, 0, 28)
saveWebhook.Text = "SIMPAN WEBHOOK"
saveWebhook.TextSize = 10
saveWebhook.Font = Enum.Font.GothamBold
saveWebhook.TextColor3 = Color3.fromRGB(235,237,242)
saveWebhook.BackgroundColor3 = Color3.fromRGB(45,48,60)
saveWebhook.Parent = webhookCard
Instance.new("UICorner", saveWebhook).CornerRadius = UDim.new(0, 6)

local testWebhook = saveWebhook:Clone()
testWebhook.Position = UDim2.new(0.55, 0, 0, 64)
testWebhook.Text = "TEST WEBHOOK"
testWebhook.Parent = webhookCard

local mentionInput = webhookInput:Clone()
mentionInput.Position = UDim2.new(0, 8, 0, 100)
mentionInput.Size = UDim2.new(1, -16, 0, 28)
mentionInput.Text = CONFIG.MENTION
mentionInput.PlaceholderText = "Mention Role ID (Optional: <@&RoleID>)"
mentionInput.Parent = webhookCard

saveWebhook.Activated:Connect(function()
    CONFIG.WEBHOOK_URL = trim(webhookInput.Text)
    saveConfig()
end)

mentionInput.FocusLost:Connect(function()
    CONFIG.MENTION = trim(mentionInput.Text)
    saveConfig()
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
                content = "Test koneksi webhook dari Delta Android berhasil! 🎣"
            })
        })
    end)
end)
--[[ [BAGIAN 10 DARI 10] ]]
local tabNames = { {"⌂", "Home"}, {"⚙", "Filters"}, {"🔔", "Webhook"} }
for i, item in ipairs(tabNames) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.33, -4, 1, -4)
    b.Position = UDim2.new((i-1)*0.33, 2, 0, 2)
    b.BackgroundTransparency = 1
    b.Text = item[1] .. " " .. item[2]
    b.TextSize = 11
    b.Font = Enum.Font.GothamSemibold
    b.TextColor3 = Color3.fromRGB(135,138,150)
    b.Parent = tabbar
    tabs[item[2]] = b
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    
    b.Activated:Connect(function()
        activeTab = item[2]
        for n, p in pairs(pages) do p.Visible = (n == activeTab) end
        for n, t in pairs(tabs) do t.TextColor3 = (n == activeTab) and Color3.fromRGB(235,237,242) or Color3.fromRGB(135,138,150) end
    end)
end
pages.Home.Visible = true
tabs.Home.TextColor3 = Color3.fromRGB(235,237,242)

local minimized = false
min.Activated:Connect(function()
    minimized = not minimized
    tabbar.Visible = not minimized
    for _, p in pairs(pages) do p.Visible = not minimized and (_ == activeTab) or false end
    main.Size = minimized and UDim2.fromOffset(180, 40) or UDim2.fromOffset(340, 320)
    min.Text = minimized and "+" or "−"
end)

local dragging, dragInput, dragStart, startPos
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true dragInput = input dragStart = input.Position startPos = main.Position
    end
end)
UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UIS.InputEnded:Connect(function(input) if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)

local function updateUI(data)
    state.Detected = state.Detected + 1
    local line = string.format("👤 Player: %s\n🐟 Fish: %s\n⚖ Berat: %.2f kg\n🎲 Chance: 1 in %s", data.Player, data.Fish, data.Weight, tostring(data.Chance))
    homeLastText.Text = "LAST CATCH:\n" .. line
    homeStats.Text = string.format("Players %d  •  Detected %d  •  Sent %d", #Players:GetPlayers(), state.Detected, state.Sent)
end

local function handleMessage(text)
    local data = parseCatch(text)
    if not data then return end
    updateUI(data)
    sendWebhook(data)
end

if TextChatService.MessageReceived then
    TextChatService.MessageReceived:Connect(function(msg)
        if msg and msg.Text then handleMessage(msg.Text) end
    end)
end

print("[LFAMILIA Android] Radar V5 Selesai Dimuat Total!")
