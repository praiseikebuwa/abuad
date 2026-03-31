class StaffController {
    constructor() {
        this.tableBody = document.querySelector('#staff-table tbody');
    }

    load() {
        if (!this.tableBody) return;
        this.tableBody.innerHTML = '<tr><td colspan="5" class="loading-text">Loading staff directory...</td></tr>';

        if (this.unsubscribe) this.unsubscribe();

        // Admins are users with role == 'admin' or isAdmin == true
        this.unsubscribe = db.collection('users')
            .where('role', '==', 'admin')
            .onSnapshot(snap => {
                this.render(snap);
            }, err => {
                console.error(err);
                this.tableBody.innerHTML = `<tr><td colspan="5" class="error-text">Error: ${err.message}</td></tr>`;
            });
    }

    render(snap) {
        this.tableBody.innerHTML = '';

        if (snap.empty) {
            this.tableBody.innerHTML = '<tr><td colspan="5">No staff members found.</td></tr>';
            return;
        }

        snap.forEach(doc => {
            const staff = doc.data();
            const tr = document.createElement('tr');

            const initial = staff.displayName ? staff.displayName[0].toUpperCase() : '?';
            const lastActive = staff.lastActive ? new Date(staff.lastActive.toDate()).toLocaleString() : 'Never';

            tr.innerHTML = `
                <td>
                    <div class="user-cell">
                        <div class="avatar-initial" style="background: var(--color-primary); color: white;">${initial}</div>
                        <div>
                            <b>${staff.displayName || 'Unknown Staff'}</b><br>
                            <small class="text-muted">${staff.email}</small>
                        </div>
                    </div>
                </td>
                <td><span class="badge badge-admin">Administrator</span></td>
                <td><span class="status-badge online">● Active</span></td>
                <td><small>${lastActive}</small></td>
                <td style="text-align: right;">
                    <button class="btn-icon btn-delete" onclick="window.staffController.removeStaff('${doc.id}', '${staff.displayName}')" title="Revoke Admin Access">
                        <i class="fas fa-user-shield"></i>
                    </button>
                </td>
            `;
            this.tableBody.appendChild(tr);
        });
    }

    async removeStaff(uid, name) {
        if (confirm(`Revoke administrative access for ${name}? they will no longer be able to access this portal.`)) {
            try {
                await db.collection('users').doc(uid).update({
                    role: 'user',
                    isAdmin: false
                });
                window.logAdminAction('REVOKE_STAFF', `Revoked admin access for ${name}`, 'user', uid);
                alert("Access revoked.");
            } catch (err) {
                alert("Error: " + err.message);
            }
        }
    }

    showAddModal() {
        const email = prompt("Enter the email address of the user you wish to promote to Staff/Admin:");
        if (!email) return;

        this.promoteByEmail(email);
    }

    async promoteByEmail(email) {
        try {
            const snap = await db.collection('users').where('email', '==', email).get();
            if (snap.empty) {
                alert("User not found with that email address.");
                return;
            }

            const userDoc = snap.docs[0];
            await userDoc.ref.update({
                role: 'admin',
                isAdmin: true
            });

            window.logAdminAction('PROMOTE_STAFF', `Promoted ${email} to Admin`, 'user', userDoc.id);
            alert(`${email} has been promoted to Staff.`);
        } catch (err) {
            alert("Error: " + err.message);
        }
    }
}

window.staffController = new StaffController();
