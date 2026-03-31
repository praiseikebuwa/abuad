class ChatsController {
    constructor() {
        this.tableBody = document.querySelector('#chats-table tbody');
    }

    load() {
        this.tableBody.innerHTML = '<tr><td colspan="4" class="loading-text">Loading active channels...</td></tr>';

        // Assuming 'channels' collection
        if (this.unsubscribe) this.unsubscribe();

        this.unsubscribe = db.collection('channels')
            .orderBy('last_message_time', 'desc')
            .limit(50)
            .onSnapshot(snap => {
                this.render(snap);
            }, err => {
                this.tableBody.innerHTML = `<tr><td colspan="4" class="error-text">Error: ${err.message}</td></tr>`;
            });
    }

    render(snap) {
        this.tableBody.innerHTML = '';
        if (snap.empty) {
            this.tableBody.innerHTML = '<tr><td colspan="4">No active chats.</td></tr>';
            return;
        }

        snap.forEach(doc => {
            const chat = doc.data();
            const lastMsg = chat.last_message || {};

            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td>
                    <span class="id-pill" title="${doc.id}">${doc.id.substring(0, 8)}...</span>
                </td>
                <td>
                    <div style="font-weight: 500">${chat.member_ids ? chat.member_ids.length : '?'} Participants</div>
                    <small style="color: #666">
                        ${chat.member_ids ? chat.member_ids.map(id => id.substring(0, 5)).join(', ') : ''}
                    </small>
                </td>
                <td>
                    <div class="message-preview">
                        ${lastMsg.content || (lastMsg.type ? `[${lastMsg.type}]` : '<i style="color:#aaa">Empty</i>')}
                    </div>
                    <small style="color: #999">${this.formatTime(chat.last_message_time)}</small>
                </td>
                <td>
                    <button class="btn-action btn-view" onclick="window.chatsController.openChatSpy('${doc.id}')" style="background:#e3f2fd; color: #1976d2; margin-right:5px;">
                        <i class="fas fa-eye"></i> Spy
                    </button>
                    <button class="btn-action btn-delete" 
                            onclick="window.chatsController.deleteChat('${doc.id}')">
                        <i class="fas fa-trash-alt"></i> Delete
                    </button>
                </td>
            `;
            this.tableBody.appendChild(tr);
        });
    }

    openChatSpy(channelId) {
        // Create Modal
        let modal = document.getElementById('chat-spy-modal');
        if (!modal) {
            modal = document.createElement('div');
            modal.id = 'chat-spy-modal';
            modal.className = 'modal-overlay';
            modal.innerHTML = `
                <div class="modal-content" style="width: 550px; height: 750px; display: flex; flex-direction: column;">
                    <div class="modal-header">
                        <div>
                            <h2>🕵️ Channel Spy</h2>
                            <small id="spy-channel-id" style="color:var(--text-secondary)"></small>
                        </div>
                        <button onclick="window.chatsController.closeSpy()" class="btn-close">&times;</button>
                    </div>
                    <div id="spy-messages" class="modal-body spy-messages-container" style="flex: 1; overflow-y: auto; padding: 20px;">
                        <div class="loading-spinner"></div>
                    </div>
                    <div class="modal-footer" style="display:flex; justify-content:space-between; align-items:center;">
                        <span class="badge badge-admin">Live Feed</span>
                        <small>Administrative Oversight Mode</small>
                    </div>
                </div>
            `;
            document.body.appendChild(modal);
        }

        modal.style.display = 'flex';
        document.getElementById('spy-channel-id').innerText = `ID: ${channelId}`;
        const container = document.getElementById('spy-messages');
        container.innerHTML = '<div class="loading-text">Establishing secure connection...</div>';

        // Session cache for user names to avoid redundant fetches
        const userCache = {};

        // Subscribe to messages
        if (this.spyUnsubscribe) this.spyUnsubscribe();

        this.spyUnsubscribe = db.collection('channels').doc(channelId).collection('messages')
            .orderBy('timestamp', 'asc')
            .limit(100)
            .onSnapshot(async snap => {
                // We use async here to fetch user names if missing
                if (snap.empty) {
                    container.innerHTML = '<div class="no-data" style="text-align:center; margin-top:50px; color:var(--text-muted)">No messages found in this channel.</div>';
                    return;
                }

                const messagesFragment = document.createDocumentFragment();
                
                for (const doc of snap.docs) {
                    const msg = doc.data();
                    const senderId = msg.senderId || 'system';
                    
                    // Fetch user name if not in cache
                    if (senderId !== 'system' && !userCache[senderId]) {
                        try {
                            const userDoc = await db.collection('users').doc(senderId).get();
                            userCache[senderId] = userDoc.exists ? userDoc.data().displayName : `User (${senderId.substring(0,4)})`;
                        } catch (e) {
                            userCache[senderId] = `User (${senderId.substring(0,4)})`;
                        }
                    }

                    const div = document.createElement('div');
                    div.className = `chat-bubble ${senderId === 'system' ? 'received' : 'received'}`; 
                    // Note: In Spy mode, we don't necessarily have a "sent/received" relative to admin, 
                    // but we can color-code multiple participants.
                    
                    const time = this.formatTime(msg.timestamp);

                    div.innerHTML = `
                        <div class="bubble-meta">
                            <span style="font-weight:700; color:var(--color-primary-light)">${userCache[senderId] || 'System'}</span>
                            <span>${time}</span>
                        </div>
                        <div class="bubble-content">
                            ${msg.type === 'image' ? `<img src="${msg.imageUrl}" alt="Shared Image">` :
                              msg.type === 'voice' ? `<div style="display:flex; align-items:center; gap:8px;"><i class="fas fa-microphone"></i> Voice Message (${msg.duration}s)</div>` :
                              msg.type === 'video' ? `<div style="display:flex; align-items:center; gap:8px;"><i class="fas fa-video"></i> Shared Video</div>` :
                              (msg.content || '<i style="color:var(--text-muted)">No content</i>')}
                        </div>
                    `;
                    messagesFragment.appendChild(div);
                }

                container.innerHTML = '';
                container.appendChild(messagesFragment);

                // Scroll to bottom
                container.scrollTop = container.scrollHeight;
            }, err => {
                container.innerHTML = `<div class="error-text">Failed to load messages: ${err.message}</div>`;
            });
    }

    closeSpy() {
        if (this.spyUnsubscribe) this.spyUnsubscribe();
        const modal = document.getElementById('chat-spy-modal');
        if (modal) modal.style.display = 'none';
    }

    deleteChat(channelId) {
        if (confirm("Permanently delete this chat channel and all its messages?")) {
            db.collection('channels').doc(channelId).delete()
                .catch(err => alert("Error: " + err.message));
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
