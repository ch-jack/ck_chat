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

-- 加入手动自定义频道的费用。填 0 表示免费；预设职业频道不扣费。
CKChatConfig.CustomChannelJoinCost = CKChatConfig.CustomChannelJoinCost or 10000

-- ox_inventory 道具配置。道具 metadata 里写 frameId 或 chatFrameId/chatBoxFrameId。
CKChatConfig.FrameItems = CKChatConfig.FrameItems or {
    -- 使用后设置聊天头像框，对应图片目录 html/txk。
    AvatarItem = 'ck_chat_avatar_frame',

    -- 使用后设置聊天框，对应图片目录 html/ltk。
    ChatBoxItem = 'ck_chat_box_frame',

    -- true = 使用成功后扣除 1 个道具；false = 只切换不扣除。
    RemoveOnUse = true,
}

-- NUI 布局和空闲隐藏配置。
-- Anchor 支持: top-left / top-right / bottom-left / bottom-right。
-- Width、MinWidth、MaxWidth、MessageListHeight 等值直接使用 CSS 尺寸单位。
CKChatConfig.UI = CKChatConfig.UI or {
    -- 输入框关闭后，聊天窗口空闲多少毫秒自动隐藏；填 0 表示不自动隐藏。
    AutoHideMs = 7000,

    -- 聊天窗口宽度限制。
    Width = '38vw',
    MinWidth = 'min(430px, 96vw)',
    MaxWidth = 'none',

    -- 消息列表高度限制。
    MessageListHeight = '23vh',
    MessageListMinHeight = '170px',

    -- 窗口锚点和边距。Top 用于顶部锚点，Bottom 用于底部锚点。
    Anchor = 'top-right',
    Top = '32%',
    Bottom = '0',
    Side = '0',
}

-- 车库读取配置。
CKChatConfig.Garage = CKChatConfig.Garage or {
    -- auto = 跟随 CKChatConfig.Framework；也可以强制 esx/qb
    Framework = 'auto',

    -- true 时只显示入库车辆。ESX 兼容 stored，QB 兼容 state。
    OnlyStored = true,

    -- 默认 ESX / QB 官方车库表名。
    ESXTable = 'owned_vehicles',
    QBTable = 'player_vehicles',
}

-- ck_realplate 真实车牌无需配置开关，始终读取 realplate/realplate2/realplate3 三个槽位。

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
