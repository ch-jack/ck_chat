-- ck_chat server
-- 作者: JACK
-- 联系方式: QQ 2518926462

math.randomseed(os.time())

local Framework = ChatFramework
local Config = CKChatConfig or {}

local MAX_HISTORY = 100
local MAX_TEXT_LENGTH = 600
local MAX_REDPACKET_AMOUNT = 50000

local function configuredCost(value, fallback)
    local cost = tonumber(value)
    if not cost then
        return fallback
    end
    if cost < 0 then
        return 0
    end
    return math.floor(cost)
end

local JOIN_CHANNEL_COST = configuredCost(Config.CustomChannelJoinCost, 10000)

local messageSeq = 0
local positionSeq = 0
local redPacketSeq = 0
local messageHistory = {}
local sharedPositions = {}
local redPackets = {}
local mutedUntil = {}
local globalMuted = false

local badWords = { '日', '操', '妈', '逼', '狗', '草', '滚', '垃圾', '脑残' }

local PresetChannels = Config.PresetChannels or {}

local AllowedBridgeEvents = {
    ['ck_chat:sendMessage'] = true,
    ['ck_chat:sharePosition'] = true,
    ['ck_chat:requestGoPosition'] = true,
    ['ck_chat:claimRedPacket'] = true,
    ['ck_chat:joinChannel'] = true,
    ['ck_chat:requestHistory'] = true,
    ['ck_chat:requestBootstrap'] = true,
    ['ck_chat:requestCatalog'] = true,
}

local GMCommandSuggestions = {
    {
        name = '/gm',
        help = '发送全频道 GM 公告，所有频道都会看到系统样式提示',
        params = {
            { name = '内容', help = '公告文本' },
        },
        adminOnly = true,
    },
    {
        name = '/ckchat_system',
        help = '发送全频道系统公告，效果同 /gm',
        params = {
            { name = '内容', help = '公告文本' },
        },
        adminOnly = true,
    },
    {
        name = '/ckchat_mute',
        help = '禁言指定玩家，禁言状态只保存在 ck_chat 服务端内存',
        params = {
            { name = '玩家ID', help = '目标玩家服务器 ID' },
            { name = '分钟', help = '禁言时长，默认 10 分钟' },
        },
        adminOnly = true,
    },
    {
        name = '/ckchat_unmute',
        help = '解除指定玩家禁言',
        params = {
            { name = '玩家ID', help = '目标玩家服务器 ID' },
        },
        adminOnly = true,
    },
    {
        name = '/ckchat_muteall',
        help = '切换全体禁言开关，GM 仍可发言',
        params = {},
        adminOnly = true,
    },
    {
        name = '/ckchat_frame',
        help = '直接设置玩家聊天头像框',
        params = {
            { name = '玩家ID', help = '目标玩家服务器 ID' },
            { name = '头像框ID', help = '0 为取消头像框' },
        },
        adminOnly = true,
    },
    {
        name = '/ckchat_boxframe',
        help = '直接设置玩家聊天框',
        params = {
            { name = '玩家ID', help = '目标玩家服务器 ID' },
            { name = '聊天框ID', help = '0 为取消聊天框' },
        },
        adminOnly = true,
    },
}

local function nextId(prefix)
    messageSeq = messageSeq + 1
    return ('%s:%s:%s'):format(prefix, os.time(), messageSeq)
end

local function clampText(value, maxLength)
    value = tostring(value or '')
    maxLength = maxLength or MAX_TEXT_LENGTH
    if #value > maxLength then
        return value:sub(1, maxLength)
    end
    return value
end

local function onlyDigits(value)
    return tostring(value or ''):gsub('%D', '')
end

local function cleanKey(value)
    return tostring(value or ''):lower()
end

local function publicPresetChannels()
    local channels = {}
    for _, item in ipairs(PresetChannels or {}) do
        local id = clampText(item.id or item.name or '', 40)
        local label = clampText(item.label or id, 20)
        if id ~= '' and label ~= '' then
            channels[#channels + 1] = {
                id = id,
                label = label,
                requireJob = item.requireJob ~= false,
            }
        end
    end
    return channels
end

local function findPresetChannel(idOrLabel)
    local key = cleanKey(idOrLabel)
    if key == '' then
        return nil
    end
    for _, item in ipairs(PresetChannels or {}) do
        if cleanKey(item.id or item.name) == key or cleanKey(item.label) == key then
            return item
        end
    end
    return nil
end

local function channelFromJoinPayload(data)
    data = data or {}
    local requestedId = clampText(data.customChannelId or '', 40)
    if requestedId ~= '' then
        local preset = findPresetChannel(requestedId)
        if preset then
            return {
                preset = preset,
                id = clampText(preset.id or preset.name or '', 40),
                label = clampText(preset.label or preset.id or preset.name or '', 20),
            }
        end
        return {
            id = requestedId,
            label = clampText(data.customChannel or requestedId, 20),
            invalidPreset = true,
        }
    end

    local label = clampText(data.customChannel or '自定义', 20)
    if label == '' then
        label = '自定义'
    end
    return {
        id = '',
        label = label,
    }
end

local function playerName(player)
    if not player then
        return '系统'
    end
    local roleName = Framework.get(player, 'rolename', '')
    if roleName ~= '' then
        return roleName
    end
    local name = Framework.get(player, 'name', '')
    if name ~= '' then
        return name
    end
    return GetPlayerName(Framework.getSource(player)) or '玩家'
end

local function playerProfile(player, options)
    options = options or {}
    if not player then
        return {
            id = 0,
            name = '系统',
            avatar = '',
            system = true,
        }
    end

    local qq = onlyDigits(Framework.get(player, 'qq', ''))
    local avatar = ''
    if qq ~= '' then
        avatar = ('https://q1.qlogo.cn/g?b=qq&nk=%s&s=100'):format(qq)
    end

    local source = Framework.getSource(player)
    local chatFrameId = tostring(Framework.get(player, 'chatFrameId', '') or '')
    local chatBoxFrameId = tostring(Framework.get(player, 'chatBoxFrameId', '') or '')

    local profile = {
        id = source,
        name = playerName(player),
        avatar = avatar,
        qq = qq,
        chatFrameId = chatFrameId,
        chatBoxFrameId = chatBoxFrameId,
        level = tonumber(Framework.get(player, 'lv', 0)) or 0,
        gang = tostring(Framework.get(player, 'gangname', Framework.get(player, 'gang', '')) or ''),
    }
    if options.includeAdmin then
        profile.isAdmin = Framework.isAdmin(player)
    end
    return profile
end

local function onlinePlayers()
    local players = {}
    for _, item in pairs(Framework.getPlayers()) do
        local profile = playerProfile(item)
        if profile.id and profile.id > 0 then
            players[#players + 1] = profile
        end
    end
    table.sort(players, function(a, b) return (a.id or 0) < (b.id or 0) end)
    return players
end

local function publicCommandSuggestions(player)
    local suggestions = {}
    local isAdmin = Framework.isAdmin(player)
    for _, item in ipairs(GMCommandSuggestions) do
        if not item.adminOnly or isAdmin then
            suggestions[#suggestions + 1] = item
        end
    end
    return suggestions
end

local function adminCommandNames()
    local commands = {}
    for _, item in ipairs(GMCommandSuggestions) do
        if item.adminOnly and item.name then
            commands[#commands + 1] = tostring(item.name):gsub('^/', '')
        end
    end
    return commands
end

local function sendCommandSuggestions(player)
    if Framework.isAdmin(player) then
        Framework.sendClient(player, 'chat:addSuggestions', publicCommandSuggestions(player))
        return
    end

    for _, item in ipairs(GMCommandSuggestions) do
        Framework.sendClient(player, 'chat:removeSuggestion', item.name)
    end
end

local function sendBootstrap(player)
    Framework.sendClient(player, 'ck_chat:bootstrap', {
        framework = Framework.name or 'unknown',
        me = playerProfile(player, { includeAdmin = true }),
        onlinePlayers = onlinePlayers(),
        permissions = {
            isAdmin = Framework.isAdmin(player),
            adminCommands = adminCommandNames(),
        },
        channels = {
            presets = publicPresetChannels(),
        },
    })
    sendCommandSuggestions(player)
end

local function addHistory(message)
    messageHistory[#messageHistory + 1] = message
    if #messageHistory > MAX_HISTORY then
        table.remove(messageHistory, 1)
    end
end

local function emitMessage(target, message)
    TriggerClientEvent('ck_chat:message', target, message)
end

local function dispatchMessage(message, route)
    route = route or { targets = -1, history = true }
    local targets = route.targets or -1
    if type(targets) == 'table' then
        for _, target in ipairs(targets) do
            emitMessage(target, message)
        end
    else
        emitMessage(targets, message)
    end

    if route.history ~= false then
        addHistory(message)
    end
end

local function makeMessage(player, channel, body, meta)
    return {
        id = nextId('msg'),
        ts = os.time(),
        channel = channel or { id = 'global', label = '全服' },
        sender = playerProfile(player),
        body = body or { type = 'text', text = '' },
        meta = meta or {},
    }
end

local function logMessage(player, message)
    local body = message.body or {}
    local logBody = {
        id = message.id,
        ts = message.ts,
        channel = message.channel,
        sender = message.sender,
        type = body.type,
        text = body.text,
        image = body.image,
        link = body.link,
        position = body.position,
        redPacket = body.redPacket,
    }

    Framework.log('chat', 'send', player, false, logBody)
end

local function sendSystemMessage(text, title, level, meta)
    local message = makeMessage(nil, { id = 'system', label = '系统', system = true }, {
        type = 'system',
        title = clampText(title or '系统提示', 40),
        text = clampText(text or ''),
        level = level or 'info',
    }, meta or {})
    dispatchMessage(message, { targets = -1, history = true })
    Framework.log('chat', 'system', 0, false, message.body.title, message.body.text, message.body.level)
    return message
end

local function getPlayerCoords(source)
    local ped = GetPlayerPed(source)
    if ped == 0 then
        return nil
    end
    return GetEntityCoords(ped)
end

local function channelFromPayload(data)
    local channel = tostring(data.channel or 'global')
    if channel == 'private' then
        return { id = 'private', label = '私聊' }
    end
    if channel == 'custom' then
        local custom = channelFromJoinPayload(data)
        return { id = 'custom:' .. custom.label, label = custom.label, presetId = custom.id ~= '' and custom.id or nil }
    end
    return { id = 'global', label = '全服' }
end

local function routeFromPayload(player, data)
    local channel = tostring(data.channel or 'global')
    local source = Framework.getSource(player)
    if channel == 'private' then
        local target = tonumber(data.target)
        if not target or target == source or not Framework.getPlayerFromSource(target) then
            Framework.notify(player, '~r~私聊目标不存在')
            return nil
        end
        return { targets = { source, target }, history = false }
    end
    if channel == 'custom' then
        local custom = channelFromJoinPayload(data)
        if custom.invalidPreset then
            Framework.notify(player, '~r~频道配置不存在')
            return nil
        end
        local ok, reason = Framework.canJoinPresetChannel(player, custom.preset)
        if not ok then
            Framework.notify(player, '~r~' .. reason)
            return nil
        end
    end
    return { targets = -1, history = true }
end

local function joinChannel(player, data)
    data = data or {}
    local custom = channelFromJoinPayload(data)
    if custom.invalidPreset then
        Framework.sendClient(player, 'ck_chat:channelJoinResult', {
            ok = false,
            message = '频道配置不存在',
        })
        return
    end
    if not custom.preset and clampText(data.customChannel or '', 20) == '' then
        Framework.sendClient(player, 'ck_chat:channelJoinResult', {
            ok = false,
            message = '请输入自定义频道名',
        })
        return
    end

    local ok, reason = Framework.canJoinPresetChannel(player, custom.preset)
    if not ok then
        Framework.sendClient(player, 'ck_chat:channelJoinResult', {
            ok = false,
            message = reason,
        })
        return
    end

    if not custom.preset and JOIN_CHANNEL_COST > 0 then
        if not Framework.removeMoney(player, JOIN_CHANNEL_COST, 'ck_chat:join_channel') then
            Framework.sendClient(player, 'ck_chat:channelJoinResult', {
                ok = false,
                message = ('金币不足，加入自定义频道需要%s金币'):format(JOIN_CHANNEL_COST),
            })
            return
        end
        Framework.updateInventory(player)
    end

    Framework.sendClient(player, 'ck_chat:channelJoinResult', {
        ok = true,
        id = custom.id,
        label = custom.label,
        preset = custom.preset ~= nil,
    })
    Framework.log('chat', 'join_channel', player, false, custom.id, custom.label, custom.preset ~= nil)
end

local function isMuted(player)
    if not player then
        return false
    end
    if Framework.isAdmin(player) then
        return false
    end
    if globalMuted then
        return true, '全体禁言中'
    end

    local key = Framework.getIdentifier(player)
    local untilTime = mutedUntil[key]
    if untilTime and untilTime > os.time() then
        return true, ('你已被禁言，剩余 %s 秒'):format(untilTime - os.time())
    end
    mutedUntil[key] = nil
    return false
end

local function blockedByFilter(text)
    local filtered = tostring(text or '')
    local blocked = false
    for _, word in ipairs(badWords) do
        if filtered:find(word, 1, true) then
            filtered = filtered:gsub(word, ' * ')
            blocked = true
        end
    end
    return blocked, filtered
end

local function sendTextMessage(player, data)
    local muted, reason = isMuted(player)
    if muted then
        Framework.notify(player, '~r~' .. reason)
        return
    end

    local route = routeFromPayload(player, data)
    if not route then
        return
    end

    local text = clampText(data.text or '')
    local blocked, filtered = blockedByFilter(text)
    if blocked then
        sendSystemMessage(('玩家:%s 涉嫌使用语言攻击，内容为( %s )'):format(playerName(player), filtered), '反语言攻击系统', 'danger')
        Framework.log('chat', 'blocked', player, false, text, filtered)
        return
    end

    local body = {
        type = 'text',
        text = text,
    }
    if body.text == '' then
        return
    end

    local message = makeMessage(player, channelFromPayload(data), body)
    dispatchMessage(message, route)
    logMessage(player, message)

    TriggerEvent('uniteSound', 'chatmsg', body.text, 1, Framework.getSource(player))
    TriggerEvent('sendqqmsg', 1, 2, playerName(player) .. ': ' .. body.text, 1025342816)
end

local function imageFromPayload(data)
    data = data or {}
    local image = type(data.image) == 'table' and data.image or {}
    local url = clampText(data.imageUrl or image.url or '', 500)
    if url == '' or (not url:match('^http://') and not url:match('^https://')) then
        return nil
    end
    return {
        url = url,
        name = clampText(data.imageName or image.name or '收藏图片', 40),
    }
end

local function sendImageMessage(player, data)
    local muted, reason = isMuted(player)
    if muted then
        Framework.notify(player, '~r~' .. reason)
        return
    end

    local route = routeFromPayload(player, data)
    if not route then
        return
    end

    local image = imageFromPayload(data)
    if not image then
        Framework.notify(player, '~r~图片地址无效')
        return
    end

    local text = clampText(data.text or '')
    local blocked, filtered = blockedByFilter(text)
    if blocked then
        sendSystemMessage(('玩家:%s 涉嫌使用语言攻击，内容为( %s )'):format(playerName(player), filtered), '反语言攻击系统', 'danger')
        Framework.log('chat', 'blocked', player, false, text, filtered)
        return
    end

    local message = makeMessage(player, channelFromPayload(data), {
        type = 'image',
        text = text,
        image = image,
    })
    dispatchMessage(message, route)
    logMessage(player, message)

    TriggerEvent('uniteSound', 'chatmsg', text ~= '' and text or '[图片]', 1, Framework.getSource(player))
    TriggerEvent('sendqqmsg', 1, 2, playerName(player) .. ': [图片] ' .. image.url, 1025342816)
end

local function tableHasValues(value)
    return type(value) == 'table' and next(value) ~= nil
end

local function clientLinkFromPayload(data, linkType, payload)
    local details = tableHasValues(data.details) and data.details or nil
    if not details and tableHasValues(payload.details) then
        details = payload.details
    end

    local meta = tableHasValues(data.meta) and data.meta or nil
    if not meta and tableHasValues(payload.meta) then
        meta = payload.meta
    end

    if not details and not meta then
        return nil
    end

    payload.meta = meta or payload.meta or {}
    payload.details = details or payload.details or {}

    return {
        linkType = clampText(linkType, 24),
        title = clampText(data.title or payload.label or payload.name or payload.model or 'Content Link', 80),
        subtitle = clampText(data.subtitle or payload.text or payload.typeLabel or payload.type or '', 120),
        image = clampText(data.image or payload.image or (meta and meta.image) or '', 500),
        bgImage = clampText(data.bgImage or payload.bgImage or (meta and meta.bgImage) or '', 500),
        payload = payload,
        details = details or {},
        meta = meta or {},
    }
end

local function linkFromPayload(player, data)
    data = data or {}
    local linkType = tostring(data.linkType or 'custom')
    local payload = type(data.payload) == 'table' and data.payload or {}
    local clientLink = clientLinkFromPayload(data, linkType, payload)
    if clientLink then
        return clientLink
    end

    if linkType == 'item' then
        local itemName = payload.name or data.name or data.itemName or data.value
        local link = type(Framework.getItemLinkPayload) == 'function' and Framework.getItemLinkPayload(player, itemName, payload) or nil
        if not link then
            Framework.notify(player, '~r~道具不存在')
            return nil
        end
        return link
    end

    if linkType == 'vehicle' then
        local model = payload.model or data.model or data.vehicle or data.value
        local link = type(Framework.getVehicleLinkPayload) == 'function' and Framework.getVehicleLinkPayload(player, model, payload) or nil
        if not link then
            Framework.notify(player, '~r~载具不存在')
            return nil
        end
        return link
    end

    return {
        linkType = clampText(linkType, 24),
        title = clampText(data.title or '内容链接', 80),
        subtitle = clampText(data.subtitle or '', 120),
        image = clampText(data.image or payload.image or '', 500),
        bgImage = clampText(data.bgImage or payload.bgImage or '', 500),
        payload = payload,
        details = type(data.details) == 'table' and data.details or {},
        meta = type(data.meta) == 'table' and data.meta or {},
    }
end

local function sendRichLink(player, data)
    local muted, reason = isMuted(player)
    if muted then
        Framework.notify(player, '~r~' .. reason)
        return
    end

    local route = routeFromPayload(player, data)
    if not route then
        return
    end

    local link = linkFromPayload(player, data)
    if not link then
        return
    end

    local message = makeMessage(player, channelFromPayload(data), {
        type = 'link',
        text = clampText(data.text or ''),
        link = {
            linkType = clampText(link.linkType or 'custom', 24),
            title = clampText(link.title or '内容链接', 80),
            subtitle = clampText(link.subtitle or '', 120),
            image = clampText(link.image or (link.payload and link.payload.image) or (link.meta and link.meta.image) or '', 500),
            bgImage = clampText(link.bgImage or (link.payload and link.payload.bgImage) or (link.meta and link.meta.bgImage) or '', 500),
            payload = link.payload or {},
            details = link.details or {},
            meta = link.meta or {},
        }
    })
    dispatchMessage(message, route)
    logMessage(player, message)
end

local function sendPositionMessage(player, pos, label, data)
    local muted, reason = isMuted(player)
    if muted then
        Framework.notify(player, '~r~' .. reason)
        return
    end

    positionSeq = positionSeq + 1
    local positionId = ('pos:%s:%s'):format(os.time(), positionSeq)
    local position = {
        id = positionId,
        x = Framework.keepDecimal(tonumber(pos.x) or 0.0, 2),
        y = Framework.keepDecimal(tonumber(pos.y) or 0.0, 2),
        z = Framework.keepDecimal(tonumber(pos.z) or 0.0, 2),
        h = Framework.keepDecimal(tonumber(pos.h or pos.heading) or 0.0, 2),
        label = clampText(label or '当前位置', 40),
    }

    sharedPositions[positionId] = {
        position = position,
        owner = Framework.getSource(player),
        expireAt = os.time() + 30 * 60,
    }

    data = data or {}
    local message = makeMessage(player, channelFromPayload(data), {
        type = 'position',
        text = position.label,
        position = position,
    })

    dispatchMessage(message, routeFromPayload(player, data) or { targets = -1, history = true })
    logMessage(player, message)
end

local function createRedPacket(player, data)
    local muted, reason = isMuted(player)
    if muted then
        Framework.notify(player, '~r~' .. reason)
        return
    end

    if tostring(data.channel or 'global') == 'private' then
        Framework.notify(player, '~r~私聊不能发送红包')
        return
    end

    local route = routeFromPayload(player, data)
    if not route then
        return
    end

    local amount = math.floor(tonumber(data.amount) or 0)
    local count = math.floor(tonumber(data.count) or 0)
    if amount <= 0 or amount > MAX_REDPACKET_AMOUNT or count <= 0 or count > 50 or amount < count then
        Framework.notify(player, '~r~红包金额或份数错误')
        return
    end

    if not Framework.removeMoney(player, amount, 'ck_chat:redpacket') then
        return
    end
    Framework.updateInventory(player)

    redPacketSeq = redPacketSeq + 1
    local redPacketId = ('hb:%s:%s'):format(os.time(), redPacketSeq)
    redPackets[redPacketId] = {
        id = redPacketId,
        owner = Framework.getSource(player),
        ownerIdentifier = Framework.getIdentifier(player),
        amount = amount,
        remainAmount = amount,
        count = count,
        remainCount = count,
        claims = {},
        expireAt = os.time() + 15 * 60,
    }

    local message = makeMessage(player, channelFromPayload(data), {
        type = 'redpacket',
        text = clampText(data.text or '恭喜发财'),
        redPacket = {
            id = redPacketId,
            amount = amount,
            count = count,
            remainCount = count,
        }
    })

    dispatchMessage(message, route)
    logMessage(player, message)
end

local function claimRedPacket(player, id)
    local packet = redPackets[id]
    if not packet then
        Framework.notify(player, '~r~红包不存在')
        return
    end
    if packet.expireAt < os.time() then
        Framework.notify(player, '~r~红包已过期')
        return
    end

    local identifier = Framework.getIdentifier(player)
    if packet.claims[identifier] then
        Framework.notify(player, '~o~你已经抢过这个红包')
        return
    end
    if packet.remainCount <= 0 or packet.remainAmount <= 0 then
        Framework.notify(player, '~o~红包已抢完')
        return
    end

    local money
    if packet.remainCount == 1 then
        money = packet.remainAmount
    else
        local average = math.max(1, math.floor(packet.remainAmount / packet.remainCount))
        money = math.random(1, math.max(1, average * 2))
        local maxAllowed = packet.remainAmount - (packet.remainCount - 1)
        if money > maxAllowed then
            money = maxAllowed
        end
    end

    packet.remainAmount = packet.remainAmount - money
    packet.remainCount = packet.remainCount - 1
    packet.claims[identifier] = money

    Framework.addMoney(player, money, 'ck_chat:redpacket_claim')
    Framework.notify(player, ('~g~抢到红包 $%s'):format(money))
    Framework.log('chat', 'redpacket_claim', player, false, id, money, packet.remainAmount, packet.remainCount)

    local ownerName = GetPlayerName(packet.owner) or '玩家'
    sendSystemMessage(('%s 抢到了 %s 的红包：$%s'):format(playerName(player), ownerName, money), '红包', 'success', {
        redPacketId = id,
    })
end

local ServerHandlers = {}

ServerHandlers['ck_chat:sendMessage'] = function(player, data)
    if type(data) ~= 'table' then
        return
    end

    if data.mode == 'redpacket' then
        createRedPacket(player, data)
        return
    end
    if data.mode == 'link' then
        sendRichLink(player, data)
        return
    end
    if data.mode == 'image' then
        sendImageMessage(player, data)
        return
    end

    local text = tostring(data.text or '')
    if text:gsub('^%s+', ''):sub(1, 1) == '/' then
        return
    end
    sendTextMessage(player, data)
end

ServerHandlers['ck_chat:sharePosition'] = function(player, data)
    if type(data) ~= 'table' then
        return
    end
    sendPositionMessage(player, data, data.label, data)
end

ServerHandlers['ck_chat:requestGoPosition'] = function(player, id)
    local item = sharedPositions[id]
    if not item or item.expireAt < os.time() then
        Framework.notify(player, '~r~位置已失效')
        return
    end
    Framework.sendClient(player, 'ck_chat:setWaypoint', item.position)
    Framework.log('chat', 'goto_position_marker', player, false, id, item.position)
end

ServerHandlers['ck_chat:claimRedPacket'] = function(player, id)
    claimRedPacket(player, id)
end

ServerHandlers['ck_chat:joinChannel'] = function(player, data)
    if type(data) ~= 'table' then
        data = {}
    end
    joinChannel(player, data)
end

ServerHandlers['ck_chat:requestHistory'] = function(player)
    Framework.sendClient(player, 'ck_chat:messages', messageHistory)
end

ServerHandlers['ck_chat:requestBootstrap'] = function(player)
    sendBootstrap(player)
end

ServerHandlers['ck_chat:requestCatalog'] = function(player, data)
    data = type(data) == 'table' and data or {}
    local sourceType = data.source == 'vehicle' and 'vehicle' or 'item'
    local category = clampText(data.category or '', 60)
    local catalog = sourceType == 'vehicle' and Framework.getVehicleCatalog(player, category) or Framework.getItemCatalog(player, category)

    Framework.sendClient(player, 'ck_chat:catalog', {
        source = sourceType,
        category = category,
        full = true,
        catalog = catalog or { categories = {}, items = {} },
    })
end

for eventName, handler in pairs(ServerHandlers) do
    AddEventHandler(eventName, handler)
end

RegisterNetEvent('ck_chat:bridge')
AddEventHandler('ck_chat:bridge', function(eventName, ...)
    if not AllowedBridgeEvents[eventName] then
        return
    end
    local player = Framework.getPlayerFromSource(source)
    if not player then
        return
    end
    ServerHandlers[eventName](player, ...)
end)

-- GM: 全频道系统公告，NUI 会以独立样式展示，并且不受玩家当前频道筛选影响。
RegisterCommand('ckchat_system', function(source, _, rawCommand)
    if source ~= 0 then
        local player = Framework.getPlayerFromSource(source)
        if not Framework.isAdmin(player) then
            return
        end
    end
    local text = rawCommand:gsub('^ckchat_system%s*', '')
    if text ~= '' then
        sendSystemMessage(text, 'GM公告', 'gm')
    end
end, false)

RegisterCommand('gm', function(source, _, rawCommand)
    if source ~= 0 then
        local player = Framework.getPlayerFromSource(source)
        if not Framework.isAdmin(player) then
            return
        end
    end
    local text = rawCommand:gsub('^gm%s*', '')
    if text ~= '' then
        sendSystemMessage(text, 'GM公告', 'gm')
    end
end, false)

-- GM: 禁言单个玩家，单位分钟。管理员不受禁言影响。
RegisterCommand('ckchat_mute', function(source, args, rawCommand)
    local admin = source == 0 and nil or Framework.getPlayerFromSource(source)
    if source ~= 0 and not Framework.isAdmin(admin) then
        return
    end

    local target = Framework.getPlayerFromSource(tonumber(args[1]))
    local minutes = math.max(1, tonumber(args[2]) or 10)
    if target then
        mutedUntil[Framework.getIdentifier(target)] = os.time() + minutes * 60
        Framework.log('chat', 'mute', admin or source, false, Framework.getSource(target), minutes, rawCommand)
        sendSystemMessage(('%s 已被禁言 %s 分钟'):format(playerName(target), minutes), 'GM禁言', 'warning')
    end
end, false)

-- GM: 解除单个玩家禁言。
RegisterCommand('ckchat_unmute', function(source, args)
    local admin = source == 0 and nil or Framework.getPlayerFromSource(source)
    if source ~= 0 and not Framework.isAdmin(admin) then
        return
    end

    local target = Framework.getPlayerFromSource(tonumber(args[1]))
    if target then
        mutedUntil[Framework.getIdentifier(target)] = nil
        Framework.log('chat', 'unmute', admin or source, false, Framework.getSource(target))
        sendSystemMessage(('%s 已解除禁言'):format(playerName(target)), 'GM禁言', 'success')
    end
end, false)

-- GM: 全体禁言开关。
RegisterCommand('ckchat_muteall', function(source)
    local admin = source == 0 and nil or Framework.getPlayerFromSource(source)
    if source ~= 0 and not Framework.isAdmin(admin) then
        return
    end

    globalMuted = not globalMuted
    Framework.log('chat', 'global_mute', admin or source, false, globalMuted)
    sendSystemMessage(globalMuted and '全体禁言已开启' or '全体禁言已关闭', 'GM禁言', globalMuted and 'warning' or 'success')
end, false)

-- GM: 直接设置玩家聊天头像框，便于发放补偿或测试。
RegisterCommand('ckchat_frame', function(source, args)
    local admin = source == 0 and nil or Framework.getPlayerFromSource(source)
    if source ~= 0 and not Framework.isAdmin(admin) then
        return
    end

    local target = Framework.getPlayerFromSource(tonumber(args[1]))
    local chatFrameId = tostring(args[2] or '')
    if chatFrameId == '0' then
        chatFrameId = ''
    end
    if target then
        Framework.set(target, 'chatFrameId', chatFrameId)
        Framework.changed(target, 'chatFrameId')
        Framework.log('chat', 'gm_set_frame', admin or source, false, Framework.getSource(target), chatFrameId)
        Framework.notify(target, ('~g~聊天头像框已切换：%s'):format(chatFrameId))
    end
end, false)

-- GM: 直接设置玩家聊天框，便于发放补偿或测试。
RegisterCommand('ckchat_boxframe', function(source, args)
    local admin = source == 0 and nil or Framework.getPlayerFromSource(source)
    if source ~= 0 and not Framework.isAdmin(admin) then
        return
    end

    local target = Framework.getPlayerFromSource(tonumber(args[1]))
    local chatBoxFrameId = tostring(args[2] or '')
    if chatBoxFrameId == '0' then
        chatBoxFrameId = ''
    end
    if target then
        Framework.set(target, 'chatBoxFrameId', chatBoxFrameId)
        Framework.changed(target, 'chatBoxFrameId')
        Framework.log('chat', 'gm_set_chat_box_frame', admin or source, false, Framework.getSource(target), chatBoxFrameId)
        Framework.notify(target, ('~g~聊天框已切换：%s'):format(chatBoxFrameId))
    end
end, false)

RegisterCommand('say', function(source, _, rawCommand)
    local text = rawCommand:gsub('^say%s*', '')
    if text ~= '' then
        sendSystemMessage(text, source == 0 and '服主' or (GetPlayerName(source) or '系统'), 'info')
    end
end, false)

exports('SendSystemMessage', function(text, title, level)
    sendSystemMessage(text, title, level)
    return true
end)

exports('SendCustomLink', function(source, payload)
    local player = Framework.getPlayerFromSource(source)
    if not player or type(payload) ~= 'table' then
        return false
    end
    sendRichLink(player, payload)
    return true
end)
