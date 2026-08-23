-- ====================================================================
-- PHASE 3 - PART 1: AUTO-LOAD CONFIG & MODERN V2 MAIN PANEL
-- ====================================================================
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")

local ActiveWebhookUrl = ""
local LogWebhookUrl = ""
local RadarActive = false
local CreatorGroupId = 34567890
local CustomBotName = "LFamiliaHelper"
local DynamicDatabase = {}

-- [PHASE 3] SISTEM AUTO-LOAD CONFIG DARI STORAGE HP
pcall(function()
    if isfile and isfile("LFAMILIA_Radar_Config.json") then
        local rawData = readfile("LFAMILIA_Radar_Config.json")
        local decoded = HttpService:JSONEncode(rawData)
        ActiveWebhookUrl = decoded.Webhook or ""
        LogWebhookUrl = decoded.LogWebhook or ""
        DynamicDatabase = decoded.Database or {}
    end
end)

if CoreGui:FindFirstChild("LynxStyleRadarGUI") then
    CoreGui.LynxStyleRadarGUI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LynxStyleRadarGUI"
ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 360, 0, 390)
MainFrame.Position = UDim2.new(0.5, -180, 0.3, -195)
MainFrame.BackgroundColor3 = Color3.fromRGB(27, 27, 27)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner", MainFrame)
MainCorner.CornerRadius = UDim.new(0, 10)

local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Color = Color3.fromRGB(47, 47, 47)
MainStroke.Thickness = 1.2
MainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, 0, 0, 45)
TitleLabel.Text = "🔮 LYNX RADAR • PHASE 3 SECURITY"
TitleLabel.TextColor3 = Color3.fromRGB(242, 243, 245)
TitleLabel.TextSize = 14
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.BackgroundColor3 = Color3.fromRGB(35, 36, 40)
TitleLabel.Parent = MainFrame
Instance.new("UICorner", TitleLabel).CornerRadius = UDim.new(0, 10)
local TitleStroke = Instance.new("UIStroke", TitleLabel)
TitleStroke.Color = Color3.fromRGB(47, 47, 47)
-- ====================================================================
-- PHASE 3 - PART 2: MULTI-CHANNEL WEBHOOKS & AUTO-SAVE DATA SYSTEM
-- ====================================================================
local WebhookBox = Instance.new("TextBox")
WebhookBox.Size = UDim2.new(0, 320, 0, 32)
WebhookBox.Position = UDim2.new(0.05, 0, 0.14, 0)
WebhookBox.PlaceholderText = "1. Webhook Utama Ikan Secret..."
WebhookBox.Text = ActiveWebhookUrl
WebhookBox.TextColor3 = Color3.fromRGB(255, 255, 255)
WebhookBox.BackgroundColor3 = Color3.fromRGB(30, 31, 34)
WebhookBox.TextSize = 11
WebhookBox.Font = Enum.Font.Gotham
WebhookBox.Parent = MainFrame
Instance.new("UICorner", WebhookBox).CornerRadius = UDim.new(0, 5)
Instance.new("UIStroke", WebhookBox).Color = Color3.fromRGB(47, 47, 47)

local LogWebhookBox = Instance.new("TextBox")
LogWebhookBox.Size = UDim2.new(0, 320, 0, 32)
LogWebhookBox.Position = UDim2.new(0.05, 0, 0.24, 0)
LogWebhookBox.PlaceholderText = "2. Webhook Log Join/Leave (Boleh Kosong)..."
LogWebhookBox.Text = LogWebhookUrl
LogWebhookBox.TextColor3 = Color3.fromRGB(255, 255, 255)
LogWebhookBox.BackgroundColor3 = Color3.fromRGB(30, 31, 34)
LogWebhookBox.TextSize = 11
LogWebhookBox.Font = Enum.Font.Gotham
LogWebhookBox.Parent = MainFrame
Instance.new("UICorner", LogWebhookBox).CornerRadius = UDim.new(0, 5)
Instance.new("UIStroke", LogWebhookBox).Color = Color3.fromRGB(47, 47, 47)

local PreviewButton = Instance.new("TextButton")
PreviewButton.Size = UDim2.new(0, 320, 0, 26)
PreviewButton.Position = UDim2.new(0.05, 0, 0.34, 0)
PreviewButton.Text = "🧪 TEST WEBHOOK (PREVIEW)"
PreviewButton.TextColor3 = Color3.fromRGB(180, 180, 180)
PreviewButton.BackgroundColor3 = Color3.fromRGB(47, 49, 54)
PreviewButton.TextSize = 11
PreviewButton.Font = Enum.Font.GothamBold
PreviewButton.Parent = MainFrame
Instance.new("UICorner", PreviewButton).CornerRadius = UDim.new(0, 5)

local SectionLabel = Instance.new("TextLabel")
SectionLabel.Size = UDim2.new(0, 320, 0, 20)
SectionLabel.Position = UDim2.new(0.05, 0, 0.43, 0)
SectionLabel.Text = "👥 REGISTRASI AKUN TIM (1 PER 1):"
SectionLabel.TextColor3 = Color3.fromRGB(148, 156, 247)
SectionLabel.TextSize = 11
SectionLabel.Font = Enum.Font.GothamBold
SectionLabel.BackgroundTransparency = 1
SectionLabel.TextXAlignment = Enum.TextXAlignment.Left
SectionLabel.Parent = MainFrame

local RobloxUserBox = Instance.new("TextBox")
RobloxUserBox.Size = UDim2.new(0, 155, 0, 32)
RobloxUserBox.Position = UDim2.new(0.05, 0, 0.49, 0)
RobloxUserBox.PlaceholderText = "Username Roblox..."
RobloxUserBox.TextColor3 = Color3.fromRGB(255, 255, 255)
RobloxUserBox.BackgroundColor3 = Color3.fromRGB(30, 31, 34)
RobloxUserBox.TextSize = 11
RobloxUserBox.Font = Enum.Font.Gotham
RobloxUserBox.Parent = MainFrame
Instance.new("UICorner", RobloxUserBox).CornerRadius = UDim.new(0, 5)

local DiscordIdBox = Instance.new("TextBox")
DiscordIdBox.Size = UDim2.new(0, 155, 0, 32)
DiscordIdBox.Position = UDim2.new(0.51, 0, 0.49, 0)
DiscordIdBox.PlaceholderText = "User ID Discord..."
DiscordIdBox.TextColor3 = Color3.fromRGB(255, 255, 255)
DiscordIdBox.BackgroundColor3 = Color3.fromRGB(30, 31, 34)
DiscordIdBox.TextSize = 11
DiscordIdBox.Font = Enum.Font.Gotham
DiscordIdBox.Parent = MainFrame
Instance.new("UICorner", DiscordIdBox).CornerRadius = UDim.new(0, 5)

local AddUserButton = Instance.new("TextButton")
AddUserButton.Size = UDim2.new(0, 320, 0, 30)
AddUserButton.Position = UDim2.new(0.05, 0, 0.60, 0)
AddUserButton.Text = "➕ SIMPAN DATA PASANGAN AKUN"
AddUserButton.TextColor3 = Color3.fromRGB(255, 255, 255)
AddUserButton.BackgroundColor3 = Color3.fromRGB(43, 45, 49)
AddUserButton.TextSize = 11
AddUserButton.Font = Enum.Font.GothamBold
AddUserButton.Parent = MainFrame
Instance.new("UICorner", AddUserButton).CornerRadius = UDim.new(0, 5)

local DbStatusLabel = Instance.new("TextLabel")
DbStatusLabel.Size = UDim2.new(0, 320, 0, 20)
DbStatusLabel.Position = UDim2.new(0.05, 0, 0.70, 0)
local initCount = 0 for _ in pairs(DynamicDatabase) do initCount = initCount + 1 end
DbStatusLabel.Text = "Database: " .. initCount .. " akun termuat otomatis"
DbStatusLabel.TextColor3 = Color3.fromRGB(148, 155, 164)
DbStatusLabel.TextSize = 11
DbStatusLabel.Font = Enum.Font.GothamItalic
DbStatusLabel.BackgroundTransparency = 1
DbStatusLabel.Parent = MainFrame

local function saveConfigToStorage()
    if writefile then
        local configTable = {
            Webhook = WebhookBox.Text,
            LogWebhook = LogWebhookBox.Text,
            Database = DynamicDatabase
        }
        writefile("LFAMILIA_Radar_Config.json", HttpService:JSONEncode(configTable))
    end
end

AddUserButton.MouseButton1Click:Connect(function()
    local rbxName = RobloxUserBox.Text
    local dcId = DiscordIdBox.Text:gsub("%D", "")
    if rbxName ~= "" and dcId ~= "" then
        DynamicDatabase[rbxName] = dcId
        saveConfigToStorage()
        local count = 0 for _ in pairs(DynamicDatabase) do count = count + 1 end
        DbStatusLabel.Text = "🟢 Sukses Menyimpan Akun!"
        RobloxUserBox.Text = "" DiscordIdBox.Text = "" task.wait(1.5)
        DbStatusLabel.Text = "Database: " .. count .. " akun aktif (Tersimpan)"
    end
end)
-- ====================================================================
-- PHASE 3 - PART 3: ADVANCED ANTI-BAN PROTECTION & ACTION CORES
-- ====================================================================
local StartButton = Instance.new("TextButton")
StartButton.Size = UDim2.new(0, 320, 0, 45)
StartButton.Position = UDim2.new(0.05, 0, 0.79, 0)
StartButton.Text = "START SECURE RADAR V3"
StartButton.TextColor3 = Color3.fromRGB(255, 255, 255)
StartButton.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
StartButton.TextSize = 14
StartButton.Font = Enum.Font.GothamBold
StartButton.Parent = MainFrame
Instance.new("UICorner", StartButton).CornerRadius = UDim.new(0, 6)

local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 30, 0, 30)
CloseButton.Position = UDim2.new(0.9, 0, 0.02, 0)
CloseButton.Text = "✕"
CloseButton.TextColor3 = Color3.fromRGB(148, 155, 164)
CloseButton.BackgroundTransparency = 1
CloseButton.Parent = MainFrame
CloseButton.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

local function sendWebhookPayload(url, data)
    if url == "" then return end
    task.spawn(function()
        pcall(function()
            request({
                Url = url:gsub("discord.com", "webhook.lewisakura.moe"),
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode(data)
            })
        end)
    end)
end

local function getDynamicMention(robloxName)
    local foundDiscordId = DynamicDatabase[robloxName]
    if foundDiscordId and foundDiscordId ~= "" then return "<@" .. foundDiscordId .. ">" end
    return nil
end

local function scanForNearbyAdmins()
    task.spawn(function()
        while RadarActive and task.wait(3) do
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    local lowerName = string.lower(player.Name)
                    local isStaff = player:GetRankInGroup(CreatorGroupId) >= 200 or lowerName:match("mod") or lowerName:match("admin") or lowerName:match("dev")
                    if isStaff and LocalPlayer.Character and player.Character then
                        local myPos = LocalPlayer.Character:GetPivot().Position
                        local adminPos = player.Character:GetPivot().Position
                        if (myPos - adminPos).Magnitude <= 250 then
                            sendWebhookPayload(WebhookBox.Text, { content = "⚠️ **EMERGENCY KICK**: Admin `" .. player.Name .. "` mendekati Anda!" })
                            task.wait(0.5)
                            LocalPlayer:Kick("Security V3: Terdeteksi Staf Game mendekati area Anda.")
                            break
                        end
                    end
                end
            end
        end
    end)
end

PreviewButton.MouseButton1Click:Connect(function()
    local targetUrl = WebhookBox.Text
    if targetUrl ~= "" then
        PreviewButton.Text = "⏳ SENDING V3 PREVIEW..."
        local demoMention = DynamicDatabase[LocalPlayer.Name] and "<@" .. DynamicDatabase[LocalPlayer.Name] .. ">" or "@" .. LocalPlayer.Name
        local demoDetails = "Hey " .. demoMention .. "\nPlayer : `" .. LocalPlayer.Name .. "`\nFish : **Poseidon V3**\nRarity : `Secret`\nMutation : `None`\nWeight : `120.40 kg`"
        sendWebhookPayload(targetUrl, {
            username = CustomBotName,
            avatar_url = "https://imgur.com",
            embeds = {{
                title = "PLAYER\nNOTIFICATION",
                color = 10181046,
                description = "───────────────────\n" .. demoDetails .. "\n───────────────────",
                thumbnail = { url = "https://roblox.com" },
                footer = { text = "©2026 LFAMILIA" },
                timestamp = os.date("!Y-%m-%dT%H:%M:%SZ")
            }}
        })
        task.wait(1) PreviewButton.Text = "🧪 TEST WEBHOOK (PREVIEW)"
    end
end)

local function sendServerLog(playerName, status)
    local isJoin = (status == "join")
    local mentionText = DynamicDatabase[playerName] and "<@" .. DynamicDatabase[playerName] .. ">" or "@" .. playerName
    local currentUrl = (LogWebhookBox.Text ~= "") and LogWebhookBox.Text or WebhookBox.Text
    local logMessage = "Hey " .. mentionText .. "\nPlayer : `" .. playerName .. "`\nStatus : " .. (isJoin and "**Connected / Reconnected**" or "**Disconnected / Leave**")
    sendWebhookPayload(currentUrl, {
        username = CustomBotName,
        avatar_url = "https://imgur.com",
        embeds = {{
            title = "PLAYER\nNOTIFICATION",
            color = isJoin and 3066993 or 15158332,
            description = "───────────────────\n" .. logMessage .. "\n───────────────────",
            footer = { text = "©2026 LFAMILIA" },
            timestamp = os.date("!Y-%m-%dT%H:%M:%SZ")
        }}
    })
end

local function sendGlobalWebhook(playerName, fishName, rarity, mutation, itemObject)
    local lowerRarity = string.lower(rarity)
    if lowerRarity == "secret" or lowerRarity == "forgotten" then
        local mutationText = (mutation and mutation ~= "") and mutation or "None"
        local embedColor = (lowerRarity == "secret") and 10181046 or 3447003
        local mentionText = DynamicDatabase[playerName] and "<@" .. DynamicDatabase[playerName] .. ">" or "@" .. playerName
        local fishWeight = "Unknown"
        if itemObject then
            local rawWeight = itemObject:GetAttribute("Weight") or itemObject:GetAttribute("FishWeight")
            if rawWeight then fishWeight = string.format("%.2f kg", tonumber(rawWeight) or 0) end
        end
        local fishImageId = "https://roblox.com"
        if itemObject and itemObject:IsA("Tool") and itemObject:FindFirstChild("TextureId") and itemObject.TextureId ~= "" then
            local rawId = itemObject.TextureId:match("%d+") if rawId then fishImageId = "https://roblox.com" .. rawId .. "&width=420&height=420&format=png" end
        end
        local fishDetails = "Hey " .. mentionText .. "\nPlayer : `" .. playerName .. "`\nFish : **" .. fishName .. "**\nRarity : `" .. rarity .. "`\nMutation : `" .. mutationText .. "`\nWeight : `" .. fishWeight .. "`"
        sendWebhookPayload(WebhookBox.Text, {
            username = CustomBotName,
            avatar_url = "https://imgur.com",
            embeds = {{
                title = "PLAYER\nNOTIFICATION",
                color = embedColor,
                description = "───────────────────\n" .. fishDetails .. "\n───────────────────",
                thumbnail = { url = fishImageId },
                footer = { text = "©2026 LFAMILIA" },
                timestamp = os.date("!Y-%m-%dT%H:%M:%SZ")
            }}
        })
    end
end

local function monitorPlayer(player)
    if not player then return end
    local function checkItem(item)
        if item:IsA("Tool") and item:GetAttribute("Rarity") then
            sendGlobalWebhook(player.Name, item.Name, item:GetAttribute("Rarity"), item:GetAttribute("Mutation"), item)
        end
    end
    task.spawn(function()
        local backpack = player:WaitForChild("Backpack", 12)
        if backpack then backpack.ChildAdded:Connect(checkItem) end
    end)
    player.CharacterAdded:Connect(function(char) char.ChildAdded:Connect(checkItem) end)
    if player.Character then player.Character.ChildAdded:Connect(checkItem) end
end

StartButton.MouseButton1Click:Connect(function()
    if not RadarActive then
        if WebhookBox.Text ~= "" then
            RadarActive = true
            saveConfigToStorage()
            StartButton.Text = "🟢 V3 TRACKER & ANTI-BAN ACTIVE"
            StartButton.BackgroundColor3 = Color3.fromRGB(35, 165, 89)
            scanForNearbyAdmins()
            for _, player in ipairs(Players:GetPlayers()) do monitorPlayer(player) end
            Players.PlayerAdded:Connect(function(player) sendServerLog(player.Name, "join") monitorPlayer(player) end)
            Players.PlayerRemoving:Connect(function(player) sendServerLog(player.Name, "leave") end)
        end
    else
        RadarActive = false
        StartButton.Text = "START SECURE RADAR V3"
        StartButton.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
    end
end)
