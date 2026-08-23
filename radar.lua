-- =================================================================
-- BAGIAN 1: INITIALIZATION, CONFIGURATION, THEME & UI HELPERS
-- =================================================================

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")

local CONFIG_FILE = "LFAMILIA_Radar_Config.json"
local GUI_NAME = "LFAMILIA_Radar_V4"

local Config = {
    Webhook = "",
    LogWebhook = "",
    Accounts = {},
    Filters = {
        Secret = true,
        Forgotten = true,
        Mythic = false,
        Legendary = false,
        Mutation = true
    }
}

pcall(function()
    if isfile and isfile(CONFIG_FILE) then
        local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
        if type(data) == "table" then
            Config.Webhook = data.Webhook or ""
            Config.LogWebhook = data.LogWebhook or ""
            Config.Accounts = type(data.Accounts) == "table" and data.Accounts or {}

            if type(data.Filters) == "table" then
                for k, v in pairs(data.Filters) do
                    Config.Filters[k] = v
                end
            end

            if type(data.Database) == "table" then
                for k, v in pairs(data.Database) do
                    if Config.Accounts[k] == nil then
                        Config.Accounts[k] = v
                    end
                end
            end
        end
    end
end)

local function saveConfig()
    if not writefile then return end
    pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode(Config))
    end)
end

local old = CoreGui:FindFirstChild(GUI_NAME)
if old then old:Destroy() end

local Theme = {
    Background = Color3.fromRGB(13, 16, 25),
    Panel = Color3.fromRGB(20, 24, 36),
    Panel2 = Color3.fromRGB(26, 31, 46),
    Stroke = Color3.fromRGB(49, 58, 82),
    Text = Color3.fromRGB(240, 243, 250),
    Muted = Color3.fromRGB(145, 154, 176),
    Purple = Color3.fromRGB(145, 92, 255),
    Cyan = Color3.fromRGB(45, 205, 255),
    Green = Color3.fromRGB(45, 210, 125),
    Red = Color3.fromRGB(245, 80, 105),
    Yellow = Color3.fromRGB(245, 190, 70)
}

local function corner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = obj
end

local function stroke(obj, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.Stroke
    s.Thickness = thickness or 1
    s.Parent = obj
end

local function makeLabel(parent, text, size, pos, font, color)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Size = size
    l.Position = pos
    l.Text = text
    l.TextColor3 = color or Theme.Text
    l.Font = font or Enum.Font.Gotham
    l.TextSize = 12
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

local function makeButton(parent, text, size, pos, bg)
    local b = Instance.new("TextButton")
    b.Size = size
    b.Position = pos
    b.Text = text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.TextColor3 = Theme.Text
    b.BackgroundColor3 = bg or Theme.Panel2
    b.AutoButtonColor = true
    b.Parent = parent
    corner(b, 8)
    stroke(b)
    return b
end

local function makeBox(parent, placeholder, text, pos)
    local b = Instance.new("TextBox")
    b.Size = UDim2.new(1, -20, 0, 36)
    b.Position = pos
    b.PlaceholderText = placeholder
    b.Text = text or ""
    b.TextColor3 = Theme.Text
    b.PlaceholderColor3 = Theme.Muted
    b.BackgroundColor3 = Theme.Panel2
    b.Font = Enum.Font.Gotham
    b.TextSize = 11
    b.ClearTextOnFocus = false
    b.Parent = parent
    corner(b, 8)
    stroke(b)
    return b
end
-- =================================================================
-- BAGIAN 2: UI LAYOUT, WINDOWS, TABS & PAGES SYSTEM
-- =================================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = GUI_NAME
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Size = UDim2.fromOffset(560, 450)
Main.Position = UDim2.new(0.5, -280, 0.5, -225)
Main.BackgroundColor3 = Theme.Background
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui

corner(Main, 14)
stroke(Main, Theme.Purple, 1.4)

local Top = Instance.new("Frame")
Top.Size = UDim2.new(1, 0, 0, 54)
Top.BackgroundColor3 = Theme.Panel
Top.BorderSizePixel = 0
Top.Parent = Main
corner(Top, 14)

makeLabel(Top, "◆ LFAMILIA RADAR", UDim2.fromOffset(230, 28), UDim2.fromOffset(18, 8), Enum.Font.GothamBold, Theme.Text)
makeLabel(Top, "V4 • Fish Monitor", UDim2.fromOffset(200, 18), UDim2.fromOffset(20, 31), Enum.Font.Gotham, Theme.Muted)

local Minimize = makeButton(Top, "—", UDim2.fromOffset(34, 30), UDim2.new(1, -78, 0, 12), Theme.Panel2)
local Close = makeButton(Top, "×", UDim2.fromOffset(34, 30), UDim2.new(1, -40, 0, 12), Theme.Panel2)
local Restore = makeButton(ScreenGui, "◆ LFAMILIA", UDim2.fromOffset(120, 38), UDim2.new(0, 20, 0, 180), Theme.Purple)
Restore.Visible = false

local Tabs = Instance.new("Frame")
Tabs.Size = UDim2.new(1, -20, 0, 40)
Tabs.Position = UDim2.fromOffset(10, 64)
Tabs.BackgroundTransparency = 1
Tabs.Parent = Main

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -20, 1, -114)
Content.Position = UDim2.fromOffset(10, 108)
Content.BackgroundColor3 = Theme.Panel
Content.BorderSizePixel = 0
Content.Parent = Main
corner(Content, 10)
stroke(Content)

local pages = {}
local tabButtons = {}

local function newPage(name)
    local page = Instance.new("Frame")
    page.Name = name
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.Parent = Content
    pages[name] = page
    return page
end

local function showPage(name)
    for n, p in pairs(pages) do p.Visible = n == name end
    for n, b in pairs(tabButtons) do b.BackgroundColor3 = n == name and Theme.Purple or Theme.Panel2 end
end

local function addTab(name, x)
    local b = makeButton(Tabs, name, UDim2.fromOffset(130, 36), UDim2.fromOffset(x, 2), Theme.Panel2)
    tabButtons[name] = b
    b.MouseButton1Click:Connect(function() showPage(name) end)
end

addTab("Radar", 0)
addTab("Fish Filter", 135)
addTab("Webhook", 270)
addTab("Accounts", 405)

local RadarPage = newPage("Radar")
local FilterPage = newPage("Fish Filter")
local WebhookPage = newPage("Webhook")
local AccountsPage = newPage("Accounts")

-- RADAR PAGE ELEMENTS
local RadarActive = false
local Status = makeLabel(RadarPage, "● OFFLINE", UDim2.fromOffset(180, 32), UDim2.fromOffset(18, 14), Enum.Font.GothamBold, Theme.Red)
Status.TextSize = 18

local Start = makeButton(RadarPage, "START RADAR", UDim2.new(1, -36, 0, 42), UDim2.fromOffset(18, 54), Theme.Purple)
local Preview = makeButton(RadarPage, "TEST WEBHOOK", UDim2.new(1, -36, 0, 38), UDim2.fromOffset(18, 104), Theme.Panel2)
local Info = makeLabel(RadarPage, "Monitoring: 0 players", UDim2.new(1, -36, 0, 22), UDim2.fromOffset(18, 150), Enum.Font.Gotham, Theme.Muted)

makeLabel(RadarPage, "PLAYER DISCONNECT", UDim2.fromOffset(260, 22), UDim2.fromOffset(18, 184), Enum.Font.GothamBold, Theme.Cyan)

local DisconnectScroll = Instance.new("ScrollingFrame")
DisconnectScroll.Size = UDim2.new(1, -36, 0, 145)
DisconnectScroll.Position = UDim2.fromOffset(18, 212)
DisconnectScroll.BackgroundColor3 = Theme.Panel2
DisconnectScroll.BorderSizePixel = 0
DisconnectScroll.ScrollBarThickness = 4
DisconnectScroll.CanvasSize = UDim2.new()
DisconnectScroll.Parent = RadarPage
corner(DisconnectScroll, 8)
stroke(DisconnectScroll)

local DisconnectLayout = Instance.new("UIListLayout")
DisconnectLayout.Padding = UDim.new(0, 4)
DisconnectLayout.Parent = DisconnectScroll

local function addDisconnect(playerName)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -8, 0, 32)
    row.BackgroundTransparency = 1
    row.Parent = DisconnectScroll

    local label = makeLabel(row, "● " .. playerName, UDim2.new(0.68, 0, 1, 0), UDim2.fromOffset(8, 0), Enum.Font.GothamBold, Theme.Red)
    label.TextYAlignment = Enum.TextYAlignment.Center

    local t = makeLabel(row, os.date("%H:%M:%S"), UDim2.new(0.28, 0, 1, 0), UDim2.new(0.70, 0, 0, 0), Enum.Font.Gotham, Theme.Muted)
    t.TextXAlignment = Enum.TextXAlignment.Right
    t.TextYAlignment = Enum.TextYAlignment.Center

    task.defer(function()
        DisconnectScroll.CanvasSize = UDim2.new(0, 0, 0, DisconnectLayout.AbsoluteContentSize.Y + 6)
    end)
end

-- FISH FILTER ELEMENTS
makeLabel(FilterPage, "FISH FILTER", UDim2.fromOffset(300, 22), UDim2.fromOffset(18, 12), Enum.Font.GothamBold, Theme.Cyan)
local filterOrder = {"Secret", "Forgotten", "Mythic", "Legendary", "Mutation"}
local filterY = 42

local function addToggle(name)
    local b = makeButton(FilterPage, "", UDim2.new(1, -36, 0, 34), UDim2.fromOffset(18, filterY), Theme.Panel2)
    local state = Config.Filters[name] == true
    local label = makeLabel(b, name, UDim2.new(1, -70, 1, 0), UDim2.fromOffset(12, 0), Enum.Font.GothamBold, Theme.Text)
    label.TextYAlignment = Enum.TextYAlignment.Center

    local dot = makeLabel(b, state and "ON" or "OFF", UDim2.fromOffset(42, 34), UDim2.new(1, -52, 0, 0), Enum.Font.GothamBold, state and Theme.Green or Theme.Muted)
    dot.TextXAlignment = Enum.TextXAlignment.Right
    dot.TextYAlignment = Enum.TextYAlignment.Center

    b.MouseButton1Click:Connect(function()
        state = not state
        Config.Filters[name] = state
        dot.Text = state and "ON" or "OFF"
        dot.TextColor3 = state and Theme.Green or Theme.Muted
        saveConfig()
    end)
    filterY += 39
end

for _, name in ipairs(filterOrder) do addToggle(name) end
makeLabel(FilterPage, "Weight tetap ditampilkan pada notifikasi; bukan filter.", UDim2.new(1, -36, 0, 25), UDim2.fromOffset(18, 244), Enum.Font.Gotham, Theme.Muted)

-- WEBHOOK PAGE ELEMENTS
local WebhookBox = makeBox(WebhookPage, "Discord webhook utama", Config.Webhook, UDim2.fromOffset(10, 14))
local LogWebhookBox = makeBox(WebhookPage, "Webhook disconnect (opsional)", Config.LogWebhook, UDim2.fromOffset(10, 60))
local SaveWebhook = makeButton(WebhookPage, "SAVE WEBHOOK", UDim2.new(1, -20, 0, 38), UDim2.fromOffset(10, 108), Theme.Purple)
local WebhookStatus = makeLabel(WebhookPage, "", UDim2.new(1, -20, 0, 25), UDim2.fromOffset(10, 154), Enum.Font.Gotham, Theme.Muted)

SaveWebhook.MouseButton1Click:Connect(function()
    Config.Webhook = WebhookBox.Text
    Config.LogWebhook = LogWebhookBox.Text
    saveConfig()
    WebhookStatus.Text = "✓ Webhook tersimpan"
    WebhookStatus.TextColor3 = Theme.Green
end)

-- ACCOUNTS PAGE ELEMENTS
makeLabel(AccountsPage, "DISCORD ACCOUNT", UDim2.fromOffset(260, 22), UDim2.fromOffset(10, 10), Enum.Font.GothamBold, Theme.Cyan)
local DiscordBox = makeBox(AccountsPage, "Discord User ID / ID angka", "", UDim2.fromOffset(10, 38))
local LoadPlayers = makeButton(AccountsPage, "LOAD PLAYERS IN SERVER", UDim2.new(1, -20, 0, 36), UDim2.fromOffset(10, 82), Theme.Purple)

local PlayerScroll = Instance.new("ScrollingFrame")
PlayerScroll.Size = UDim2.new(1, -20, 0, 180)
PlayerScroll.Position = UDim2.fromOffset(10, 126)
PlayerScroll.BackgroundColor3 = Theme.Panel2
PlayerScroll.BorderSizePixel = 0
PlayerScroll.ScrollBarThickness = 4
PlayerScroll.CanvasSize = UDim2.new()
PlayerScroll.Parent = AccountsPage
corner(PlayerScroll, 8)
stroke(PlayerScroll)

local PlayerLayout = Instance.new("UIListLayout")
PlayerLayout.Padding = UDim.new(0, 4)
PlayerLayout.Parent = PlayerScroll

local selectedPlayer = nil
local accountStatus = makeLabel(AccountsPage, "Pilih player yang ingin dikaitkan.", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 314), Enum.Font.Gotham, Theme.Muted)

local function refreshPlayerList()
    for _, child in ipairs(PlayerScroll:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    selectedPlayer = nil

    for _, player in ipairs(Players:GetPlayers()) do
        local b = makeButton(PlayerScroll, player.Name .. "  •  " .. player.DisplayName, UDim2.new(1, -8, 0, 34), UDim2.new(), Theme.Background)
        b.Parent = PlayerScroll
        b.MouseButton1Click:Connect(function()
            selectedPlayer = player.Name
            for _, other in ipairs(PlayerScroll:GetChildren()) do
                if other:IsA("TextButton") then other.BackgroundColor3 = Theme.Background end
            end
            b.BackgroundColor3 = Theme.Purple
            accountStatus.Text = "Selected: " .. player.Name
            accountStatus.TextColor3 = Theme.Green
        end)
    end

    task.defer(function()
        PlayerScroll.CanvasSize = UDim2.new(0, 0, 0, PlayerLayout.AbsoluteContentSize.Y + 6)
    end)
end

LoadPlayers.MouseButton1Click:Connect(function()
    if DiscordBox.Text:gsub("%s+", "") == "" then
        accountStatus.Text = "Masukkan Discord User ID terlebih dahulu."
        accountStatus.TextColor3 = Theme.Red
        return
    end
    refreshPlayerList()
    accountStatus.Text = "Pilih player dari server."
    accountStatus.TextColor3 = Theme.Muted
end)

local SaveAccount = makeButton(AccountsPage, "SAVE SELECTED PLAYER", UDim2.new(1, -20, 0, 34), UDim2.fromOffset(10, 342), Theme.Purple)
SaveAccount.MouseButton1Click:Connect(function()
    local discordId = DiscordBox.Text:gsub("%D", "")
    if discordId == "" or not selectedPlayer then
        accountStatus.Text = "Masukkan Discord ID dan pilih player."
        accountStatus.TextColor3 = Theme.Red
        return
    end
    Config.Accounts[selectedPlayer] = discordId
    saveConfig()
    accountStatus.Text = "✓ " .. selectedPlayer .. " tersimpan."
    accountStatus.TextColor3 = Theme.Green
end)
-- =================================================================
-- BAGIAN 3: EMBED CONVERSION & RADAR ENGINE LOGIC
-- =================================================================

local httpRequest = (syn and syn.request) or http_request or request

local function sendRequest(url, data)
    if not url or url == "" or not httpRequest then return false end
    local ok = pcall(function()
        httpRequest({
            Url = url,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end)
    return ok
end

local function mentionFor(playerName)
    local id = Config.Accounts[playerName]
    if id and id ~= "" then return "<@" .. id .. ">" end
    return "@" .. playerName
end

local function readAttributeRecursive(root, aliases)
    if not root then return nil end
    for _, alias in ipairs(aliases) do
        local ok, value = pcall(function() return root:GetAttribute(alias) end)
        if ok and value ~= nil and tostring(value) ~= "" then return value end
    end
    for _, obj in ipairs(root:GetDescendants()) do
        for _, alias in ipairs(aliases) do
            local ok, value = pcall(function() return obj:GetAttribute(alias) end)
            if ok and value ~= nil and tostring(value) ~= "" then return value end
        end
    end
    return nil
end

local function readFishData(item)
    local name = item.Name
    local rarity = readAttributeRecursive(item, {"Rarity", "RarityName", "FishRarity", "Tier", "RarityType"})
    local mutation = readAttributeRecursive(item, {"Mutation", "MutationName", "FishMutation", "Mutations"})
    local weight = readAttributeRecursive(item, {"Weight", "FishWeight", "Fish_Weight", "KG", "Kg", "WeightKg"})
    local assetId = readAttributeRecursive(item, {"AssetId", "ImageId", "TextureId", "FishAssetId", "IconId"})

    return {
        Name = tostring(name),
        Rarity = rarity and tostring(rarity) or "Unknown",
        Mutation = mutation and tostring(mutation) or "None",
        Weight = weight,
        AssetId = assetId
    }
end

local function getRobloxAssetImage(assetId)
    if not assetId or not httpRequest then return nil end
    local id = tostring(assetId):match("%d+")
    if not id then return nil end

    local url = "https://roproxy.com" .. id .. "&returnPolicy=PlaceHolder&size=420x420&format=Png&isCircular=false"
    
    local success, result = pcall(function()
        return httpRequest({Url = url, Method = "GET"})
    end)

    if not success or not result or not result.Body then return nil end

    local decodeSuccess, data = pcall(function()
        return HttpService:JSONDecode(result.Body)
    end)

    if not decodeSuccess or not data or not data.data or not data.data then return nil end
    return data.data.imageUrl
end

local function getFishImage(item, knownAssetId)
    local assetId = knownAssetId
    if not assetId and item then
        assetId = readAttributeRecursive(item, {"AssetId", "ImageId", "TextureId", "FishAssetId", "IconId"})
    end
    if not assetId and item then
        pcall(function()
            if item:IsA("Tool") and item.TextureId ~= "" then assetId = item.TextureId end
        end)
    end
    if not assetId and item then
        for _, obj in ipairs(item:GetDescendants()) do
            if obj:IsA("Texture") or obj:IsA("Decal") then
                if obj.Texture ~= "" then assetId = obj.Texture break end
            elseif obj:IsA("SpecialMesh") then
                if obj.TextureId ~= "" then assetId = obj.TextureId break end
            elseif obj:IsA("MeshPart") then
                if obj.TextureID ~= "" then assetId = obj.TextureID break end
            end
        end
    end
    return getRobloxAssetImage(assetId)
end

local function passesFilter(rarity, mutation)
    local r = string.lower(tostring(rarity or ""))
    local allowed = false

    if r == "secret" and Config.Filters.Secret then allowed = true end
    if r == "forgotten" and Config.Filters.Forgotten then allowed = true end
    if r == "mythic" and Config.Filters.Mythic then allowed = true end
    if r == "legendary" and Config.Filters.Legendary then allowed = true end

    local hasMutation = mutation and tostring(mutation) ~= "" and string.lower(tostring(mutation)) ~= "none"
    if hasMutation and Config.Filters.Mutation then allowed = true end

    return allowed
end

local function formatWeight(weight)
    if weight == nil or tostring(weight) == "" then return "Unknown" end
    local n = tonumber(weight)
    if not n then return tostring(weight) end
    if n >= 1000000 then return string.format("%.2fM kg", n / 1000000)
    elseif n >= 1000 then return string.format("%.2fK kg", n / 1000) end
    return string.format("%.2f kg", n)
end

local function buildEmbedPayload(playerName, fishData, imageUrl)
    local playerMention = mentionFor(playerName)
    
    local targetPlayer = Players:FindFirstChild(playerName)
    local displayName = targetPlayer and targetPlayer.DisplayName or playerName
    local formattedPlayerName = playerName .. " (" .. displayName .. ")"

    local descriptionText = "Player      : **" .. formattedPlayerName .. "**\n"
        .. "Caught    : **" .. fishData.Name .. "**\n"
        .. "Rarity       : **" .. fishData.Rarity .. "**\n"
        .. "Mutation : **" .. fishData.Mutation .. "**\n"
        .. "Weight     : **" .. formatWeight(fishData.Weight) .. "**"

    local embed = {
        title = "### PLAYER NOTIFICATION",
        description = descriptionText,
        color = 9542550,
        footer = {
            text = "©2026 LFAMILIA • V2"
        }
    }

    if imageUrl and imageUrl ~= "" then
        embed.thumbnail = { url = imageUrl }
    end

    return {
        content = "Hey " .. playerMention .. "!!",
        embeds = { embed },
        allowed_mentions = { parse = {"users"} }
    }
end

local function sendFish(playerName, item)
    local data = readFishData(item)
    if not passesFilter(data.Rarity, data.Mutation) then return end
    local imageUrl = getFishImage(item, data.AssetId)

    local payload = buildEmbedPayload(playerName, data, imageUrl)
    sendRequest(Config.Webhook, payload)
end

local monitored = {}

local function monitorPlayer(player)
    if monitored[player] then return end
    monitored[player] = true

    local function check(item)
        if not RadarActive or not item:IsA("Tool") then return end
        local rarity = readAttributeRecursive(item, {"Rarity", "RarityName", "FishRarity", "Tier", "RarityType"})
        if rarity then sendFish(player.Name, item) end
    end

    task.spawn(function()
        local backpack = player:WaitForChild("Backpack", 12)
        if backpack then backpack.ChildAdded:Connect(check) end
    end)

    player.CharacterAdded:Connect(function(char) char.ChildAdded:Connect(check) end)
    if player.Character then player.Character.ChildAdded:Connect(check) end
end

Start.MouseButton1Click:Connect(function()
    RadarActive = not RadarActive
    if RadarActive then
        Start.Text = "STOP RADAR"
        Start.BackgroundColor3 = Theme.Green
        Status.Text = "● ONLINE"
        Status.TextColor3 = Theme.Green

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then monitorPlayer(player) end
        end
        Info.Text = "Monitoring: " .. tostring(math.max(#Players:GetPlayers() - 1, 0)) .. " players"
    else
        Start.Text = "START RADAR"
        Start.BackgroundColor3 = Theme.Purple
        Status.Text = "● OFFLINE"
        Status.TextColor3 = Theme.Red
        Info.Text = "Monitoring: 0 players"
    end
end)

Preview.MouseButton1Click:Connect(function()
    if Config.Webhook == "" then
        WebhookStatus.Text = "Isi webhook terlebih dahulu."
        WebhookStatus.TextColor3 = Theme.Red
        showPage("Webhook")
        return
    end

    local testData = {
        Name = "Astralune",
        Rarity = "Forgotten",
        Mutation = "Binary",
        Weight = 1100000
    }

    local payload = buildEmbedPayload(LocalPlayer.Name, testData, "https://rbxcdn.com")
    local success = sendRequest(Config.Webhook, payload)
    
    if success then
        Status.Text = "● TEST SENT"
        Status.TextColor3 = Theme.Cyan
        WebhookStatus.Text = "✓ Format Embed sukses dikirim!"
        WebhookStatus.TextColor3 = Theme.Green
    else
        Status.Text = "● FAILED"
        Status.TextColor3 = Theme.Red
        WebhookStatus.Text = "⚠ Server Discord menolak request."
        WebhookStatus.TextColor3 = Theme.Red
    end
end)

Players.PlayerAdded:Connect(function(player)
    if RadarActive then
        monitorPlayer(player)
        Info.Text = "Monitoring: " .. tostring(math.max(#Players:GetPlayers() - 1, 0)) .. " players"
    end
end)

Players.PlayerRemoving:Connect(function(player)
    monitored[player] = nil
    addDisconnect(player.Name)
    if RadarActive and Config.LogWebhook ~= "" then
        sendRequest(Config.LogWebhook, {
            username = "LFAMILIA",
            content = "🔴 `" .. player.Name .. "` left the server at `" .. os.date("%H:%M:%S") .. "`."
        })
    end
end)

Minimize.MouseButton1Click:Connect(function() Main.Visible = false Restore.Visible = true end)
Restore.MouseButton1Click:Connect(function() Main.Visible = true Restore.Visible = false end)
Close.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

showPage("Radar")
