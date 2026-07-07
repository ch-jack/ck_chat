-- ck_chat ox_inventory 物品示例
-- 作者: JACK
-- 联系方式: QQ 2518926462
--
-- 复制到 ox_inventory/data/items.lua。
-- 注意 consume 必须是 0，ck_chat 服务端校验槽位、写入数据库后会自己扣除道具。

['ck_chat_avatar_frame'] = {
    label = '聊天头像框',
    weight = 0,
    stack = false,
    close = true,
    consume = 0,
    description = '使用后切换聊天头像框，metadata.frameId 对应 ck_chat/html/txk 文件名',
    client = {
        export = 'ck_chat.useAvatarFrameItem',
    },
},

['ck_chat_box_frame'] = {
    label = '聊天框',
    weight = 0,
    stack = false,
    close = true,
    consume = 0,
    description = '使用后切换聊天框，metadata.frameId 对应 ck_chat/html/ltk 文件名',
    client = {
        export = 'ck_chat.useChatBoxFrameItem',
    },
},
