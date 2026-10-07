class ConfigController {
    constructor() {
        this.maintenanceToggle = document.getElementById('config-maintenance');
        this.signupsToggle = document.getElementById('config-signups');
        this.themeSelect = document.getElementById('config-theme');
        this.saveBtn = document.getElementById('save-config-btn');
        this.userInfo = document.getElementById('admin-user-info');

        if (this.saveBtn) {
            this.saveBtn.addEventListener('click', () => this.saveConfig());
        }

        // Apply theme immediately on init
        this.applyTheme(localStorage.getItem('admin-theme') || 'dark');
    }

    load() {
        // ... (existing auth logic)
        auth.onAuthStateChanged(user => {
            if (user && this.userInfo) {
                this.userInfo.innerHTML = `Logged in as:<br><b>${user.email}</b><br><small>Level: Super Admin</small>`;
            }
        });

        // Load current config from DB
        db.collection('system').doc('config').onSnapshot(doc => {
            if (doc.exists) {
                const data = doc.data();
                if (this.maintenanceToggle) this.maintenanceToggle.checked = data.maintenanceMode || false;
                if (this.signupsToggle) this.signupsToggle.checked = data.allowSignups !== false;
            }
        });

        // Sync local theme select UI
        if (this.themeSelect) {
            this.themeSelect.value = localStorage.getItem('admin-theme') || 'dark';
        }
    }

    applyTheme(theme) {
        document.documentElement.setAttribute('data-theme', theme);
        localStorage.setItem('admin-theme', theme);
    }

    async saveConfig() {
        this.saveBtn.disabled = true;
        this.saveBtn.innerText = "Saving...";

        try {
            // 1. Save DB Config
            await db.collection('system').doc('config').set({
                maintenanceMode: this.maintenanceToggle.checked,
                allowSignups: this.signupsToggle.checked,
                lastUpdated: new Date().toISOString(),
                updatedBy: (window.auth && window.auth.currentUser) ? window.auth.currentUser.email : 'admin@abuad.edu.ng'
            }, { merge: true });

            // 2. Save and Apply Local Theme
            if (this.themeSelect) {
                this.applyTheme(this.themeSelect.value);
            }

            window.logAdminAction('UPDATE_CONFIG', `Updated system config & theme`, 'system_config', 'global');
            alert("Configuration saved and theme applied!");
        } catch (err) {
            alert("Failed to update config: " + err.message);
        } finally {
            this.saveBtn.disabled = false;
            this.saveBtn.innerText = "Save Changes";
        }
    }
}
window.configController = new ConfigController();
