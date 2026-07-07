CKChatConfig = CKChatConfig or {}

CKChatConfig.AdminGroups = CKChatConfig.AdminGroups or {
    superadmin = true,
    admin = true,
    gm = true,
}

CKChatConfig.Framework = CKChatConfig.Framework or 'auto' -- auto, esx, qb
CKChatConfig.Inventory = CKChatConfig.Inventory or 'auto' -- auto, ox, framework
CKChatConfig.MoneyAccount = CKChatConfig.MoneyAccount or 'cash'

CKChatConfig.Garage = CKChatConfig.Garage or {
    Framework = 'auto',
    OnlyStored = true,
    ESXTable = 'owned_vehicles',
    QBTable = 'player_vehicles',
}

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
