// ck_chat NUI
// Author: JACK
// QQ: 2518926462

(function () {
    const TEST_MODE = Boolean(window.CK_CHAT_TEST);
    const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'ck_chat';
    const MAX_MESSAGES = 120;
    const MAX_REDPACKET_AMOUNT = 50000;
    const AUTO_HIDE_MS = 7000;
    const FRAME_IMAGE_ROOT = `nui://${RESOURCE}/html/images`;
    const FRAME_EXTENSIONS = ['webp', 'png', 'gif', 'jpg', 'jpeg'];
    const EMOJIS = ['😀', '😂', '😎', '😍', '😡', '😭', '👍', '👀', '🔥', '🎉', '🚗', '🏁', '💰', '📍', '⭐', '✅', '❌', '？', '！', 'OK'];
    const FAVORITE_IMAGES_KEY = 'ck_chat.favoriteImages';
    const DEFAULT_PRESET_CHANNELS = [
        { id: 'police', label: '警察', requireJob: true },
        { id: 'medical', label: '医护', requireJob: true }
    ];

    const state = {
        messages: [],
        suggestions: [],
        inputOpen: false,
        hidden: false,
        screenHidden: false,
        idleHidden: false,
        channel: 'global',
        customChannel: '',
        customChannelId: '',
        unread: { global: 0, private: 0, custom: 0 },
        customDraft: '',
        customMode: 'preset',
        customPendingId: 'police',
        presetChannels: DEFAULT_PRESET_CHANNELS.slice(),
        target: '',
        mode: 'text',
        activePanel: '',
        oldMessages: [],
        oldIndex: -1,
        redAmount: '',
        redCount: '',
        me: {},
        onlinePlayers: [],
        catalogs: {
            item: { categories: [], items: [] },
            vehicle: { categories: [], items: [] }
        },
        catalogRequested: { item: {}, vehicle: {} },
        linkSource: 'item',
        linkCategory: '',
        linkValue: '',
        favoriteImages: loadFavoriteImages()
    };

    const refs = {};
    let activeDetailFloat = null;
    let idleTimer = null;

    function post(name, payload) {
        if (TEST_MODE && window.CKChatTest && typeof window.CKChatTest.handlePost === 'function') {
            window.CKChatTest.handlePost(name, payload || {});
            return Promise.resolve();
        }
        return fetch(`https://${RESOURCE}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(payload || {})
        }).catch(() => {});
    }

    function init() {
        const app = document.getElementById('app');
        app.innerHTML = `
            <div class="ck-chat" id="ckChat">
                <div class="chat-shell">
                    <div class="chat-header">
                        <div class="channel-tabs" id="channelTabs"></div>
                        <div class="chat-status"><span class="status-dot"></span><span id="routeLabel">全服</span></div>
                    </div>
                    <div class="chat-window">
                        <div class="message-list" id="messageList"></div>
                    </div>
                    <div class="chat-input" id="chatInput">
                        <div class="route-fields">
                            <select id="privateTarget" class="hidden"></select>
                            <div id="customRoute" class="custom-route hidden">
                                <div class="preset-channels" id="customChannelChoices"></div>
                                <div id="customInputWrap" class="custom-input-wrap hidden">
                                    <input id="customChannel" placeholder="频道名">
                                </div>
                                <button class="mini-btn" id="joinChannelBtn" type="button">加入频道</button>
                            </div>
                        </div>
                        <div class="composer">
                            <textarea id="messageInput" spellcheck="false" maxlength="600" placeholder="输入消息，/ 可查看命令"></textarea>
                            <button class="send-btn" id="sendBtn" type="button">发送</button>
                        </div>
                        <div class="toolbar">
                            <button class="tool-btn" data-panel="emoji" type="button">表情</button>
                            <button class="tool-btn" data-panel="stickers" type="button">收藏</button>
                            <button class="tool-btn" data-mode="link" type="button">链接</button>
                            <button class="tool-btn" data-mode="redpacket" type="button">红包</button>
                            <button class="tool-btn" id="positionBtn" type="button">位置</button>
                        </div>
                        <div class="panel" id="emojiPanel"><div class="emoji-grid" id="emojiGrid"></div></div>
                        <div class="panel" id="stickersPanel">
                            <div class="sticker-grid" id="stickerGrid"></div>
                            <div class="sticker-editor">
                                <input id="stickerUrl" placeholder="图片URL">
                                <button class="mini-btn" id="addStickerBtn" type="button">收藏图片</button>
                            </div>
                        </div>
                        <div class="panel" id="linkPanel">
                            <div class="form-grid link-grid">
                                <select id="linkSource">
                                    <option value="item">背包</option>
                                    <option value="vehicle">载具</option>
                                </select>
                                <select id="linkCategory"></select>
                                <select id="linkValue"></select>
                            </div>
                            <div class="link-preview" id="linkPreview"></div>
                        </div>
                        <div class="panel" id="redpacketPanel">
                            <div class="form-grid">
                                <input id="redAmount" type="number" min="1" max="50000" placeholder="金额">
                                <input id="redCount" type="number" min="1" max="50" placeholder="份数">
                                <input id="redText" placeholder="祝福语">
                            </div>
                        </div>
                        <div class="suggestions" id="suggestions"></div>
                    </div>
                </div>
            </div>
        `;

        [
            'ckChat', 'messageList', 'channelTabs', 'routeLabel', 'privateTarget', 'customRoute',
            'customChannelChoices', 'customInputWrap', 'customChannel', 'joinChannelBtn',
            'messageInput', 'sendBtn', 'emojiPanel', 'emojiGrid',
            'stickersPanel', 'stickerGrid', 'stickerUrl', 'addStickerBtn', 'linkPanel', 'linkSource',
            'linkCategory', 'linkValue', 'linkPreview', 'redpacketPanel', 'redAmount',
            'redCount', 'redText', 'suggestions', 'positionBtn'
        ].forEach((id) => {
            refs[id] = document.getElementById(id);
        });

        bindEvents();
        renderChannels();
        renderPanels();
        renderPrivateTargets();
        renderLinkPicker();
        renderSuggestions();
        updateShell();
        resetIdleTimer();
        post('loaded', {});
    }

    function bindEvents() {
        window.addEventListener('message', (event) => receive(event.data || event.detail || {}));
        window.addEventListener('keydown', handleWindowKey);
        window.addEventListener('resize', hideDetailFloat);
        document.addEventListener('click', handleDocumentClick);

        refs.sendBtn.addEventListener('click', sendCurrentMessage);
        refs.messageInput.addEventListener('input', () => {
            resizeInput();
            renderSuggestions();
        });
        refs.messageInput.addEventListener('keydown', handleInputKey);
        refs.messageList.addEventListener('scroll', hideDetailFloat);

        refs.privateTarget.addEventListener('change', (event) => {
            state.target = event.target.value;
            updateRouteLabel();
        });
        refs.customChannel.addEventListener('input', (event) => {
            state.customDraft = event.target.value;
            renderCustomRoute();
        });
        refs.joinChannelBtn.addEventListener('click', joinCustomChannel);
        refs.customChannelChoices.addEventListener('click', (event) => {
            const button = event.target.closest('[data-channel-choice]');
            if (!button) return;
            selectCustomChoice(button.dataset.channelChoice, button.dataset.channelId || '');
        });

        refs.positionBtn.addEventListener('click', () => {
            if (!validateCurrentRoute()) return;
            post('action', {
                action: 'sharePosition',
                channel: state.channel,
                customChannel: state.customChannel,
                customChannelId: state.customChannelId,
                target: state.target,
                label: refs.messageInput.value.trim()
            });
            hideInput();
        });
        refs.addStickerBtn.addEventListener('click', addFavoriteImage);
        refs.stickerUrl.addEventListener('keydown', (event) => {
            if (event.key === 'Enter') {
                event.preventDefault();
                addFavoriteImage();
            }
        });

        document.querySelectorAll('[data-panel]').forEach((button) => {
            button.addEventListener('click', () => {
                state.mode = 'text';
                state.activePanel = state.activePanel === button.dataset.panel ? '' : button.dataset.panel;
                renderPanels();
            });
        });

        document.querySelectorAll('[data-mode]').forEach((button) => {
            button.addEventListener('click', () => {
                state.mode = state.mode === button.dataset.mode ? 'text' : button.dataset.mode;
                state.activePanel = state.mode === 'link' ? 'link' : state.mode === 'redpacket' ? 'redpacket' : '';
                if (state.activePanel === 'link') requestCatalog(state.linkSource);
                renderPanels();
            });
        });

        refs.linkSource.addEventListener('change', (event) => {
            state.linkSource = event.target.value;
            state.linkCategory = '';
            state.linkValue = '';
            requestCatalog(state.linkSource);
            renderLinkPicker();
        });
        refs.linkCategory.addEventListener('change', (event) => {
            state.linkCategory = event.target.value;
            state.linkValue = '';
            requestCatalog(state.linkSource, state.linkCategory);
            renderLinkPicker();
        });
        refs.linkValue.addEventListener('change', (event) => {
            state.linkValue = event.target.value;
            renderLinkPreview();
        });
        refs.redAmount.addEventListener('input', (event) => {
            const amount = Number(event.target.value || 0);
            if (amount > MAX_REDPACKET_AMOUNT) {
                event.target.value = String(MAX_REDPACKET_AMOUNT);
            }
            state.redAmount = event.target.value;
        });
        refs.redCount.addEventListener('input', (event) => { state.redCount = event.target.value; });
    }

    function handleInputKey(event) {
        if (event.key === 'Escape') {
            event.preventDefault();
            event.stopPropagation();
            hideInput();
            return;
        }
        if (event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault();
            sendCurrentMessage();
            return;
        }
        if (event.key === 'ArrowUp' && state.oldMessages.length > 0) {
            event.preventDefault();
            state.oldIndex = Math.min(state.oldIndex + 1, state.oldMessages.length - 1);
            refs.messageInput.value = state.oldMessages[state.oldIndex];
            resizeInput();
            renderSuggestions();
        }
        if (event.key === 'ArrowDown' && state.oldIndex >= 0) {
            event.preventDefault();
            state.oldIndex -= 1;
            refs.messageInput.value = state.oldIndex >= 0 ? state.oldMessages[state.oldIndex] : '';
            resizeInput();
            renderSuggestions();
        }
    }

    function handleWindowKey(event) {
        if (event.defaultPrevented || event.key !== 'Escape' || !state.inputOpen) {
            return;
        }
        event.preventDefault();
        event.stopPropagation();
        hideInput();
    }

    function sendCurrentMessage() {
        const text = refs.messageInput.value.trim();
        if (!text && state.mode === 'text') {
            hideInput();
            return;
        }
        const isCommand = text.charAt(0) === '/';
        if (!isCommand && !validateCurrentRoute()) {
            return;
        }

        const payload = {
            channel: state.channel,
            customChannel: state.customChannel,
            customChannelId: state.customChannelId,
            target: state.target,
            text
        };

        if (state.mode === 'link' && !isCommand) {
            const selected = getSelectedLinkItem();
            if (!selected) {
                refs.linkPreview.textContent = '请选择要发送的物品或载具';
                return;
            }
            payload.mode = 'link';
            payload.linkType = state.linkSource;
            payload.title = selected.label || selected.name || selected.model || '内容链接';
            payload.subtitle = selected.text || selected.typeLabel || selected.type || '';
            payload.image = selected.image || (selected.meta && selected.meta.image) || '';
            payload.bgImage = selected.bgImage || (selected.meta && selected.meta.bgImage) || '';
            payload.payload = buildLinkPayload(selected);
            payload.details = selected.details || [];
            payload.meta = selected.meta || {};
        }

        if (state.mode === 'redpacket' && !isCommand) {
            payload.mode = 'redpacket';
            payload.amount = state.redAmount;
            payload.count = state.redCount;
            payload.text = refs.redText.value || text || '恭喜发财';
        }

        post('sendMessage', payload);
        if (text) {
            state.oldMessages.unshift(text);
            state.oldMessages = state.oldMessages.slice(0, 20);
            state.oldIndex = -1;
        }
        clearComposer();
        hideInput({ notify: !isCommand });
    }

    function buildLinkPayload(item) {
        if (state.linkSource === 'vehicle') {
            return {
                id: item.id || item.vin || item.plate || item.model,
                model: item.model,
                type: item.type,
                vin: item.vin || item.ck_veh_vin || '',
                plate: item.plate || '',
                label: item.label || '',
                image: item.image || (item.meta && item.meta.image) || '',
                bgImage: item.bgImage || (item.meta && item.meta.bgImage) || '',
                meta: item.meta || {}
            };
        }
        return {
            id: item.id || item.objId || item.name,
            objId: item.objId || '',
            name: item.name,
            type: item.type,
            label: item.label || '',
            image: item.image || (item.meta && item.meta.image) || '',
            bgImage: item.bgImage || (item.meta && item.meta.bgImage) || '',
            meta: item.meta || {}
        };
    }

    function clearComposer() {
        refs.messageInput.value = '';
        refs.redText.value = '';
        refs.redAmount.value = '';
        refs.redCount.value = '';
        state.redAmount = '';
        state.redCount = '';
        state.mode = 'text';
        state.activePanel = '';
        resizeInput();
        renderPanels();
        renderSuggestions();
    }

    function showInput() {
        state.inputOpen = true;
        state.idleHidden = false;
        resetIdleTimer();
        updateShell();
        setTimeout(() => refs.messageInput.focus(), 40);
    }

    function hideInput(options = {}) {
        state.inputOpen = false;
        hideDetailFloat();
        resetIdleTimer();
        updateShell();
        if (options.notify !== false) {
            post('close', {});
        }
    }

    function updateShell() {
        refs.ckChat.classList.toggle('input-open', state.inputOpen);
        refs.ckChat.classList.toggle('hidden', state.hidden);
        refs.ckChat.classList.toggle('screen-hidden', state.screenHidden);
        refs.ckChat.classList.toggle('idle-hidden', state.idleHidden);
    }

    function resetIdleTimer() {
        if (idleTimer) {
            clearTimeout(idleTimer);
            idleTimer = null;
        }
        if (!refs.ckChat || state.hidden || state.screenHidden) return;
        state.idleHidden = false;
        updateShell();
        idleTimer = setTimeout(() => {
            if (state.inputOpen) return;
            state.idleHidden = true;
            updateShell();
        }, AUTO_HIDE_MS);
    }

    function renderChannels() {
        const channels = [
            { id: 'global', label: '全服' },
            { id: 'private', label: '私聊' },
            { id: 'custom', label: '自定义' }
        ];
        refs.channelTabs.innerHTML = '';
        channels.forEach((channel) => {
            const button = document.createElement('button');
            button.type = 'button';
            const active = state.channel === channel.id;
            const hasUnread = !active && (state.unread[channel.id] || 0) > 0;
            button.className = `channel-btn${active ? ' active' : ''}${hasUnread ? ' has-unread' : ''}`;
            button.textContent = channel.label;
            button.addEventListener('click', () => {
                state.channel = channel.id;
                if (state.channel === 'private' && state.mode === 'redpacket') {
                    state.mode = 'text';
                    state.activePanel = '';
                }
                clearUnread(channel.id);
                renderChannels();
                renderPanels();
                renderMessages();
            });
            refs.channelTabs.appendChild(button);
        });
        updateRouteFields();
    }

    function updateRouteFields() {
        refs.privateTarget.classList.toggle('hidden', state.channel !== 'private');
        refs.customRoute.classList.toggle('hidden', state.channel !== 'custom');
        renderCustomRoute();
        updateRouteLabel();
    }

    function updateRouteLabel() {
        const labelMap = {
            global: '全服',
            private: `私聊 ${getPrivateTargetName() || '未选择'}`,
            custom: state.customChannel ? `自定义 ${state.customChannel}` : '自定义 未加入'
        };
        refs.routeLabel.textContent = labelMap[state.channel] || '全服';
    }

    function clearUnread(channel) {
        if (!(channel in state.unread)) return;
        state.unread[channel] = 0;
    }

    function renderCustomRoute() {
        if (!refs.customChannelChoices) return;
        ensureCustomSelection();
        refs.customChannelChoices.innerHTML = '';

        state.presetChannels.forEach((channel) => {
            const button = document.createElement('button');
            button.type = 'button';
            button.className = 'mini-btn';
            button.dataset.channelChoice = 'preset';
            button.dataset.channelId = channel.id;
            button.textContent = channel.label || channel.id;
            if (state.customMode === 'preset' && state.customPendingId === channel.id) {
                button.classList.add('active');
            }
            refs.customChannelChoices.appendChild(button);
        });

        const custom = document.createElement('button');
        custom.type = 'button';
        custom.className = `mini-btn${state.customMode === 'custom' ? ' active' : ''}`;
        custom.dataset.channelChoice = 'custom';
        custom.textContent = '自定义';
        refs.customChannelChoices.appendChild(custom);

        const isCustom = state.customMode === 'custom';
        refs.customInputWrap.classList.toggle('hidden', !isCustom);
        if (isCustom && document.activeElement !== refs.customChannel) {
            refs.customChannel.value = state.customDraft || '';
        }
    }

    function ensureCustomSelection() {
        if (state.customMode === 'custom') return;
        if (findPresetChannel(state.customPendingId)) return;
        const first = state.presetChannels[0];
        if (first) {
            state.customMode = 'preset';
            state.customPendingId = first.id;
            return;
        }
        state.customMode = 'custom';
        state.customPendingId = '';
    }

    function selectCustomChoice(type, id) {
        if (type === 'custom') {
            state.customMode = 'custom';
            state.customPendingId = '';
            renderCustomRoute();
            setTimeout(() => refs.customChannel.focus(), 20);
            return;
        }
        const preset = findPresetChannel(id);
        if (!preset) return;
        state.customMode = 'preset';
        state.customPendingId = preset.id;
        renderCustomRoute();
    }

    function joinCustomChannel() {
        ensureCustomSelection();
        if (state.customMode === 'preset') {
            const preset = findPresetChannel(state.customPendingId);
            if (!preset) {
                addLocalSystemMessage('频道', '请选择频道', 'warning');
                return;
            }
            post('action', {
                action: 'joinChannel',
                customChannelId: preset.id,
                customChannel: preset.label || preset.id
            });
            return;
        }

        const name = clampUiText(state.customDraft || refs.customChannel.value || '', 20);
        if (!name) {
            addLocalSystemMessage('频道', '请输入自定义频道名', 'warning');
            return;
        }
        post('action', {
            action: 'joinChannel',
            customChannel: name
        });
    }

    function getPrivateTargetName() {
        const id = String(state.target || '');
        const player = state.onlinePlayers.find((item) => String(item.id) === id);
        return player ? `${player.name || '玩家'}(${player.id})` : '';
    }

    function renderPrivateTargets() {
        const current = String(state.target || '');
        refs.privateTarget.innerHTML = '';
        const empty = document.createElement('option');
        empty.value = '';
        empty.textContent = '选择在线玩家';
        refs.privateTarget.appendChild(empty);

        state.onlinePlayers
            .filter((player) => String(player.id) !== String(state.me && state.me.id))
            .forEach((player) => {
                const option = document.createElement('option');
                option.value = String(player.id);
                option.textContent = `${player.name || '玩家'} (${player.id})`;
                refs.privateTarget.appendChild(option);
            });

        if (current && Array.from(refs.privateTarget.options).some((option) => option.value === current)) {
            refs.privateTarget.value = current;
        } else {
            refs.privateTarget.value = '';
            state.target = '';
        }
        updateRouteLabel();
    }

    function getPrivateTarget() {
        const id = String(state.target || '');
        return state.onlinePlayers.find((item) => String(item.id) === id && String(item.id) !== String(state.me && state.me.id));
    }

    function validateCurrentRoute() {
        if (state.channel === 'private' && !getPrivateTarget()) {
            addLocalSystemMessage('私聊', '玩家不存在，无法私聊', 'warning');
            renderPrivateTargets();
            return false;
        }
        if (state.channel === 'custom' && !state.customChannel) {
            addLocalSystemMessage('频道', '请先点击加入频道', 'warning');
            return false;
        }
        return true;
    }

    function addLocalSystemMessage(title, text, level) {
        addMessage({
            id: `local:${Date.now()}:${Math.random().toString(16).slice(2)}`,
            ts: Math.floor(Date.now() / 1000),
            channel: { id: 'system', label: '系统', system: true },
            sender: { id: 0, name: '系统', system: true },
            body: { type: 'system', title, text, level: level || 'info' },
            meta: { local: true }
        });
    }

    function clampUiText(value, maxLength) {
        return String(value || '').trim().slice(0, maxLength || 80);
    }

    function renderPanels() {
        const redPacketDisabled = state.channel === 'private';
        if (redPacketDisabled && state.mode === 'redpacket') {
            state.mode = 'text';
            state.activePanel = '';
        }
        const panelMap = {
            emoji: refs.emojiPanel,
            stickers: refs.stickersPanel,
            link: refs.linkPanel,
            redpacket: refs.redpacketPanel
        };
        Object.keys(panelMap).forEach((key) => {
            panelMap[key].classList.toggle('open', state.activePanel === key);
        });
        document.querySelectorAll('[data-panel]').forEach((button) => {
            button.classList.toggle('active', state.activePanel === button.dataset.panel);
        });
        document.querySelectorAll('[data-mode]').forEach((button) => {
            if (button.dataset.mode === 'redpacket') {
                button.hidden = redPacketDisabled;
                button.disabled = redPacketDisabled;
            }
            button.classList.toggle('active', state.mode === button.dataset.mode);
        });
        renderEmojiGrid();
        renderFavoriteImages();
        renderLinkPicker();
    }

    function renderEmojiGrid() {
        refs.emojiGrid.innerHTML = '';
        EMOJIS.forEach((emoji) => {
            const button = document.createElement('button');
            button.type = 'button';
            button.className = 'emoji-item';
            button.textContent = emoji;
            button.addEventListener('click', () => {
                insertAtCursor(refs.messageInput, emoji);
                refs.messageInput.focus();
                renderSuggestions();
            });
            refs.emojiGrid.appendChild(button);
        });
    }

    function loadFavoriteImages() {
        try {
            const raw = JSON.parse(localStorage.getItem(FAVORITE_IMAGES_KEY) || '[]');
            if (!Array.isArray(raw)) return [];
            return raw
                .map((item) => ({
                    url: normaliseImageUrl(item && item.url),
                    name: clampUiText(item && item.name, 32) || '收藏图片'
                }))
                .filter((item) => item.url)
                .slice(0, 24);
        } catch (error) {
            return [];
        }
    }

    function saveFavoriteImages() {
        try {
            localStorage.setItem(FAVORITE_IMAGES_KEY, JSON.stringify(state.favoriteImages));
        } catch (error) {}
    }

    function favoriteImageName(name) {
        return clampUiText(name, 32) || '收藏图片';
    }

    function normaliseImageUrl(value) {
        const text = String(value || '').trim();
        if (!text) return '';
        try {
            const url = new URL(text);
            if (url.protocol !== 'http:' && url.protocol !== 'https:') return '';
            return url.href.slice(0, 500);
        } catch (error) {
            return '';
        }
    }

    function isFavoriteImage(url) {
        const normalized = normaliseImageUrl(url);
        return Boolean(normalized && state.favoriteImages.some((item) => item.url === normalized));
    }

    function saveFavoriteImage(url, name, silent) {
        const normalized = normaliseImageUrl(url);
        if (!normalized) return false;
        const existing = state.favoriteImages.filter((item) => item.url !== normalized);
        state.favoriteImages = [{ url: normalized, name: favoriteImageName(name) }, ...existing].slice(0, 24);
        saveFavoriteImages();
        renderFavoriteImages();
        if (!silent) {
            addLocalSystemMessage('收藏', '图片已收藏', 'success');
        }
        return true;
    }

    function addFavoriteImage() {
        const url = normaliseImageUrl(refs.stickerUrl.value);
        if (!url) {
            addLocalSystemMessage('收藏', '请输入 http 或 https 图片URL', 'warning');
            return;
        }
        refs.stickerUrl.value = '';
        saveFavoriteImage(url, '收藏图片');
    }

    function removeFavoriteImage(url) {
        const normalized = normaliseImageUrl(url);
        if (!normalized) return;
        state.favoriteImages = state.favoriteImages.filter((item) => item.url !== normalized);
        saveFavoriteImages();
        renderFavoriteImages();
        addLocalSystemMessage('收藏', '图片已删除', 'info');
    }

    function renderFavoriteImages() {
        if (!refs.stickerGrid) return;
        refs.stickerGrid.innerHTML = '';
        if (state.favoriteImages.length === 0) {
            const empty = document.createElement('div');
            empty.className = 'sticker-empty';
            empty.textContent = '暂无收藏图片';
            refs.stickerGrid.appendChild(empty);
            return;
        }
        state.favoriteImages.forEach((image) => {
            const button = document.createElement('div');
            button.className = 'sticker-item';
            button.tabIndex = 0;
            button.setAttribute('role', 'button');
            button.title = '发送收藏图片';
            const img = document.createElement('img');
            img.src = image.url;
            img.alt = '';
            img.referrerPolicy = 'no-referrer';
            const remove = document.createElement('button');
            remove.type = 'button';
            remove.className = 'sticker-delete';
            remove.title = '删除收藏';
            remove.textContent = '×';
            remove.addEventListener('click', (event) => {
                event.preventDefault();
                event.stopPropagation();
                removeFavoriteImage(image.url);
            });
            button.appendChild(img);
            button.appendChild(remove);
            button.addEventListener('click', () => sendFavoriteImage(image));
            button.addEventListener('keydown', (event) => {
                if (event.key !== 'Enter' && event.key !== ' ') return;
                event.preventDefault();
                sendFavoriteImage(image);
            });
            refs.stickerGrid.appendChild(button);
        });
    }

    function sendFavoriteImage(image) {
        if (!image || !image.url || !validateCurrentRoute()) return;
        const text = refs.messageInput.value.trim();
        post('sendMessage', {
            channel: state.channel,
            customChannel: state.customChannel,
            customChannelId: state.customChannelId,
            target: state.target,
            mode: 'image',
            text,
            imageUrl: image.url,
            imageName: '收藏图片'
        });
        if (text) {
            state.oldMessages.unshift(text);
            state.oldMessages = state.oldMessages.slice(0, 20);
            state.oldIndex = -1;
        }
        clearComposer();
        hideInput();
    }

    function renderLinkPicker() {
        if (!refs.linkSource) return;
        refs.linkSource.value = state.linkSource;

        const catalog = getActiveCatalog();
        const categories = catalog.categories || [];
        if (!state.linkCategory || !categories.some((item) => String(item.id) === String(state.linkCategory))) {
            state.linkCategory = categories[0] ? String(categories[0].id) : '';
        }
        if (state.linkCategory) {
            requestCatalog(state.linkSource, state.linkCategory);
        }

        refs.linkCategory.innerHTML = '';
        if (categories.length === 0) {
            refs.linkCategory.appendChild(option('', '暂无类型'));
        } else {
            categories.forEach((category) => refs.linkCategory.appendChild(option(category.id, category.label || category.id)));
        }
        refs.linkCategory.value = state.linkCategory;

        const items = filteredLinkItems();
        if (!state.linkValue || !items.some((item) => getLinkItemId(item) === state.linkValue)) {
            state.linkValue = items[0] ? getLinkItemId(items[0]) : '';
        }

        refs.linkValue.innerHTML = '';
        if (items.length === 0) {
            refs.linkValue.appendChild(option('', '暂无内容'));
        } else {
            items.forEach((item) => refs.linkValue.appendChild(option(getLinkItemId(item), linkOptionLabel(item))));
        }
        refs.linkValue.value = state.linkValue;
        renderLinkPreview();
    }

    function option(value, label) {
        const item = document.createElement('option');
        item.value = String(value || '');
        item.textContent = String(label || value || '');
        return item;
    }

    function getActiveCatalog() {
        return normaliseCatalog(state.catalogs[state.linkSource]);
    }

    function requestCatalog(source, category) {
        source = source === 'vehicle' ? 'vehicle' : 'item';
        const key = String(category || '__default');
        if (state.catalogRequested[source][key]) return;
        state.catalogRequested[source][key] = true;
        post('requestCatalog', { source, category: category || '' });
    }

    function filteredLinkItems() {
        const catalog = getActiveCatalog();
        if (!state.linkCategory) {
            return catalog.items || [];
        }
        return (catalog.items || []).filter((item) => String(item.type || '') === String(state.linkCategory || ''));
    }

    function getLinkItemId(item) {
        return linkItemIdForSource(state.linkSource, item);
    }

    function getSelectedLinkItem() {
        return filteredLinkItems().find((item) => getLinkItemId(item) === String(state.linkValue || '')) || null;
    }

    function linkOptionLabel(item) {
        if (state.linkSource === 'vehicle') {
            const label = item.label || item.name || item.model || '车辆';
            return item.plate ? `${label} [${item.plate}]` : label;
        }
        return item.label || item.name || item.model || '';
    }

    function linkImageFromItem(item) {
        return (item && (item.image || (item.meta && item.meta.image))) || '';
    }

    function linkImageFromLink(link) {
        const payload = (link && link.payload) || {};
        const meta = (link && link.meta) || payload.meta || {};
        return (link && link.image) || payload.image || meta.image || '';
    }

    function linkBgFromItem(item) {
        return (item && (item.bgImage || (item.meta && item.meta.bgImage))) || '';
    }

    function linkBgFromLink(link) {
        const payload = (link && link.payload) || {};
        const meta = (link && link.meta) || payload.meta || {};
        return (link && link.bgImage) || payload.bgImage || meta.bgImage || '';
    }

    function applyImageBg(img, bgUrl) {
        if (!img || !bgUrl) return;
        img.classList.add('has-bg');
        img.style.backgroundImage = `url("${String(bgUrl).replace(/"/g, '\\"')}")`;
    }

    function renderLinkPreview() {
        if (!refs.linkPreview) return;
        const item = getSelectedLinkItem();
        refs.linkPreview.innerHTML = '';
        if (!item) {
            refs.linkPreview.classList.remove('has-image');
            refs.linkPreview.textContent = '暂无可发送内容';
            return;
        }

        const imageUrl = linkImageFromItem(item);
        refs.linkPreview.classList.toggle('has-image', Boolean(imageUrl));
        if (imageUrl) {
            const img = document.createElement('img');
            img.className = 'link-preview-img';
            img.src = imageUrl;
            img.alt = item.label || item.name || item.model || '';
            img.referrerPolicy = 'no-referrer';
            applyImageBg(img, linkBgFromItem(item));
            refs.linkPreview.appendChild(img);
        }

        const text = document.createElement('div');
        text.className = 'link-preview-text';

        const title = document.createElement('div');
        title.className = 'link-preview-title';
        title.textContent = item.label || item.name || item.model;

        const meta = document.createElement('div');
        meta.className = 'link-preview-meta';
        meta.textContent = [item.typeLabel || item.type, item.text, item.brand, item.year].filter(Boolean).join(' · ');

        text.append(title, meta);
        refs.linkPreview.appendChild(text);
    }

    function insertAtCursor(input, text) {
        const start = input.selectionStart || 0;
        const end = input.selectionEnd || 0;
        input.value = input.value.slice(0, start) + text + input.value.slice(end);
        input.selectionStart = input.selectionEnd = start + text.length;
        resizeInput();
    }

    function resizeInput() {
        refs.messageInput.style.height = '34px';
        refs.messageInput.style.height = `${Math.min(96, Math.max(34, refs.messageInput.scrollHeight))}px`;
    }

    function receive(item) {
        if (!item || !item.type) return;
        if (item.type === 'ck_chat:ready') {
            post('loaded', {});
            return;
        }
        if (item.type === 'ck_chat:message') addMessage(item.message);
        if (item.type === 'ck_chat:messages') setMessages(item.messages || []);
        if (item.type === 'ck_chat:bootstrap') applyBootstrap(item.data || {});
        if (item.type === 'ck_chat:catalog') applyCatalog(item.data || {});
        if (item.type === 'ck_chat:channelJoinResult') applyChannelJoinResult(item.data || {});
        if (item.type === 'ck_chat:suggestion:add') addSuggestion(item.suggestion);
        if (item.type === 'ck_chat:suggestion:addMany') (item.suggestions || []).forEach(addSuggestion);
        if (item.type === 'ck_chat:suggestion:remove') removeSuggestion(item.name);
        if (item.type === 'ck_chat:clear') clearMessages();
        if (item.type === 'ck_chat:visibility') {
            state.hidden = Boolean(item.hidden);
            updateShell();
            resetIdleTimer();
        }
        if (item.type === 'ck_chat:screen') {
            state.screenHidden = Boolean(item.hidden);
            updateShell();
            resetIdleTimer();
        }
        if (item.type === 'ck_chat:open') showInput();
    }

    function applyBootstrap(data) {
        state.me = data.me || state.me || {};
        state.onlinePlayers = Array.isArray(data.onlinePlayers) ? data.onlinePlayers : [];
        const catalogs = data.catalogs || {};
        if (catalogs.item || catalogs.items) {
            state.catalogs.item = normaliseCatalog(catalogs.item || catalogs.items);
            markCatalogLoaded('item', '', state.catalogs.item, true);
        }
        if (catalogs.vehicle || catalogs.vehicles) {
            state.catalogs.vehicle = normaliseCatalog(catalogs.vehicle || catalogs.vehicles);
            markCatalogLoaded('vehicle', '', state.catalogs.vehicle, true);
        }
        state.presetChannels = normalisePresetChannels(data.channels && data.channels.presets);
        ensureCustomSelection();
        renderCustomRoute();
        renderPrivateTargets();
        renderLinkPicker();
        renderMessages();
        renderSuggestions();
    }

    function applyCatalog(data) {
        const source = data.source === 'vehicle' ? 'vehicle' : 'item';
        const catalog = normaliseCatalog(data.catalog || {});
        state.catalogs[source] = mergeCatalog(source, catalog);
        markCatalogLoaded(source, data.category || '', catalog, Boolean(data.full));
        if (source === state.linkSource) {
            const category = String(data.category || '');
            if (category && (!state.linkCategory || !catalog.categories.some((item) => String(item.id) === String(state.linkCategory)))) {
                state.linkCategory = category;
                state.linkValue = '';
            }
            renderLinkPicker();
        }
    }

    function normalisePresetChannels(channels) {
        const source = Array.isArray(channels) ? channels : DEFAULT_PRESET_CHANNELS;
        return source
            .map((item) => ({
                id: clampUiText(item && item.id, 40),
                label: clampUiText(item && item.label, 20),
                requireJob: item && item.requireJob !== false
            }))
            .filter((item) => item.id && item.label)
            .slice(0, 12);
    }

    function findPresetChannel(id) {
        return state.presetChannels.find((item) => String(item.id) === String(id || '')) || null;
    }

    function applyChannelJoinResult(data) {
        if (!data.ok) {
            addLocalSystemMessage('频道', data.message || '无法加入频道', 'warning');
            return;
        }
        state.customChannel = clampUiText(data.label || data.customChannel || '', 20);
        state.customChannelId = clampUiText(data.id || data.customChannelId || '', 40);
        if (state.customChannelId) {
            state.customMode = 'preset';
            state.customPendingId = state.customChannelId;
        } else {
            state.customMode = 'custom';
            state.customDraft = state.customChannel;
            refs.customChannel.value = state.customChannel;
        }
        renderCustomRoute();
        updateRouteLabel();
        addLocalSystemMessage('频道', `加入成功：${state.customChannel}`, 'success');
        clearUnread('custom');
        renderChannels();
        renderMessages();
        refs.messageInput.focus();
    }

    function normaliseCatalog(catalog) {
        const items = Array.isArray(catalog && catalog.items) ? catalog.items : [];
        const categories = Array.isArray(catalog && catalog.categories) ? catalog.categories.slice() : [];
        const known = new Set(categories.map((item) => String(item.id)));
        items.forEach((item) => {
            const id = String(item.type || '');
            if (id && !known.has(id)) {
                categories.push({ id, label: item.typeLabel || id });
                known.add(id);
            }
        });
        return {
            categories,
            items
        };
    }

    function linkItemIdForSource(source, item) {
        if (source === 'vehicle') {
            return String(item.id || item.vin || item.ck_veh_vin || (item.plate ? `${item.model}:${item.plate}` : item.model) || '');
        }
        return String(item.id || item.objId || item.name || '');
    }

    function mergeCatalog(source, incoming) {
        const current = normaliseCatalog(state.catalogs[source]);
        incoming = normaliseCatalog(incoming);

        const categoryMap = new Map();
        current.categories.concat(incoming.categories).forEach((category) => {
            const id = String(category.id || '');
            if (id) categoryMap.set(id, category);
        });

        const itemMap = new Map();
        current.items.concat(incoming.items).forEach((item) => {
            const id = linkItemIdForSource(source, item);
            if (id) itemMap.set(id, item);
        });

        return {
            categories: Array.from(categoryMap.values()),
            items: Array.from(itemMap.values())
        };
    }

    function markCatalogLoaded(source, category, catalog, fullCatalog) {
        state.catalogRequested[source].__default = true;
        if (category) {
            state.catalogRequested[source][String(category)] = true;
        }
        if (fullCatalog) {
            (catalog.categories || []).forEach((item) => {
                if (item.id) state.catalogRequested[source][String(item.id)] = true;
            });
        }
    }

    function addMessage(message) {
        if (!message) return;
        state.idleHidden = false;
        state.messages.push(message);
        if (state.messages.length > MAX_MESSAGES) {
            state.messages.shift();
        }
        markUnread(message);
        renderMessages();
        resetIdleTimer();
    }

    function setMessages(messages) {
        state.messages = messages.slice(-MAX_MESSAGES);
        state.unread = { global: 0, private: 0, custom: 0 };
        renderChannels();
        renderMessages();
        resetIdleTimer();
    }

    function clearMessages() {
        state.messages = [];
        state.unread = { global: 0, private: 0, custom: 0 };
        renderChannels();
        renderMessages();
        resetIdleTimer();
    }

    function addSuggestion(suggestion) {
        if (!suggestion || !suggestion.name) return;
        suggestion.params = Array.isArray(suggestion.params) ? suggestion.params : [];
        const existing = state.suggestions.find((item) => item.name === suggestion.name);
        if (existing) {
            if (!suggestion.help && suggestion.params.length === 0) {
                suggestion.help = existing.help || '';
                suggestion.params = existing.params || [];
            }
            if (existing.adminOnly && suggestion.adminOnly === undefined) {
                suggestion.adminOnly = true;
            }
        }
        state.suggestions = state.suggestions.filter((item) => item.name !== suggestion.name);
        state.suggestions.push(suggestion);
        state.suggestions.sort((a, b) => a.name.localeCompare(b.name));
        renderSuggestions();
    }

    function removeSuggestion(name) {
        state.suggestions = state.suggestions.filter((item) => item.name !== name);
        renderSuggestions();
    }

    function isSystemMessage(message) {
        const body = message && message.body || {};
        const channel = message && message.channel || {};
        return body.type === 'system' || channel.system === true || String(channel.id || '') === 'system';
    }

    function messageBucket(message) {
        if (isSystemMessage(message)) return 'system';
        const channel = message && message.channel || {};
        const id = String(channel.id || '').toLowerCase();
        if (id === 'private') return 'private';
        if (id === 'custom' || id.indexOf('custom:') === 0 || channel.presetId) return 'custom';
        return 'global';
    }

    function isCurrentCustomMessage(message) {
        const channel = message && message.channel || {};
        const currentId = String(state.customChannelId || '');
        const currentLabel = String(state.customChannel || '');
        if (!currentId && !currentLabel) return false;

        const id = String(channel.id || '');
        const presetId = String(channel.presetId || '');
        const label = String(channel.label || '');
        const rawId = id.replace(/^custom:/i, '');

        if (currentId && presetId && currentId === presetId) return true;
        if (currentId && (currentId === rawId || currentId === id)) return true;
        return Boolean(currentLabel && (currentLabel === label || currentLabel === rawId || currentLabel === id));
    }

    function shouldRenderMessage(message) {
        if (isSystemMessage(message)) return true;
        const body = message && message.body || {};
        const bucket = messageBucket(message);
        if (bucket === 'private' && body.type === 'redpacket') return false;
        if (bucket !== state.channel) return false;
        if (bucket === 'custom') return isCurrentCustomMessage(message);
        return true;
    }

    function markUnread(message) {
        const bucket = messageBucket(message);
        if (!(bucket in state.unread)) return;
        if (bucket === state.channel && shouldRenderMessage(message)) return;
        if (bucket === 'custom' && !isCurrentCustomMessage(message)) return;
        state.unread[bucket] += 1;
        renderChannels();
    }

    function renderMessages() {
        if (!refs.messageList) return;
        hideDetailFloat();
        refs.messageList.innerHTML = '';
        state.messages
            .filter(shouldRenderMessage)
            .forEach((message) => refs.messageList.appendChild(createMessageNode(message)));
        refs.messageList.scrollTop = refs.messageList.scrollHeight;
    }

    function createMessageNode(message) {
        const body = message.body || {};
        if (body.type === 'system' || (message.channel && message.channel.id === 'system')) {
            return createSystemNode(message);
        }

        const row = document.createElement('div');
        row.className = 'message';
        const sender = message.sender || {};
        const chatFrameId = senderChatFrameId(sender);
        if (String(sender.id) === String(state.me && state.me.id)) {
            row.classList.add('mine');
        }
        if (chatFrameId) {
            row.classList.add('has-avatar-frame');
            row.dataset.chatFrameId = chatFrameId;
        }

        row.appendChild(createAvatar(sender));

        const card = document.createElement('div');
        card.className = 'message-card';
        applyChatBoxFrame(card, sender);
        card.appendChild(createMessageHead(message));

        if (body.type === 'text' && body.text) {
            const text = document.createElement('div');
            text.className = 'message-text';
            appendColoredText(text, body.text);
            card.appendChild(text);
        }
        if (body.type === 'image') {
            if (body.text) {
                const text = document.createElement('div');
                text.className = 'message-text';
                appendColoredText(text, body.text);
                card.appendChild(text);
            }
            if (body.image) {
                card.appendChild(createImageCard(body.image));
            }
        }
        if (body.type === 'link' && body.link) {
            card.appendChild(createLinkCard(body.link));
        }
        if (body.type === 'position' && body.position) {
            card.appendChild(createPositionCard(body.position));
        }
        if (body.type === 'redpacket' && body.redPacket) {
            card.appendChild(createRedPacketCard(body));
        }

        row.appendChild(card);
        return row;
    }

    function createSystemNode(message) {
        const body = message.body || {};
        const row = document.createElement('div');
        row.className = 'message system-message';
        const card = document.createElement('div');
        card.className = `system-card ${body.level || ''}`;

        const title = document.createElement('div');
        title.className = 'system-title';
        title.textContent = body.title || (message.sender && message.sender.name) || '系统提示';

        const text = document.createElement('div');
        text.className = 'system-text';
        text.textContent = body.text || '';

        card.append(title, text);
        row.appendChild(card);
        return row;
    }

    function createAvatar(sender) {
        const avatar = document.createElement('div');
        avatar.className = 'avatar';
        applyAvatarFrame(avatar, sender);
        if (sender.avatar) {
            const img = document.createElement('img');
            img.src = sender.avatar;
            img.alt = '';
            img.onerror = () => {
                img.remove();
                avatar.appendChild(createFallback(sender.name));
            };
            avatar.appendChild(img);
        } else {
            avatar.appendChild(createFallback(sender.name));
        }
        return avatar;
    }

    function frameAssetId(value) {
        const id = String(value || '').trim().replace(/\.(webp|png|jpg|jpeg|gif)$/i, '');
        if (!id || id === '0' || /[\\/]/.test(id) || id.includes('..')) return '';
        return id;
    }

    function frameImageUrls(folder, id) {
        const cleanId = frameAssetId(id);
        if (!cleanId) return [];
        const base = `${FRAME_IMAGE_ROOT}/${folder}/${cleanId.replace(/"/g, '\\"')}`;
        return FRAME_EXTENSIONS.map((ext) => `${base}.${ext}`);
    }

    function createFrameImage(folder, id, className) {
        const urls = frameImageUrls(folder, id);
        if (!urls.length) return null;

        const image = document.createElement('img');
        let index = 0;
        image.className = className;
        image.alt = '';
        image.draggable = false;
        image.onerror = () => {
            index += 1;
            if (index < urls.length) {
                image.src = urls[index];
            } else {
                image.remove();
            }
        };
        image.src = urls[index];
        return image;
    }

    function applyAvatarFrame(target, sender) {
        const id = senderChatFrameId(sender);
        const frameImage = createFrameImage('txk', id, 'avatar-frame-img');
        if (frameImage) {
            target.appendChild(frameImage);
            target.classList.add('has-avatar-frame');
            target.dataset.chatFrameId = id;
            target.title = id;
        }
    }

    function senderChatFrameId(sender) {
        return frameAssetId((sender || {}).chatFrameId);
    }

    function applyChatBoxFrame(target, sender) {
        const id = (sender || {}).chatBoxFrameId;
        const frameImage = createFrameImage('ltk', id, 'chat-box-frame-img');
        if (frameImage) {
            const cleanId = frameAssetId(id);
            target.appendChild(frameImage);
            target.classList.add('has-chat-box-frame');
            target.dataset.chatBoxFrameId = cleanId;
            target.title = cleanId;
        }
    }

    function createFallback(name) {
        const fallback = document.createElement('div');
        fallback.className = 'avatar-fallback';
        fallback.textContent = (name || 'U').trim().slice(0, 1).toUpperCase();
        return fallback;
    }

    function createMessageHead(message) {
        const head = document.createElement('div');
        head.className = 'message-head';
        const sender = message.sender || {};

        const name = document.createElement('div');
        name.className = 'sender-name';
        name.textContent = sender.name || '玩家';
        head.appendChild(name);

        if (sender.level) head.appendChild(tag(`Lv.${sender.level}`, 'level'));
        if (sender.gang) head.appendChild(tag(sender.gang, 'gang'));
        if (message.channel && message.channel.label) head.appendChild(tag(message.channel.label, 'channel'));

        const time = document.createElement('div');
        time.className = 'message-time';
        time.textContent = formatTime(message.ts);
        head.appendChild(time);
        return head;
    }

    function tag(text, className) {
        const item = document.createElement('span');
        item.className = `tag ${className || ''}`;
        item.textContent = text;
        return item;
    }

    function appendColoredText(target, text) {
        const source = String(text || '');
        let currentClass = '';
        let buffer = '';
        for (let i = 0; i < source.length; i += 1) {
            if (source[i] === '^' && i + 1 < source.length) {
                flush();
                const code = source[i + 1];
                if (/^[0-9]$/.test(code)) currentClass = `color-${code}`;
                if (code === 'r') currentClass = '';
                i += 1;
            } else {
                buffer += source[i];
            }
        }
        flush();

        function flush() {
            if (!buffer) return;
            const span = document.createElement('span');
            if (currentClass) span.className = currentClass;
            span.textContent = buffer;
            target.appendChild(span);
            buffer = '';
        }
    }

    function createLinkCard(link) {
        const card = document.createElement('div');
        card.className = 'rich-card link-card';
        card.tabIndex = 0;
        card.setAttribute('role', 'button');

        const imageUrl = linkImageFromLink(link);
        const bgUrl = linkBgFromLink(link);
        const main = document.createElement('div');
        main.className = imageUrl ? 'link-card-main has-image' : 'link-card-main';

        if (imageUrl) {
            const img = document.createElement('img');
            img.className = 'link-card-img';
            img.src = imageUrl;
            img.alt = link.title || '内容链接';
            img.referrerPolicy = 'no-referrer';
            applyImageBg(img, bgUrl);
            main.appendChild(img);
        }

        const content = document.createElement('div');
        content.className = 'link-card-content';

        const type = document.createElement('div');
        type.className = 'rich-type';
        type.textContent = linkTypeLabel(link.linkType);

        const title = document.createElement('div');
        title.className = 'rich-title';
        title.textContent = link.title || '内容链接';

        const subtitle = document.createElement('div');
        subtitle.className = 'rich-subtitle';
        subtitle.textContent = link.subtitle || '';

        content.append(type, title, subtitle);
        main.appendChild(content);
        card.appendChild(main);

        const details = detailsFromLink(link);
        if (details.length > 0) {
            card.classList.add('has-details');
            const hint = document.createElement('div');
            hint.className = 'rich-hint';
            hint.textContent = '点击查看详细信息';
            card.appendChild(hint);
            bindDetailFloat(card, link);
        }
        return card;
    }

    function createImageCard(image) {
        const card = document.createElement('div');
        card.className = 'rich-card image-card';

        const type = document.createElement('div');
        type.className = 'rich-type';
        type.textContent = '收藏图片';

        const img = document.createElement('img');
        img.src = image.url || '';
        img.alt = image.name || '收藏图片';
        img.referrerPolicy = 'no-referrer';

        const action = document.createElement('button');
        action.type = 'button';
        action.className = 'card-action';
        const alreadySaved = isFavoriteImage(image.url);
        action.textContent = alreadySaved ? '已收藏' : '收藏';
        action.disabled = alreadySaved;
        action.addEventListener('click', (event) => {
            event.preventDefault();
            event.stopPropagation();
            if (saveFavoriteImage(image.url, '收藏图片')) {
                action.textContent = '已收藏';
                action.disabled = true;
            }
        });

        card.append(type, img, action);
        return card;
    }

    function detailsFromLink(link) {
        if (Array.isArray(link.details) && link.details.length > 0) {
            return link.details;
        }
        const payload = link.payload || {};
        if (Array.isArray(payload.details) && payload.details.length > 0) {
            return payload.details;
        }
        return objectDetails(link.meta || payload.meta || {});
    }

    function objectDetails(source) {
        return Object.keys(source || {})
            .filter((key) => source[key] !== null && source[key] !== undefined && typeof source[key] !== 'object' && String(source[key]) !== '')
            .map((key) => ({ key, label: key, value: String(source[key]) }));
    }

    function createDetailPopover(link) {
        const details = detailsFromLink(link);
        const popover = document.createElement('div');
        popover.className = 'detail-popover';

        const imageUrl = linkImageFromLink(link);
        const bgUrl = linkBgFromLink(link);
        const hero = document.createElement('div');
        hero.className = imageUrl ? 'detail-hero has-image' : 'detail-hero';
        if (imageUrl) {
            const img = document.createElement('img');
            img.className = 'detail-hero-img';
            img.src = imageUrl;
            img.alt = link.title || '内容链接';
            img.referrerPolicy = 'no-referrer';
            applyImageBg(img, bgUrl);
            hero.appendChild(img);
        }

        const heroText = document.createElement('div');
        heroText.className = 'detail-hero-text';
        const type = document.createElement('div');
        type.className = 'detail-hero-type';
        type.textContent = linkTypeLabel(link.linkType);
        const title = document.createElement('div');
        title.className = 'detail-hero-title';
        title.textContent = link.title || '内容链接';
        const subtitle = document.createElement('div');
        subtitle.className = 'detail-hero-subtitle';
        subtitle.textContent = link.subtitle || '';
        heroText.append(type, title, subtitle);
        hero.appendChild(heroText);
        popover.appendChild(hero);

        const section = document.createElement('div');
        section.className = 'detail-section';
        details.forEach((detail) => {
            const row = document.createElement('div');
            row.className = 'detail-row';
            const label = document.createElement('span');
            label.className = 'detail-label';
            label.textContent = detail.label || detail.key || '';
            const value = document.createElement('span');
            value.className = 'detail-value';
            value.textContent = String(detail.value ?? '');
            row.append(label, value);
            section.appendChild(row);
        });
        popover.appendChild(section);
        return popover;
    }

    function bindDetailFloat(anchor, link) {
        anchor.addEventListener('click', (event) => {
            event.stopPropagation();
            toggleDetailFloat(anchor, link);
        });
        anchor.addEventListener('keydown', (event) => {
            if (event.key !== 'Enter' && event.key !== ' ') return;
            event.preventDefault();
            event.stopPropagation();
            toggleDetailFloat(anchor, link);
        });
    }

    function toggleDetailFloat(anchor, link) {
        if (activeDetailFloat && activeDetailFloat.anchor === anchor) {
            hideDetailFloat();
            return;
        }
        showDetailFloat(anchor, link);
    }

    function showDetailFloat(anchor, link) {
        hideDetailFloat();
        const details = detailsFromLink(link);
        if (!anchor || !details || details.length === 0) return;

        const popover = createDetailPopover(link);
        popover.classList.add('detail-float');
        document.body.appendChild(popover);
        activeDetailFloat = popover;
        activeDetailFloat.anchor = anchor;
        anchor.classList.add('detail-open');

        const gap = 10;
        const margin = 8;
        const chat = anchor.closest('.ck-chat') || document.querySelector('.ck-chat') || anchor;
        const chatWindow = chat.querySelector ? chat.querySelector('.chat-window') : null;
        const rect = (chatWindow || chat).getBoundingClientRect();
        const width = popover.offsetWidth;
        const height = popover.offsetHeight;
        let left = rect.left - width - gap;
        left = Math.max(margin, Math.min(left, window.innerWidth - width - margin));

        let top = rect.top;
        if (top + height > window.innerHeight - margin) {
            top = window.innerHeight - height - margin;
        }
        top = Math.max(margin, top);

        popover.style.transform = `translate(${Math.round(left)}px, ${Math.round(top)}px)`;
    }

    function hideDetailFloat() {
        if (!activeDetailFloat) return;
        if (activeDetailFloat.anchor) {
            activeDetailFloat.anchor.classList.remove('detail-open');
        }
        activeDetailFloat.remove();
        activeDetailFloat = null;
    }

    function handleDocumentClick(event) {
        if (!activeDetailFloat) return;
        if (activeDetailFloat.contains(event.target)) return;
        if (activeDetailFloat.anchor && activeDetailFloat.anchor.contains(event.target)) return;
        hideDetailFloat();
    }

    function createPositionCard(position) {
        const card = document.createElement('div');
        card.className = 'rich-card position-card';
        const type = document.createElement('div');
        type.className = 'rich-type';
        type.textContent = '位置';
        const title = document.createElement('div');
        title.className = 'rich-title';
        title.textContent = position.label || '当前位置';
        const subtitle = document.createElement('div');
        subtitle.className = 'rich-subtitle';
        subtitle.textContent = `${position.x}, ${position.y}, ${position.z}`;
        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'card-action';
        button.textContent = '地图打标';
        button.addEventListener('click', () => post('action', { action: 'gotoPosition', id: position.id }));
        card.append(type, title, subtitle, button);
        return card;
    }

    function createRedPacketCard(body) {
        const packet = body.redPacket || {};
        const card = document.createElement('div');
        card.className = 'rich-card redpacket-card';
        const type = document.createElement('div');
        type.className = 'rich-type';
        type.textContent = '红包';
        const title = document.createElement('div');
        title.className = 'rich-title';
        title.textContent = body.text || '恭喜发财';
        const subtitle = document.createElement('div');
        subtitle.className = 'rich-subtitle';
        subtitle.textContent = `$${packet.amount || 0} / ${packet.count || 0} 份`;
        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'card-action';
        button.textContent = '抢红包';
        button.addEventListener('click', () => post('action', { action: 'claimRedPacket', id: packet.id }));
        card.append(type, title, subtitle, button);
        return card;
    }

    function linkTypeLabel(type) {
        const map = { item: '背包道具', vehicle: '载具', task: '任务', custom: '内容' };
        return map[type] || type || '内容';
    }

    function formatTime(ts) {
        const date = ts ? new Date(ts * 1000) : new Date();
        return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
    }

    function renderSuggestions() {
        const text = refs.messageInput ? refs.messageInput.value.trimStart() : '';
        refs.suggestions.innerHTML = '';
        if (!text.startsWith('/')) {
            refs.suggestions.classList.remove('open');
            return;
        }
        const keyword = text.split(/\s+/)[0].toLowerCase();
        const suggestions = state.suggestions
            .filter((item) => !item.adminOnly || Boolean(state.me && state.me.isAdmin))
            .filter((item) => item.name.toLowerCase().startsWith(keyword))
            .slice(0, 8);
        suggestions.forEach((item) => {
            const row = document.createElement('div');
            row.className = 'suggestion';
            const params = (item.params || []).map(formatSuggestionParam).join(' ');
            row.innerHTML = '<strong></strong> <span></span>';
            row.querySelector('strong').textContent = item.name;
            row.querySelector('span').textContent = `${params}  ${item.help || ''}`;
            row.addEventListener('click', () => {
                refs.messageInput.value = `${item.name} `;
                refs.messageInput.focus();
                resizeInput();
                renderSuggestions();
            });
            refs.suggestions.appendChild(row);
        });
        refs.suggestions.classList.toggle('open', suggestions.length > 0);
    }

    function formatSuggestionParam(param) {
        if (typeof param === 'string') return `[${param}]`;
        const name = param && param.name ? String(param.name) : '';
        const help = param && param.help ? String(param.help) : '';
        if (!name) return '';
        return help ? `[${name}: ${help}]` : `[${name}]`;
    }

    window.CKChat = { receive };
    document.addEventListener('DOMContentLoaded', init);
}());
