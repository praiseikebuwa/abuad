class UsersController {
    constructor() {
        this.tableBody = document.querySelector('#users-table tbody');
        this.users = []; // Cache for search

        // Search Listener
        const searchInput = document.getElementById('user-search');
        if (searchInput) {
            searchInput.addEventListener('input', (e) => {
                this.filterUsers(e.target.value);
            });
        }
    }

    load() {
        this.tableBody.innerHTML = '<tr><td colspan="5" class="loading-text">Loading users directory...</td></tr>';

        // Unsubscribe from previous listener if exists
        if (this.unsubscribe) this.unsubscribe();

        this.unsubscribe = db.collection('users')
            .orderBy('createdAt', 'desc')
            .limit(100)
            .onSnapshot(snap => {
                this.users = [];
                snap.forEach(doc => {
                    this.users.push({ id: doc.id, ...doc.data() });
                });
                this.renderTable(this.users);
            }, err => {
                console.error(err);
                this.tableBody.innerHTML = `<tr><td colspan="5" class="error-text">Error loading users: ${err.message}</td></tr>`;
            });
    }

    filterUsers(query) {
        if (!query) {
            this.renderTable(this.users);
            return;
        }
        const lower = query.toLowerCase();
        const filtered = this.users.filter(u =>
            (u.displayName && u.displayName.toLowerCase().includes(lower)) ||
            (u.email && u.email.toLowerCase().includes(lower)) ||
            (u.handle && u.handle.toLowerCase().includes(lower))
        );
        this.renderTable(filtered);
    }

    renderTable(userList) {
        this.tableBody.innerHTML = '';

        if (userList.length === 0) {
            this.tableBody.innerHTML = '<tr><td colspan="5">No matching users found.</td></tr>';
            return;
        }

        userList.forEach(user => {
            const tr = document.createElement('tr');

            const initial = user.displayName ? user.displayName[0].toUpperCase() : '?';
            const isVerified = user.isVerified || false;

            tr.innerHTML = `
                <td>
                    <div class="user-cell">
                        <div class="avatar-initial" style="background-color: ${seededColor(user.displayName)}">${initial}</div>
                        <div>
                            <div class="user-name">
                                ${user.displayName || 'No Name'} 
                                ${isVerified ? '<i class="fas fa-check-circle verified-icon"></i>' : ''}
                            </div>
                            <small class="user-email">${user.email}</small>
                        </div>
                    </div>
                </td>
                <td>
                    <span class="status-badge ${user.status || 'offline'}">
                        ${user.status === 'online' ? '● Online' : 'Offline'}
                    </span>
                </td>
                <td>
                    <span class="badge ${isVerified ? 'badge-verified' : 'badge-gray'}">
                        ${isVerified ? 'Verified' : 'Unverified'}
                    </span>
                </td>
                <td>${formatDate(user.createdAt)}</td>
                <td>
                    <div class="action-buttons">
                        <button class="btn-icon ${isVerified ? 'btn-revoke' : 'btn-approve'}" 
                                onclick="window.usersController.toggleVerify('${user.id}', ${!isVerified})"
                                title="${isVerified ? 'Revoke Verification' : 'Verify User'}">
                            <i class="fas ${isVerified ? 'fa-times' : 'fa-check'}"></i>
                        </button>
                        <button class="btn-icon btn-delete" 
                                onclick="window.usersController.deleteUser('${user.id}')"
                                title="Delete User">
                            <i class="fas fa-trash"></i>
                        </button>
                    </div>
                </td>
            `;
            this.tableBody.appendChild(tr);
        });

        // Update stats counter if exists
        const totalCount = document.getElementById('stat-total-users');
        if (totalCount) totalCount.innerText = this.users.length + '+';
    }

    // Keep render method for compatibility if needed, but load calls renderTable via onSnapshot callbacks now.
    // Actually, I removed render() and replaced logic in load(). 
    // I should remove the old render() method to avoid confusion? 
    // Yes.
    render(snap) { /* Deprecated */ }

    toggleVerify(uid, newStatus) {
        // Optimistic UI update could happen here, but Firestore listener handles it fast enough
        db.collection('users').doc(uid).update({
            isVerified: newStatus
        }).catch(err => alert("Error: " + err.message));
    }

    deleteUser(uid) {
        if (confirm("DANGER: This will delete the user's profile data permanently. Continue?")) {
            db.collection('users').doc(uid).delete()
                .catch(err => alert("Error: " + err.message));
        }
    }
}

// Helpers
function seededColor(name) {
    if (!name) return '#9e9e9e';
    const colors = ['#1976d2', '#388e3c', '#d32f2f', '#7b1fa2', '#f57c00', '#0097a7'];
    let hash = 0;
    for (let i = 0; i < name.length; i++) {
        hash = name.charCodeAt(i) + ((hash << 5) - hash);
    }
    return colors[Math.abs(hash) % colors.length];
}

function formatDate(timestamp) {
    if (!timestamp) return 'N/A';
    return new Date(timestamp).toLocaleDateString(undefined, {
        day: 'numeric', month: 'short', year: 'numeric'
    });
}
