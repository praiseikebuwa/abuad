class ReportsController {
    constructor() {
        this.tableBody = document.querySelector('#reports-table tbody');
    }

    load() {
        this.tableBody.innerHTML = '<tr><td colspan="6" class="loading-text">Loading reports...</td></tr>';

        if (this.unsubscribe) this.unsubscribe();

        // Listen to 'reports' collection
        this.unsubscribe = db.collection('reports')
            .orderBy('timestamp', 'desc')
            .limit(50)
            .onSnapshot(snap => {
                this.render(snap);
            }, err => {
                console.error(err);
                this.tableBody.innerHTML = `<tr><td colspan="6" class="error-text">Error: ${err.message}</td></tr>`;
            });
    }

    async render(snap) {
        this.tableBody.innerHTML = '';

        if (snap.empty) {
            this.tableBody.innerHTML = '<tr><td colspan="6">No pending reports.</td></tr>';
            return;
        }

        for (const doc of snap.docs) {
            const report = doc.data();
            const tr = document.createElement('tr');

            // Fetch Reporter Info
            let reporterInfo = 'Anon';
            if (report.reporterId) {
                const repDoc = await db.collection('users').doc(report.reporterId).get();
                if (repDoc.exists) {
                    const repData = repDoc.data();
                    reporterInfo = `<div class="user-cell-mini">
                        <small><b>${repData.displayName || 'User'}</b></small><br>
                        <small class="text-muted">${repData.email || ''}</small>
                    </div>`;
                } else {
                    reporterInfo = `<small class="text-muted">${report.reporterId.substring(0, 8)}...</small>`;
                }
            }

            // Fetch Target Content Preview
            let contentPreview = `<div class="reason-text">${report.reason || 'No reason'}</div>`;
            if (report.reportType === 'post') {
                const postDoc = await db.collection('posts').doc(report.targetId).get();
                if (postDoc.exists) {
                    const postData = postDoc.data();
                    contentPreview += `<div class="content-snippet">
                        <i>"${postData.content ? postData.content.substring(0, 60) + '...' : 'No text'}"</i>
                    </div>`;
                }
            }

            const typeBadge = `<span class="badge badge-gray">${report.reportType}</span>`;
            const statusBadge = report.status === 'resolved'
                ? `<span class="badge badge-success">Resolved</span>`
                : `<span class="badge badge-warning">Pending</span>`;

            tr.innerHTML = `
                <td>${typeBadge}</td>
                <td>
                    ${contentPreview}
                </td>
                <td>${reporterInfo}</td>
                <td>${this.formatDate(report.timestamp)}</td>
                <td>${statusBadge}</td>
                <td>
                    <div class="action-buttons">
                        <button class="btn-icon btn-approve" 
                                onclick="window.reportsController.resolveReport('${doc.id}')"
                                title="Mark Resolved">
                            <i class="fas fa-check"></i>
                        </button>
                        <button class="btn-icon btn-delete" 
                                onclick="window.reportsController.deleteContent('${report.reportType}', '${report.targetId}', '${doc.id}')"
                                title="Delete Content & Resolve">
                            <i class="fas fa-trash-alt"></i>
                        </button>
                    </div>
                </td>
            `;
            this.tableBody.appendChild(tr);
        }
    }

    resolveReport(reportId) {
        db.collection('reports').doc(reportId).update({
            status: 'resolved'
        }).then(() => {
            window.logAdminAction('RESOLVE_REPORT', `Report ${reportId} marked as resolved`, 'report', reportId);
        }).catch(err => alert("Error: " + err.message));
    }

    async deleteContent(type, targetId, reportId) {
        if (!confirm(`CAUTION: Delete this ${type} and resolve the report?`)) return;

        try {
            if (type === 'post') {
                await db.collection('posts').doc(targetId).delete();
                console.log(`Post ${targetId} deleted.`);
            } else if (type === 'user') {
                await db.collection('users').doc(targetId).update({
                    status: 'banned',
                    isBlocked: true
                });
                console.log(`User ${targetId} banned.`);
            } else if (type === 'comment') {
                alert("Please handle comment deletion via Firestore subcollection for now.");
                return;
            }

            // Mark report resolved
            await this.resolveReport(reportId);
            alert("Action taken successfully.");

        } catch (err) {
            console.error("Moderation Error:", err);
            alert("Error: " + err.message);
        }
    }

    formatDate(timestamp) {
        if (!timestamp) return 'N/A';
        const d = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
        return d.toLocaleDateString() + ' ' + d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }
}
