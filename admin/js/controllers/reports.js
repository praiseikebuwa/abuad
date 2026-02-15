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

    render(snap) {
        this.tableBody.innerHTML = '';

        if (snap.empty) {
            this.tableBody.innerHTML = '<tr><td colspan="6">No pending reports.</td></tr>';
            return;
        }

        snap.forEach(doc => {
            const report = doc.data();
            const tr = document.createElement('tr');

            // Determine severity/style based on type
            const typeBadge = `<span class="badge badge-gray">${report.reportType}</span>`;
            const statusBadge = report.status === 'resolved'
                ? `<span class="badge badge-success">Resolved</span>`
                : `<span class="badge badge-warning">Pending</span>`;

            tr.innerHTML = `
                <td>${typeBadge}</td>
                <td>
                    <div style="font-weight:500">${report.reason || 'No reason provided'}</div>
                    <small class="text-muted">Target ID: ${report.targetId}</small>
                </td>
                <td>${report.reporterId ? report.reporterId.substring(0, 8) + '...' : 'Anon'}</td>
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
        });
    }

    resolveReport(reportId) {
        db.collection('reports').doc(reportId).update({
            status: 'resolved'
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
                    isBlocked: true,
                    status: 'offline' // Force offline UI
                });
                console.log(`User ${targetId} blocked.`);
            } else if (type === 'comment') {
                // Comments are subcollections, require parent postId. 
                // If the report doesn't have parentId, we can't delete directly without a collectionGroup query which is slow.
                alert("Comment deletion requires parent Post ID. Please handle manually in Firestore for now.");
                return;
            }

            // Mark report resolved
            await this.resolveReport(reportId);
            alert("Action taken and report resolved.");

        } catch (err) {
            console.error("Moderation Error:", err);
            alert("Error taking action: " + err.message);
        }
    }

    formatDate(timestamp) {
        if (!timestamp) return 'N/A';
        return new Date(timestamp.toDate()).toLocaleString();
    }
}
