--[[
    ck_chat 配置文件
    作者: JACK
    联系方式: QQ 2518926462

    本资源支持 ESX / QBCore 自动识别，背包优先兼容 ox_inventory 元数据，
    车辆信息从车库表读取，并可显示 ck_realplate 写入的真实车牌槽位。
]]

CKChatConfig = CKChatConfig or {}

-- 管理员组名。支持框架 group，也支持 ACE group.<name>。
CKChatConfig.AdminGroups = CKChatConfig.AdminGroups or {
    superadmin = true,
    admin = true,
    gm = true,
}

-- 框架选择:
-- auto = 自动优先识别 qb-core，其次 es_extended
-- esx  = 强制使用 ESX
-- qb   = 强制使用 QBCore
CKChatConfig.Framework = CKChatConfig.Framework or 'auto'

-- 背包选择:
-- auto      = ox_inventory 已启动时优先用 OX，否则用框架背包
-- ox        = 强制尝试 ox_inventory
-- framework = 只用 ESX/QB 自带玩家背包数据
CKChatConfig.Inventory = CKChatConfig.Inventory or 'auto'

-- 红包和自定义频道扣钱/加钱账户:
-- ESX: cash 会映射到 money；也可以填 bank/black_money 等账号
-- QB : cash/bank/crypto 等 QBCore money 类型
CKChatConfig.MoneyAccount = CKChatConfig.MoneyAccount or 'cash'

-- 车库读取配置。
CKChatConfig.Garage = CKChatConfig.Garage or {
    -- auto = 跟随 CKChatConfig.Framework；也可以强制 esx/qb
    Framework = 'auto',

    -- true 时只显示入库车辆。ESX 兼容 stored，QB 兼容 state。
    OnlyStored = true,

    -- 默认 ESX / QB 官方车库表名。
    ESXTable = 'owned_vehicles',
    QBTable = 'player_vehicles',

    -- true 时读取 ck_realplate 添加在车库表上的 realplate/realplate2/realplate3。
    UseCKRealPlate = true,

    -- ck_realplate 默认支持 3 个真实车牌槽位。范围 1-3。
    RealPlateSlots = 3,
}

-- 预设频道。requireJob=true 时只有 jobs 里的职业能加入。
CKChatConfig.PresetChannels = CKChatConfig.PresetChannels or {
    {
        id = 'police',
        label = '警察',
        requireJob = true,
        jobs = { 'police' },
    },
    {
        id = 'medical',
        label = '医护',
        requireJob = true,
        jobs = { 'medical' },
    },
}
