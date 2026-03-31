class VerificationController {
    constructor() {
        this.tableBody = document.querySelector('#verification-table tbody');
    }

    load() {
        if (!this.tableBody) return;
        this.tableBody.innerHTML = '<tr><td colspan="5" class="loading-text">Loading verification requests...</td></tr>';

        if (this.unsubscribe) this.unsubscribe();

        this.unsubscribe = db.collection('verification_requests')
            .where('status', '==', 'pending')
            .orderBy('timestamp', 'desc')
            .onSnapshot(snap => {
                this.render(snap);
            }, err => {
                console.error(err);
                this.tableBody.innerHTML = `<tr><td colspan="5" class="error-text">Error: ${err.message}</td></tr>`;
            });
    }

    async render(snap) {
        this.tableBody.innerHTML = '';

        if (snap.empty) {
            this.tableBody.innerHTML = '<tr><td colspan="5">No pending verification requests.</td></tr>';
            return;
        }

        for (const doc of snap.docs) {
            const req = doc.data();
            const tr = document.createElement('tr');

            // Fetch User Details
            const userSnap = await db.collection('users').doc(req.uid).get();
            const userData = userSnap.exists ? userSnap.data() : {};

            const badgeClass = req.requestedTier === 'gold' ? 'badge-gold' : 'badge-verified';

            tr.innerHTML = `
                <td>
                    <div class="user-cell-mini">
                        <b>${userData.displayName || 'Unknown'}</b><br>
                        <small class="text-muted">${userData.email || req.uid}</small>
                    </div>
                </td>
                <td>${userData.college || userData.department || 'N/A'}</td>
                <td><span class="badge ${badgeClass}">${req.requestedTier.toUpperCase()}</span></td>
                <td>${new Date(req.timestamp?.toDate()).toLocaleDateString()}</td>
                <td>
                    <div class="action-buttons">
                        <button class="btn-icon btn-approve" onclick="window.verificationController.action('${doc.id}', '${req.uid}', '${req.requestedTier}', true)" title="Approve">
                            <i class="fas fa-check"></i>
                        </button>
                        <button class="btn-icon btn-delete" onclick="window.verificationController.action('${doc.id}', '${req.uid}', '${req.requestedTier}', false)" title="Reject">
                            <i class="fas fa-times"></i>
                        </button>
                    </div>
                </td>
            `;
            this.tableBody.appendChild(tr);
        }
    }

    async action(requestId, uid, tier, approved) {
        const confirmMsg = approved ? `Approve ${tier.toUpperCase()} badge for this user?` : `Reject this request?`;
        if (!confirm(confirmMsg)) return;

        try {
            const batch = db.batch();

            // 1. Update Request Status
            batch.update(db.collection('verification_requests').doc(requestId), {
                status: approved ? 'approved' : 'rejected',
                processedAt: firebase.firestore.FieldValue.serverTimestamp()
            });

            // 2. If approved, update User Profile
            if (approved) {
                batch.update(db.collection('users').doc(uid), {
                    isVerified: true,
                    verificationType: tier
                });
            }

            await batch.commit();
            alert(approved ? "Verification approved!" : "Request rejected.");
        } catch (err) {
            alert("Error: " + err.message);
        }
    }
}
window.verificationController = new VerificationController();
