-- ============================================
-- FISH IT - SERVER CHAT MONITOR
-- Hook system notification di server chat
-- ============================================

local WebhookURL = "https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN"

-- ============================================
-- DATABASE IKAN
-- ============================================
local FishDatabase = {
    -- Secret Fish
    ["Rocky Scorpi"] = {Rarity = "Secret", Emoji = "🦂", Color = "#FF6B6B"},
    ["Astralune"] = {Rarity = "Secret", Emoji = "✨", Color = "#C084FC"},
    ["Celestial"] = {Rarity = "Secret", Emoji = "🌌", Color = "#6366F1"},
    
    -- Forgotten Fish
    ["Forgotten King"] = {Rarity = "Forgotten", Emoji = "👑", Color = "#8B5CF6"},
    ["Ancient Guardian"] = {Rarity = "Forgotten", Emoji = "🏛️", Color = "#A78BFA"},
    
    -- Tambahkan database lengkap dari game
}

-- ============================================
-- PARSE CHAT MESSAGE
-- ============================================
local function ParseChatMessage(message)
    -- Pattern 1: Dengan mutasi
    -- "combro obtained a SANDY Rocky Scorpi (125kg) with a 1 in 5K chance!"
    local pattern1 = "(.+) obtained a (.+) (.+) %((%d+)kg%) with a 1 in (.+) chance!"
    
    -- Pattern 2: Tanpa mutasi
    -- "TuanZhang obtained a Lobster (27kg) with a 1 in 5K chance!"
    local pattern2 = "(.+) obtained a (.+) %((%d+)kg%) with a 1 in (.+) chance!"
    
    local player, mutation, fishName, weight, chance
    local hasMutation = false
    
    -- Coba pattern 1 (dengan mutasi)
    player, mutation, fishName, weight, chance = 
        string.match(message, pattern1)
    
    if player then
        hasMutation = true
    else
        -- Coba pattern 2 (tanpa mutasi)
        player, fishName, weight, chance = 
            string.match(message, pattern2)
        mutation = nil
    end
    
    if player and fishName then
        return {
            Player = player:gsub("^%s*(.-)%s*$", "%1"), -- Trim
            Mutation = mutation and mutation:gsub("^%s*(.-)%s*$", "%1") or nil,
            Fish = fishName:gsub("^%s*(.-)%s*$", "%1"),
            Weight = tonumber(weight) or 0,
            Chance = chance:gsub("^%s*(.-)%s*$", "%1")
        }
    end
    
    return nil
end

-- ============================================
-- SEND TO DISCORD
-- ============================================
local function SendToDiscord(data)
    if not data or not data.Fish then return end
    
    -- Cek di database
    local fishData = FishDatabase[data.Fish]
    
    -- Filter: hanya Secret atau Forgotten
    if not fishData or (fishData.Rarity ~= "Secret" and fishData.Rarity ~= "Forgotten") then
        return
    end
    
    local HttpService = game:GetService("HttpService")
    
    -- Format pesan
    local mutationText = data.Mutation and ("[" .. data.Mutation .. "] ") or ""
    local emoji = fishData.Emoji or "🐟"
    local rarity = fishData.Rarity or "Unknown"
    local color = fishData.Color or "#FFFFFF"
    
    -- Build embed
    local embed = {
        title = emoji .. " " .. rarity:upper() .. " CATCH!",
        description = string.format("**%s** obtained a rare fish!", data.Player),
        color = tonumber(color:gsub("#", ""), 16) or 16777215,
        fields = {
            {
                name = "🎣 Fish",
                value = mutationText .. data.Fish,
                inline = true
            },
            {
                name = "⚖️ Weight",
                value = data.Weight .. " kg",
                inline = true
            },
            {
                name = "🎲 Chance",
                value = "1 in " .. data.Chance,
                inline = true
            },
            {
                name = "⭐ Rarity",
                value = rarity,
                inline = false
            },
            {
                name = "🌐 Server",
                value = game.JobId or "Unknown",
                inline = false
            }
        },
        timestamp = os.date("!%Y-%m-%dT%T.000Z"),
        footer = {
            text = "Fish It Server Monitor • " .. os.date("%H:%M:%S")
        }
    }
    
    local payload = {
        content = "@everyone **RARE FISH CAUGHT!**",
        embeds = {embed},
        username = "Fish It Hunter",
        avatar_url = "https://i.imgur.com/fish.png"
    }
    
    local json = HttpService:JSONEncode(payload)
    local headers = {["Content-Type"] = "application/json"}
    
    pcall(function()
        request({
            Url = WebhookURL,
            Method = "POST",
            Headers = headers,
            Body = json
        })
        print("✅ Webhook sent! - " .. data.Fish)
    end)
end

-- ============================================
-- HOOK CHAT (SERVER CHAT)
-- ============================================
local function HookServerChat()
    print("🔍 Mencari Server Chat...")
    
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local ChatService = nil
    
    -- Cari service chat
    for _, service in pairs(ReplicatedStorage:GetChildren()) do
        if service.Name:lower():find("chat") or service.Name:lower():find("message") then
            ChatService = service
            break
        end
    end
    
    if not ChatService then
        warn("❌ Chat service tidak ditemukan!")
        return
    end
    
    -- Cari remote event di dalam service
    for _, remote in pairs(ChatService:GetChildren()) do
        if remote:IsA("RemoteEvent") then
            local oldEvent = remote.OnClientEvent
            remote.OnClientEvent = function(...)
                local args = {...}
                for _, arg in pairs(args) do
                    if type(arg) == "string" and string.find(arg, "obtained a") then
                        local parsed = ParseChatMessage(arg)
                        if parsed then
                            print("📡 Server Chat:", arg)
                            SendToDiscord(parsed)
                        end
                    end
                end
                
                if oldEvent then
                    oldEvent(table.unpack(args))
                end
            end
            print("✅ RemoteEvent hooked: " .. remote.Name)
        end
    end
end

-- ============================================
-- MONITOR CHAT GUI (SERVER CHAT)
-- ============================================
local function MonitorServerChatGUI()
    print("🔍 Monitoring Server Chat GUI...")
    
    local Players = game:GetService("Players")
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local processedMessages = {}
    
    -- Cari chat GUI
    local function findServerChat()
        for _, gui in pairs(playerGui:GetChildren()) do
            if gui:IsA("ScreenGui") then
                for _, child in pairs(gui:GetChildren()) do
                    -- Cari frame chat server
                    if child:IsA("ScrollingFrame") and 
                       (child.Name:lower():find("chat") or child.Name:lower():find("server")) then
                        return child
                    end
                end
            end
        end
        return nil
    end
    
    local chatFrame = findServerChat()
    if not chatFrame then
        warn("❌ Server Chat frame tidak ditemukan!")
        return
    end
    
    -- Scan chat setiap detik
    game:GetService("RunService").Heartbeat:Connect(function()
        for _, child in pairs(chatFrame:GetChildren()) do
            if child:IsA("TextLabel") or child:IsA("TextButton") then
                local text = child.Text or ""
                if text ~= "" and not processedMessages[text] then
                    processedMessages[text] = true
                    
                    if string.find(text, "obtained a") then
                        local parsed = ParseChatMessage(text)
                        if parsed then
                            print("📡 Server Chat (GUI):", text)
                            SendToDiscord(parsed)
                        end
                    end
                end
            end
        end
    end)
    
    print("✅ Server Chat GUI monitor aktif!")
end

-- ============================================
-- MAIN START
-- ============================================
print("========================================")
print("🐟 FISH IT - SERVER CHAT WEBHOOK")
print("========================================")
print("📡 Webhook: " .. WebhookURL:sub(1, 50) .. "...")
print("🌐 Server: " .. game.JobId)

-- Jalankan kedua metode
pcall(HookServerChat)
pcall(MonitorServerChatGUI)

print("🔄 Monitoring server chat...")
print("Menunggu catch ikan langka...")

-- Keep alive
while wait(10) do
    print("🟢 Script running...")
end
