class MonitorController {
    constructor() {
        this.feed = document.getElementById('live-activity-feed');
        this.maxItems = 30;
        this.collections = [
            { name: 'users', icon: 'fas fa-user-plus', color: '#42a5f5', label: 'New Signup' },
            { name: 'posts', icon: 'fas fa-newspaper', color: '#66bb6a', label: 'New Post' },
            { name: 'marketplace_items', icon: 'fas fa-shopping-bag', color: '#ffa726', label: 'New Listing' },
            { name: 'reports', icon: 'fas fa-flag', color: '#f43f5e', label: 'New Report' }
        ];
    }

    init() {
        if (!this.feed) return;
        this.feed.innerHTML = '';
        
        this.collections.forEach(coll => {
            db.collection(coll.name)
                .orderBy('createdAt', 'desc')
                .limit(5)
                .onSnapshot(snap => {
                    snap.docChanges().forEach(change => {
                        if (change.type === 'added') {
                            this.addActivity(coll, change.doc.data(), change.doc.id);
                        }
                    });
                });
        });
    }

    addActivity(coll, data, id) {
        if (!this.feed) return;

        const item = document.createElement('div');
        item.className = 'activity-item';
        
        const timestamp = data.createdAt ? this.formatTime(data.createdAt) : 'Just now';
        const title = data.displayName || data.title || data.userName || coll.label;
        const details = data.content || data.description || data.email || `ID: ${id.substring(0,8)}`;

        item.innerHTML = `
            <div class="activity-icon" style="background: ${coll.color}20; color: ${coll.color}">
                <i class="${coll.icon}"></i>
            </div>
            <div class="activity-content">
                <div class="activity-header">
                    <span class="activity-label" style="color: ${coll.color}; font-weight: 700;">${coll.label}</span>
                    <span class="activity-time">${timestamp}</span>
                </div>
                <div class="activity-body">
                    <b>${this.escapeHTML(title)}</b><br>
                    <small class="text-muted">${this.escapeHTML(details.substring(0, 100))}${details.length > 100 ? '...' : ''}</small>
                </div>
            </div>
        `;

        this.feed.prepend(item);

        // Keep list size manageable
        while (this.feed.children.length > this.maxItems) {
            this.feed.removeChild(this.feed.lastChild);
        }
    }

    formatTime(ts) {
        const d = ts.toDate ? ts.toDate() : new Date(ts);
        return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }

    escapeHTML(str) {
        const p = document.createElement('p');
        p.textContent = str;
        return p.innerHTML;
    }
}
