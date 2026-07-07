-- ck_chat client framework bridge
-- 作者: JACK
-- 联系方式: QQ 2518926462

ChatClientFramework = ChatClientFramework or {}

local Framework = ChatClientFramework
Framework.name = 'esx_qb'

function Framework.send(eventName, ...)
    TriggerServerEvent('ck_chat:bridge', eventName, ...)
end

function Framework.notify(message)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(tostring(message or ''))
    EndTextCommandThefeedPostTicker(false, false)
end

function Framework.getItemCatalog()
    return { categories = {}, items = {} }
end

function Framework.getVehicleCatalog()
    return { categories = {}, items = {} }
end

function Framework.hydrateOutgoingMessage(data)
    return data
end
