class NavigationController {
    constructor() {
        this.tabs = document.querySelectorAll('.sidebar-nav li');
        this.sections = document.querySelectorAll('.tab-content');
        this.init();
    }

    init() {
        this.tabs.forEach(tab => {
            tab.addEventListener('click', () => {
                const targetId = tab.getAttribute('data-tab');
                this.switchTab(targetId);
            });
        });
    }

    switchTab(tabId) {
        // Update Sidebar UI
        this.tabs.forEach(t => t.classList.remove('active'));
        const activeTab = document.querySelector(`.sidebar-nav li[data-tab="${tabId}"]`);
        if (activeTab) activeTab.classList.add('active');

        // Update Content UI
        this.sections.forEach(s => s.classList.remove('active'));
        const targetSection = document.getElementById(`${tabId}-tab`);
        if (targetSection) targetSection.classList.add('active');

        // Trigger Controller Load
        this.loadCurrentTab(tabId);
    }

    loadCurrentTab(tabId) {
        const controllers = {
            'overview': window.analyticsController,
            'users': window.usersController,
            'posts': window.postsController,
            'reels': window.reelsController,
            'stories': window.storiesController,
            'chats': window.chatsController,
            'events': window.eventsController,
            'groups': window.groupsController,
            'resources': window.resourcesController,
            'analytics': window.analyticsController,
            'broadcasts': window.broadcastController,
            'reports': window.reportsController,
            'presence': window.presenceController,
            'sos': window.sosController,
            'verification': window.verificationController,
            'config': window.configController,
            'staff': window.staffController,
            'audit': window.auditController
        };

        const controller = controllers[tabId];
        if (controller && typeof controller.load === 'function') {
            controller.load();
        } else if (controller && typeof controller.init === 'function') {
            controller.init();
        }
    }
}

// Global Orchestrator
document.addEventListener('DOMContentLoaded', () => {
    // 1. Initialize Objects
    window.authController = new AuthController();
    window.usersController = new UsersController();
    window.postsController = new PostsController();
    window.reelsController = new ReelsController();
    window.storiesController = new StoriesController();
    window.chatsController = new ChatsController();
    window.marketplaceController = new MarketplaceController();
    window.broadcastController = new BroadcastController();
    window.reportsController = new ReportsController();
    window.presenceController = new PresenceController();
    window.verificationController = new VerificationController();
    window.configController = new ConfigController();
    window.sosController = new SOSController();
    window.monitorController = new MonitorController();

    // 2. Monitoring will be started by NavigationController when tab is active
    // window.monitorController.init();
    // window.sosController.load(); 

    // 2. Global Search Logic
    const globalSearch = document.getElementById('global-search');
    if (globalSearch) {
        globalSearch.addEventListener('keypress', async (e) => {
            if (e.key === 'Enter') {
                const query = globalSearch.value;
                if (query.length > 2) {
                    // Start Unified Search
                    window.navigationController.switchTab('users');
                    window.usersController.filterUsers(query);
                    
                    // Show a notification or update UI to show it's a cross-platform search
                    console.log(`Global search for: ${query}`);
                }
            }
        });
    }

    // 3. Update Header Admin Info
    firebase.auth().onAuthStateChanged(user => {
        if (user) {
            document.getElementById('admin-name').innerText = user.displayName || 'Administrator';
        }
    });

    // 4. Initialize Navigation
    window.navigationController = new NavigationController();
});
