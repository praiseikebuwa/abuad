// Main Navigation & Initialization Controller
class NavigationController {
    constructor() {
        this.tabs = document.querySelectorAll('.sidebar-nav li');
        this.tabContents = document.querySelectorAll('.tab-content');

        // Initialize Sub-Controllers
        // Note: AuthController auto-inits because it monitors Auth State
        window.authController = new AuthController();
        window.usersController = new UsersController();
        window.postsController = new PostsController();
        window.chatsController = new ChatsController();
        window.broadcastController = new BroadcastController();

        // Bind Navigation
        this.tabs.forEach(tab => {
            tab.addEventListener('click', () => {
                this.switchTab(tab);
            });
        });

        // Expose self
        window.navigationController = this;
    }

    switchTab(selectedTab) {
        // UI Updates
        this.tabs.forEach(t => t.classList.remove('active'));
        this.tabContents.forEach(c => c.classList.remove('active'));

        selectedTab.classList.add('active');
        const targetId = selectedTab.dataset.tab;
        document.getElementById(`${targetId}-tab`).classList.add('active');

        // Trigger Controller Load
        this.loadCurrentTab(targetId);
    }

    loadCurrentTab(targetId = null) {
        // If not provided, find active tab
        if (!targetId) {
            const active = document.querySelector('.sidebar-nav li.active');
            if (active) targetId = active.dataset.tab;
            else return;
        }

        switch (targetId) {
            case 'overview':
                this.loadOverview();
                break;
            case 'users':
                window.usersController.load();
                break;
            case 'posts':
                window.postsController.load();
                break;
            case 'chats':
                window.chatsController.load();
                break;
            case 'broadcasts':
                window.broadcastController.load();
                break;
            case 'presence':
                // Reusing presence logic from original app.js or moving it?
                // I should have moved it. Let's create a quick PresenceController or just keep it simple here.
                // For now, I'll implement a simple inline load since I didn't make a controller file for it (my bad).
                // Actually, let's make a quick file for it or put it here.
                this.loadPresence();
                break;
        }
    }

    loadOverview() {
        // Fetch Users for Stats & Chart
        db.collection('users').get().then(snap => {
            document.getElementById('stat-total-users').innerText = snap.size;
            let verified = 0, online = 0;
            const colleges = {};

            snap.forEach(doc => {
                const d = doc.data();
                if (d.isVerified) verified++;
                if (d.status === 'online') online++;

                // Chart Data: College Distribution
                const col = d.college || 'Unknown';
                colleges[col] = (colleges[col] || 0) + 1;
            });
            document.getElementById('stat-verified-users').innerText = verified;
            document.getElementById('stat-online-users').innerText = online;

            this.renderUserChart(colleges);
        });

        // Fetch Posts for Chart
        db.collection('posts').orderBy('timestamp', 'desc').limit(100).get().then(snap => {
            const days = {};
            snap.forEach(doc => {
                const d = doc.data();
                // Group by day (simple approximation)
                if (d.timestamp) {
                    const date = new Date(d.timestamp).toLocaleDateString(undefined, { weekday: 'short' });
                    days[date] = (days[date] || 0) + 1;
                }
            });
            this.renderPostChart(days);
        });
    }

    renderUserChart(data) {
        const ctx = document.getElementById('userChart').getContext('2d');
        if (window.myUserChart) window.myUserChart.destroy();

        window.myUserChart = new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: Object.keys(data),
                datasets: [{
                    data: Object.values(data),
                    backgroundColor: ['#4CAF50', '#2196F3', '#FFC107', '#E91E63', '#9C27B0', '#607D8B']
                }]
            },
            options: { responsive: true }
        });
    }

    renderPostChart(data) {
        const ctx = document.getElementById('postChart').getContext('2d');
        if (window.myPostChart) window.myPostChart.destroy();

        window.myPostChart = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: Object.keys(data),
                datasets: [{
                    label: 'Recent Posts',
                    data: Object.values(data),
                    backgroundColor: '#0D47A1'
                }]
            },
            options: {
                scales: { y: { beginAtZero: true } }
            }
        });
    }

    loadPresence() {
        const grid = document.getElementById('live-users-grid');
        grid.innerHTML = '<p>Listening for active users...</p>';

        if (this.presenceUnsub) this.presenceUnsub();

        this.presenceUnsub = db.collection('users').where('status', '==', 'online').onSnapshot(snap => {
            grid.innerHTML = '';
            if (snap.empty) {
                grid.innerHTML = '<p>No users currently online.</p>';
                return;
            }
            snap.forEach(doc => {
                const user = doc.data();
                const div = document.createElement('div');
                div.className = 'presence-card';
                div.innerHTML = `
                    <div class="avatar-initial" style="margin: 0 auto 10px auto; width: 48px; height: 48px; font-size: 1.2rem;">
                        ${user.displayName ? user.displayName[0].toUpperCase() : '?'}
                    </div>
                    <h3>${user.displayName || 'Unknown'}</h3>
                    <p style="color: #666; font-size: 0.9rem;">${user.email}</p>
                    <span class="status-badge online" style="margin-top: 5px; display: inline-block;">Live Now</span>
                `;
                grid.appendChild(div);
            });
        });
    }
}

// Start App
document.addEventListener('DOMContentLoaded', () => {
    new NavigationController();
});
