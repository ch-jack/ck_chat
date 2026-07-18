-- ck_chat client
-- 作者: JACK
-- 联系方式: QQ 2518926462

local Framework = ChatClientFramework
local Config = CKChatConfig or {}

local chatInputActive = false
local chatInputActivating = false
local chatHidden = true
local chatLoaded = false
local chatVisibilityToggle = false
local pendingMessages = {}
local positionBlip = nil
local frameworkIsAdmin = false
local frameworkAdminCommands = {}

local function nuiMessage(payload, force)
    if chatLoaded or force then
        SendNUIMessage(payload)
    end
    if not chatLoaded then
        pendingMessages[#pendingMessages + 1] = payload
    end
end

local function flushPendingMessages()
    for _, payload in ipairs(pendingMessages) do
        SendNUIMessage(payload)
    end
    pendingMessages = {}
end

local function requestServerCatalog(source, category)
    source = source == 'vehicle' and 'vehicle' or 'item'
    Framework.send('ck_chat:requestCatalog', {
        source = source,
        category = category or '',
    })
end

local function systemLocal(title, text, level)
    nuiMessage({
        type = 'ck_chat:message',
        message = {
            id = ('local:%s:%s'):format(GetGameTimer(), math.random(1000, 9999)),
            channel = { id = 'system', label = '系统', system = true },
            sender = { id = 0, name = '系统', system = true },
            body = { type = 'system', title = title or '系统提示', text = text or '', level = level or 'info' },
        }
    })
end

local function oxInventoryStarted()
    local state = GetResourceState('ox_inventory')
    return state == 'started' or state == 'starting'
end

local function useFrameItem(kind, data, slot)
    if not oxInventoryStarted() then
        Framework.notify('~r~ox_inventory 未启动')
        return
    end

    local useSlot = slot or (type(data) == 'table' and data.slot)
    if not useSlot then
        Framework.notify('~r~道具槽位无效')
        return
    end

    exports.ox_inventory:useItem(data, function(used)
        if not used then
            return
        end

        TriggerServerEvent('ck_chat:useFrameItem', kind, useSlot)
    end)
end

exports('useAvatarFrameItem', function(data, slot)
    useFrameItem('avatar', data, slot)
end)

exports('useChatBoxFrameItem', function(data, slot)
    useFrameItem('chatbox', data, slot)
end)

local function legacyMessage(author, color, text)
    if chatVisibilityToggle then
        return
    end

    nuiMessage({
        type = 'ck_chat:message',
        message = {
            id = ('legacy:%s:%s'):format(GetGameTimer(), math.random(1000, 9999)),
            channel = { id = 'legacy', label = '兼容' },
            sender = { id = 0, name = author or '', system = author == nil or author == '' },
            body = { type = 'text', text = text or '' },
            color = color or { 255, 255, 255 },
            legacy = true,
        }
    })
end

local function normaliseCommandName(name)
    local value = tostring(name or ''):lower():gsub('^/', '')
    return value
end

local function applyFrameworkPermissions(data)
    data = data or {}
    frameworkIsAdmin = data.me and data.me.isAdmin == true or false
    frameworkAdminCommands = {}

    local permissions = data.permissions or {}
    for _, name in ipairs(permissions.adminCommands or {}) do
        local key = normaliseCommandName(name)
        if key ~= '' then
            frameworkAdminCommands[key] = true
        end
    end
end

local function canShowCommand(commandName)
    local key = normaliseCommandName(commandName)
    if key == '' then
        return false
    end
    if frameworkIsAdmin then
        return true
    end
    if frameworkAdminCommands[key] then
        return false
    end
    return IsAceAllowed(('command.%s'):format(key))
end

local function canShowSuggestion(suggestion)
    if type(suggestion) ~= 'table' or not suggestion.name then
        return false
    end
    if suggestion.adminOnly and not frameworkIsAdmin then
        return false
    end
    return canShowCommand(suggestion.name)
end

RegisterNetEvent('ck_chat:message')
AddEventHandler('ck_chat:message', function(message)
    if not chatVisibilityToggle then
        nuiMessage({ type = 'ck_chat:message', message = message })
    end
end)

RegisterNetEvent('ck_chat:messages')
AddEventHandler('ck_chat:messages', function(messages)
    nuiMessage({ type = 'ck_chat:messages', messages = messages or {} })
end)

RegisterNetEvent('ck_chat:bootstrap')
AddEventHandler('ck_chat:bootstrap', function(data)
    data = data or {}
    data.ui = Config.UI or {}
    applyFrameworkPermissions(data)
    nuiMessage({ type = 'ck_chat:bootstrap', data = data })
end)

RegisterNetEvent('ck_chat:catalog')
AddEventHandler('ck_chat:catalog', function(data)
    nuiMessage({ type = 'ck_chat:catalog', data = data or {} })
end)

RegisterNetEvent('ck_chat:channelJoinResult')
AddEventHandler('ck_chat:channelJoinResult', function(data)
    nuiMessage({ type = 'ck_chat:channelJoinResult', data = data or {} })
end)

RegisterNetEvent('ck_chat:setWaypoint')
AddEventHandler('ck_chat:setWaypoint', function(position)
    if type(position) ~= 'table' then
        return
    end
    local x = tonumber(position.x)
    local y = tonumber(position.y)
    local z = tonumber(position.z) or 0.0
    if not x or not y then
        return
    end

    if positionBlip then
        RemoveBlip(positionBlip)
        positionBlip = nil
    end

    SetNewWaypoint(x, y)
    positionBlip = AddBlipForCoord(x, y, z)
    SetBlipSprite(positionBlip, 280)
    SetBlipColour(positionBlip, 3)
    SetBlipScale(positionBlip, 0.9)
    SetBlipRoute(positionBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(position.label or '聊天位置')
    EndTextCommandSetBlipName(positionBlip)
    Framework.notify('~g~已在地图标记聊天位置')
end)

RegisterNetEvent('chatMessage')
AddEventHandler('chatMessage', function(author, color, text)
    legacyMessage(author, color, text)
end)

RegisterNetEvent('chatMessages')
AddEventHandler('chatMessages', function(author, color, text)
    legacyMessage(author, color, text)
end)

RegisterNetEvent('chat:addMessage')
AddEventHandler('chat:addMessage', function(message)
    if type(message) == 'table' then
        local args = message.args or {}
        local author = args[1] or message.author or ''
        local text = args[2] or args[1] or message.text or ''
        if #args == 1 then
            author = ''
        end
        legacyMessage(author, message.color, text)
    else
        legacyMessage('', { 255, 255, 255 }, tostring(message))
    end
end)

RegisterNetEvent('chat:addSuggestion')
AddEventHandler('chat:addSuggestion', function(name, help, params)
    local suggestion = { name = name, help = help, params = params or {} }
    if not canShowSuggestion(suggestion) then
        nuiMessage({ type = 'ck_chat:suggestion:remove', name = name })
        return
    end
    nuiMessage({
        type = 'ck_chat:suggestion:add',
        suggestion = suggestion
    })
end)

RegisterNetEvent('chat:addSuggestions')
AddEventHandler('chat:addSuggestions', function(suggestions)
    local allowed = {}
    for _, suggestion in ipairs(suggestions or {}) do
        if canShowSuggestion(suggestion) then
            allowed[#allowed + 1] = suggestion
        elseif type(suggestion) == 'table' and suggestion.name then
            nuiMessage({ type = 'ck_chat:suggestion:remove', name = suggestion.name })
        end
    end
    nuiMessage({ type = 'ck_chat:suggestion:addMany', suggestions = allowed })
end)

RegisterNetEvent('chat:removeSuggestion')
AddEventHandler('chat:removeSuggestion', function(name)
    nuiMessage({ type = 'ck_chat:suggestion:remove', name = name })
end)

RegisterNetEvent('chat:clear')
AddEventHandler('chat:clear', function()
    nuiMessage({ type = 'ck_chat:clear' })
end)

local function toggleChatVisibility()
    chatVisibilityToggle = not chatVisibilityToggle
    nuiMessage({ type = 'ck_chat:visibility', hidden = chatVisibilityToggle })
    systemLocal('聊天窗口显示状态', chatVisibilityToggle and '关闭' or '开启', chatVisibilityToggle and 'warning' or 'success')
end

RegisterNetEvent('chat:toggleChat')
AddEventHandler('chat:toggleChat', toggleChatVisibility)

RegisterNUICallback('loaded', function(_, cb)
    chatLoaded = true
    flushPendingMessages()
    Framework.send('ck_chat:requestBootstrap')
    Framework.send('ck_chat:requestHistory')
    cb('ok')
end)

RegisterNUICallback('sendMessage', function(data, cb)
    data = data or {}
    local text = tostring(data.text or ''):gsub('^%s+', '')
    if text:sub(1, 1) == '/' then
        chatInputActive = false
        SetNuiFocus(false, false)
        ExecuteCommand(text:sub(2))
        cb('ok')
        return
    end
    data = Framework.hydrateOutgoingMessage(data) or data
    Framework.send('ck_chat:sendMessage', data or {})
    cb('ok')
end)

RegisterNUICallback('requestCatalog', function(data, cb)
    data = data or {}
    requestServerCatalog(data.source or data.type or 'item', data.category or '')
    cb('ok')
end)

RegisterNUICallback('action', function(data, cb)
    data = data or {}
    if data.action == 'claimRedPacket' and data.id then
        Framework.send('ck_chat:claimRedPacket', data.id)
    elseif data.action == 'gotoPosition' and data.id then
        Framework.send('ck_chat:requestGoPosition', data.id)
    elseif data.action == 'joinChannel' then
        Framework.send('ck_chat:joinChannel', data)
    elseif data.action == 'sharePosition' then
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        Framework.send('ck_chat:sharePosition', {
            channel = data.channel or 'global',
            customChannel = data.customChannel,
            customChannelId = data.customChannelId,
            target = data.target,
            x = coords.x,
            y = coords.y,
            z = coords.z,
            h = GetEntityHeading(ped),
            label = data.label or ''
        })
    end
    cb('ok')
end)

RegisterNUICallback('close', function(_, cb)
    chatInputActive = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterCommand('clear', function()
    nuiMessage({ type = 'ck_chat:clear' })
end, false)

RegisterCommand('tc', function()
    toggleChatVisibility()
end, false)

RegisterCommand('openNewChat', function()
    if not chatInputActive then
        chatInputActive = true
        chatInputActivating = true
        if not chatLoaded then
            SendNUIMessage({ type = 'ck_chat:ready' })
        end
        Framework.send('ck_chat:requestBootstrap')
        nuiMessage({ type = 'ck_chat:open' }, true)
    end
    if chatInputActivating then
        SetNuiFocus(true, true)
        chatInputActivating = false
    end
end, false)

RegisterCommand('sendpos', function(_, args)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    Framework.send('ck_chat:sharePosition', {
        channel = 'global',
        x = coords.x,
        y = coords.y,
        z = coords.z,
        h = GetEntityHeading(ped),
        label = table.concat(args or {}, ' ')
    })
end, false)

RegisterKeyMapping('openNewChat', '打开聊天', 'keyboard', 'T')

AddEventHandler('onClientResourceStart', function(resource)
    Wait(500)

    if resource == GetCurrentResourceName() then
        systemLocal('聊天系统', '新聊天已加载', 'success')
    end
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        return
    end

    Wait(500)
end)

CreateThread(function()
    SetTextChatEnabled(false)
    SetNuiFocus(false, false)

    while true do
        Wait(600)
        if chatLoaded then
            local shouldBeHidden = IsScreenFadedOut() or IsPauseMenuActive()
            if (shouldBeHidden and not chatHidden) or (not shouldBeHidden and chatHidden) then
                chatHidden = shouldBeHidden
                nuiMessage({ type = 'ck_chat:screen', hidden = shouldBeHidden })
            end
        else
            Wait(500)
        end
    end
end)
