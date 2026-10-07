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

        let hasLoaded = false;
        this.collections.forEach(coll => {
            db.collection(coll.name)
                .orderBy('createdAt', 'desc')
                .limit(5)
                .onSnapshot(snap => {
                    if (snap && snap.docs && snap.docs.length > 0) {
                        if (!hasLoaded) {
                            this.feed.innerHTML = '';
                            hasLoaded = true;
                        }
                        snap.docs.forEach(doc => {
                            this.addActivity(coll, doc.data(), doc.id);
                        });
                    } else if (!hasLoaded) {
                        this.feed.innerHTML = '<div style="padding: 12px; color: var(--text-muted); font-size: 0.85rem; text-align: center;">No recent platform activity found.</div>';
                    }
                });
        });
    }

    addActivity(coll, data, id) {
        if (!this.feed || !data) return;

        const item = document.createElement('div');
        item.className = 'activity-item';

        const timestamp = data.createdAt ? this.formatTime(data.createdAt) : 'Just now';
        const title = data.displayName || data.title || data.username || data.fullName || coll.label;
        const details = data.content || data.description || data.email || `ID: ${String(id).substring(0, 8)}`;

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
                    <b>${this.escapeHTML(String(title))}</b><br>
                    <small class="text-muted">${this.escapeHTML(String(details).substring(0, 100))}${String(details).length > 100 ? '...' : ''}</small>
                </div>
            </div>
        `;

        this.feed.prepend(item);

        while (this.feed.children.length > this.maxItems) {
            this.feed.removeChild(this.feed.lastChild);
        }
    }

    formatTime(ts) {
        if (!ts) return 'Just now';
        const d = ts.toDate ? ts.toDate() : new Date(ts);
        return isNaN(d.getTime()) ? 'Just now' : d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }

    escapeHTML(str) {
        const p = document.createElement('p');
        p.textContent = str;
        return p.innerHTML;
    }
}
