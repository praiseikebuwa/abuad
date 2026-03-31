class ConfigController {
    constructor() {
        this.maintenanceToggle = document.getElementById('config-maintenance');
        this.signupsToggle = document.getElementById('config-signups');
        this.saveBtn = document.getElementById('save-config-btn');
        this.userInfo = document.getElementById('admin-user-info');

        if (this.saveBtn) {
            this.saveBtn.addEventListener('click', () => this.saveConfig());
        }
    }

    load() {
        // Show current admin user
        auth.onAuthStateChanged(user => {
            if (user && this.userInfo) {
                this.userInfo.innerHTML = `Logged in as:<br><b>${user.email}</b><br><small>Level: Super Admin</small>`;
            }
        });

        // Load current config
        db.collection('system').doc('config').onSnapshot(doc => {
            if (doc.exists) {
                const data = doc.data();
                if (this.maintenanceToggle) this.maintenanceToggle.checked = data.maintenanceMode || false;
                if (this.signupsToggle) this.signupsToggle.checked = data.allowSignups !== false;
            }
        });
    }

    async saveConfig() {
        this.saveBtn.disabled = true;
        this.saveBtn.innerText = "Saving...";

        try {
            await db.collection('system').doc('config').set({
                maintenanceMode: this.maintenanceToggle.checked,
                allowSignups: this.signupsToggle.checked,
                lastUpdated: firebase.firestore.FieldValue.serverTimestamp(),
                updatedBy: auth.currentUser.email
            }, { merge: true });

            window.logAdminAction('UPDATE_CONFIG', `Updated system config: Maintenance ${this.maintenanceToggle.checked}, Signups ${this.signupsToggle.checked}`, 'system_config', 'global');
            alert("System configuration updated successfully!");
        } catch (err) {
            alert("Failed to update config: " + err.message);
        } finally {
            this.saveBtn.disabled = false;
            this.saveBtn.innerText = "Save Changes";
        }
    }
}
window.configController = new ConfigController();
