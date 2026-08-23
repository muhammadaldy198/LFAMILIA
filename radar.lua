--[[
    LFAMILIA RADAR V4
    Modern UI • Fish Filter • Webhook • Accounts
    Minimize / Restore
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")

local CONFIG_FILE = "LFAMILIA_Radar_Config.json"
local GUI_NAME = "LFAMILIA_Radar_V4"

local Config = {
    Webhook = "",
    LogWebhook = "",
    Database = {},
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
        local raw = readfile(CONFIG_FILE)
        local data = HttpService:JSONDecode(raw)

        if type(data) == "table" then
            for k, v in pairs(data) do
                if k ~= "Filters" then
                    Config[k] = v
                end
            end

            if type(data.Filters) == "table" then
                for k, v in pairs(data.Filters) do
                    Config.Filters[k] = v
                end
            end
        end
    end
end)

local function saveConfig()
    if not writefile then
        return
    end

    pcall(function()
        writefile(
            CONFIG_FILE,
            HttpService:JSONEncode(Config)
        )
    end)
end

local old = CoreGui:FindFirstChild(GUI_NAME)

if old then
    old:Destroy()
end

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

local function makeLabel(
    parent,
    text,
    size,
    pos,
    font,
    color
)
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

local function makeButton(
    parent,
    text,
    size,
    pos,
    bg
)
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

local function makeBox(
    parent,
    placeholder,
    text,
    pos
)
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

local ScreenGui = Instance.new("ScreenGui")

ScreenGui.Name = GUI_NAME
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

local Main = Instance.new("Frame")

Main.Size = UDim2.fromOffset(540, 410)
Main.Position = UDim2.new(0.5, -270, 0.5, -205)
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

makeLabel(
    Top,
    "◆ LFAMILIA RADAR",
    UDim2.fromOffset(230, 28),
    UDim2.fromOffset(18, 8),
    Enum.Font.GothamBold,
    Theme.Text
)

makeLabel(
    Top,
    "V4 • Fish Monitor",
    UDim2.fromOffset(200, 18),
    UDim2.fromOffset(20, 31),
    Enum.Font.Gotham,
    Theme.Muted
)

local Minimize = makeButton(
    Top,
    "—",
    UDim2.fromOffset(34, 30),
    UDim2.new(1, -78, 0, 12),
    Theme.Panel2
)

local Close = makeButton(
    Top,
    "×",
    UDim2.fromOffset(34, 30),
    UDim2.new(1, -40, 0, 12),
    Theme.Panel2
)

local Restore = makeButton(
    ScreenGui,
    "◆ LFAMILIA",
    UDim2.fromOffset(120, 38),
    UDim2.new(0, 20, 0, 180),
    Theme.Purple
)

Restore.Visible = false
corner(Restore, 12)

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
local activePage

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
    for n, p in pairs(pages) do
        p.Visible = (n == name)
    end

    for n, b in pairs(tabButtons) do
        b.BackgroundColor3 =
            (n == name)
            and Theme.Purple
            or Theme.Panel2
    end

    activePage = name
end

local function addTab(name, x)
    local b = makeButton(
        Tabs,
        name,
        UDim2.fromOffset(120, 36),
        UDim2.fromOffset(x, 2),
        Theme.Panel2
    )

    tabButtons[name] = b

    b.MouseButton1Click:Connect(function()
        showPage(name)
    end)
end

addTab("Radar", 0)
addTab("Fish Filter", 125)
addTab("Webhook", 250)
addTab("Accounts", 375)
local RadarPage = newPage("Radar")
local FilterPage = newPage("Fish Filter")
local WebhookPage = newPage("Webhook")
local AccountsPage = newPage("Accounts")

local RadarActive = false

local Status = makeLabel(
    RadarPage,
    "● OFFLINE",
    UDim2.fromOffset(180, 32),
    UDim2.fromOffset(18, 18),
    Enum.Font.GothamBold,
    Theme.Red
)

Status.TextSize = 18

makeLabel(
    RadarPage,
    "LFAMILIA V4 Radar",
    UDim2.fromOffset(300, 24),
    UDim2.fromOffset(18, 55),
    Enum.Font.GothamBold,
    Theme.Text
)

local Start = makeButton(
    RadarPage,
    "START RADAR",
    UDim2.new(1, -36, 0, 44),
    UDim2.fromOffset(18, 90),
    Theme.Purple
)

local Preview = makeButton(
    RadarPage,
    "TEST WEBHOOK",
    UDim2.new(1, -36, 0, 38),
    UDim2.fromOffset(18, 144),
    Theme.Panel2
)

local Info = makeLabel(
    RadarPage,
    "Monitoring: 0 players",
    UDim2.new(1, -36, 0, 24),
    UDim2.fromOffset(18, 198),
    Enum.Font.Gotham,
    Theme.Muted
)

local function countAccounts()
    local n = 0

    for _ in pairs(Config.Database) do
        n += 1
    end

    return n
end

makeLabel(
    FilterPage,
    "RARITY FILTER",
    UDim2.fromOffset(300, 22),
    UDim2.fromOffset(18, 12),
    Enum.Font.GothamBold,
    Theme.Cyan
)

local filterOrder = {
    "Secret",
    "Forgotten",
    "Mythic",
    "Legendary",
    "Mutation"
}

local filterY = 42

local function addToggle(name)
    local b = makeButton(
        FilterPage,
        "",
        UDim2.new(1, -36, 0, 34),
        UDim2.fromOffset(18, filterY),
        Theme.Panel2
    )

    local state = Config.Filters[name] == true

    local label = makeLabel(
        b,
        name,
        UDim2.new(1, -70, 1, 0),
        UDim2.fromOffset(12, 0),
        Enum.Font.GothamBold,
        Theme.Text
    )

    label.TextYAlignment = Enum.TextYAlignment.Center

    local dot = makeLabel(
        b,
        state and "ON" or "OFF",
        UDim2.fromOffset(42, 34),
        UDim2.new(1, -52, 0, 0),
        Enum.Font.GothamBold,
        state and Theme.Green or Theme.Muted
    )

    dot.TextXAlignment = Enum.TextXAlignment.Right
    dot.TextYAlignment = Enum.TextYAlignment.Center

    b.MouseButton1Click:Connect(function()
        state = not state

        Config.Filters[name] = state

        dot.Text = state and "ON" or "OFF"
        dot.TextColor3 =
            state
            and Theme.Green
            or Theme.Muted

        saveConfig()
    end)

    filterY += 39
end

for _, name in ipairs(filterOrder) do
    addToggle(name)
end

local WebhookBox = makeBox(
    WebhookPage,
    "Discord webhook utama",
    Config.Webhook,
    UDim2.fromOffset(10, 14)
)

local LogWebhookBox = makeBox(
    WebhookPage,
    "Webhook log join/leave (opsional)",
    Config.LogWebhook,
    UDim2.fromOffset(10, 60)
)

local SaveWebhook = makeButton(
    WebhookPage,
    "SAVE WEBHOOK",
    UDim2.new(1, -20, 0, 38),
    UDim2.fromOffset(10, 108),
    Theme.Purple
)

local WebhookStatus = makeLabel(
    WebhookPage,
    "",
    UDim2.new(1, -20, 0, 25),
    UDim2.fromOffset(10, 154),
    Enum.Font.Gotham,
    Theme.Muted
)

SaveWebhook.MouseButton1Click:Connect(function()
    Config.Webhook = WebhookBox.Text
    Config.LogWebhook = LogWebhookBox.Text

    saveConfig()

    WebhookStatus.Text = "✓ Webhook tersimpan"
    WebhookStatus.TextColor3 = Theme.Green
end)

local RobloxBox = makeBox(
    AccountsPage,
    "Username Roblox",
    "",
    UDim2.fromOffset(10, 14)
)

local DiscordBox = makeBox(
    AccountsPage,
    "Discord User ID",
    "",
    UDim2.fromOffset(10, 60)
)

local AddAccount = makeButton(
    AccountsPage,
    "ADD ACCOUNT",
    UDim2.new(1, -20, 0, 38),
    UDim2.fromOffset(10, 108),
    Theme.Purple
)

local AccountStatus = makeLabel(
    AccountsPage,
    "Accounts: " .. countAccounts(),
    UDim2.new(1, -20, 0, 24),
    UDim2.fromOffset(10, 154),
    Enum.Font.Gotham,
    Theme.Muted
)

AddAccount.MouseButton1Click:Connect(function()
    local rbx =
        RobloxBox.Text
        :gsub("^%s+", "")
        :gsub("%s+$", "")

    local dc =
        DiscordBox.Text
        :gsub("%D", "")

    if rbx ~= "" and dc ~= "" then
        Config.Database[rbx] = dc

        RobloxBox.Text = ""
        DiscordBox.Text = ""

        saveConfig()

        AccountStatus.Text =
            "✓ Saved • Accounts: "
            .. countAccounts()

        AccountStatus.TextColor3 = Theme.Green
    else
        AccountStatus.Text =
            "Isi username Roblox dan Discord ID."

        AccountStatus.TextColor3 = Theme.Red
    end
end)

-- HTTP REQUEST
local httpRequest =
    (syn and syn.request)
    or http_request
    or request

local function sendRequest(url, data)
    if not url or url == "" then
        return false
    end

    if not httpRequest then
        return false
    end

    local ok = pcall(function()
        httpRequest({
            Url = url,
            Method = "POST",

            Headers = {
                ["Content-Type"] = "application/json"
            },

            Body = HttpService:JSONEncode(data)
        })
    end)

    return ok
end

local function mentionFor(name)
    local id = Config.Database[name]

    if id and id ~= "" then
        return "<@" .. id .. ">"
    end

    return "@" .. name
end

local function passesFilter(rarity, mutation)
    local r =
        string.lower(
            tostring(rarity or "")
        )

    local allowedRarity = false

    if r == "secret"
        and Config.Filters.Secret then

        allowedRarity = true
    end

    if r == "forgotten"
        and Config.Filters.Forgotten then

        allowedRarity = true
    end

    if r == "mythic"
        and Config.Filters.Mythic then

        allowedRarity = true
    end

    if r == "legendary"
        and Config.Filters.Legendary then

        allowedRarity = true
    end

    local hasMutation =
        mutation
        and tostring(mutation) ~= ""
        and string.lower(
            tostring(mutation)
        ) ~= "none"

    if hasMutation
        and Config.Filters.Mutation then

        allowedRarity = true
    end

    return allowedRarity
end

-- Ambil asset/texture ID dari ikan.
local function getFishAssetId(item)
    if not item then
        return nil
    end

    local assetId =
        item:GetAttribute("AssetId")
        or item:GetAttribute("ImageId")
        or item:GetAttribute("TextureId")

    if not assetId and item:IsA("Tool") then
        local ok, value = pcall(function()
            return item.TextureId
        end)

        if ok then
            assetId = value
        end
    end

    if not assetId then
        local handle =
            item:FindFirstChild("Handle")

        if handle then
            local texture =
                handle:FindFirstChildWhichIsA(
                    "Texture"
                )

            if texture then
                assetId = texture.Texture
            end
        end
    end

    if not assetId then
        return nil
    end

    return tostring(assetId):match("%d+")
end

local function getFishImage(item)
    local assetId =
        getFishAssetId(item)

    if not assetId then
        return nil
    end

    return
        "https://www.roblox.com/asset-thumbnail/image"
        .. "?assetId=" .. assetId
        .. "&width=420"
        .. "&height=420"
        .. "&format=png"
end

local function sendFish(
    playerName,
    fishName,
    rarity,
    mutation,
    item
)
    if not passesFilter(
        rarity,
        mutation
    ) then
        return
    end

    local mutationText =
        (
            mutation
            and tostring(mutation) ~= ""
        )
        and tostring(mutation)
        or "None"

    local weight = "Unknown"

    if item then
        weight =
            item:GetAttribute("Weight")
            or item:GetAttribute("FishWeight")
            or "Unknown"
    end

    local imageUrl =
        getFishImage(item)

    local description =
        "━━━━━━━━━━━━━━━━━━━━\n\n"
        .. "Hey " .. mentionFor(playerName) .. "\n\n"
        .. "Player : **" .. playerName .. "**\n"
        .. "Fish : **" .. fishName .. "**\n"
        .. "Rarity : **" .. tostring(rarity) .. "**\n"
        .. "Mutation : **" .. mutationText .. "**\n"
        .. "Weight : **" .. tostring(weight) .. " kg**\n\n"
        .. "━━━━━━━━━━━━━━━━━━━━"

    local embed = {
        title =
            "# " .. playerName
            .. "\nNOTIFICATION",

        color = 9542550,

        description = description,

        footer = {
            text = "©2026 LFAMILIA • V1"
        },

        timestamp =
            os.date(
                "!%Y-%m-%dT%H:%M:%SZ"
            )
    }

    if imageUrl then
        embed.image = {
            url = imageUrl
        }
    end

    sendRequest(
        Config.Webhook,
        {
            username = "LFAMILIA",
            embeds = {embed}
        }
    )
end
local monitored = {}

local function monitorPlayer(player)
    if monitored[player] then
        return
    end

    monitored[player] = true

    local function check(item)
        if not RadarActive then
            return
        end

        if not item:IsA("Tool") then
            return
        end

        local rarity =
            item:GetAttribute("Rarity")

        if not rarity then
            return
        end

        sendFish(
            player.Name,
            item.Name,
            rarity,
            item:GetAttribute("Mutation"),
            item
        )
    end

    task.spawn(function()
        local backpack =
            player:WaitForChild(
                "Backpack",
                12
            )

        if backpack then
            backpack.ChildAdded:Connect(
                check
            )
        end
    end)

    player.CharacterAdded:Connect(
        function(char)
            char.ChildAdded:Connect(check)
        end
    )

    if player.Character then
        player.Character.ChildAdded:Connect(
            check
        )
    end
end

Start.MouseButton1Click:Connect(
    function()
        RadarActive = not RadarActive

        if RadarActive then
            Start.Text = "STOP RADAR"
            Start.BackgroundColor3 =
                Theme.Green

            Status.Text = "● ONLINE"
            Status.TextColor3 =
                Theme.Green

            for _, player in
                ipairs(Players:GetPlayers()) do

                if player ~= LocalPlayer then
                    monitorPlayer(player)
                end
            end

            Info.Text =
                "Monitoring: "
                .. tostring(
                    #Players:GetPlayers() - 1
                )
                .. " players"

        else
            Start.Text = "START RADAR"
            Start.BackgroundColor3 =
                Theme.Purple

            Status.Text = "● OFFLINE"
            Status.TextColor3 =
                Theme.Red

            Info.Text =
                "Monitoring: 0 players"
        end
    end
)

Preview.MouseButton1Click:Connect(
    function()
        if Config.Webhook == "" then
            WebhookStatus.Text =
                "Isi webhook terlebih dahulu."

            WebhookStatus.TextColor3 =
                Theme.Red

            showPage("Webhook")

            return
        end

        local description =
            "━━━━━━━━━━━━━━━━━━━━\n\n"
            .. "Hey " .. mentionFor(LocalPlayer.Name) .. "\n\n"
            .. "Player : **" .. LocalPlayer.Name .. "**\n"
            .. "Fish : **Demo Fish**\n"
            .. "Rarity : **Secret**\n"
            .. "Mutation : **Albino**\n"
            .. "Weight : **250K kg**\n\n"
            .. "━━━━━━━━━━━━━━━━━━━━"

        sendRequest(
            Config.Webhook,
            {
                username = "LFAMILIA",

                embeds = {{
                    title =
                        "# "
                        .. LocalPlayer.Name
                        .. "\nNOTIFICATION",

                    color = 9542550,

                    description = description,

                    footer = {
                        text =
                            "©2026 LFAMILIA • V1"
                    },

                    timestamp =
                        os.date(
                            "!%Y-%m-%dT%H:%M:%SZ"
                        )
                }}
            }
        )

        Status.Text = "● TEST SENT"
        Status.TextColor3 =
            Theme.Cyan
    end
)

Players.PlayerAdded:Connect(
    function(player)
        if RadarActive then
            monitorPlayer(player)

            Info.Text =
                "Monitoring: "
                .. tostring(
                    #Players:GetPlayers() - 1
                )
                .. " players"
        end
    end
)

Players.PlayerRemoving:Connect(
    function(player)
        monitored[player] = nil

        if RadarActive
            and Config.LogWebhook ~= "" then

            sendRequest(
                Config.LogWebhook,
                {
                    username = "LFAMILIA",

                    content =
                        "🔴 `"
                        .. player.Name
                        .. "` left the server."
                }
            )
        end
    end
)

Minimize.MouseButton1Click:Connect(
    function()
        Main.Visible = false
        Restore.Visible = true
    end
)

Restore.MouseButton1Click:Connect(
    function()
        Main.Visible = true
        Restore.Visible = false
    end
)

Close.MouseButton1Click:Connect(
    function()
        ScreenGui:Destroy()
    end
)

showPage("Radar")
