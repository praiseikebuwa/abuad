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
            'chats': window.chatsController,
            'events': window.eventsController,
            'groups': window.groupsController,
            'resources': window.resourcesController,
            'analytics': window.analyticsController,
            'broadcasts': window.broadcastController,
            'reports': window.reportsController,
            'presence': window.presenceController
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
    window.chatsController = new ChatsController();
    window.broadcastController = new BroadcastController();
    window.reportsController = new ReportsController();
    window.presenceController = new PresenceController();

    // Some are objects-literal from legacy code
    // window.eventsController (already global)
    // window.resourcesController (already global)
    // window.analyticsController (already global)

    // 2. Initialize Navigation
    window.navigationController = new NavigationController();
});
