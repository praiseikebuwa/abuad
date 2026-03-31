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
            const vType = user.verificationType || (user.isVerified ? 'blue' : 'none');

            let badgeHtml = '';
            let iconHtml = '';

            if (vType === 'gold') {
                badgeHtml = '<span class="badge badge-gold">Gold</span>';
                iconHtml = '<i class="fas fa-check-circle verified-icon-gold" title="Gold Verified"></i>';
            } else if (vType === 'blue') {
                badgeHtml = '<span class="badge badge-verified">Blue</span>';
                iconHtml = '<i class="fas fa-check-circle verified-icon" title="Blue Verified"></i>';
            } else {
                badgeHtml = '<span class="badge badge-gray">None</span>';
            }

            tr.innerHTML = `
                <td>
                    <div class="user-cell">
                        <div class="avatar-initial" style="background-color: ${seededColor(user.displayName)}">${initial}</div>
                        <div>
                            <div class="user-name">
                                ${user.displayName || 'No Name'} 
                                ${iconHtml}
                            </div>
                            <small class="user-email">${user.email}</small>
                        </div>
                    </div>
                </td>
                <td>
                    <span class="status-badge ${user.status || 'offline'}">
                        ${user.status === 'online' ? '● Online' : (user.status === 'banned' ? '🚫 Banned' : 'Offline')}
                    </span>
                </td>
                <td>
                    ${badgeHtml}
                </td>
                <td>${formatDate(user.createdAt || user.created_at)}</td>
                <td>
                    <div class="action-buttons">
                        <div class="verification-tier-buttons">
                            <button class="btn-icon btn-tier-none ${vType === 'none' ? 'active' : ''}" 
                                    onclick="window.usersController.setVerification('${user.id}', 'none')"
                                    title="Unverify">
                                <i class="fas fa-times"></i>
                            </button>
                            <button class="btn-icon btn-tier-blue ${vType === 'blue' ? 'active' : ''}" 
                                    onclick="window.usersController.setVerification('${user.id}', 'blue')"
                                    title="Blue Badge">
                                <i class="fas fa-check"></i>
                            </button>
                            <button class="btn-icon btn-tier-gold ${vType === 'gold' ? 'active' : ''}" 
                                    onclick="window.usersController.setVerification('${user.id}', 'gold')"
                                    title="Gold Badge">
                                <i class="fas fa-award"></i>
                            </button>
                        </div>
                        <button class="btn-icon ${user.status === 'banned' ? 'btn-unban' : 'btn-ban'}" 
                                onclick="window.usersController.toggleBan('${user.id}', ${user.status === 'banned'})"
                                title="${user.status === 'banned' ? 'Unban User' : 'Ban User'}"
                                style="color: ${user.status === 'banned' ? '#4caf50' : '#f44336'}">
                            <i class="fas ${user.status === 'banned' ? 'fa-unlock' : 'fa-ban'}"></i>
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

    setVerification(uid, type) {
        db.collection('users').doc(uid).update({
            verificationType: type,
            isVerified: type !== 'none'
        }).then(() => {
            window.logAdminAction('VERIFY_USER', `Updated verification tier to ${type} for User ${uid}`, 'user', uid);
        }).catch(err => alert("Error: " + err.message));
    }

    toggleBan(uid, isBanned) {
        const newStatus = isBanned ? 'offline' : 'banned';
        const confirmMsg = isBanned ? "Unban this user?" : "Permenantly BAN this user from the platform?";

        if (confirm(confirmMsg)) {
            db.collection('users').doc(uid).update({
                status: newStatus
            }).then(() => {
                window.logAdminAction(isBanned ? 'UNBAN_USER' : 'BAN_USER', `Toggled ban status for User ${uid}`, 'user', uid);
            }).catch(err => alert("Error: " + err.message));
        }
    }

    deleteUser(uid) {
        if (confirm("DANGER: This will delete the user's profile data permanently. Continue?")) {
            db.collection('users').doc(uid).delete().then(() => {
                window.logAdminAction('DELETE_USER', `Permanently deleted user profile for ${uid}`, 'user', uid);
            })
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
