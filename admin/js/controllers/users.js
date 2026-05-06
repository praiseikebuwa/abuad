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
            .limit(500)
            .onSnapshot(snap => {
                this.users = [];
                snap.forEach(doc => {
                    this.users.push({ id: doc.id, ...doc.data() });
                });
                this.users.sort((a, b) => {
                    const timeA = a.createdAt?.seconds || a.created_at?.seconds || 0;
                    const timeB = b.createdAt?.seconds || b.created_at?.seconds || 0;
                    return timeB - timeA;
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
            const displayName = user.display_name || user.displayName || 'No Name';
            const initial = displayName[0].toUpperCase();
            const avatarUrl = user.avatar_url || user.profile_image_url || user.avatarUrl;
            const vType = user.verification_type || user.verificationType || (user.is_verified || user.isVerified ? 'blue' : 'none');

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
                        <div class="avatar-initial" style="background-color: ${seededColor(displayName)}; width: 40px; height: 40px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: bold; overflow: hidden; font-size: 1.2rem; color: #fff; box-shadow: 0 2px 5px rgba(0,0,0,0.2);">
                            ${avatarUrl ? `<img src="${avatarUrl}" style="width: 100%; height: 100%; object-fit: cover;" onerror="this.style.display='none'; this.nextElementSibling.style.display='inline';" /><span style="display:none;">${initial}</span>` : initial}
                        </div>
                        <div>
                            <div class="user-name">
                                ${displayName} 
                                ${iconHtml}
                            </div>
                            <small class="user-email">${user.email || 'No email'}</small>
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
                <td>${formatDate(user.created_at || user.createdAt)}</td>
                <td>
                    <div class="action-buttons" style="display: flex; gap: 8px; align-items: center;">
                        <button class="btn-icon btn-view" 
                                onclick="window.usersController.openUserModal('${user.id}')"
                                title="View Profile" style="color: #4facfe; background: rgba(79, 172, 254, 0.1); border: none; padding: 6px 10px; border-radius: 4px; cursor: pointer;">
                            <i class="fas fa-id-badge"></i>
                        </button>
                        <div class="verification-tier-buttons" style="display: flex; gap: 2px; border: 1px solid rgba(255,255,255,0.1); border-radius: 4px; padding: 2px;">
                            <button class="btn-icon btn-tier-none ${vType === 'none' ? 'active' : ''}" 
                                    onclick="window.usersController.setVerification('${user.id}', 'none')"
                                    title="Unverify" style="background: ${vType === 'none' ? 'rgba(255,255,255,0.1)' : 'transparent'}; border: none; color: #fff; padding: 4px 6px; cursor: pointer; border-radius: 2px;">
                                <i class="fas fa-times"></i>
                            </button>
                            <button class="btn-icon btn-tier-blue ${vType === 'blue' ? 'active' : ''}" 
                                    onclick="window.usersController.setVerification('${user.id}', 'blue')"
                                    title="Blue Badge" style="background: ${vType === 'blue' ? 'rgba(29, 161, 242, 0.2)' : 'transparent'}; border: none; color: #1DA1F2; padding: 4px 6px; cursor: pointer; border-radius: 2px;">
                                <i class="fas fa-check"></i>
                            </button>
                            <button class="btn-icon btn-tier-gold ${vType === 'gold' ? 'active' : ''}" 
                                    onclick="window.usersController.setVerification('${user.id}', 'gold')"
                                    title="Gold Badge" style="background: ${vType === 'gold' ? 'rgba(255, 215, 0, 0.2)' : 'transparent'}; border: none; color: #FFD700; padding: 4px 6px; cursor: pointer; border-radius: 2px;">
                                <i class="fas fa-award"></i>
                            </button>
                        </div>
                        <button class="btn-icon ${user.status === 'banned' ? 'btn-unban' : 'btn-ban'}" 
                                onclick="window.usersController.toggleBan('${user.id}', ${user.status === 'banned'})"
                                title="${user.status === 'banned' ? 'Unban User' : 'Ban User'}"
                                style="color: ${user.status === 'banned' ? '#4caf50' : '#f44336'}; background: rgba(0,0,0,0.2); border: none; padding: 6px 10px; border-radius: 4px; cursor: pointer;">
                            <i class="fas ${user.status === 'banned' ? 'fa-unlock' : 'fa-ban'}"></i>
                        </button>
                        <button class="btn-icon btn-delete" 
                                onclick="window.usersController.deleteUser('${user.id}')"
                                title="Delete User" style="color: #ff4d4d; background: rgba(255, 77, 77, 0.1); border: none; padding: 6px 10px; border-radius: 4px; cursor: pointer;">
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

    openUserModal(uid) {
        const user = this.users.find(u => u.id === uid);
        if (!user) return;

        let modal = document.getElementById('user-detail-modal');
        if (!modal) {
            modal = document.createElement('div');
            modal.id = 'user-detail-modal';
            modal.className = 'modal-overlay';
            document.body.appendChild(modal);
        }

        const displayName = user.display_name || user.displayName || 'No Name';
        const avatarUrl = user.avatar_url || user.profile_image_url || user.avatarUrl;
        const initial = displayName[0].toUpperCase();
        const vType = user.verification_type || user.verificationType || (user.is_verified || user.isVerified ? 'blue' : 'none');
        const vBadge = vType === 'gold' ? '🥇 Gold' : (vType === 'blue' ? 'Verified' : 'None');

        modal.innerHTML = `
            <div class="modal-content" style="width: 500px;">
                <div class="modal-header">
                    <h2>User Profile Details</h2>
                    <button onclick="document.getElementById('user-detail-modal').style.display='none'" class="btn-close">&times;</button>
                </div>
                <div class="modal-body">
                    <div style="display:flex; gap:20px; align-items:center; margin-bottom:25px;">
                        <div class="avatar-initial" style="width:80px; height:80px; font-size:2rem; background-color: ${seededColor(displayName)}; border-radius: 50%; overflow: hidden; display: flex; align-items: center; justify-content: center; box-shadow: 0 4px 10px rgba(0,0,0,0.3);">
                            ${avatarUrl ? `<img src="${avatarUrl}" style="width: 100%; height: 100%; object-fit: cover;" onerror="this.style.display='none'; this.nextElementSibling.style.display='inline';" /><span style="display:none;">${initial}</span>` : initial}
                        </div>
                        <div>
                            <h2 style="margin:0">${displayName}</h2>
                            <p style="color:var(--text-secondary); margin:4px 0;">@${user.handle || 'no_handle'}</p>
                            <span class="status-badge ${user.status || 'offline'}">${user.status || 'Offline'}</span>
                        </div>
                    </div>

                    <div style="display:grid; grid-template-columns: 1fr 1fr; gap:15px;">
                        <div class="card" style="padding:15px; background:rgba(255,255,255,0.02)">
                            <small style="color:var(--text-muted)">Email</small>
                            <div style="font-weight:500; word-break:break-all;">${user.email || 'N/A'}</div>
                        </div>
                        <div class="card" style="padding:15px; background:rgba(255,255,255,0.02)">
                            <small style="color:var(--text-muted)">College/Department</small>
                            <div style="font-weight:500;">${user.college || user.department || 'N/A'}</div>
                        </div>
                        <div class="card" style="padding:15px; background:rgba(255,255,255,0.02)">
                            <small style="color:var(--text-muted)">Followers</small>
                            <div style="font-weight:500;">${user.followers_count || 0}</div>
                        </div>
                        <div class="card" style="padding:15px; background:rgba(255,255,255,0.02)">
                            <small style="color:var(--text-muted)">Verification</small>
                            <div style="font-weight:500;">${vBadge}</div>
                        </div>
                    </div>

                    <div style="margin-top:20px;">
                        <small style="color:var(--text-muted)">Biography</small>
                        <p style="margin-top:5px; line-height:1.4;">${user.bio || '<i>No biography provided.</i>'}</p>
                    </div>

                    <div style="margin-top:20px;">
                        <small style="color:var(--text-muted)">Streak/Activity</small>
                        <div style="display:flex; gap:10px; margin-top:5px;">
                             <span>🔥 ${user.streak_count || user.streak || 0} Day Streak</span>
                             <span>📅 Joined ${formatDate(user.created_at || user.createdAt)}</span>
                        </div>
                    </div>
                </div>
                <div class="modal-footer">
                    <button class="btn-primary" style="width:100%" onclick="document.getElementById('user-detail-modal').style.display='none'">Done</button>
                </div>
            </div>
        `;

        modal.style.display = 'flex';
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
    const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
    return date.toLocaleDateString(undefined, {
        day: 'numeric', month: 'short', year: 'numeric'
    });
}
