class ChatsController {
    constructor() {
        this.tableBody = document.querySelector('#chats-table tbody');
    }

    load() {
        this.tableBody.innerHTML = '<tr><td colspan="4" class="loading-text">Loading active channels...</td></tr>';

        // Assuming 'channels' collection
        if (this.unsubscribe) this.unsubscribe();

        this.unsubscribe = db.collection('channels')
            .orderBy('lastMessageTime', 'desc')
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
            const lastMsg = chat.lastMessage || {};

            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td>
                    <span class="id-pill" title="${doc.id}">${doc.id.substring(0, 8)}...</span>
                </td>
                <td>
                    <div style="font-weight: 500">${chat.memberIds ? chat.memberIds.length : '?'} Participants</div>
                    <small style="color: #666">
                        ${chat.memberIds ? chat.memberIds.map(id => id.substring(0, 5)).join(', ') : ''}
                    </small>
                </td>
                <td>
                    <div class="message-preview">
                        ${lastMsg.content || '<i style="color:#aaa">Empty</i>'}
                    </div>
                    <small style="color: #999">${this.formatTime(chat.lastMessageTime)}</small>
                </td>
                <td>
                    <button class="btn-action btn-delete" 
                            onclick="window.chatsController.deleteChat('${doc.id}')">
                        <i class="fas fa-trash-alt"></i> Delete
                    </button>
                </td>
            `;
            this.tableBody.appendChild(tr);
        });
    }

    deleteChat(channelId) {
        if (confirm("Permanently delete this chat channel and all its messages?")) {
            db.collection('channels').doc(channelId).delete()
                .catch(err => alert("Error: " + err.message));
        }
    }

    formatTime(timestamp) {
        if (!timestamp) return 'N/A';
        return new Date(timestamp).toLocaleString(undefined, {
            hour: '2-digit', minute: '2-digit', month: 'short', day: 'numeric'
        });
    }
}
