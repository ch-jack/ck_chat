# ck_chat

[![Build ck_chat](https://github.com/ch-jack/ck_chat/actions/workflows/build.yml/badge.svg)](https://github.com/ch-jack/ck_chat/actions/workflows/build.yml)

FiveM 富文本 NUI 聊天系统，支持 ESX / QBCore、ox_inventory metadata、ck_realplate 真实车牌、动态头像框/聊天框、红包、位置、私聊和自定义频道。

作者: JACK  
联系方式: QQ 2518926462

![全服聊天](docs/images/feature-global-chat.png)

## 功能

- 框架兼容: 自动识别 ESX / QBCore，也可以在配置里强制指定。
- 背包兼容: 支持 ox_inventory，物品链接会显示 metadata 详情。
- 车库车辆: 支持 ESX `owned_vehicles` 和 QBCore `player_vehicles`。
- 真实车牌: 支持 ck_realplate 的 `realplate`、`realplate2`、`realplate3` 三个槽位。
- 聊天频道: 支持全服、私聊、自定义频道和职业预设频道。
- 富文本消息: 支持物品链接、载具链接、收藏图片、红包、位置分享和系统公告。
- 聊天外观: 支持动态头像框和动态聊天框，可通过 GM 命令或 ox_inventory 道具设置。
- 持久化: 头像框和聊天框写入 `ck_chat_profiles` 数据库表。
- 自动构建: GitHub Actions 自动检查并打包 `ck_chat.zip`。

## 依赖

必需:

- FiveM artifact，支持 `cerulean`
- `oxmysql`
- ESX 或 QBCore

可选:

- `ox_inventory`: 背包物品、metadata 和聊天外观道具
- `ck_realplate`: 车辆链接显示真实车牌

## 安装

1. 放入服务器资源目录:

```text
resources/[local]/ck_chat
```

2. 在 `server.cfg` 中按顺序启动:

```cfg
ensure oxmysql
ensure es_extended
# 或 ensure qb-core

# 可选
ensure ox_inventory
ensure ck_realplate

ensure ck_chat
```

3. 修改 `config.lua`。

4. 重启资源:

```cfg
restart ck_chat
```

首次启动会自动创建 `ck_chat_profiles` 表；也可以手动导入 [sql/ck_chat.sql](sql/ck_chat.sql)。

## 配置

配置文件: [config.lua](config.lua)

```lua
CKChatConfig.Framework = 'auto' -- auto / esx / qb
CKChatConfig.Inventory = 'auto' -- auto / ox / framework
CKChatConfig.MoneyAccount = 'cash'
CKChatConfig.CustomChannelJoinCost = 10000

CKChatConfig.FrameItems = {
    AvatarItem = 'ck_chat_avatar_frame',
    ChatBoxItem = 'ck_chat_box_frame',
    RemoveOnUse = true,
}

CKChatConfig.UI = {
    AutoHideMs = 7000,
    Width = '38vw',
    MinWidth = 'min(430px, 96vw)',
    MaxWidth = 'none',
    MessageListHeight = '23vh',
    MessageListMinHeight = '170px',
    Anchor = 'top-right',
    Top = '32%',
    Bottom = '0',
    Side = '0',
}

CKChatConfig.Garage = {
    Framework = 'auto',
    OnlyStored = true,
    ESXTable = 'owned_vehicles',
    QBTable = 'player_vehicles',
}
```

配置说明:

- `Framework`: `auto` 自动优先识别 QBCore，其次 ESX。
- `Inventory`: `auto` 会优先使用 ox_inventory，否则回退框架背包。
- `MoneyAccount`: 红包和自定义频道扣款账户。ESX 的 `cash` 会映射到 `money`。
- `CustomChannelJoinCost`: 手动加入自定义频道的费用，填 `0` 表示免费。
- `FrameItems.AvatarItem`: ox_inventory 头像框道具名。
- `FrameItems.ChatBoxItem`: ox_inventory 聊天框道具名。
- `FrameItems.RemoveOnUse`: 使用成功后是否扣除 1 个道具。
- `UI.AutoHideMs`: 输入关闭后自动隐藏的毫秒数，填 `0` 禁用自动隐藏。
- `UI.Width / MinWidth / MaxWidth`: 聊天窗口宽度限制，支持 `px`、`vw`、`%`、`min()` 等 CSS 尺寸。
- `UI.MessageListHeight / MessageListMinHeight`: 消息列表高度和最小高度。
- `UI.Anchor`: 支持 `top-left`、`top-right`、`bottom-left`、`bottom-right`。
- `UI.Top / Bottom / Side`: 顶部、底部和左右边距；顶部锚点使用 `Top`，底部锚点使用 `Bottom`。
- `Garage.OnlyStored`: 只显示入库车辆。ESX 读取 `stored`，QB 读取 `state`。
- ck_realplate 无需额外开关，固定读取 `realplate`、`realplate2`、`realplate3`。

## 功能用法

### 全服聊天

默认按 `T` 打开聊天，也可以执行:

```text
openNewChat
```

全服频道默认所有在线玩家可见，支持普通文本、系统公告、GM 提示和 FiveM 颜色码。

```text
^3黄色文字 ^7恢复默认
```

![全服聊天](docs/images/feature-global-chat.png)

### 私聊

1. 点击顶部 `私聊`。
2. 选择在线玩家。
3. 输入消息并发送。

![私聊](docs/images/feature-private-chat.png)

### 自定义频道

1. 点击顶部 `自定义`。
2. 选择预设频道，或输入频道名。
3. 点击 `加入频道`。
4. 发送消息。

费用规则:

- 手动自定义频道按 `CKChatConfig.CustomChannelJoinCost` 扣费。
- 预设职业频道不扣费。
- `CKChatConfig.CustomChannelJoinCost = 0` 表示免费。

![自定义频道](docs/images/feature-custom-channel.png)

### 收藏发送图片

1. 点击 `收藏`。
2. 输入 `http://` 或 `https://` 图片地址并收藏。
3. 点击收藏图片发送。

收藏数据保存在玩家本地 NUI `localStorage`。

![收藏发送图片](docs/images/feature-favorite-image.png)

### 发送物品链接

1. 点击 `链接`。
2. 选择 `背包`。
3. 选择分类和物品。
4. 发送消息。

启用 ox_inventory 时会读取 `name`、`label`、`count`、`slot`、`weight` 和 `metadata`，metadata 会在详情里逐项显示。

![发送物品链接](docs/images/feature-item-link.png)

### 发送载具链接

1. 点击 `链接`。
2. 选择 `载具`。
3. 选择车库分类和车辆。
4. 发送消息。

车辆来源:

- ESX: `owned_vehicles`
- QBCore: `player_vehicles`

ck_realplate 显示规则:

- 有几个真实车牌槽位，就显示几条车辆记录。
- 三个真实车牌字段都为空时，只显示原车库车牌。
- 详情保留原车库车牌，方便排查。

![发送载具链接](docs/images/feature-vehicle-link.png)

### 发红包

1. 点击 `红包`。
2. 输入金额和份数。
3. 发送红包。
4. 其他玩家点击红包卡片领取。

限制:

- 私聊频道不能发红包。
- 最大金额默认 `50000`，在 `server.lua` 的 `MAX_REDPACKET_AMOUNT` 中调整。
- 扣款和加款账户由 `CKChatConfig.MoneyAccount` 控制。

![发红包](docs/images/feature-redpacket.png)

### 发位置

1. 点击 `位置`。
2. 当前输入框内容会作为位置标题。
3. 发送后其他玩家点击 `地图打标`。

服务端保存坐标 30 分钟，客户端会调用 `SetNewWaypoint` 并创建路线 blip。

![发位置](docs/images/feature-position.png)

## 动态头像框和聊天框

图片资源路径:

```text
html/txk/<头像框ID>.png
html/txk/<头像框ID>.webp
html/ltk/<聊天框ID>.png
html/ltk/<聊天框ID>.webp
```

支持后缀: `webp / png / gif / jpg / jpeg`

GM 命令:

```text
/ckchat_frame <玩家ID> <头像框ID>
/ckchat_boxframe <玩家ID> <聊天框ID>
```

`0` 表示取消当前头像框或聊天框。命令和 ox_inventory 道具都会写入 `ck_chat_profiles`。

ox_inventory 物品:

1. 将 [docs/ox_inventory_items.lua](docs/ox_inventory_items.lua) 复制到 `ox_inventory/data/items.lua`。
2. 保持 `consume = 0`，ck_chat 会在服务端校验槽位、写入数据库后再扣除道具。
3. 发放带 metadata 的物品。

示例:

```text
/giveitem 1 ck_chat_avatar_frame 1 {"frameId":"dynamic_avatar_01","label":"动态头像框 01"}
/giveitem 1 ck_chat_box_frame 1 {"frameId":"dynamic_chatbox_01","label":"动态聊天框 01"}
```

metadata 字段:

- 头像框: `frameId` / `chatFrameId` / `avatarFrameId`
- 聊天框: `frameId` / `chatBoxFrameId` / `boxFrameId`

![动态头像框和聊天框](docs/images/feature-dynamic-frames.png)

## 管理命令

```text
/gm <内容>
/ckchat_system <内容>
/ckchat_mute <玩家ID> <分钟>
/ckchat_unmute <玩家ID>
/ckchat_muteall
/ckchat_frame <玩家ID> <头像框ID>
/ckchat_boxframe <玩家ID> <聊天框ID>
```

权限:

- 支持 `CKChatConfig.AdminGroups` 中的框架 group。
- 支持 ACE `group.<name>` 和 `command.ckchat_admin`。

## 导出

服务端导出:

```lua
exports['ck_chat']:SendSystemMessage('公告内容', '标题', 'info')
```

```lua
exports['ck_chat']:SendCustomLink(source, {
    channel = 'global',
    mode = 'link',
    linkType = 'custom',
    title = '标题',
    subtitle = '副标题',
    payload = {},
    details = {
        { key = 'id', label = 'ID', value = '1001' }
    },
    meta = {}
})
```

## 构建

本地打包:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build.ps1
```

输出:

```text
dist/ck_chat.zip
```

GitHub Actions 会执行:

- `node --check html/app.js`
- `luac5.4 -p` Lua 语法检查
- `scripts/build.ps1`
- 上传 `ck_chat.zip`

## 目录

```text
ck_chat/
  client.lua
  server.lua
  config.lua
  fxmanifest.lua
  framework/
  html/
    app.js
    index.css
    index.html
    test.html
    txk/
    ltk/
  docs/
    images/
    ox_inventory_items.lua
  sql/
    ck_chat.sql
  scripts/
    build.ps1
  .github/workflows/build.yml
```

## 预览

本地预览测试页:

```powershell
python -m http.server 5173 --bind 127.0.0.1
```

打开:

```text
http://127.0.0.1:5173/html/test.html
```

## 作者

作者: JACK  
联系方式: QQ 2518926462
