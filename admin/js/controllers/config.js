class ConfigController {
    constructor() {
        this.maintenanceToggle = document.getElementById('config-maintenance');
        this.signupsToggle = document.getElementById('config-signups');
        this.adsToggle = document.getElementById('config-ads-enabled');
        this.adsBadge = document.getElementById('ads-badge-indicator');
        this.themeSelect = document.getElementById('config-theme');
        this.saveBtn = document.getElementById('save-config-btn');
        this.userInfo = document.getElementById('admin-user-info');

        this.aiPostingToggle = document.getElementById('config-ai-posting');
        this.cleanAiPostsBtn = document.getElementById('clean-ai-posts-btn');

        if (this.saveBtn) {
            this.saveBtn.addEventListener('click', () => this.saveConfig());
        }

        if (this.adsToggle) {
            this.adsToggle.addEventListener('change', () => this.updateAdsSetting());
        }

        if (this.aiPostingToggle) {
            this.aiPostingToggle.addEventListener('change', () => this.updateAiPosting());
        }

        if (this.cleanAiPostsBtn) {
            this.cleanAiPostsBtn.addEventListener('click', () => this.cleanAiPosts());
        }

        // Apply theme immediately on init
        this.applyTheme(localStorage.getItem('admin-theme') || 'dark');
    }

    updateAdsStatusBadge(isEnabled) {
        if (!this.adsBadge) return;
        if (isEnabled) {
            this.adsBadge.className = 'badge badge-success';
            this.adsBadge.innerHTML = 'ACTIVE 🟢';
            this.adsBadge.style.backgroundColor = '#10b981';
            this.adsBadge.style.color = '#ffffff';
        } else {
            this.adsBadge.className = 'badge badge-danger';
            this.adsBadge.innerHTML = 'SHUT DOWN 🔴';
            this.adsBadge.style.backgroundColor = '#ef4444';
            this.adsBadge.style.color = '#ffffff';
        }
    }

    async updateAdsSetting() {
        if (!this.adsToggle) return;
        const isEnabled = this.adsToggle.checked;
        this.updateAdsStatusBadge(isEnabled);

        const confirmMsg = isEnabled
            ? "Re-enable Campus Advertisements across all student devices?\n\nSponsored cards, stories, boost buttons, and promo items will become visible immediately."
            : "⚠️ SHUT DOWN all Campus Advertisements & Paid Promos?\n\nThis is a master kill-switch: all sponsored cards, stories, boost buttons, and campaign screens will immediately disappear for all students.";
        
        if (!confirm(confirmMsg)) {
            this.adsToggle.checked = !isEnabled;
            this.updateAdsStatusBadge(!isEnabled);
            return;
        }

        try {
            const res = await ApiClientAdmin.fetch('/admin/settings/ads', {
                method: 'POST',
                body: JSON.stringify({ enabled: isEnabled }),
            });
            const data = await res.json();
            if (data.success) {
                window.logAdminAction('TOGGLE_ADVERTISEMENTS', `Campus Advertisements set to ${isEnabled ? 'ACTIVE' : 'SHUT DOWN'}`, 'advertisements', 'global');
                alert(`Platform Master Switch: Campus Advertisements are now ${isEnabled ? 'ACTIVE 🟢' : 'SHUT DOWN 🔴 across all student devices'}`);
                
                // Update overview summary if element is present
                const summaryEl = document.getElementById('summary-ads-status');
                if (summaryEl) {
                    summaryEl.innerText = isEnabled ? '✅ ACTIVE' : '🚫 SHUT DOWN';
                    summaryEl.style.color = isEnabled ? 'var(--color-primary-light)' : 'var(--color-accent-rose)';
                }
            } else {
                alert('Failed to update advertisements setting: ' + (data.error || 'Server error'));
                this.adsToggle.checked = !isEnabled;
                this.updateAdsStatusBadge(!isEnabled);
            }
        } catch (e) {
            alert('Error updating advertisements setting: ' + e.message);
            this.adsToggle.checked = !isEnabled;
            this.updateAdsStatusBadge(!isEnabled);
        }
    }

    async updateAiPosting() {
        if (!this.aiPostingToggle) return;
        const isEnabled = this.aiPostingToggle.checked;
        try {
            const res = await ApiClientAdmin.fetch('/admin/settings/ai-posting', {
                method: 'POST',
                body: JSON.stringify({ enabled: isEnabled }),
            });
            const data = await res.json();
            if (data.success) {
                alert(`ABUAD AI Autonomous Feed Posting is now ${isEnabled ? 'ENABLED' : 'DISABLED'}`);
            } else {
                alert('Failed to update AI posting setting: ' + (data.error || 'Server error'));
                this.aiPostingToggle.checked = !isEnabled;
            }
        } catch (e) {
            alert('Error updating AI posting setting: ' + e.message);
            this.aiPostingToggle.checked = !isEnabled;
        }
    }

    async cleanAiPosts() {
        const confirmed = confirm("Are you sure you want to remove all automated ABUAD AI posts from the campus feed?\n\nThis will immediately remove previous AI posts so real students take top priority.");
        if (!confirmed) return;

        if (this.cleanAiPostsBtn) {
            this.cleanAiPostsBtn.disabled = true;
            this.cleanAiPostsBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Cleaning...';
        }

        try {
            const res = await ApiClientAdmin.fetch('/admin/ai-posts/clean', {
                method: 'POST',
                body: JSON.stringify({}),
            });
            const data = await res.json();
            if (data.success) {
                alert(data.message || `Cleaned ${data.count} AI posts from the feed.`);
                if (window.postsController) {
                    window.postsController.load();
                }
            } else {
                alert('Failed to clean AI posts: ' + (data.error || 'Server error'));
            }
        } catch (e) {
            alert('Error cleaning AI posts: ' + e.message);
        } finally {
            if (this.cleanAiPostsBtn) {
                this.cleanAiPostsBtn.disabled = false;
                this.cleanAiPostsBtn.innerHTML = '<i class="fas fa-trash"></i> Clean All AI Posts';
            }
        }
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
                
                const adsActive = (data.ads_enabled !== false && data.ads_enabled !== 'false' && data.adsEnabled !== false && data.adsEnabled !== 'false');
                if (this.adsToggle) this.adsToggle.checked = adsActive;
                this.updateAdsStatusBadge(adsActive);
            }
        });

        // Load Ads status directly from backend REST endpoint for immediate consistency
        ApiClientAdmin.fetch('/admin/settings/ads')
            .then(res => res.json())
            .then(data => {
                if (data && typeof data.adsEnabled === 'boolean') {
                    if (this.adsToggle) this.adsToggle.checked = data.adsEnabled;
                    this.updateAdsStatusBadge(data.adsEnabled);
                }
            })
            .catch(err => console.warn('Could not load ads setting:', err));

        // Load AI posting status from backend REST endpoint
        ApiClientAdmin.fetch('/admin/settings/ai-posting')
            .then(res => res.json())
            .then(data => {
                if (data && this.aiPostingToggle) {
                    this.aiPostingToggle.checked = !!data.enabled;
                }
            })
            .catch(err => console.warn('Could not load AI posting setting:', err));

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
            const isAdsOn = this.adsToggle ? this.adsToggle.checked : true;
            // 1. Save DB Config
            await db.collection('system').doc('config').set({
                maintenanceMode: this.maintenanceToggle.checked,
                allowSignups: this.signupsToggle.checked,
                ads_enabled: isAdsOn,
                adsEnabled: isAdsOn,
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
