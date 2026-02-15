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
                <div class="modal-content" style="width: 500px; height: 600px; display: flex; flex-direction: column;">
                    <div class="modal-header">
                        <h2>🕵️ Chat Spy</h2>
                        <button onclick="window.chatsController.closeSpy()" class="btn-close">&times;</button>
                    </div>
                    <div id="spy-messages" class="modal-body" style="flex: 1; overflow-y: auto; background: #f5f5f5; padding: 15px;">
                        <div class="loading-spinner"></div>
                    </div>
                    <div class="modal-footer">
                        <small>You are viewing this chat in Read-Only mode.</small>
                    </div>
                </div>
            `;
            document.body.appendChild(modal);
        }

        modal.style.display = 'flex';
        const container = document.getElementById('spy-messages');
        container.innerHTML = '<div class="loading-spinner"></div>';

        // Subscribe to messages
        if (this.spyUnsubscribe) this.spyUnsubscribe();

        this.spyUnsubscribe = db.collection('channels').doc(channelId).collection('messages')
            .orderBy('timestamp', 'asc')
            .limit(50)
            .onSnapshot(snap => {
                container.innerHTML = '';
                if (snap.empty) {
                    container.innerHTML = '<div class="no-data">No messages yet.</div>';
                    return;
                }

                snap.forEach(doc => {
                    const msg = doc.data();
                    const div = document.createElement('div');
                    div.style.marginBottom = '10px';
                    div.style.padding = '8px 12px';
                    div.style.borderRadius = '12px';
                    div.style.background = 'white';
                    div.style.maxWidth = '85%';
                    div.style.boxShadow = '0 1px 3px rgba(0,0,0,0.1)';
                    // Simple alignment: Left (assuming we don't know who is who easily without user map, just show logs)

                    div.innerHTML = `
                        <div style="font-size: 0.8rem; color: #888; display:flex; justify-content:space-between;">
                            <span>${msg.senderId ? msg.senderId.substring(0, 6) : 'System'}</span>
                            <span>${this.formatTime(msg.timestamp?.toDate ? msg.timestamp.toDate() : msg.timestamp)}</span>
                        </div>
                        <div style="margin-top: 4px; word-wrap: break-word;">
                            ${msg.type === 'image' ? `<img src="${msg.imageUrl}" style="max-width:100%; border-radius:8px;">` :
                            msg.type === 'voice' ? `🎤 Voice Message (${msg.duration}s)` :
                                (msg.content || '')}
                        </div>
                    `;
                    container.appendChild(div);
                });

                // Scroll to bottom
                container.scrollTop = container.scrollHeight;
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
