ChatFramework = ChatFramework or {}

local Framework = ChatFramework
local Config = CKChatConfig or {}

Framework.name = 'auto'

local cachedESX = nil
local cachedQBCore = nil
local runtimeData = {}

local function safeCall(fn, ...)
    local ok, result = pcall(fn, ...)
    if ok then
        return result
    end
    return nil
end

local function resourceStarted(name)
    local state = GetResourceState(name)
    return state == 'started' or state == 'starting'
end

local function normalizedFramework(value)
    value = tostring(value or 'auto'):lower()
    if value == 'qbcore' or value == 'qbus' then
        return 'qb'
    end
    if value == 'es_extended' then
        return 'esx'
    end
    if value ~= 'esx' and value ~= 'qb' then
        return 'auto'
    end
    return value
end

local function getESX()
    if cachedESX then
        return cachedESX
    end
    if not resourceStarted('es_extended') then
        return nil
    end

    cachedESX = safeCall(function()
        return exports['es_extended']:getSharedObject()
    end)

    if not cachedESX then
        TriggerEvent('esx:getSharedObject', function(obj)
            cachedESX = obj
        end)
    end

    return cachedESX
end

local function getQBCore()
    if cachedQBCore then
        return cachedQBCore
    end
    if not resourceStarted('qb-core') then
        return nil
    end

    cachedQBCore = safeCall(function()
        return exports['qb-core']:GetCoreObject()
    end)

    return cachedQBCore
end

local function activeFramework()
    local requested = normalizedFramework(Config.Framework)

    if requested == 'qb' then
        Framework.name = getQBCore() and 'qb' or 'qb'
        return Framework.name
    end
    if requested == 'esx' then
        Framework.name = getESX() and 'esx' or 'esx'
        return Framework.name
    end
    if getQBCore() then
        Framework.name = 'qb'
        return 'qb'
    end
    if getESX() then
        Framework.name = 'esx'
        return 'esx'
    end

    Framework.name = 'standalone'
    return 'standalone'
end

local function useOxInventory()
    local inventoryMode = tostring(Config.Inventory or 'auto'):lower()
    if inventoryMode == 'framework' then
        return false
    end
    if inventoryMode == 'ox' or inventoryMode == 'auto' then
        return resourceStarted('ox_inventory')
    end
    return false
end

local function trimText(value, maxLength)
    if value == nil then
        return ''
    end
    local text = tostring(value)
    maxLength = maxLength or 500
    if #text > maxLength then
        return text:sub(1, maxLength) .. '...'
    end
    return text
end

local function displayValue(value)
    if value == nil then
        return ''
    end
    if type(value) == 'boolean' then
        return value and 'true' or 'false'
    end
    if type(value) == 'table' then
        local encoded = safeCall(function()
            return json.encode(value)
        end)
        return trimText(encoded or '[table]', 500)
    end
    return trimText(value, 500)
end

local function decodeJson(value)
    if type(value) == 'table' then
        return value
    end
    if type(value) ~= 'string' or value == '' then
        return {}
    end
    return safeCall(function()
        return json.decode(value)
    end) or {}
end

local function addDetail(details, key, label, value)
    local text = displayValue(value)
    if text == '' then
        return
    end
    details[#details + 1] = {
        key = tostring(key),
        label = tostring(label or key),
        value = text,
    }
end

local function addMetadata(meta, details, metadata)
    if type(metadata) ~= 'table' or not next(metadata) then
        return
    end

    meta.metadata = metadata
    meta.metadataJson = displayValue(metadata)
    addDetail(details, 'metadata', '元数据', metadata)

    for key, value in pairs(metadata) do
        key = tostring(key)
        addDetail(details, ('metadata.%s'):format(key), ('元数据:%s'):format(key), value)
    end
end

local function addCategory(categories, categoryMap, id, label)
    id = trimText(id, 60)
    if id == '' or categoryMap[id] then
        return
    end
    categoryMap[id] = true
    categories[#categories + 1] = {
        id = id,
        label = trimText(label ~= nil and label or id, 60),
    }
end

local function sortCatalog(catalog)
    table.sort(catalog.categories, function(a, b)
        return tostring(a.label) < tostring(b.label)
    end)
    table.sort(catalog.items, function(a, b)
        return tostring(a.label) < tostring(b.label)
    end)
    return catalog
end

local function runtimeFor(player)
    local identifier = Framework.getIdentifier(player)
    if identifier == '' then
        identifier = tostring(Framework.getSource(player))
    end
    runtimeData[identifier] = runtimeData[identifier] or {}
    return runtimeData[identifier]
end

function Framework.getPlayerFromSource(source)
    source = tonumber(source)
    if not source then
        return nil
    end

    if activeFramework() == 'qb' then
        local qb = getQBCore()
        return qb and qb.Functions and qb.Functions.GetPlayer(source) or nil
    end

    local esx = getESX()
    if esx and esx.GetPlayerFromId then
        return esx.GetPlayerFromId(source)
    end

    return source
end

function Framework.getPlayers()
    if activeFramework() == 'qb' then
        local qb = getQBCore()
        if qb and qb.Functions and qb.Functions.GetQBPlayers then
            return qb.Functions.GetQBPlayers()
        end
    end

    local esx = getESX()
    if esx then
        if esx.GetExtendedPlayers then
            return esx.GetExtendedPlayers()
        end
        if esx.GetPlayers and esx.GetPlayerFromId then
            local players = {}
            for _, source in ipairs(esx.GetPlayers()) do
                local player = esx.GetPlayerFromId(source)
                if player then
                    players[#players + 1] = player
                end
            end
            return players
        end
    end

    local players = {}
    for _, source in ipairs(GetPlayers()) do
        players[#players + 1] = tonumber(source)
    end
    return players
end

function Framework.getSource(player)
    if type(player) == 'number' then
        return player
    end
    if type(player) ~= 'table' then
        return 0
    end
    if player.PlayerData and player.PlayerData.source then
        return tonumber(player.PlayerData.source) or 0
    end
    return tonumber(player.source or player.src or 0) or 0
end

function Framework.getIdentifier(player)
    if type(player) == 'number' then
        for _, identifier in ipairs(GetPlayerIdentifiers(player)) do
            if identifier:find('license:', 1, true) then
                return identifier
            end
        end
        return tostring(player)
    end
    if type(player) ~= 'table' then
        return ''
    end
    if player.PlayerData and player.PlayerData.citizenid then
        return tostring(player.PlayerData.citizenid)
    end
    if type(player.getIdentifier) == 'function' then
        return tostring(player.getIdentifier())
    end
    return tostring(player.identifier or player.license or Framework.getSource(player))
end

local function qbCharName(data)
    local char = data and data.charinfo or {}
    local first = trimText(char.firstname)
    local last = trimText(char.lastname)
    local full = (first .. ' ' .. last):gsub('^%s+', ''):gsub('%s+$', '')
    if full ~= '' then
        return full
    end
    return trimText(data and data.name)
end

local function qbGroup(player)
    local source = Framework.getSource(player)
    local qb = getQBCore()
    if source <= 0 or not qb or not qb.Functions then
        return 'user'
    end
    for group in pairs(Config.AdminGroups or {}) do
        if qb.Functions.HasPermission and qb.Functions.HasPermission(source, group) then
            return group
        end
    end
    return 'user'
end

function Framework.has(player, key)
    return Framework.get(player, key, nil) ~= nil
end

function Framework.get(player, key, default)
    if not player then
        return default
    end

    local data = type(player) == 'table' and runtimeFor(player) or nil
    if data and data[key] ~= nil then
        return data[key]
    end

    if type(player) == 'table' and player.PlayerData then
        local playerData = player.PlayerData
        if key == 'identifier' then return playerData.citizenid or default end
        if key == 'source' then return playerData.source or default end
        if key == 'name' or key == 'rolename' then return qbCharName(playerData) ~= '' and qbCharName(playerData) or default end
        if key == 'group' then return qbGroup(player) end
        if key == 'gang' or key == 'gangname' then
            local gang = playerData.gang or {}
            return gang.label or gang.name or default
        end
        if key == 'job' then
            return playerData.job and playerData.job.name or default
        end
        if key == 'qq' then
            return playerData.metadata and (playerData.metadata.qq or playerData.metadata.QQ) or default
        end
        if key == 'lv' then
            return playerData.metadata and (playerData.metadata.level or playerData.metadata.lv) or default
        end
        if playerData[key] ~= nil then
            return playerData[key]
        end
        return default
    end

    if type(player) == 'table' then
        if key == 'identifier' and type(player.getIdentifier) == 'function' then return player.getIdentifier() end
        if key == 'name' or key == 'rolename' then
            if type(player.getName) == 'function' then return player.getName() end
            return player.name or default
        end
        if key == 'group' then
            if type(player.getGroup) == 'function' then return player.getGroup() end
            return player.group or default
        end
        if key == 'job' then
            local job = type(player.getJob) == 'function' and player.getJob() or player.job
            return job and job.name or default
        end
        if key == 'gang' or key == 'gangname' then
            local gang = player.gang or {}
            return gang.label or gang.name or default
        end
        if type(player.get) == 'function' then
            local value = player.get(key)
            if value ~= nil then
                return value
            end
        end
        if player[key] ~= nil then
            return player[key]
        end
    end

    return default
end

function Framework.set(player, key, value)
    if not player or key == nil or value == nil then
        return
    end
    runtimeFor(player)[key] = value
    if type(player) == 'table' and type(player.set) == 'function' then
        safeCall(function()
            player.set(key, value)
        end)
    end
end

function Framework.changed()
end

function Framework.sendClient(playerOrSource, eventName, ...)
    local source = Framework.getSource(playerOrSource)
    if source > 0 then
        TriggerClientEvent(eventName, source, ...)
    end
end

local function stripColorCodes(message)
    return tostring(message or ''):gsub('~.-~', '')
end

function Framework.notify(player, message)
    local source = Framework.getSource(player)
    if source <= 0 then
        print(('[ck_chat] %s'):format(stripColorCodes(message)))
        return
    end

    if activeFramework() == 'qb' then
        TriggerClientEvent('QBCore:Notify', source, stripColorCodes(message))
        return
    end

    if getESX() then
        TriggerClientEvent('esx:showNotification', source, message)
        return
    end

    TriggerClientEvent('chat:addMessage', source, {
        args = { 'ck_chat', stripColorCodes(message) }
    })
end

function Framework.isAdmin(player)
    if not player then
        return false
    end

    local source = Framework.getSource(player)
    local group = tostring(Framework.get(player, 'group', 'user'))
    local adminGroups = Config.AdminGroups or {}
    if adminGroups[group] == true then
        return true
    end

    if source > 0 then
        for aceGroup in pairs(adminGroups) do
            if IsPlayerAceAllowed(source, ('group.%s'):format(aceGroup)) or IsPlayerAceAllowed(source, 'command.ckchat_admin') then
                return true
            end
        end
    end

    return false
end

function Framework.registerProperty()
end

local function playerJobName(player)
    if type(player) == 'table' and player.PlayerData and player.PlayerData.job then
        return tostring(player.PlayerData.job.name or '')
    end
    if type(player) == 'table' then
        local job = type(player.getJob) == 'function' and player.getJob() or player.job
        if type(job) == 'table' then
            return tostring(job.name or '')
        end
    end
    return tostring(Framework.get(player, 'job', ''))
end

function Framework.canJoinPresetChannel(player, channel)
    if not channel or channel.requireJob == false then
        return true
    end

    local jobs = channel.jobs or channel.jobNames or {}
    if #jobs == 0 then
        return false, '频道未配置可加入职业'
    end

    local currentJob = playerJobName(player)
    for _, job in ipairs(jobs) do
        if tostring(job) == currentJob then
            return true
        end
    end

    return false, '当前职业不能加入该频道'
end

local function qbMoneyType()
    local account = tostring(Config.MoneyAccount or 'cash')
    if account == 'money' then
        return 'cash'
    end
    return account
end

local function esxMoneyAccount()
    local account = tostring(Config.MoneyAccount or 'money')
    if account == 'cash' then
        return 'money'
    end
    return account
end

local function getESXMoney(player, account)
    if account == 'money' and type(player.getMoney) == 'function' then
        return tonumber(player.getMoney()) or 0
    end
    if type(player.getAccount) == 'function' then
        local accountData = player.getAccount(account)
        return tonumber(accountData and accountData.money) or 0
    end
    return 0
end

function Framework.removeMoney(player, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or not player then
        return false
    end

    if activeFramework() == 'qb' and type(player) == 'table' and player.Functions then
        return player.Functions.RemoveMoney(qbMoneyType(), amount, reason or 'ck_chat') == true
    end

    if type(player) == 'table' then
        local account = esxMoneyAccount()
        if getESXMoney(player, account) < amount then
            return false
        end
        if account == 'money' and type(player.removeMoney) == 'function' then
            player.removeMoney(amount, reason or 'ck_chat')
            return true
        end
        if type(player.removeAccountMoney) == 'function' then
            player.removeAccountMoney(account, amount, reason or 'ck_chat')
            return true
        end
    end

    return false
end

function Framework.addMoney(player, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or not player then
        return false
    end

    if activeFramework() == 'qb' and type(player) == 'table' and player.Functions then
        return player.Functions.AddMoney(qbMoneyType(), amount, reason or 'ck_chat') == true
    end

    if type(player) == 'table' then
        local account = esxMoneyAccount()
        if account == 'money' and type(player.addMoney) == 'function' then
            player.addMoney(amount, reason or 'ck_chat')
            return true
        end
        if type(player.addAccountMoney) == 'function' then
            player.addAccountMoney(account, amount, reason or 'ck_chat')
            return true
        end
    end

    return false
end

function Framework.removeItem(player, itemName, count)
    count = math.floor(tonumber(count) or 1)
    if count <= 0 or not player then
        return false
    end

    if useOxInventory() then
        return exports.ox_inventory:RemoveItem(Framework.getSource(player), itemName, count) == true
    end

    if activeFramework() == 'qb' and type(player) == 'table' and player.Functions then
        return player.Functions.RemoveItem(itemName, count) == true
    end

    if type(player) == 'table' and type(player.removeInventoryItem) == 'function' then
        player.removeInventoryItem(itemName, count)
        return true
    end

    return false
end

function Framework.updateInventory()
end

function Framework.keepDecimal(value, digits)
    value = tonumber(value) or 0.0
    local scale = 10 ^ (digits or 2)
    return math.floor(value * scale + 0.5) / scale
end

function Framework.log(types, key, playerOrSource, notify, ...)
    if Config.DebugLog ~= true then
        return
    end
    print(('[ck_chat:%s:%s] source=%s notify=%s'):format(types, key, Framework.getSource(playerOrSource), notify == true))
end

local function itemCategoryFrom(typeName)
    local id = trimText(typeName, 60)
    if id == '' then
        return 'backpack'
    end
    return id
end

local function itemEntry(sourceName, itemName, label, itemType, count, text, meta, details)
    itemType = itemCategoryFrom(itemType)
    meta = meta or {}
    details = details or {}

    return {
        id = sourceName,
        name = trimText(itemName, 80),
        label = trimText(label ~= '' and label or itemName, 80),
        type = itemType,
        typeLabel = itemType,
        text = trimText(text, 160),
        count = tonumber(count) or 0,
        details = details,
        meta = meta,
    }
end

local function oxItemCatalog(player)
    local source = Framework.getSource(player)
    local inventory = safeCall(function()
        return exports.ox_inventory:GetInventoryItems(source)
    end) or {}
    local itemDefs = safeCall(function()
        return exports.ox_inventory:Items()
    end) or {}

    local catalog = { categories = {}, items = {} }
    local categoryMap = {}

    for slot, item in pairs(inventory) do
        if type(item) == 'table' and item.name and (tonumber(item.count or item.amount) or 0) > 0 then
            local def = itemDefs[item.name] or {}
            local metadata = item.metadata or item.info or {}
            if type(metadata) ~= 'table' then
                metadata = {}
            end
            local label = trimText(metadata.label or item.label or def.label or item.name, 80)
            local itemType = itemCategoryFrom(def.type or def.category or item.type or 'backpack')
            local count = tonumber(item.count or item.amount) or 0
            local meta = {
                framework = Framework.name,
                inventory = 'ox',
                id = ('%s:%s'):format(item.name, item.slot or slot),
                name = item.name,
                label = label,
                type = itemType,
                count = count,
                slot = item.slot or slot,
                weight = item.weight or def.weight,
                stack = def.stack,
                close = def.close,
            }
            local details = {}
            addDetail(details, 'name', '物品ID', meta.name)
            addDetail(details, 'label', '名称', meta.label)
            addDetail(details, 'type', '类型', meta.type)
            addDetail(details, 'count', '数量', meta.count)
            addDetail(details, 'slot', '格子', meta.slot)
            addDetail(details, 'weight', '重量', meta.weight)
            addMetadata(meta, details, metadata)

            addCategory(catalog.categories, categoryMap, itemType, itemType)
            catalog.items[#catalog.items + 1] = itemEntry(meta.id, item.name, label, itemType, count, metadata.description or def.description or '', meta, details)
        end
    end

    return sortCatalog(catalog)
end

local function qbItemCatalog(player)
    local qb = getQBCore()
    local sharedItems = qb and qb.Shared and qb.Shared.Items or {}
    local playerData = type(player) == 'table' and player.PlayerData or {}
    local catalog = { categories = {}, items = {} }
    local categoryMap = {}

    for slot, item in pairs(playerData.items or {}) do
        if type(item) == 'table' and item.name and (tonumber(item.amount or item.count) or 0) > 0 then
            local def = sharedItems[item.name] or {}
            local metadata = item.metadata or item.info or {}
            if type(metadata) ~= 'table' then
                metadata = {}
            end
            local label = trimText(metadata.label or item.label or def.label or item.name, 80)
            local itemType = itemCategoryFrom(item.type or def.type or 'backpack')
            local count = tonumber(item.amount or item.count) or 0
            local meta = {
                framework = 'qb',
                inventory = 'qb',
                id = ('%s:%s'):format(item.name, item.slot or slot),
                name = item.name,
                label = label,
                type = itemType,
                count = count,
                slot = item.slot or slot,
                weight = item.weight or def.weight,
                unique = item.unique or def.unique,
                usable = item.useable or def.useable,
            }
            local details = {}
            addDetail(details, 'name', '物品ID', meta.name)
            addDetail(details, 'label', '名称', meta.label)
            addDetail(details, 'type', '类型', meta.type)
            addDetail(details, 'count', '数量', meta.count)
            addDetail(details, 'slot', '格子', meta.slot)
            addDetail(details, 'weight', '重量', meta.weight)
            addMetadata(meta, details, metadata)

            addCategory(catalog.categories, categoryMap, itemType, itemType)
            catalog.items[#catalog.items + 1] = itemEntry(meta.id, item.name, label, itemType, count, metadata.description or item.description or def.description or '', meta, details)
        end
    end

    return sortCatalog(catalog)
end

local function esxItemCatalog(player)
    local inventory = {}
    if type(player) == 'table' and type(player.getInventory) == 'function' then
        inventory = player.getInventory(false) or {}
    elseif type(player) == 'table' then
        inventory = player.inventory or {}
    end

    local catalog = { categories = {}, items = {} }
    local categoryMap = {}

    for key, item in pairs(inventory) do
        local name = type(item) == 'table' and (item.name or key) or key
        local count = type(item) == 'table' and (tonumber(item.count or item.amount) or 0) or (tonumber(item) or 0)
        if name and count > 0 then
            local metadata = type(item) == 'table' and (item.metadata or item.info or {}) or {}
            if type(metadata) ~= 'table' then
                metadata = {}
            end
            local label = trimText(type(item) == 'table' and (metadata.label or item.label) or name, 80)
            local itemType = itemCategoryFrom(type(item) == 'table' and (item.type or item.category) or 'backpack')
            local meta = {
                framework = 'esx',
                inventory = 'esx',
                id = tostring(name),
                name = tostring(name),
                label = label ~= '' and label or tostring(name),
                type = itemType,
                count = count,
                weight = type(item) == 'table' and item.weight or nil,
                usable = type(item) == 'table' and item.usable or nil,
            }
            local details = {}
            addDetail(details, 'name', '物品ID', meta.name)
            addDetail(details, 'label', '名称', meta.label)
            addDetail(details, 'type', '类型', meta.type)
            addDetail(details, 'count', '数量', meta.count)
            addDetail(details, 'weight', '重量', meta.weight)
            addMetadata(meta, details, metadata)

            addCategory(catalog.categories, categoryMap, itemType, itemType)
            catalog.items[#catalog.items + 1] = itemEntry(meta.id, name, meta.label, itemType, count, metadata.description or (type(item) == 'table' and item.description) or '', meta, details)
        end
    end

    return sortCatalog(catalog)
end

function Framework.getItemCatalog(player)
    if useOxInventory() then
        return oxItemCatalog(player)
    end
    if activeFramework() == 'qb' then
        return qbItemCatalog(player)
    end
    return esxItemCatalog(player)
end

function Framework.getItemLinkPayload(player, itemName, payload)
    payload = type(payload) == 'table' and payload or {}
    if type(payload.details) == 'table' or type(payload.meta) == 'table' then
        return {
            linkType = 'item',
            title = trimText(payload.label or payload.name or itemName, 80),
            subtitle = trimText(payload.text or payload.typeLabel or payload.type or '', 120),
            payload = payload,
            details = payload.details or {},
            meta = payload.meta or {},
        }
    end

    itemName = tostring(itemName or '')
    if itemName == '' then
        return nil
    end

    local catalog = Framework.getItemCatalog(player)
    for _, item in ipairs(catalog.items or {}) do
        if item.name == itemName or item.id == itemName then
            return {
                linkType = 'item',
                title = item.label,
                subtitle = item.text ~= '' and item.text or item.typeLabel,
                payload = {
                    id = item.id,
                    name = item.name,
                    type = item.type,
                    meta = item.meta,
                },
                details = item.details,
                meta = item.meta,
            }
        end
    end

    return nil
end

local function mysqlQuery(query, params)
    if not MySQL or not MySQL.query then
        return {}
    end

    if MySQL.query.await then
        return safeCall(function()
            return MySQL.query.await(query, params)
        end) or {}
    end

    local p = promise.new()
    MySQL.query(query, params, function(result)
        p:resolve(result or {})
    end)
    return Citizen.Await(p)
end

local function garageConfig()
    return Config.Garage or {}
end

local function garageFramework()
    local garage = garageConfig()
    local requested = normalizedFramework(garage.Framework or Config.Framework)
    if requested ~= 'auto' then
        return requested
    end
    return activeFramework()
end

local function onlyStored()
    local garage = garageConfig()
    return garage.OnlyStored ~= false
end

local function rowIsStored(row)
    if not onlyStored() then
        return true
    end
    if row.state ~= nil then
        local state = tostring(row.state):lower()
        return tonumber(row.state) == 1 or state == 'true' or state == 'stored'
    end
    if row.stored ~= nil then
        local stored = tostring(row.stored):lower()
        return tonumber(row.stored) == 1 or stored == 'true' or stored == 'stored'
    end
    return true
end

local function sqlTableName(value, fallback)
    value = tostring(value or fallback or '')
    if value:match('^[%w_]+$') then
        return value
    end
    return fallback
end

local function realPlateSlots()
    local count = tonumber(garageConfig().RealPlateSlots) or 3
    if count < 1 then
        return 1
    end
    if count > 3 then
        return 3
    end
    return math.floor(count)
end

local function realPlateColumn(slot)
    if slot == 1 then
        return 'realplate'
    end
    return ('realplate%s'):format(slot)
end

local function collectRealPlates(row)
    local plates = {}
    if garageConfig().UseCKRealPlate == false then
        return plates
    end

    for slot = 1, realPlateSlots() do
        local column = realPlateColumn(slot)
        local value = trimText(row[column], 50)
        if value ~= '' then
            plates[#plates + 1] = {
                slot = slot,
                column = column,
                plate = value,
            }
        end
    end

    return plates
end

local function vehicleLabel(model, row)
    local qb = getQBCore()
    if qb and qb.Shared and qb.Shared.Vehicles then
        local key = tostring(model or ''):lower()
        local vehicle = qb.Shared.Vehicles[key] or qb.Shared.Vehicles[tostring(model or '')]
        if vehicle then
            return vehicle.name or vehicle.label or tostring(model or ''), vehicle.brand
        end
    end
    return trimText(row and (row.vehicle_name or row.name or row.label) or model, 80), nil
end

local function vehicleEntries(row, garageType)
    if not rowIsStored(row) then
        return {}
    end

    local vehicleJson = type(row.vehicle) == 'string' and row.vehicle:match('^%s*{') and row.vehicle or nil
    local props = decodeJson(row.mods or vehicleJson)
    local model = row.model or props.model or props.modelHash or props.hash or row.hash
    if garageType == 'qb' and row.vehicle then
        model = row.vehicle
    elseif not model and type(row.vehicle) == 'string' then
        model = row.vehicle
    end
    local sourcePlate = row.plate or props.plate or ''
    local realPlates = collectRealPlates(row)
    local displayPlates = #realPlates > 0 and realPlates or {
        {
            slot = 1,
            column = 'plate',
            plate = sourcePlate,
            fallback = true,
        }
    }
    local garageName = row.garage or row.parking or row.garage_id or row.type or 'garage'
    local label, brand = vehicleLabel(model, row)
    local baseId = trimText(row.id or row.citizenid and (row.citizenid .. ':' .. sourcePlate) or row.owner and (row.owner .. ':' .. sourcePlate) or sourcePlate or model, 100)
    local vehicleType = trimText(garageName, 60)
    if vehicleType == '' then
        vehicleType = 'garage'
    end

    local entries = {}
    for _, plateInfo in ipairs(displayPlates) do
        local displayPlate = tostring(plateInfo.plate or '')
        local slot = tonumber(plateInfo.slot) or 1
        local hasRealPlate = plateInfo.fallback ~= true
        local slotText = hasRealPlate and ('槽' .. slot) or ''
        local itemLabel = trimText(label ~= '' and label or model, 80)
        if slotText ~= '' then
            itemLabel = trimText(('%s %s'):format(itemLabel, slotText), 80)
        end

        local id = hasRealPlate and ('%s:%s'):format(baseId, plateInfo.column) or baseId
        local meta = {
            framework = garageType,
            id = id,
            model = tostring(model or ''),
            label = itemLabel,
            plate = displayPlate,
            sourcePlate = tostring(sourcePlate or ''),
            realPlate = hasRealPlate and displayPlate or '',
            realPlateSlot = hasRealPlate and slot or nil,
            garage = tostring(garageName or ''),
            state = row.state,
            stored = row.stored,
            hash = row.hash or props.hash,
            fuel = row.fuel or props.fuelLevel,
            engine = row.engine or props.engineHealth,
            body = row.body or props.bodyHealth,
            brand = brand,
        }
        local details = {}
        addDetail(details, 'model', '模型', meta.model)
        addDetail(details, 'label', '名称', meta.label)
        addDetail(details, 'plate', hasRealPlate and ('显示车牌槽' .. slot) or '显示车牌', meta.plate)
        if hasRealPlate then
            addDetail(details, 'realPlate', 'CK真实车牌', meta.realPlate)
            addDetail(details, 'realPlateSlot', '真实车牌槽位', slot)
            addDetail(details, 'sourcePlate', '原车库车牌', meta.sourcePlate)
            for _, item in ipairs(realPlates) do
                addDetail(details, item.column, item.slot == 1 and '真实车牌槽1' or ('真实车牌槽' .. item.slot), item.plate)
            end
        else
            addDetail(details, 'sourcePlate', '车库车牌', meta.sourcePlate)
        end
        addDetail(details, 'garage', '车库', meta.garage)
        addDetail(details, 'state', '状态', meta.state ~= nil and meta.state or meta.stored)
        addDetail(details, 'hash', 'Hash', meta.hash)
        addDetail(details, 'fuel', '油量', meta.fuel)
        addDetail(details, 'engine', '引擎', meta.engine)
        addDetail(details, 'body', '车身', meta.body)
        addDetail(details, 'brand', '品牌', meta.brand)

        entries[#entries + 1] = {
            id = id,
            model = meta.model,
            label = itemLabel,
            type = vehicleType,
            typeLabel = vehicleType,
            plate = meta.plate,
            realPlate = meta.realPlate,
            sourcePlate = meta.sourcePlate,
            realPlateSlot = meta.realPlateSlot,
            text = meta.plate ~= '' and ('车牌 ' .. meta.plate) or '',
            details = details,
            meta = meta,
        }
    end

    return entries
end

local function qbVehicleCatalog(player)
    local playerData = type(player) == 'table' and player.PlayerData or {}
    local citizenid = playerData.citizenid or Framework.getIdentifier(player)
    local tableName = sqlTableName(garageConfig().QBTable, 'player_vehicles')
    local rows = mysqlQuery(('SELECT * FROM `%s` WHERE `citizenid` = ?'):format(tableName), { citizenid })
    local catalog = { categories = {}, items = {} }
    local categoryMap = {}

    for _, row in ipairs(rows or {}) do
        for _, item in ipairs(vehicleEntries(row, 'qb')) do
            addCategory(catalog.categories, categoryMap, item.type, item.typeLabel)
            catalog.items[#catalog.items + 1] = item
        end
    end

    return sortCatalog(catalog)
end

local function esxVehicleCatalog(player)
    local owner = Framework.getIdentifier(player)
    local tableName = sqlTableName(garageConfig().ESXTable, 'owned_vehicles')
    local rows = mysqlQuery(('SELECT * FROM `%s` WHERE `owner` = ?'):format(tableName), { owner })
    local catalog = { categories = {}, items = {} }
    local categoryMap = {}

    for _, row in ipairs(rows or {}) do
        for _, item in ipairs(vehicleEntries(row, 'esx')) do
            addCategory(catalog.categories, categoryMap, item.type, item.typeLabel)
            catalog.items[#catalog.items + 1] = item
        end
    end

    return sortCatalog(catalog)
end

function Framework.getVehicleCatalog(player)
    if garageFramework() == 'qb' then
        return qbVehicleCatalog(player)
    end
    return esxVehicleCatalog(player)
end

function Framework.getVehicleLinkPayload(player, model, payload)
    payload = type(payload) == 'table' and payload or {}
    if type(payload.details) == 'table' or type(payload.meta) == 'table' then
        return {
            linkType = 'vehicle',
            title = trimText(payload.label or payload.model or model, 80),
            subtitle = trimText(payload.plate or payload.typeLabel or payload.type or '车辆信息', 120),
            payload = payload,
            details = payload.details or {},
            meta = payload.meta or {},
        }
    end

    model = tostring(model or '')
    if model == '' then
        return nil
    end

    local catalog = Framework.getVehicleCatalog(player)
    for _, item in ipairs(catalog.items or {}) do
        if item.model == model or item.id == model or item.plate == model then
            return {
                linkType = 'vehicle',
                title = item.label,
                subtitle = item.text ~= '' and item.text or item.typeLabel,
                payload = {
                    id = item.id,
                    model = item.model,
                    plate = item.plate,
                    realPlate = item.realPlate,
                    sourcePlate = item.sourcePlate,
                    type = item.type,
                    meta = item.meta,
                },
                details = item.details,
                meta = item.meta,
            }
        end
    end

    return nil
end

function Framework.getTaskInfo()
    return nil
end
