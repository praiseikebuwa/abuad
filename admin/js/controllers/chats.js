class ChatsController {
    constructor() {
        this.tableBody = document.querySelector('#chats-table tbody');
        this.channels = [];
        this.filteredChannels = [];

        this.searchInput = document.getElementById('chats-search');
        this.filterSelect = document.getElementById('chats-filter');
        this.countBadge = document.getElementById('chats-count-badge');
        this.refreshBtn = document.getElementById('chats-refresh-btn');

        if (this.searchInput) {
            this.searchInput.addEventListener('input', () => this.applyFilters());
        }

        if (this.filterSelect) {
            this.filterSelect.addEventListener('change', () => this.applyFilters());
        }

        if (this.refreshBtn) {
            this.refreshBtn.addEventListener('click', () => this.load());
        }
    }

    load() {
        this.tableBody.innerHTML = '<tr><td colspan="5" class="loading-text"><i class="fas fa-spinner fa-spin"></i> Loading active channels...</td></tr>';

        if (this.unsubscribe) this.unsubscribe();

        this.unsubscribe = db.collection('channels')
            .orderBy('last_message_time', 'desc')
            .limit(60)
            .onSnapshot(snap => {
                this.channels = [];
                snap.forEach(doc => {
                    this.channels.push({ id: doc.id, ...doc.data() });
                });
                this.applyFilters();
            }, err => {
                this.tableBody.innerHTML = `<tr><td colspan="5" class="error-text">Error: ${err.message}</td></tr>`;
            });
    }

    applyFilters() {
        const query = (this.searchInput?.value || '').toLowerCase().trim();
        const filterType = this.filterSelect?.value || 'all';

        this.filteredChannels = this.channels.filter(chat => {
            const channelId = chat.id.toLowerCase();
            const channelName = (chat.name || chat.title || '').toLowerCase();
            const members = (chat.member_ids || []).join(' ').toLowerCase();

            const matchesQuery = !query || channelId.includes(query) || channelName.includes(query) || members.includes(query);
            if (!matchesQuery) return false;

            const isGroup = !!(chat.is_group || (chat.member_ids && chat.member_ids.length > 2) || chat.name);
            if (filterType === 'group' && !isGroup) return false;
            if (filterType === 'direct' && isGroup) return false;

            return true;
        });

        if (this.countBadge) {
            this.countBadge.textContent = `${this.filteredChannels.length} Channels`;
        }

        this.render();
    }

    render() {
        this.tableBody.innerHTML = '';
        if (this.filteredChannels.length === 0) {
            this.tableBody.innerHTML = '<tr><td colspan="5" style="text-align:center; padding:30px; color:var(--text-muted)">No active chat channels found matching your filter.</td></tr>';
            return;
        }

        this.filteredChannels.forEach(chat => {
            const lastMsg = chat.last_message || {};
            const isGroup = !!(chat.is_group || (chat.member_ids && chat.member_ids.length > 2) || chat.name);
            const isLocked = !!(chat.is_locked || chat.isLocked);

            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td>
                    <div style="display:flex; align-items:center; gap:8px;">
                        <span class="badge ${isGroup ? 'badge-primary' : 'badge-gray'}" style="font-size:11px;">
                            <i class="${isGroup ? 'fas fa-users' : 'fas fa-user'}"></i> ${isGroup ? 'Group' : 'DM'}
                        </span>
                        <strong style="color:var(--text-primary); font-size:0.9rem;">${chat.name || `Chat #${chat.id.substring(0, 8)}`}</strong>
                        ${isLocked ? '<span class="badge" style="background:rgba(239,68,68,0.2); color:#f87171; border:1px solid rgba(239,68,68,0.4); font-size:10px;"><i class="fas fa-lock"></i> Locked</span>' : ''}
                    </div>
                    <small style="color:var(--text-secondary); font-family:monospace;">ID: ${chat.id.substring(0, 16)}...</small>
                </td>
                <td>
                    <div style="font-weight: 600; color:var(--text-primary);">${chat.member_ids ? chat.member_ids.length : '?'} Participants</div>
                    <small style="color: var(--text-secondary)">
                        ${chat.member_ids ? `${chat.member_ids.slice(0, 3).map(id => id.substring(0, 6)).join(', ')}${chat.member_ids.length > 3 ? '...' : ''}` : 'No members'}
                    </small>
                </td>
                <td>
                    <div class="message-preview" style="max-width:260px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; color:var(--text-primary); font-size:0.88rem;">
                        ${lastMsg.content || (lastMsg.type ? `[${lastMsg.type.toUpperCase()}]` : '<i style="color:var(--text-muted)">No recent messages</i>')}
                    </div>
                    <small style="color: var(--text-secondary)"><i class="far fa-clock"></i> ${this.formatTime(chat.last_message_time)}</small>
                </td>
                <td style="text-align: right;">
                    <div style="display: inline-flex; gap: 6px;">
                        <button class="btn btn-secondary" onclick="window.chatsController.openChatSpy('${chat.id}', '${(chat.name || 'Channel').replace(/'/g, "\\'")}')" 
                                style="padding: 5px 10px; font-size: 0.78rem; display:inline-flex; align-items:center; gap:6px;">
                            <i class="fas fa-eye" style="color: #0284c7;"></i> Spy
                        </button>
                        <button class="btn btn-secondary" onclick="window.chatsController.toggleLockChannel('${chat.id}')"
                                title="${isLocked ? 'Unlock Channel' : 'Freeze / Lock Channel'}"
                                style="padding: 5px 10px; font-size: 0.78rem; color: ${isLocked ? '#f87171' : 'var(--text-secondary)'};">
                            <i class="fas ${isLocked ? 'fa-lock-open' : 'fa-lock'}"></i>
                        </button>
                        <button class="btn-icon btn-delete" 
                                onclick="window.chatsController.deleteChat('${chat.id}')"
                                title="Delete Channel">
                            <i class="fas fa-trash"></i>
                        </button>
                    </div>
                </td>
            `;
            this.tableBody.appendChild(tr);
        });
    }

    async toggleLockChannel(channelId) {
        const chat = this.channels.find(c => c.id === channelId);
        if (!chat) return;
        const current = !!(chat.is_locked || chat.isLocked);
        const nextState = !current;

        try {
            await db.collection('channels').doc(channelId).update({
                is_locked: nextState,
                isLocked: nextState
            });
            window.logAdminAction('LOCK_CHANNEL', `Admin ${nextState ? 'locked' : 'unlocked'} channel ${channelId}`, 'channel', channelId);
            chat.is_locked = nextState;
            chat.isLocked = nextState;
            this.render();
            alert(`Channel has been ${nextState ? 'FROZEN & LOCKED' : 'UNLOCKED'}.`);
        } catch (e) {
            alert("Error toggling channel lock: " + e.message);
        }
    }

    openChatSpy(channelId, channelName) {
        // Create Modal
        let modal = document.getElementById('chat-spy-modal');
        if (!modal) {
            modal = document.createElement('div');
            modal.id = 'chat-spy-modal';
            modal.className = 'modal-overlay';
            modal.innerHTML = `
                <div class="modal-content" style="width: 580px; height: 750px; display: flex; flex-direction: column; background: #000; border: 1px solid var(--border-glass);">
                    <div class="modal-header" style="border-bottom: 1px solid var(--border-subtle); padding: 16px 20px;">
                        <div>
                            <h2 style="display:flex; align-items:center; gap:8px; font-size:1.2rem;">🕵️ Administrative Channel Spy</h2>
                            <small id="spy-channel-id" style="color:var(--text-secondary); font-family:monospace;"></small>
                        </div>
                        <button onclick="window.chatsController.closeSpy()" class="btn-close">&times;</button>
                    </div>
                    <div id="spy-messages" class="modal-body spy-messages-container" style="flex: 1; overflow-y: auto; padding: 20px; background: rgba(0,0,0,0.4);">
                        <div class="loading-spinner"></div>
                    </div>
                    <div class="modal-footer" style="display:flex; justify-content:space-between; align-items:center; border-top: 1px solid var(--border-subtle); padding: 14px 20px;">
                        <span class="badge" style="background:rgba(16,185,129,0.2); color:#34d399; border:1px solid rgba(16,185,129,0.3); font-size:11px;">
                            <i class="fas fa-satellite-dish fa-spin"></i> Live Campus Stream
                        </span>
                        <button class="btn btn-secondary" onclick="window.chatsController.closeSpy()" style="padding: 6px 14px; font-size: 0.85rem;">Close Inspector</button>
                    </div>
                </div>
            `;
            document.body.appendChild(modal);
        }

        modal.style.display = 'flex';
        document.getElementById('spy-channel-id').innerText = `${channelName || 'Channel'} • ID: ${channelId}`;
        const container = document.getElementById('spy-messages');
        container.innerHTML = '<div class="loading-text"><i class="fas fa-spinner fa-spin"></i> Establishing administrative oversight tap...</div>';

        const userCache = {};

        if (this.spyUnsubscribe) this.spyUnsubscribe();

        this.spyUnsubscribe = db.collection('channels').doc(channelId).collection('messages')
            .orderBy('timestamp', 'asc')
            .limit(100)
            .onSnapshot(async snap => {
                if (snap.empty) {
                    container.innerHTML = '<div class="no-data" style="text-align:center; margin-top:80px; color:var(--text-muted);"><i class="fas fa-comment-slash" style="font-size:2rem; margin-bottom:10px; display:block;"></i>No messages recorded in this channel yet.</div>';
                    return;
                }

                const messagesFragment = document.createDocumentFragment();
                
                for (const doc of snap.docs) {
                    const msg = doc.data();
                    const senderId = msg.senderId || msg.sender_id || 'system';
                    
                    if (senderId !== 'system' && !userCache[senderId]) {
                        try {
                            const userDoc = await db.collection('users').doc(senderId).get();
                            userCache[senderId] = userDoc.exists ? (userDoc.data().displayName || userDoc.data().name) : `User (${senderId.substring(0,4)})`;
                        } catch (e) {
                            userCache[senderId] = `User (${senderId.substring(0,4)})`;
                        }
                    }

                    const div = document.createElement('div');
                    div.className = 'chat-bubble received';
                    div.style.background = 'rgba(255,255,255,0.05)';
                    div.style.border = '1px solid rgba(255,255,255,0.08)';
                    div.style.borderRadius = '12px';
                    div.style.padding = '10px 14px';
                    div.style.marginBottom = '10px';
                    
                    const time = this.formatTime(msg.timestamp || msg.created_at);

                    div.innerHTML = `
                        <div class="bubble-meta" style="display:flex; justify-content:space-between; margin-bottom:4px; font-size:0.75rem;">
                            <span style="font-weight:700; color:var(--color-primary-light);">${userCache[senderId] || 'System'}</span>
                            <span style="color:var(--text-secondary);">${time}</span>
                        </div>
                        <div class="bubble-content" style="color:var(--text-primary); font-size:0.9rem; word-break:break-word;">
                            ${msg.type === 'image' || msg.imageUrl ? `<img src="${msg.imageUrl || msg.content}" alt="Attachment" style="max-width:100%; border-radius:8px; margin-top:4px;">` :
                              msg.type === 'voice' ? `<div style="display:flex; align-items:center; gap:8px;"><i class="fas fa-microphone" style="color:var(--color-accent-amber);"></i> Voice Note (${msg.duration || '?'}s)</div>` :
                              msg.type === 'video' ? `<div style="display:flex; align-items:center; gap:8px;"><i class="fas fa-video" style="color:var(--color-primary-light);"></i> Video Note</div>` :
                              (msg.content || '<i style="color:var(--text-muted)">Empty message</i>')}
                        </div>
                    `;
                    messagesFragment.appendChild(div);
                }

                container.innerHTML = '';
                container.appendChild(messagesFragment);
                container.scrollTop = container.scrollHeight;
            }, err => {
                container.innerHTML = `<div class="error-text">Failed to load stream: ${err.message}</div>`;
            });
    }

    closeSpy() {
        if (this.spyUnsubscribe) this.spyUnsubscribe();
        const modal = document.getElementById('chat-spy-modal');
        if (modal) modal.style.display = 'none';
    }

    deleteChat(channelId) {
        if (confirm("Permanently delete this chat channel and all stored message history?")) {
            db.collection('channels').doc(channelId).delete()
                .then(() => {
                    window.logAdminAction('DELETE_CHANNEL', `Admin deleted channel ${channelId}`, 'channel', channelId);
                    this.closeSpy();
                })
                .catch(err => alert("Error deleting channel: " + err.message));
        }
    }

    formatTime(timestamp) {
        if (!timestamp) return 'N/A';
        const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
        return date.toLocaleString(undefined, {
            hour: '2-digit', minute: '2-digit', month: 'short', day: 'numeric'
        });
    }
}

