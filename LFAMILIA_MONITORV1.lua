-- LFAMILIA MONITOR V1
-- Standalone source for Delta Android
-- No runtime patch loader.

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local HttpService = game:GetService("HttpService")
local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local CONFIG = {
    WEBHOOK_URL = "",
    JOIN_LEAVE_URL = "",
    WEBHOOK_ENABLED = true,

    FISH_DB_URL = "https://raw.githubusercontent.com/muhammadaldy198/LFAMILIA/refs/heads/main/FishDatabase.lua",
    RARITY_DB_URL = "https://raw.githubusercontent.com/muhammadaldy198/LFAMILIA/refs/heads/main/RarityDatabase.lua",
    VARIANT_DB_URL = "https://raw.githubusercontent.com/muhammadaldy198/LFAMILIA/refs/heads/main/VariantDatabase.lua",

    ALLOW_RARITY = {
        SECRET = true,
        FORGOTTEN = true,
        Mythic = true,
        Legendary = true,
    },

    SPECIAL_FILTERS = {
        RUBY_GEMSTONE = true,
    },

    MIN_WEIGHT = 0,
    WEBHOOK_USERNAME = "LFAMILIA WEBHOOK",
    BANNER_URL = "https://i.imgur.com/42wd0m0.png",
}

local RELAY_URL = "https://Aldayyy.pythonanywhere.com/api/catch"

local mappings = {}
local state = {
    Running = true,
    Detected = 0,
    Sent = 0,
    WebhooksSent = 0,
    Seen = {},
}

local CONFIG_FILES = {
    [1] = "LFAMILIA_Slot1.json",
    [2] = "LFAMILIA_Slot2.json",
    [3] = "LFAMILIA_Slot3.json",
}

local function trim(v)
    return tostring(v or ""):gsub("^%s*(.-)%s*$", "%1")
end

local function clearTable(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

local function requestFn()
    if type(request) == "function" then return request end
    if type(http_request) == "function" then return http_request end
    if syn and type(syn.request) == "function" then return syn.request end
    if fluxus and type(fluxus.request) == "function" then return fluxus.request end
    return nil
end

local function getWriteFn()
    if type(writefile) == "function" then return writefile end
    if syn and type(syn.writefile) == "function" then return syn.writefile end
    return nil
end

local function getReadFn()
    if type(readfile) == "function" then return readfile end
    if syn and type(syn.readfile) == "function" then return syn.readfile end
    return nil
end

local function normalizeDiscordId(v)
    return tostring(v or ""):match("%d+") or ""
end

local function addMappingEntry(target, discordId, playerName)
    discordId = normalizeDiscordId(discordId)
    playerName = trim(playerName)
    if discordId == "" or playerName == "" then return end

    target[discordId] = target[discordId] or {}
    for _, name in ipairs(target[discordId]) do
        if tostring(name):lower() == playerName:lower() then
            return
        end
    end
    table.insert(target[discordId], playerName)
end

local function normalizeMappings(raw)
    local out = {}

    for key, value in pairs(raw or {}) do
        if type(value) == "table" then
            for _, playerName in ipairs(value) do
                addMappingEntry(out, key, playerName)
            end
        elseif type(value) == "string" or type(value) == "number" then
            addMappingEntry(out, value, key)
        end
    end

    return out
end

local refreshMappings
local refreshPlayers
local refreshStats
local syncInputs

local function manualSave(slot)
    local wf = getWriteFn()
    if not wf then return false, "writefile tidak tersedia" end

    local payload = {
        SchemaVersion = 3,
        CONFIG = {
            WEBHOOK_URL = CONFIG.WEBHOOK_URL,
            JOIN_LEAVE_URL = CONFIG.JOIN_LEAVE_URL,
            WEBHOOK_ENABLED = CONFIG.WEBHOOK_ENABLED,
            ALLOW_RARITY = CONFIG.ALLOW_RARITY,
            SPECIAL_FILTERS = CONFIG.SPECIAL_FILTERS,
            MIN_WEIGHT = CONFIG.MIN_WEIGHT,
            WEBHOOK_USERNAME = CONFIG.WEBHOOK_USERNAME,
        },
        mappings = normalizeMappings(mappings),
    }

    local ok1, encoded = pcall(function()
        return HttpService:JSONEncode(payload)
    end)
    if not ok1 then return false, "JSON encode gagal" end

    local ok2, err = pcall(function()
        wf(CONFIG_FILES[slot] or CONFIG_FILES[1], encoded)
    end)

    return ok2, ok2 and "Saved" or tostring(err)
end

local function manualLoad(slot)
    local rf = getReadFn()
    if not rf then return false, "readfile tidak tersedia" end

    local ok1, raw = pcall(function()
        return rf(CONFIG_FILES[slot] or CONFIG_FILES[1])
    end)
    if not ok1 or not raw or raw == "" then
        return false, "Slot kosong"
    end

    local ok2, data = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if not ok2 or type(data) ~= "table" then
        return false, "JSON invalid"
    end

    if type(data.CONFIG) == "table" then
        local c = data.CONFIG
        if type(c.WEBHOOK_URL) == "string" then CONFIG.WEBHOOK_URL = c.WEBHOOK_URL end
        if type(c.JOIN_LEAVE_URL) == "string" then CONFIG.JOIN_LEAVE_URL = c.JOIN_LEAVE_URL end
        if type(c.WEBHOOK_ENABLED) == "boolean" then CONFIG.WEBHOOK_ENABLED = c.WEBHOOK_ENABLED end
        if type(c.MIN_WEIGHT) == "number" then CONFIG.MIN_WEIGHT = c.MIN_WEIGHT end
        if type(c.WEBHOOK_USERNAME) == "string" then CONFIG.WEBHOOK_USERNAME = c.WEBHOOK_USERNAME end

        if type(c.ALLOW_RARITY) == "table" then
            for _, n in ipairs({"SECRET","FORGOTTEN","Mythic","Legendary"}) do
                CONFIG.ALLOW_RARITY[n] = c.ALLOW_RARITY[n] == true
            end
        end

        if type(c.SPECIAL_FILTERS) == "table" then
            CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE =
                c.SPECIAL_FILTERS.RUBY_GEMSTONE ~= false
        end
    end

    if type(data.mappings) == "table" then
        clearTable(mappings)
        local n = normalizeMappings(data.mappings)
        for id, list in pairs(n) do
            mappings[id] = list
        end
    end

    if refreshMappings then pcall(refreshMappings) end
    if refreshPlayers then pcall(refreshPlayers) end
    if refreshStats then pcall(refreshStats) end
    if syncInputs then pcall(syncInputs) end

    return true, "Loaded"
end

local function fetchLua(url)
    local ok, data = pcall(function()
        local src = game:HttpGet(url)
        local fn = loadstring(src)
        if not fn then return {} end
        return fn()
    end)
    return ok and type(data) == "table" and data or {}
end

local FishDatabase = fetchLua(CONFIG.FISH_DB_URL)
local RarityDatabase = fetchLua(CONFIG.RARITY_DB_URL)
local VariantDatabase = fetchLua(CONFIG.VARIANT_DB_URL)

local FishDatabaseTotal = 0
for _ in pairs(FishDatabase) do
    FishDatabaseTotal = FishDatabaseTotal + 1
end

local function findFishExact(name)
    local wanted = trim(name):lower()
    if wanted == "" then return nil, nil end

    for realName, data in pairs(FishDatabase) do
        if tostring(realName):lower() == wanted then
            return data, realName
        end
    end

    return nil, nil
end

local function getVariantFromName(text)
    local wanted = trim(text)
    local lower = wanted:lower()

    for _, v in pairs(VariantDatabase) do
        if type(v) == "table" and v.Name then
            local prefix = tostring(v.Name):lower() .. " "
            if lower:sub(1, #prefix) == prefix then
                return tostring(v.Name), trim(wanted:sub(#prefix + 1)), v
            end
        end
    end

    return nil, wanted, nil
end

local function getVariantByExactName(text)
    local wanted = trim(text):lower()
    for _, v in pairs(VariantDatabase) do
        if type(v) == "table" and v.Name
            and tostring(v.Name):lower() == wanted then
            return tostring(v.Name), v
        end
    end
    return nil, nil
end

local function getVariantByColor(r,g,b)
    if not r or not g or not b then return nil,nil end

    for _, v in pairs(VariantDatabase) do
        if type(v) == "table" and v.Name and type(v.Colors) == "table" then
            for _, c in ipairs(v.Colors) do
                if type(c) == "table" then
                    local cr,cg,cb = tonumber(c[1]) or 0, tonumber(c[2]) or 0, tonumber(c[3]) or 0
                    if math.abs(cr-r)<=5 and math.abs(cg-g)<=5 and math.abs(cb-b)<=5 then
                        return tostring(v.Name), v
                    end
                end
            end
        end
    end

    return nil,nil
end

-- Shiny/size are display modifiers only.
local DISPLAY_MODIFIERS = {
    shiny=true, big=true, small=true, tiny=true,
    huge=true, massive=true, large=true, giant=true, mini=true,
}

local function isDisplayModifierText(text)
    local t = trim(text):lower()
    if t == "" then return false end
    local count = 0
    for w in t:gmatch("%S+") do
        count = count + 1
        if not DISPLAY_MODIFIERS[w] then return false end
    end
    return count > 0
end

local function stripDisplayModifiers(text)
    local requested = trim(text)

    local exactData, exactName = findFishExact(requested)
    if exactData then return exactName, {} end

    local current = requested
    local mods = {}

    while true do
        local first, rest = current:match("^(%S+)%s+(.+)$")
        if not first or not rest then break end
        if not DISPLAY_MODIFIERS[first:lower()] then break end

        table.insert(mods, first)
        current = trim(rest)

        local data, real = findFishExact(current)
        if data then return real, mods end
    end

    return current, mods
end

-- Supports:
-- Shiny Astralune
-- Big Shiny Astralune
-- Gemstone Big Shiny Ruby
-- Big Shiny Gemstone Ruby
local function resolveCatchName(raw)
    local requested = trim(raw)
    if requested == "" then return requested,nil,{},nil,nil end

    local exactData, exactName = findFishExact(requested)
    if exactData then
        return exactName,nil,{},exactData,nil
    end

    -- Variant first.
    local variant, rest, variantData = getVariantFromName(requested)
    if variant then
        local base, mods = stripDisplayModifiers(rest)
        local fishData, real = findFishExact(base)
        if fishData then
            return real,variant,mods,fishData,variantData
        end
    end

    -- Display modifiers first.
    local afterDisplay, mods = stripDisplayModifiers(requested)
    local fishData, real = findFishExact(afterDisplay)
    if fishData then
        return real,nil,mods,fishData,nil
    end

    -- Variant after display modifiers.
    local nestedVariant, nestedRest, nestedVariantData = getVariantFromName(afterDisplay)
    if nestedVariant then
        local base, mods2 = stripDisplayModifiers(nestedRest)
        for _, m in ipairs(mods2) do table.insert(mods,m) end

        fishData, real = findFishExact(base)
        if fishData then
            return real,nestedVariant,mods,fishData,nestedVariantData
        end
    end

    return afterDisplay,variant or nestedVariant,mods,nil,variantData or nestedVariantData
end

local function resolveFish(name)
    local base, variant, mods, fishData, variantData = resolveCatchName(name)
    if fishData then
        return fishData,base,variantData,variant,mods
    end
    local data, real = findFishExact(base)
    return data, real or base, variantData, variant, mods
end

local function stripRichText(text)
    text = tostring(text or "")
    text = text:gsub("<[^>]->","")
    text = text:gsub("&lt;","<")
    text = text:gsub("&gt;",">")
    text = text:gsub("&amp;","&")
    return text
end

local function extractRGBFromFont(text)
    local r,g,b = tostring(text or ""):match(
        '<font[^>]-color%s*=%s*"rgb%((%d+)%s*,%s*(%d+)%s*,%s*(%d+)%)'
    )

    if r then
        return tonumber(r),tonumber(g),tonumber(b)
    end

    return nil,nil,nil
end

local function collectSpans(message)
    local out = {}
    local cursor = 1

    while true do
        local s,e,attrs,inside = message:find("<font([^>]*)>(.-)</font>",cursor)
        if not s then break end

        local r,g,b = extractRGBFromFont("<font"..attrs..">")
        table.insert(out,{
            Text=trim(stripRichText(inside)),
            R=r,G=g,B=b
        })
        cursor=e+1
    end

    return out
end

local function parseWeightValue(text)
    local compact = trim(text):lower():gsub("%s+","")
    local n = tonumber(compact:match("([%d%.]+)")) or 0

    if compact:sub(-2)=="kg" then
        local pre = compact:sub(1,-3)
        local scale = pre:sub(-1)
        if scale=="k" then return n*1000 end
        if scale=="m" then return n*1000000 end
        if scale=="b" then return n*1000000000 end
        return n
    end

    if compact:sub(-1)=="k" then return n*1000 end
    if compact:sub(-1)=="m" then return n*1000000 end
    if compact:sub(-1)=="b" then return n*1000000000 end
    return n
end

local function parseCatch(message)
    local rich = trim(message)
    if rich=="" then return nil end

    local spans = collectSpans(rich)
    local clean = trim(stripRichText(rich):gsub("!%s*$",""):gsub("%s+"," "))

    local player,caught,weight,chance = clean:match(
        "^(.+)%s+[Oo]btained%s+[Aa]%s+(.+)%s+%(([^)]+)%)%s+[Ww]ith%s+(.+)%s+[Cc]hance$"
    )

    if not player then
        player,caught,weight,chance = clean:match(
            "^(.+)%s+[Oo]btained%s+[Aa][Nn]%s+(.+)%s+%(([^)]+)%)%s+[Ww]ith%s+(.+)%s+[Cc]hance$"
        )
    end

    if not player then return nil end

    local baseFish,variant,mods,fishData = resolveCatchName(caught)
    local rarityColor=nil
    local variantColor=nil
    local playerColor=nil

    for i,span in ipairs(spans) do
        if i==1 and span.R and span.G and span.B then
            playerColor={span.R,span.G,span.B}
        end

        if span.Text:find("%([^)]-%)") and span.R and span.G and span.B then
            rarityColor={span.R,span.G,span.B}
        end

        if variant and span.Text:lower()==tostring(variant):lower()
            and span.R and span.G and span.B then
            variantColor={span.R,span.G,span.B}
        end
    end

    -- Fallback RGB variant, excluding Shiny/Big/etc.
    if not variant and not fishData then
        for i,span in ipairs(spans) do
            if i>1 and not span.Text:find("%([^)]-%)"
                and not isDisplayModifierText(span.Text) then

                local detected, vd = getVariantByExactName(span.Text)
                if not detected and span.R and span.G and span.B then
                    detected,vd=getVariantByColor(span.R,span.G,span.B)
                end

                if detected then
                    variant=detected
                    if span.R and span.G and span.B then
                        variantColor={span.R,span.G,span.B}
                    elseif vd and type(vd.Colors)=="table" and type(vd.Colors[1])=="table" then
                        variantColor=vd.Colors[1]
                    end
                    break
                end
            end
        end
    end

    chance=trim(chance):gsub("^[Aa]%s+","")

    return {
        Player=trim(player),
        Fish=baseFish,
        RawFish=trim(caught),
        Variant=variant,
        Mutation=variant,
        DisplayModifiers=mods,
        Weight=parseWeightValue(weight),
        Chance=chance,
        PlayerColor=playerColor,
        VariantColor=variantColor,
        RarityColor=rarityColor,
        RawMessage=rich,
    }
end

local function resolveRarity(fishData)
    if not fishData then return nil end

    local id=tonumber(fishData.Id)
    if id and RarityDatabase[id] then return RarityDatabase[id] end

    if fishData.Rarity then
        for _,tier in pairs(RarityDatabase) do
            if type(tier)=="table" and tier.Name
                and tostring(tier.Name):lower()==tostring(fishData.Rarity):lower() then
                return tier
            end
        end
    end

    return nil
end

local function resolveRarityByColor(r,g,b)
    if not r or not g or not b then return nil end

    for _,tier in pairs(RarityDatabase) do
        if type(tier)=="table" and type(tier.Colors)=="table" then
            for _,c in ipairs(tier.Colors) do
                if type(c)=="table" then
                    local cr,cg,cb=tonumber(c[1]) or 0,tonumber(c[2]) or 0,tonumber(c[3]) or 0
                    if math.abs(cr-r)<=5 and math.abs(cg-g)<=5 and math.abs(cb-b)<=5 then
                        return tier
                    end
                end
            end
        end
    end

    return nil
end

local AssetThumbnailCache={}

local function normalizeAssetId(v)
    return tostring(v or ""):match("%d+")
end

local function thumbnail(assetId)
    local id=normalizeAssetId(assetId)
    if not id then return nil end
    if AssetThumbnailCache[id]~=nil then return AssetThumbnailCache[id] or nil end

    local req=requestFn()
    if not req then
        AssetThumbnailCache[id]=false
        return nil
    end

    local url="https://thumbnails.roproxy.com/v1/assets?assetIds="
        ..id.."&size=420x420&format=png"

    local ok,res=pcall(function()
        return req({Url=url,Method="GET"})
    end)

    if ok and res and res.Body then
        local ok2,d=pcall(function()
            return HttpService:JSONDecode(res.Body)
        end)

        if ok2 and d and d.data and d.data[1]
            and type(d.data[1].imageUrl)=="string"
            and d.data[1].imageUrl~="" then

            AssetThumbnailCache[id]=d.data[1].imageUrl
            return d.data[1].imageUrl
        end
    end

    AssetThumbnailCache[id]=false
    return nil
end

local function buildAssetInfo(assetId)
    local id=normalizeAssetId(assetId)
    if not id then return {} end

    local info={
        asset_id=id,
        asset_uri="rbxassetid://"..id,
        asset_source="Fish It private asset",
        asset_private=true,
    }

    local url=thumbnail(id)
    if url then
        info.thumbnail_url=url
        info.asset_private=false
    end

    return info
end

local function normalizePlayerName(v)
    return trim(v):gsub("^@",""):lower()
end

local function playerNamesMatch(a,b,obj)
    local x,y=normalizePlayerName(a),normalizePlayerName(b)
    if x=="" or y=="" then return false end
    if x==y then return true end

    if obj then
        local u=normalizePlayerName(obj.Name)
        local d=normalizePlayerName(obj.DisplayName)
        if (x==u and y==d) or (x==d and y==u) then return true end
    end

    return false
end

local function getMentionsForPlayer(playerName,obj)
    local out={}
    local seen={}

    for discordId,list in pairs(mappings) do
        if type(list)=="table" then
            for _,mapped in ipairs(list) do
                if playerNamesMatch(mapped,playerName,obj) then
                    local id=normalizeDiscordId(discordId)
                    if id~="" and not seen[id] then
                        seen[id]=true
                        table.insert(out,"<@"..id..">")
                    end
                    break
                end
            end
        end
    end

    table.sort(out)
    return table.concat(out," ")
end

local monitorLog=nil
local monitorLines={}

local function appendLog(kind,message)
    table.insert(monitorLines,
        "["..os.date("%H:%M:%S").."] "..tostring(kind).." "..tostring(message)
    )

    while #monitorLines>60 do
        table.remove(monitorLines,1)
    end

    if monitorLog then
        monitorLog.Text="DETECTION LOG\n\n"..table.concat(monitorLines,"\n")
    end
end

local function seenRecently(key)
    local now=os.clock()
    local old=state.Seen[key]
    state.Seen[key]=now
    return old and (now-old)<5
end

local function effectiveVariant(data)
    local v=data and (data.Variant or data.Mutation)
    if v and trim(v)~="" and not isDisplayModifierText(v) then
        return tostring(v)
    end

    if data and data.RawFish then
        local _,rv=resolveCatchName(data.RawFish)
        if rv and not isDisplayModifierText(rv) then return rv end
    end

    return nil
end

local function isRubyGemstoneCatch(data)
    if not data then return false end

    local fishData,realName=resolveFish(data.Fish or data.RawFish or "")
    if not fishData or tostring(realName or ""):lower()~="ruby" then
        return false
    end

    local v=effectiveVariant(data)
    return v and tostring(v):lower()=="gemstone"
end

local function sendWebhook(data)
    if CONFIG.WEBHOOK_ENABLED==false then return false end
    if CONFIG.WEBHOOK_URL=="" then
        appendLog("ERR","Webhook URL kosong")
        return false
    end

    local req=requestFn()
    if not req then
        appendLog("ERR","request() tidak tersedia")
        return false
    end

    local fishData,realName=resolveFish(data.Fish or data.RawFish or "")
    local fishName=realName or data.Fish or data.RawFish or "Unknown"
    local variant=effectiveVariant(data)
    local special=isRubyGemstoneCatch(data)

    local rarity=nil
    local rarityName="Unknown"
    local color=0xFFFFFF

    if data.RarityColor then
        local r,g,b=data.RarityColor[1],data.RarityColor[2],data.RarityColor[3]
        if r and g and b then
            color=r*65536+g*256+b
            rarity=resolveRarityByColor(r,g,b)
            if rarity and rarity.Name then rarityName=rarity.Name end
        end
    end

    if not rarity then
        rarity=resolveRarity(fishData)
        if rarity and rarity.Name then
            rarityName=rarity.Name
        elseif special then
            rarityName="SPECIAL"
            color=0xE0115F
        else
            appendLog("ERR","Rarity tidak ditemukan: "..tostring(fishName))
            return false
        end
    end

    if special then
        if CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE~=true then return false end
    else
        local allowed=CONFIG.ALLOW_RARITY[rarityName]
            or CONFIG.ALLOW_RARITY[string.upper(tostring(rarityName))]
        if not allowed then return false end
    end

    if data.Weight<CONFIG.MIN_WEIGHT then return false end

    local key=tostring(data.Player).."|"..tostring(fishName).."|"
        ..tostring(variant or "-").."|"..tostring(data.Weight)

    if seenRecently(key) then return false end

    local assetId=data._assetId
    if not assetId and fishData and fishData.AssetId then
        assetId=tostring(fishData.AssetId):match("%d+")
    end

    local assetInfo=buildAssetInfo(assetId)
    assetId=assetInfo.asset_id or assetId

    local mention=getMentionsForPlayer(
        data.Player,
        Players:FindFirstChild(tostring(data.Player))
    )

    local modifiers=""
    if type(data.DisplayModifiers)=="table" and #data.DisplayModifiers>0 then
        modifiers=table.concat(data.DisplayModifiers," ")
    end

    local payload={
        discord_url=CONFIG.WEBHOOK_URL,
        webhook_username=CONFIG.WEBHOOK_USERNAME,
        content=mention,
        mention=mention,
        allowed_mentions={parse={"users"}},

        player=data.Player,
        fish=fishName,
        raw_fish=data.RawFish,
        display_modifiers=modifiers,

        weight=data.Weight,
        chance=data.Chance,
        rarity=rarityName,
        color=color,

        variant=variant,
        mutation=variant,
        variant_color=data.VariantColor,
        rarity_color=data.RarityColor,
        player_color=data.PlayerColor,

        asset_id=assetId,
        asset_uri=assetInfo.asset_uri,
        asset_source=assetInfo.asset_source,
        asset_private=assetInfo.asset_private,
        thumbnail_url=assetInfo.thumbnail_url,

        banner_url=CONFIG.BANNER_URL,
        server_id=game.JobId or "",
        time=os.date("%H:%M WIB • %d %b %Y"),
    }

    local response
    local ok,err=pcall(function()
        response=req({
            Url=RELAY_URL,
            Method="POST",
            Headers={["Content-Type"]="application/json"},
            Body=HttpService:JSONEncode(payload),
        })
    end)

    local status=response and tonumber(response.StatusCode)
    local accepted=ok and response and response.Success~=false
        and (not status or (status>=200 and status<300))

    if accepted then
        state.Sent=state.Sent+1
        state.WebhooksSent=state.WebhooksSent+1
        if refreshStats then pcall(refreshStats) end
        return true
    end

    appendLog("ERR","Relay gagal: "..tostring(err or status or "empty"))
    return false
end

local function sendJoinLeaveWebhook(player,action)
    if CONFIG.WEBHOOK_ENABLED==false or CONFIG.JOIN_LEAVE_URL=="" then return end

    local req=requestFn()
    if not req then return end

    local mention=getMentionsForPlayer(player.Name,player)
    local payload={
        username=CONFIG.WEBHOOK_USERNAME,
        content=mention~="" and (mention.." Ping!") or nil,
        allowed_mentions={parse={"users"}},
        embeds={{
            description="**"..player.Name.."** "
                ..(action=="JOINED" and "has joined the server!" or "has left the server!"),
            color=action=="JOINED" and 0x2ECC71 or 0xE74C3C,
            footer={text="LFAMILIA V1 • Fish It | "..os.date("%H:%M:%S")}
        }}
    }

    pcall(function()
        req({
            Url=CONFIG.JOIN_LEAVE_URL,
            Method="POST",
            Headers={["Content-Type"]="application/json"},
            Body=HttpService:JSONEncode(payload),
        })
    end)
end

-- UI
local function guiParent()
    if type(gethui)=="function" then
        local ok,p=pcall(gethui)
        if ok and p then return p end
    end
    return CoreGui
end

local parent=guiParent()
pcall(function()
    local old=parent:FindFirstChild("LFAMILIA_Radar_V5")
    if old then old:Destroy() end
end)

local gui=Instance.new("ScreenGui")
gui.Name="LFAMILIA_Radar_V5"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=99999
gui.Parent=parent

local T={
    bg=Color3.fromRGB(8,10,17),
    panel=Color3.fromRGB(16,19,30),
    panel2=Color3.fromRGB(22,26,40),
    border=Color3.fromRGB(85,96,135),
    text=Color3.fromRGB(242,245,255),
    muted=Color3.fromRGB(155,164,188),
    cyan=Color3.fromRGB(67,211,255),
    purple=Color3.fromRGB(148,93,255),
    pink=Color3.fromRGB(255,91,178),
    green=Color3.fromRGB(65,222,139),
    orange=Color3.fromRGB(255,174,74),
    red=Color3.fromRGB(246,86,108),
}

local function corner(o,r)
    local c=Instance.new("UICorner")
    c.CornerRadius=UDim.new(0,r or 8)
    c.Parent=o
end

local function stroke(o,color,trans,thick)
    local s=Instance.new("UIStroke")
    s.Color=color or T.border
    s.Transparency=trans or 0
    s.Thickness=thick or 1
    s.Parent=o
end

local viewport=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
local w=math.max(340,math.floor(math.min(viewport.X*0.94,1200)))
local h=math.max(320,math.floor(math.min(viewport.Y*0.88,650)))

local main=Instance.new("Frame")
main.Size=UDim2.fromOffset(w,h)
main.AnchorPoint=Vector2.new(.5,.5)
main.Position=UDim2.new(.5,0,.5,0)
main.BackgroundColor3=T.bg
main.BorderSizePixel=0
main.Parent=gui
corner(main,12)
stroke(main,T.border,.05,1.8)

local header=Instance.new("TextButton")
header.Size=UDim2.new(1,-100,0,52)
header.Position=UDim2.fromOffset(14,0)
header.BackgroundTransparency=1
header.Text="LFAMILIA MONITOR"
header.TextColor3=T.text
header.Font=Enum.Font.GothamBold
header.TextSize=13
header.TextXAlignment=Enum.TextXAlignment.Left
header.Parent=main

local hide=Instance.new("TextButton")
hide.Size=UDim2.fromOffset(70,30)
hide.Position=UDim2.new(1,-82,0,11)
hide.BackgroundColor3=T.cyan
hide.Text="HIDE"
hide.TextColor3=T.bg
hide.Font=Enum.Font.GothamBold
hide.TextSize=10
hide.Parent=main
corner(hide,8)

local restore=Instance.new("TextButton")
restore.Size=UDim2.fromOffset(58,58)
restore.Position=UDim2.new(.5,-29,.5,-29)
restore.BackgroundColor3=T.purple
restore.Text="LFM"
restore.TextColor3=T.text
restore.Font=Enum.Font.GothamBold
restore.Visible=false
restore.Parent=gui
corner(restore,16)
stroke(restore,T.cyan,.1,1.5)

local sidebar=Instance.new("Frame")
sidebar.Position=UDim2.fromOffset(10,58)
sidebar.Size=UDim2.new(0,118,1,-68)
sidebar.BackgroundColor3=T.panel2
sidebar.BorderSizePixel=0
sidebar.Parent=main
corner(sidebar,10)
stroke(sidebar,T.border,.12,1.3)

local sideLayout=Instance.new("UIListLayout")
sideLayout.Padding=UDim.new(0,7)
sideLayout.HorizontalAlignment=Enum.HorizontalAlignment.Center
sideLayout.Parent=sidebar

local pages={}
local tabs={}

local function page(name)
    local p=Instance.new("ScrollingFrame")
    p.Name=name
    p.Position=UDim2.fromOffset(140,58)
    p.Size=UDim2.new(1,-152,1,-68)
    p.BackgroundTransparency=1
    p.BorderSizePixel=0
    p.ScrollBarThickness=4
    p.AutomaticCanvasSize=Enum.AutomaticSize.Y
    p.CanvasSize=UDim2.new()
    p.Visible=false
    p.Parent=main

    local l=Instance.new("UIListLayout")
    l.Padding=UDim.new(0,10)
    l.Parent=p

    pages[name]=p
    return p
end

local function card(parent,height,accent)
    local f=Instance.new("Frame")
    f.Size=UDim2.new(1,-3,0,height)
    f.BackgroundColor3=T.panel
    f.BorderSizePixel=0
    f.Parent=parent
    corner(f,10)
    stroke(f,T.border,.1,1.1)

    local stripe=Instance.new("Frame")
    stripe.Size=UDim2.new(0,3,1,-18)
    stripe.Position=UDim2.fromOffset(0,9)
    stripe.BackgroundColor3=accent or T.purple
    stripe.BorderSizePixel=0
    stripe.Parent=f

    local div=Instance.new("Frame")
    div.Position=UDim2.fromOffset(12,32)
    div.Size=UDim2.new(1,-24,0,1)
    div.BackgroundColor3=T.border
    div.BackgroundTransparency=.18
    div.BorderSizePixel=0
    div.Parent=f

    return f
end

local function label(parent,textValue,y,size,color,bold)
    local l=Instance.new("TextLabel")
    l.Position=UDim2.fromOffset(13,y)
    l.Size=UDim2.new(1,-26,0,22)
    l.BackgroundTransparency=1
    l.Text=textValue
    l.TextColor3=color or T.text
    l.TextSize=size or 10
    l.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham
    l.TextXAlignment=Enum.TextXAlignment.Left
    l.TextWrapped=true
    l.Parent=parent
    return l
end

local function button(parent,textValue,pos,size,color)
    local b=Instance.new("TextButton")
    b.Position=pos
    b.Size=size
    b.BackgroundColor3=color or T.panel2
    b.BorderSizePixel=0
    b.Text=textValue
    b.TextColor3=T.text
    b.TextSize=10
    b.Font=Enum.Font.GothamBold
    b.Parent=parent
    corner(b,7)
    stroke(b,T.border,.35,1)
    return b
end

local function input(parent,y,value,placeholder)
    local x=Instance.new("TextBox")
    x.Position=UDim2.fromOffset(13,y)
    x.Size=UDim2.new(1,-26,0,29)
    x.BackgroundColor3=T.panel2
    x.BorderSizePixel=0
    x.Text=value or ""
    x.PlaceholderText=placeholder or ""
    x.ClearTextOnFocus=false
    x.TextColor3=T.text
    x.PlaceholderColor3=T.muted
    x.TextSize=10
    x.Font=Enum.Font.Code
    x.TextXAlignment=Enum.TextXAlignment.Left
    x.Parent=parent
    corner(x,7)
    stroke(x,T.border,.3,1)
    return x
end

local homePage=page("Home")
local webhookPage=page("Webhook")
local logPage=page("Log")
local configPage=page("Config")

for i,name in ipairs({"Home","Webhook","Log","Config"}) do
    local b=button(sidebar,name,UDim2.new(),UDim2.new(1,-14,0,42),T.panel2)
    b.LayoutOrder=i
    tabs[name]=b
end

local function active(name)
    for n,p in pairs(pages) do p.Visible=(n==name) end
    for n,b in pairs(tabs) do
        b.BackgroundColor3=(n==name) and Color3.fromRGB(45,45,75) or T.panel2
        b.TextColor3=(n==name) and T.text or T.muted
    end
end

for name,b in pairs(tabs) do
    b.Activated:Connect(function() active(name) end)
end
active("Home")

-- HOME
local statusCard=card(homePage,105,T.green)
label(statusCard,"MONITOR STATUS",8,11,T.green,true)
local statsLabel=label(statusCard,"Detected 0 • Sent 0",44,12,T.text,true)
local webhookToggle=button(statusCard,"WEBHOOK ON",UDim2.new(.65,0,0,54),UDim2.new(.35,-14,0,32),T.green)

local overview=card(homePage,140,T.cyan)
label(overview,"OVERVIEW",8,11,T.cyan,true)
local overviewText=label(overview,"Players: 0\nFish Database: "..FishDatabaseTotal.."\nWebhooks Sent: 0",45,12,T.text,true)
overviewText.Size=UDim2.new(1,-26,0,82)

local lastCard=card(homePage,100,T.pink)
label(lastCard,"LAST ACTIVITY",8,11,T.pink,true)
local lastText=label(lastCard,"Menunggu aktivitas...",43,10,T.text,false)
lastText.Size=UDim2.new(1,-26,0,50)

-- CONFIG FILTERS
local filterCard=card(configPage,310,T.orange)
label(filterCard,"CATCH FILTERS",8,11,T.orange,true)

local rarityButtons={}
local rarityOrder={"SECRET","FORGOTTEN","Mythic","Legendary"}

for i,name in ipairs(rarityOrder) do
    local row=math.floor((i-1)/2)
    local col=(i-1)%2
    local b=button(
        filterCard,
        name,
        UDim2.new(col*.5,col==0 and 13 or 7,0,55+row*38),
        UDim2.new(.5,-20,0,31),
        CONFIG.ALLOW_RARITY[name] and T.green or T.panel2
    )
    rarityButtons[name]=b

    local function redraw()
        local on=CONFIG.ALLOW_RARITY[name]
        b.Text=name.."  "..(on and "ON" or "OFF")
        b.BackgroundColor3=on and T.green or T.panel2
    end
    redraw()

    b.Activated:Connect(function()
        CONFIG.ALLOW_RARITY[name]=not CONFIG.ALLOW_RARITY[name]
        redraw()
    end)
end

label(filterCard,"SPECIAL CATCH",140,9,T.muted,true)

local rubyButton=button(
    filterCard,
    "RUBY + GEMSTONE",
    UDim2.fromOffset(13,164),
    UDim2.new(1,-26,0,34),
    CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE and T.pink or T.panel2
)

local function redrawRuby()
    local on=CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE
    rubyButton.Text="RUBY + GEMSTONE  "..(on and "ON" or "OFF")
    rubyButton.BackgroundColor3=on and T.pink or T.panel2
end
redrawRuby()

rubyButton.Activated:Connect(function()
    CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE=
        not CONFIG.SPECIAL_FILTERS.RUBY_GEMSTONE
    redrawRuby()
end)

label(filterCard,"MIN WEIGHT (KG)",213,9,T.muted,true)
local weightInput=input(filterCard,236,tostring(CONFIG.MIN_WEIGHT),"0")
weightInput.FocusLost:Connect(function()
    local n=tonumber(trim(weightInput.Text))
    if n and n>=0 then CONFIG.MIN_WEIGHT=n end
    weightInput.Text=tostring(CONFIG.MIN_WEIGHT)
end)

-- SAVE LOAD
local storageCard=card(configPage,118,T.purple)
label(storageCard,"PROFILE DATA",8,11,T.purple,true)
local activeSlot=1
local slotButton=button(storageCard,"SLOT 1",UDim2.fromOffset(13,48),UDim2.new(.3,-8,0,31),T.panel2)
local saveButton=button(storageCard,"SAVE",UDim2.new(.32,2,0,48),UDim2.new(.31,-8,0,31),T.green)
local loadButton=button(storageCard,"LOAD",UDim2.new(.65,2,0,48),UDim2.new(.31,-15,0,31),T.orange)
local storageStatus=label(storageCard,"Ready",84,9,T.muted,false)

slotButton.Activated:Connect(function()
    activeSlot=activeSlot%3+1
    slotButton.Text="SLOT "..activeSlot
end)

saveButton.Activated:Connect(function()
    local ok,msg=manualSave(activeSlot)
    storageStatus.Text=(ok and "OK: " or "ERR: ")..msg
end)

loadButton.Activated:Connect(function()
    local ok,msg=manualLoad(activeSlot)
    storageStatus.Text=(ok and "OK: " or "ERR: ")..msg
end)

-- WEBHOOK
local webhookCard=card(webhookPage,250,T.green)
label(webhookCard,"WEBHOOK ROUTING",8,11,T.green,true)
local webhookInput=input(webhookCard,52,CONFIG.WEBHOOK_URL,"Discord webhook catch")
local joinInput=input(webhookCard,88,CONFIG.JOIN_LEAVE_URL,"Discord webhook join/leave")
local usernameInput=input(webhookCard,124,CONFIG.WEBHOOK_USERNAME,"Webhook name")
local applyButton=button(webhookCard,"APPLY",UDim2.fromOffset(13,170),UDim2.new(.48,-17,0,32),T.green)
local testButton=button(webhookCard,"TEST",UDim2.new(.52,4,0,170),UDim2.new(.48,-17,0,32),T.cyan)
local webhookInfo=label(webhookCard,"Relay: "..RELAY_URL,213,9,T.muted,false)

local function applyWebhook()
    CONFIG.WEBHOOK_URL=trim(webhookInput.Text)
    CONFIG.JOIN_LEAVE_URL=trim(joinInput.Text)
    CONFIG.WEBHOOK_USERNAME=trim(usernameInput.Text)
end

applyButton.Activated:Connect(function()
    applyWebhook()
    webhookInfo.Text="Settings applied"
end)

testButton.Activated:Connect(function()
    applyWebhook()

    local d={
        Player=LocalPlayer and LocalPlayer.Name or "TestPlayer",
        Fish="Ruby",
        RawFish="Big Shiny Gemstone Ruby",
        Variant="Gemstone",
        Mutation="Gemstone",
        DisplayModifiers={"Big","Shiny"},
        Weight=5.5,
        Chance="1 in 6K",
        RarityColor={255,100,150},
    }

    local ok=sendWebhook(d)
    webhookInfo.Text=ok and "Test sent" or "Test failed / filtered"
end)

-- MAPPING
local mappingCard=card(webhookPage,250,T.purple)
label(mappingCard,"DISCORD ACCOUNT MAPPING",8,11,T.purple,true)
local discordInput=input(mappingCard,52,"","Discord User ID")
local playerInput=input(mappingCard,88,"","Roblox username")
local addMapButton=button(mappingCard,"ADD MAPPING",UDim2.fromOffset(13,128),UDim2.new(1,-26,0,31),T.purple)

local mappingScroll=Instance.new("ScrollingFrame")
mappingScroll.Position=UDim2.fromOffset(13,170)
mappingScroll.Size=UDim2.new(1,-26,0,66)
mappingScroll.BackgroundColor3=T.panel2
mappingScroll.BorderSizePixel=0
mappingScroll.ScrollBarThickness=3
mappingScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
mappingScroll.CanvasSize=UDim2.new()
mappingScroll.Parent=mappingCard
corner(mappingScroll,7)

local mapLayout=Instance.new("UIListLayout")
mapLayout.Parent=mappingScroll

refreshMappings=function()
    for _,c in ipairs(mappingScroll:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end

    for id,list in pairs(mappings) do
        local b=button(
            mappingScroll,
            "<@"..id.."> -> "..table.concat(list,", "),
            UDim2.new(),
            UDim2.new(1,-4,0,27),
            T.panel2
        )
        b.TextSize=9
        b.Activated:Connect(function()
            mappings[id]=nil
            refreshMappings()
        end)
    end
end

addMapButton.Activated:Connect(function()
    local id=normalizeDiscordId(discordInput.Text)
    local player=trim(playerInput.Text)

    if id~="" and player~="" then
        addMappingEntry(mappings,id,player)
        refreshMappings()
        playerInput.Text=""
    end
end)

-- LOG
local playersCard=card(logPage,180,T.cyan)
label(playersCard,"ACTIVE PLAYERS",8,11,T.cyan,true)
local playersLabel=label(playersCard,"Loading...",44,9,T.text,false)
playersLabel.Size=UDim2.new(1,-26,0,120)
playersLabel.TextYAlignment=Enum.TextYAlignment.Top

local logCard=card(logPage,330,T.pink)
label(logCard,"LIVE ACTIVITY LOG",8,11,T.pink,true)

local logScroll=Instance.new("ScrollingFrame")
logScroll.Position=UDim2.fromOffset(13,44)
logScroll.Size=UDim2.new(1,-26,1,-58)
logScroll.BackgroundColor3=T.panel2
logScroll.BorderSizePixel=0
logScroll.ScrollBarThickness=3
logScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
logScroll.CanvasSize=UDim2.new()
logScroll.Parent=logCard
corner(logScroll,7)

monitorLog=Instance.new("TextLabel")
monitorLog.Position=UDim2.fromOffset(9,9)
monitorLog.Size=UDim2.new(1,-18,0,260)
monitorLog.AutomaticSize=Enum.AutomaticSize.Y
monitorLog.BackgroundTransparency=1
monitorLog.Text="DETECTION LOG\n\nWaiting..."
monitorLog.TextColor3=T.text
monitorLog.TextSize=9
monitorLog.Font=Enum.Font.Code
monitorLog.TextWrapped=true
monitorLog.TextXAlignment=Enum.TextXAlignment.Left
monitorLog.TextYAlignment=Enum.TextYAlignment.Top
monitorLog.Parent=logScroll

refreshPlayers=function()
    local names={}
    for _,p in ipairs(Players:GetPlayers()) do
        table.insert(names,"@"..p.Name)
    end
    table.sort(names)
    playersLabel.Text=table.concat(names,"\n")
end

refreshStats=function()
    statsLabel.Text="Detected "..state.Detected.." • Sent "..state.Sent
    overviewText.Text=
        "Players: "..#Players:GetPlayers()
        .."\nFish Database: "..FishDatabaseTotal
        .."\nWebhooks Sent: "..state.WebhooksSent
end

local function redrawWebhookToggle()
    webhookToggle.Text=CONFIG.WEBHOOK_ENABLED and "WEBHOOK ON" or "WEBHOOK OFF"
    webhookToggle.BackgroundColor3=CONFIG.WEBHOOK_ENABLED and T.green or T.panel2
end

webhookToggle.Activated:Connect(function()
    CONFIG.WEBHOOK_ENABLED=not CONFIG.WEBHOOK_ENABLED
    redrawWebhookToggle()
end)
redrawWebhookToggle()

syncInputs=function()
    webhookInput.Text=CONFIG.WEBHOOK_URL
    joinInput.Text=CONFIG.JOIN_LEAVE_URL
    usernameInput.Text=CONFIG.WEBHOOK_USERNAME
    weightInput.Text=tostring(CONFIG.MIN_WEIGHT)
    redrawRuby()
    redrawWebhookToggle()

    for name,b in pairs(rarityButtons) do
        local on=CONFIG.ALLOW_RARITY[name]
        b.Text=name.."  "..(on and "ON" or "OFF")
        b.BackgroundColor3=on and T.green or T.panel2
    end
end

-- Drag
local dragging=false
local dragStart
local startPos

header.InputBegan:Connect(function(inputObject)
    if inputObject.UserInputType==Enum.UserInputType.Touch
        or inputObject.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=true
        dragStart=inputObject.Position
        startPos=main.Position
    end
end)

UIS.InputChanged:Connect(function(inputObject)
    if dragging and (
        inputObject.UserInputType==Enum.UserInputType.Touch
        or inputObject.UserInputType==Enum.UserInputType.MouseMovement
    ) then
        local d=inputObject.Position-dragStart
        main.Position=UDim2.new(
            startPos.X.Scale,startPos.X.Offset+d.X,
            startPos.Y.Scale,startPos.Y.Offset+d.Y
        )
    end
end)

UIS.InputEnded:Connect(function(inputObject)
    if inputObject.UserInputType==Enum.UserInputType.Touch
        or inputObject.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=false
    end
end)

hide.Activated:Connect(function()
    main.Visible=false
    restore.Visible=true
end)

restore.Activated:Connect(function()
    restore.Visible=false
    main.Visible=true
end)

local function formatWeight(v)
    v=tonumber(v) or 0
    if v>=1000000000 then return string.format("%.2fB kg",v/1000000000) end
    if v>=1000000 then return string.format("%.2fM kg",v/1000000) end
    if v>=1000 then return string.format("%.2fK kg",v/1000) end
    return string.format("%.2f kg",v)
end

local function handleMessage(textMessage)
    local d=parseCatch(textMessage)
    if not d then return end

    state.Detected=state.Detected+1

    local modifierText=""
    if type(d.DisplayModifiers)=="table" and #d.DisplayModifiers>0 then
        modifierText=" ["..table.concat(d.DisplayModifiers," ").."]"
    end

    local line=tostring(d.Player).." caught "
        ..tostring(d.Variant and ("["..d.Variant.."] ") or "")
        ..modifierText
        ..tostring(d.Fish)
        .." ("..formatWeight(d.Weight)..")"

    lastText.Text=line
    appendLog("CATCH",line)
    refreshStats()
    sendWebhook(d)
end

local function setupChatHook()
    local ok,connection=pcall(function()
        return TextChatService.MessageReceived:Connect(function(message)
            if message and message.Text and message.Text~="" then
                pcall(handleMessage,message.Text)
            end
        end)
    end)

    appendLog(ok and "OK" or "ERR",
        ok and "TextChatService hook active" or "TextChatService hook failed"
    )

    return ok and connection~=nil
end

setupChatHook()

Players.PlayerAdded:Connect(function(p)
    appendLog("JOIN",p.Name)
    refreshPlayers()
    refreshStats()
    pcall(sendJoinLeaveWebhook,p,"JOINED")
end)

Players.PlayerRemoving:Connect(function(p)
    appendLog("LEAVE",p.Name)
    refreshPlayers()
    refreshStats()
    pcall(sendJoinLeaveWebhook,p,"LEFT")
end)

task.spawn(function()
    while state.Running do
        pcall(refreshPlayers)
        pcall(refreshStats)
        task.wait(2)
    end
end)

refreshMappings()
refreshPlayers()
refreshStats()
syncInputs()

print("[LFAMILIA MONITOR] Ready - Delta Android standalone")
