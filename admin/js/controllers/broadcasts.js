class BroadcastController {
    constructor() {
        this.form = document.getElementById('broadcast-form');
        this.historyList = document.getElementById('broadcast-history');

        if (this.form) {
            this.form.addEventListener('submit', (e) => this.sendBroadcast(e));
        }
    }

    load() {
        this.loadHistory();
    }

    async sendBroadcast(e) {
        e.preventDefault();

        const title = document.getElementById('broadcast-title').value;
        const message = document.getElementById('broadcast-message').value;
        const type = document.getElementById('broadcast-type').value; // 'info', 'warning', 'urgent'
        const btn = this.form.querySelector('button');

        if (!title || !message) return;

        btn.disabled = true;
        btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Sending...';

        try {
            // Write to 'announcements' collection
            await db.collection('announcements').add({
                title: title,
                body: message,
                type: type,
                senderId: auth.currentUser.uid,
                senderName: 'Admin',
                timestamp: firebase.firestore.FieldValue.serverTimestamp(),
                active: true
            });

            // Reset form
            this.form.reset();
            alert("Broadcast sent successfully!");
        } catch (error) {
            alert("Failed to send broadcast: " + error.message);
        } finally {
            btn.disabled = false;
            btn.innerText = 'Send Broadcast';
        }
    }

    loadHistory() {
        if (!this.historyList) return;

        this.historyList.innerHTML = '<div class="loading-spinner"></div>';

        db.collection('announcements')
            .orderBy('timestamp', 'desc')
            .limit(10)
            .onSnapshot(snap => {
                this.historyList.innerHTML = '';
                if (snap.empty) {
                    this.historyList.innerHTML = '<div>No recent broadcasts.</div>';
                    return;
                }

                snap.forEach(doc => {
                    const data = doc.data();
                    const item = document.createElement('div');
                    item.className = `broadcast-item type-${data.type || 'info'}`;

                    const time = data.timestamp ? new Date(data.timestamp.toDate()).toLocaleString() : 'Pending...';

                    item.innerHTML = `
                        <div class="bc-header">
                            <strong>${data.title}</strong>
                            <span class="bc-time">${time}</span>
                        </div>
                        <div class="bc-body">${data.body}</div>
                        <div class="bc-footer">
                            <span class="badge badge-${data.type}">${data.type.toUpperCase()}</span>
                            <button class="btn-text-danger" onclick="window.broadcastController.delete('${doc.id}')">Delete</button>
                        </div>
                    `;
                    this.historyList.appendChild(item);
                });
            });
    }

    delete(id) {
        if (confirm("Remove this announcement?")) {
            db.collection('announcements').doc(id).delete();
        }
    }
}
