class AuditController {
    constructor() {
        this.tableBody = document.querySelector('#audit-table tbody');
        this.actionFilter = document.getElementById('audit-filter-action');

        if (this.actionFilter) {
            this.actionFilter.addEventListener('change', () => this.load());
        }
    }

    load() {
        if (!this.tableBody) return;
        this.tableBody.innerHTML = '<tr><td colspan="5" class="loading-text">Loading audit logs...</td></tr>';

        if (this.unsubscribe) this.unsubscribe();

        let query = db.collection('audit_logs').orderBy('timestamp', 'desc').limit(100);

        const action = this.actionFilter ? this.actionFilter.value : 'all';
        if (action !== 'all') {
            query = query.where('actionType', '==', action);
        }

        this.unsubscribe = query.onSnapshot(snap => {
            this.render(snap);
        }, err => {
            console.error(err);
            this.tableBody.innerHTML = `<tr><td colspan="5" class="error-text">Error: ${err.message}</td></tr>`;
        });
    }

    render(snap) {
        this.tableBody.innerHTML = '';

        if (snap.empty) {
            this.tableBody.innerHTML = '<tr><td colspan="5">No audit logs found.</td></tr>';
            return;
        }

        snap.forEach(doc => {
            const log = doc.data();
            const tr = document.createElement('tr');

            const timestamp = log.timestamp ? new Date(log.timestamp.toDate()).toLocaleString() : 'Just now';
            const actionClass = `action-${log.actionType || 'info'}`;

            tr.innerHTML = `
                <td class="audit-time">${timestamp}</td>
                <td class="audit-admin">
                    <b>${log.adminName || 'Admin'}</b><br>
                    <small class="text-muted">${log.adminEmail || ''}</small>
                </td>
                <td><span class="audit-action ${actionClass}">${log.action || 'Unknown Action'}</span></td>
                <td>
                    <span class="badge badge-gray">${log.targetType || 'item'}</span><br>
                    <small>${log.targetId || ''}</small>
                </td>
                <td><small>${log.details || ''}</small></td>
            `;
            this.tableBody.appendChild(tr);
        });
    }

    // Utility to log actions from other controllers
    static async logAction(action, details, targetType, targetId) {
        try {
            const user = firebase.auth().currentUser;
            await db.collection('audit_logs').add({
                timestamp: firebase.firestore.FieldValue.serverTimestamp(),
                adminId: user ? user.uid : 'system',
                adminName: user ? user.displayName : 'System',
                adminEmail: user ? user.email : 'system@abuad.edu.ng',
                action: action,
                actionType: this.deriveActionType(action),
                details: details,
                targetType: targetType,
                targetId: targetId
            });
        } catch (err) {
            console.error("Failed to write audit log:", err);
        }
    }

    static deriveActionType(action) {
        if (!action || typeof action !== 'string') return 'info';
        const a = action.toLowerCase();
        if (a.includes('delete') || a.includes('remove') || a.includes('ban')) return 'delete';
        if (a.includes('verify') || a.includes('approve')) return 'verify';
        if (a.includes('config') || a.includes('maintenance')) return 'config';
        return 'info';
    }
}

window.auditController = new AuditController();
window.logAdminAction = AuditController.logAction.bind(AuditController);
