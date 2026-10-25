class BroadcastController {
    constructor() {
        this.form = document.getElementById('broadcast-form');
        this.historyList = document.getElementById('broadcast-history');
        this.targetSelect = document.getElementById('broadcast-target');
        this.collegeSelect = document.getElementById('broadcast-college');
        this.departmentSelect = document.getElementById('broadcast-department');
        this.levelSelect = document.getElementById('broadcast-level');
        this.reachBadge = document.getElementById('broadcast-reach-badge');
        this.refreshBtn = document.getElementById('refresh-broadcasts-btn');
        this.countBadge = document.getElementById('broadcasts-count');

        this.initEventListeners();
    }

    initEventListeners() {
        if (this.form) {
            this.form.addEventListener('submit', (e) => this.sendBroadcast(e));
        }

        if (this.targetSelect) {
            this.targetSelect.addEventListener('change', () => this.updateReachSummary());
        }

        if (this.collegeSelect) {
            this.collegeSelect.addEventListener('change', () => this.updateReachSummary());
        }

        if (this.departmentSelect) {
            this.departmentSelect.addEventListener('change', () => this.updateReachSummary());
        }

        if (this.levelSelect) {
            this.levelSelect.addEventListener('change', () => this.updateReachSummary());
        }

        if (this.refreshBtn) {
            this.refreshBtn.addEventListener('click', () => this.loadHistory());
        }
    }

    updateReachSummary() {
        if (!this.reachBadge) return;

        const target = this.targetSelect ? this.targetSelect.value : 'everyone';
        const college = this.collegeSelect ? this.collegeSelect.value : 'all';
        const department = this.departmentSelect ? this.departmentSelect.value : 'all';
        const level = this.levelSelect ? this.levelSelect.value : 'all';

        let label = 'Target: ';

        if (target === 'everyone' && college === 'all' && department === 'all' && level === 'all') {
            label += 'All Campus';
            this.reachBadge.className = 'badge badge-info';
            this.reachBadge.innerHTML = `<i class="fas fa-users"></i> ${label}`;
            return;
        }

        const parts = [];
        if (target === 'students') parts.push('All Students');
        else if (target === 'staff') parts.push('Staff Only');
        else if (target !== 'everyone') parts.push(target.toUpperCase());

        if (college !== 'all') parts.push(college.replace('College of ', 'Col. '));
        if (department !== 'all') parts.push(department);
        if (level !== 'all') parts.push(`${level}L`);

        label += parts.join(' • ');
        this.reachBadge.className = 'badge badge-warning';
        this.reachBadge.innerHTML = `<i class="fas fa-crosshairs"></i> ${label}`;
    }

    load() {
        this.updateReachSummary();
        this.loadHistory();
    }

    async sendBroadcast(e) {
        e.preventDefault();

        const title = document.getElementById('broadcast-title').value.trim();
        const message = document.getElementById('broadcast-message').value.trim();
        const type = document.getElementById('broadcast-type') ? document.getElementById('broadcast-type').value : 'info';
        const target = this.targetSelect ? this.targetSelect.value : 'everyone';
        const college = this.collegeSelect ? this.collegeSelect.value : 'all';
        const department = this.departmentSelect ? this.departmentSelect.value : 'all';
        const level = this.levelSelect ? this.levelSelect.value : 'all';

        const submitBtn = this.form.querySelector('button[type="submit"]');

        if (!title || !message) {
            alert('Please fill in both the announcement title and message content.');
            return;
        }

        submitBtn.disabled = true;
        submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Dispatching Broadcast...';

        try {
            const payload = {
                title: title,
                body: message,
                type: type,
                target: target,
                college: college !== 'all' ? college : undefined,
                department: department !== 'all' ? department : undefined,
                level: level !== 'all' ? level : undefined,
            };

            const res = await ApiClientAdmin.fetch('/admin/broadcast', {
                method: 'POST',
                body: JSON.stringify(payload)
            });

            const json = await res.json();

            if (!res.ok || !json.success) {
                // Fallback to Firestore announcements collection
                if (typeof db !== 'undefined') {
                    await db.collection('announcements').add({
                        title: title,
                        body: message,
                        type: type,
                        target: target,
                        college: college,
                        department: department,
                        level: level,
                        timestamp: new Date().toISOString(),
                        active: true
                    });
                } else {
                    throw new Error(json.error || 'Failed to dispatch broadcast');
                }
            }

            if (typeof window.logAdminAction === 'function') {
                window.logAdminAction(
                    'BROADCAST_ANNOUNCEMENT',
                    `Dispatched campus broadcast: "${title}" to ${target} (${department !== 'all' ? department : ''} ${level !== 'all' ? level + 'L' : ''})`,
                    'announcement'
                );
            }

            const recipients = json.recipientCount !== undefined ? ` to ${json.recipientCount} verified recipients` : '';
            alert(`🎉 Broadcast dispatched successfully${recipients} and pushed in real-time to active devices!`);

            // Reset form
            this.form.reset();
            this.updateReachSummary();
            this.loadHistory();
        } catch (error) {
            console.error('Error sending broadcast:', error);
            alert('Failed to send broadcast: ' + error.message);
        } finally {
            submitBtn.disabled = false;
            submitBtn.innerHTML = '<i class="fas fa-paper-plane"></i> Send Broadcast to Campus';
        }
    }

    async loadHistory() {
        if (!this.historyList) return;

        this.historyList.innerHTML = `
            <div style="text-align: center; padding: 30px; color: var(--text-secondary);">
                <i class="fas fa-spinner fa-spin" style="font-size: 1.5rem; margin-bottom: 10px;"></i>
                <p>Loading broadcast history...</p>
            </div>
        `;

        try {
            const res = await ApiClientAdmin.fetch('/admin/announcements');
            const json = await res.json();

            if (res.ok && json.success && Array.isArray(json.data)) {
                this.renderAnnouncements(json.data);
                return;
            }
        } catch (err) {
            console.warn('Backend announcement fetch failed, trying Firestore fallback...', err);
        }

        // Firestore Fallback
        if (typeof db !== 'undefined') {
            db.collection('announcements')
                .orderBy('timestamp', 'desc')
                .limit(20)
                .get()
                .then(snap => {
                    const list = [];
                    snap.forEach(doc => {
                        const d = doc.data();
                        list.push({
                            id: doc.id,
                            title: d.title,
                            body: d.body,
                            target: d.target || 'everyone',
                            createdAt: d.timestamp || new Date().toISOString(),
                            type: d.type || 'info',
                        });
                    });
                    this.renderAnnouncements(list);
                })
                .catch(e => {
                    this.historyList.innerHTML = `<div style="padding: 20px; color: var(--color-danger); text-align: center;">Error loading announcements: ${e.message}</div>`;
                });
        } else {
            this.historyList.innerHTML = '<div style="padding: 20px; text-align: center; color: var(--text-secondary);">No broadcasts found.</div>';
        }
    }

    renderAnnouncements(announcements) {
        if (!this.historyList) return;
        this.historyList.innerHTML = '';

        if (this.countBadge) {
            this.countBadge.innerText = `${announcements.length} Total`;
        }

        if (announcements.length === 0) {
            this.historyList.innerHTML = `
                <div style="text-align: center; padding: 40px 20px; color: var(--text-secondary);">
                    <i class="fas fa-bullhorn" style="font-size: 2rem; opacity: 0.3; margin-bottom: 12px;"></i>
                    <p style="margin: 0; font-size: 0.95rem;">No broadcasts have been dispatched yet.</p>
                    <small>Compose a notice on the left to push announcements to students.</small>
                </div>
            `;
            return;
        }

        announcements.forEach(item => {
            const card = document.createElement('div');
            card.className = 'broadcast-item';
            card.style.cssText = `
                background: var(--bg-card);
                border: 1px solid var(--border-subtle);
                border-radius: 10px;
                padding: 16px;
                position: relative;
                transition: transform 0.2s, border-color 0.2s;
            `;

            const dateStr = item.createdAt ? new Date(item.createdAt).toLocaleString(undefined, {
                dateStyle: 'medium',
                timeStyle: 'short',
            }) : 'Just now';

            const targetBadge = item.target || 'Everyone';
            const isTargeted = targetBadge.toLowerCase() !== 'everyone';

            card.innerHTML = `
                <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 8px;">
                    <div>
                        <h4 style="margin: 0 0 4px 0; font-size: 1rem; color: var(--text-primary); font-weight: 600;">
                            ${this.escapeHtml(item.title)}
                        </h4>
                        <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
                            <span class="badge ${isTargeted ? 'badge-warning' : 'badge-info'}" style="font-size: 0.72rem; padding: 2px 8px;">
                                <i class="fas ${isTargeted ? 'fa-crosshairs' : 'fa-users'}"></i> ${this.escapeHtml(targetBadge)}
                            </span>
                            <span style="font-size: 0.78rem; color: var(--text-secondary);">
                                <i class="far fa-clock"></i> ${dateStr}
                            </span>
                        </div>
                    </div>
                    <button class="btn-text-danger" style="background: none; border: none; color: #ef4444; cursor: pointer; padding: 4px 8px; font-size: 0.85rem;"
                        title="Delete Broadcast" onclick="window.broadcastController.delete('${item.id}')">
                        <i class="fas fa-trash-alt"></i>
                    </button>
                </div>
                <p style="margin: 0; font-size: 0.88rem; color: var(--text-secondary); line-height: 1.5; white-space: pre-wrap;">
                    ${this.escapeHtml(item.body)}
                </p>
            `;

            this.historyList.appendChild(card);
        });
    }

    async delete(id) {
        if (!confirm('Are you sure you want to revoke and delete this campus broadcast?')) return;

        try {
            const res = await ApiClientAdmin.fetch(`/admin/announcements/${id}`, {
                method: 'DELETE',
            });
            const json = await res.json();

            if (res.ok && json.success) {
                if (typeof window.logAdminAction === 'function') {
                    window.logAdminAction('DELETE_ANNOUNCEMENT', `Deleted campus announcement ${id}`, 'announcement', id);
                }
                this.loadHistory();
                return;
            }
        } catch (e) {
            console.warn('Backend delete failed, trying Firestore...', e);
        }

        if (typeof db !== 'undefined') {
            db.collection('announcements').doc(id).delete().then(() => {
                if (typeof window.logAdminAction === 'function') {
                    window.logAdminAction('DELETE_ANNOUNCEMENT', `Deleted campus announcement ${id}`, 'announcement', id);
                }
                this.loadHistory();
            }).catch(err => {
                alert('Failed to delete announcement: ' + err.message);
            });
        }
    }

    escapeHtml(str) {
        if (!str) return '';
        const div = document.createElement('div');
        div.innerText = str;
        return div.innerHTML;
    }
}
