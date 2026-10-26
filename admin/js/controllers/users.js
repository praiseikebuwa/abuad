class UsersController {
    constructor() {
        this.tableBody = document.querySelector('#users-table tbody');
        this.users = []; // Cache
        this.selectedUserIds = new Set();

        this.initControls();
    }

    initControls() {
        // Search Listener
        const searchInput = document.getElementById('user-search');
        if (searchInput) {
            searchInput.addEventListener('input', () => this.applyFilters());
        }

        // Dropdown Filters
        const roleFilter = document.getElementById('user-role-filter');
        if (roleFilter) roleFilter.addEventListener('change', () => this.applyFilters());

        const statusFilter = document.getElementById('user-status-filter');
        if (statusFilter) statusFilter.addEventListener('change', () => this.applyFilters());

        const tierFilter = document.getElementById('user-tier-filter');
        if (tierFilter) tierFilter.addEventListener('change', () => this.applyFilters());

        // Refresh Button
        const refreshBtn = document.getElementById('users-refresh-btn');
        if (refreshBtn) refreshBtn.addEventListener('click', () => this.load());

        // Export CSV Button
        const exportBtn = document.getElementById('users-export-btn');
        if (exportBtn) exportBtn.addEventListener('click', () => this.exportCsv());

        // Select All Checkbox
        const selectAll = document.getElementById('users-select-all');
        if (selectAll) {
            selectAll.addEventListener('change', (e) => {
                const checkboxes = document.querySelectorAll('.user-row-checkbox');
                checkboxes.forEach(cb => {
                    cb.checked = e.target.checked;
                    if (e.target.checked) {
                        this.selectedUserIds.add(cb.value);
                    } else {
                        this.selectedUserIds.delete(cb.value);
                    }
                });
                this.updateBulkActionBar();
            });
        }

        // Bulk Actions
        const bulkVerifyBtn = document.getElementById('bulk-verify-blue-btn');
        if (bulkVerifyBtn) {
            bulkVerifyBtn.addEventListener('click', () => this.bulkSetVerification('blue'));
        }

        const bulkBanBtn = document.getElementById('bulk-ban-btn');
        if (bulkBanBtn) {
            bulkBanBtn.addEventListener('click', () => this.bulkToggleBan(true));
        }
    }

    load() {
        this.tableBody.innerHTML = '<tr><td colspan="6" class="loading-text">Loading users directory...</td></tr>';

        if (typeof this.unsubscribe === 'function') this.unsubscribe();

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
                this.applyFilters();
            }, err => {
                console.error(err);
                this.tableBody.innerHTML = `<tr><td colspan="6" class="error-text">Error loading users: ${err.message}</td></tr>`;
            });
    }

    applyFilters() {
        const query = (document.getElementById('user-search')?.value || '').toLowerCase().trim();
        const role = document.getElementById('user-role-filter')?.value || 'all';
        const status = document.getElementById('user-status-filter')?.value || 'all';
        const tier = document.getElementById('user-tier-filter')?.value || 'all';

        let filtered = this.users;

        // Text search
        if (query) {
            filtered = filtered.filter(u =>
                (u.fullName && u.fullName.toLowerCase().includes(query)) ||
                (u.displayName && u.displayName.toLowerCase().includes(query)) ||
                (u.email && u.email.toLowerCase().includes(query)) ||
                (u.username && u.username.toLowerCase().includes(query)) ||
                (u.department && u.department.toLowerCase().includes(query)) ||
                (u.matricNumber && u.matricNumber.toLowerCase().includes(query))
            );
        }

        // Role filter
        if (role !== 'all') {
            filtered = filtered.filter(u => (u.role || 'student').toLowerCase() === role.toLowerCase());
        }

        // Status filter
        if (status === 'online') {
            filtered = filtered.filter(u => u.status === 'online');
        } else if (status === 'banned') {
            filtered = filtered.filter(u => u.status === 'banned' || u.isBlocked === true);
        }

        // Verification tier filter
        if (tier !== 'all') {
            filtered = filtered.filter(u => {
                const v = (u.verificationType || u.verification_type || (u.isVerified ? 'blue' : 'none')).toLowerCase();
                return v === tier;
            });
        }

        this.renderTable(filtered);
    }

    renderTable(userList) {
        this.tableBody.innerHTML = '';

        if (userList.length === 0) {
            this.tableBody.innerHTML = '<tr><td colspan="6" style="text-align: center; padding: 30px; color: var(--text-secondary);">No matching users found.</td></tr>';
            return;
        }

        userList.forEach(user => {
            const tr = document.createElement('tr');
            const displayName = user.fullName || user.displayName || user.display_name || user.username || 'Unknown';
            const handle = user.username || user.handle || '';
            const initial = displayName.length > 0 ? displayName[0].toUpperCase() : '?';
            const avatarUrl = user.avatarUrl || user.avatar_url || user.profile_image_url;
            const rawVType = (user.verificationType || user.verification_type || (user.isVerified || user.is_verified ? 'blue' : 'none')).toString().toLowerCase();
            const vType = rawVType === 'violet' ? 'violet' : (rawVType === 'gold' ? 'gold' : (rawVType === 'blue' ? 'blue' : 'none'));

            let badgeHtml = '';
            let iconHtml = '';

            if (vType === 'violet') {
                badgeHtml = '<span class="badge" style="background: rgba(124, 58, 237, 0.2); color: #a78bfa; border: 1px solid #7C3AED; padding: 2px 8px; border-radius: 12px; font-weight: 600; font-size: 0.78rem;">Violet Leader</span>';
                iconHtml = '<i class="fas fa-check-circle" style="color: #7C3AED; margin-left: 4px;" title="Violet Verified"></i>';
            } else if (vType === 'gold') {
                badgeHtml = '<span class="badge" style="background: rgba(217, 119, 6, 0.2); color: #fbbf24; border: 1px solid #D97706; padding: 2px 8px; border-radius: 12px; font-weight: 600; font-size: 0.78rem;">Gold Honors</span>';
                iconHtml = '<i class="fas fa-check-circle" style="color: #D97706; margin-left: 4px;" title="Gold Verified"></i>';
            } else if (vType === 'blue') {
                badgeHtml = '<span class="badge" style="background: rgba(2, 132, 199, 0.2); color: #38bdf8; border: 1px solid #0284C7; padding: 2px 8px; border-radius: 12px; font-weight: 600; font-size: 0.78rem;">Blue Verified</span>';
                iconHtml = '<i class="fas fa-check-circle" style="color: #0284C7; margin-left: 4px;" title="Blue Verified"></i>';
            } else {
                badgeHtml = '<span class="badge badge-gray" style="font-size: 0.78rem;">Unverified</span>';
            }

            const isChecked = this.selectedUserIds.has(user.id);

            tr.innerHTML = `
                <td>
                    <input type="checkbox" class="user-row-checkbox" value="${user.id}" ${isChecked ? 'checked' : ''} onchange="window.usersController.toggleRowSelection('${user.id}', this.checked)">
                </td>
                <td>
                    <div class="user-cell" style="display: flex; align-items: center; gap: 12px;">
                        <div class="avatar-initial" style="background-color: ${seededColor(displayName)}; width: 40px; height: 40px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: bold; overflow: hidden; font-size: 1.1rem; color: #fff; box-shadow: 0 2px 5px rgba(0,0,0,0.3); flex-shrink: 0;">
                            ${avatarUrl ? `<img src="${avatarUrl}" style="width: 100%; height: 100%; object-fit: cover;" onerror="this.style.display='none'; this.nextElementSibling.style.display='inline';" /><span style="display:none;">${initial}</span>` : initial}
                        </div>
                        <div>
                            <div class="user-name" style="font-weight: 600; color: var(--text-primary); font-size: 0.92rem; display: flex; align-items: center;">
                                ${displayName} 
                                ${iconHtml}
                            </div>
                            <small class="user-email" style="color: var(--text-secondary); font-size: 0.8rem;">${user.email || (handle ? '@' + handle : 'No email')}</small>
                        </div>
                    </div>
                </td>
                <td>
                    <span class="status-badge ${user.status || 'offline'}" style="font-size: 0.78rem; padding: 3px 8px; border-radius: 10px;">
                        ${user.status === 'online' ? '🟢 Online' : (user.status === 'banned' ? '🚫 Banned' : '⚪ Offline')}
                    </span>
                </td>
                <td>
                    ${badgeHtml}
                </td>
                <td><small style="color: var(--text-secondary);">${formatDate(user.createdAt || user.created_at)}</small></td>
                <td style="text-align: right;">
                    <div class="action-buttons" style="display: inline-flex; gap: 6px; align-items: center; justify-content: flex-end;">
                        <button class="btn-icon btn-view" 
                                onclick="window.usersController.openUserModal('${user.id}')"
                                title="Inspect Student Profile">
                            <i class="fas fa-id-badge"></i>
                        </button>
                        <button class="btn-icon btn-notify" 
                                onclick="window.usersController.openNotifyModal('${user.id}')"
                                title="Direct Message / Alert">
                            <i class="fas fa-paper-plane"></i>
                        </button>
                        <div class="verification-tier-buttons">
                            <button class="btn-tier btn-tier-none ${vType === 'none' ? 'active' : ''}" 
                                    onclick="window.usersController.setVerification('${user.id}', 'none')"
                                    title="Unverify">
                                <i class="fas fa-times"></i>
                            </button>
                            <button class="btn-tier btn-tier-blue ${vType === 'blue' ? 'active' : ''}" 
                                    onclick="window.usersController.setVerification('${user.id}', 'blue')"
                                    title="Blue Badge">
                                <i class="fas fa-check-circle"></i>
                            </button>
                            <button class="btn-tier btn-tier-gold ${vType === 'gold' ? 'active' : ''}" 
                                    onclick="window.usersController.setVerification('${user.id}', 'gold')"
                                    title="Gold Badge">
                                <i class="fas fa-award"></i>
                            </button>
                            <button class="btn-tier btn-tier-violet ${vType === 'violet' ? 'active' : ''}" 
                                    onclick="window.usersController.setVerification('${user.id}', 'violet')"
                                    title="Violet Badge">
                                <i class="fas fa-crown"></i>
                            </button>
                        </div>
                        <button class="btn-icon ${user.status === 'banned' ? 'btn-unban' : 'btn-ban'}" 
                                onclick="window.usersController.toggleBan('${user.id}', ${user.status === 'banned'})"
                                title="${user.status === 'banned' ? 'Unban Account' : 'Restrict / Ban Account'}">
                            <i class="fas ${user.status === 'banned' ? 'fa-unlock' : 'fa-ban'}"></i>
                        </button>
                        <button class="btn-icon btn-delete" 
                                onclick="window.usersController.deleteUser('${user.id}')"
                                title="Delete User">
                            <i class="fas fa-trash-alt"></i>
                        </button>
                    </div>
                </td>
            `;
            this.tableBody.appendChild(tr);
        });

        const totalCount = document.getElementById('stat-total-users');
        if (totalCount) totalCount.innerText = this.users.length + '+';
    }

    toggleRowSelection(userId, checked) {
        if (checked) {
            this.selectedUserIds.add(userId);
        } else {
            this.selectedUserIds.delete(userId);
        }
        this.updateBulkActionBar();
    }

    updateBulkActionBar() {
        const bar = document.getElementById('users-bulk-actions');
        const countSpan = document.getElementById('users-selected-count');
        if (!bar || !countSpan) return;

        if (this.selectedUserIds.size > 0) {
            bar.classList.add('active');
            countSpan.innerText = `${this.selectedUserIds.size} Selected`;
        } else {
            bar.classList.remove('active');
            countSpan.innerText = '0 Selected';
        }
    }

    async bulkSetVerification(tier) {
        if (this.selectedUserIds.size === 0) return;
        const count = this.selectedUserIds.size;
        if (!confirm(`Apply "${tier.toUpperCase()}" verification badge to ${count} selected accounts?`)) return;

        const promises = Array.from(this.selectedUserIds).map(uid => this.setVerification(uid, tier, true));
        await Promise.all(promises);
        this.selectedUserIds.clear();
        this.updateBulkActionBar();
        alert(`Successfully updated verification for ${count} users.`);
    }

    async bulkToggleBan(shouldBan) {
        if (this.selectedUserIds.size === 0) return;
        const count = this.selectedUserIds.size;
        if (!confirm(`${shouldBan ? 'Ban' : 'Unban'} ${count} selected accounts?`)) return;

        const promises = Array.from(this.selectedUserIds).map(uid => this.toggleBan(uid, !shouldBan, true));
        await Promise.all(promises);
        this.selectedUserIds.clear();
        this.updateBulkActionBar();
        alert(`Successfully ${shouldBan ? 'banned' : 'unbanned'} ${count} users.`);
    }

    exportCsv() {
        if (this.users.length === 0) {
            alert('No user records available to export.');
            return;
        }

        const headers = ['ID', 'Full Name', 'Username', 'Email', 'Role', 'Department', 'Level', 'Status', 'Verification', 'Created Date'];
        const rows = this.users.map(u => [
            u.id || '',
            `"${(u.fullName || u.displayName || '').replace(/"/g, '""')}"`,
            `"${(u.username || u.handle || '').replace(/"/g, '""')}"`,
            `"${(u.email || '').replace(/"/g, '""')}"`,
            u.role || 'student',
            `"${(u.department || '').replace(/"/g, '""')}"`,
            u.level || '',
            u.status || 'offline',
            u.verificationType || (u.isVerified ? 'blue' : 'none'),
            u.createdAt ? new Date(u.createdAt.seconds ? u.createdAt.seconds * 1000 : u.createdAt).toISOString() : ''
        ]);

        const csvContent = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map(r => r.join(','))].join('\n');
        const encodedUri = encodeURI(csvContent);
        const link = document.createElement('a');
        link.setAttribute('href', encodedUri);
        link.setAttribute('download', `abuad_users_export_${new Date().toISOString().split('T')[0]}.csv`);
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
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

        const displayName = user.fullName || user.displayName || user.display_name || user.username || 'No Name';
        const handle = user.username || user.handle || 'no_handle';
        const avatarUrl = user.avatarUrl || user.avatar_url || user.profile_image_url;
        const bannerUrl = user.bannerUrl || user.banner_url;
        const initial = displayName.length > 0 ? displayName[0].toUpperCase() : '?';

        const rawVType = (user.verificationType || user.verification_type || (user.isVerified || user.is_verified ? 'blue' : 'none')).toString().toLowerCase();
        
        let vBadgeHtml = '';
        if (rawVType === 'violet') {
            vBadgeHtml = '<span class="badge" style="background: rgba(124, 58, 237, 0.2); color: #7C3AED; border: 1px solid #7C3AED; padding: 4px 10px; border-radius: 12px; font-weight: 600; font-size: 0.85rem;"><i class="fas fa-crown"></i> Violet Badge</span>';
        } else if (rawVType === 'gold') {
            vBadgeHtml = '<span class="badge" style="background: rgba(217, 119, 6, 0.2); color: #D97706; border: 1px solid #D97706; padding: 4px 10px; border-radius: 12px; font-weight: 600; font-size: 0.85rem;"><i class="fas fa-award"></i> Gold Badge</span>';
        } else if (rawVType === 'blue') {
            vBadgeHtml = '<span class="badge" style="background: rgba(2, 132, 199, 0.2); color: #0284C7; border: 1px solid #0284C7; padding: 4px 10px; border-radius: 12px; font-weight: 600; font-size: 0.85rem;"><i class="fas fa-check-circle"></i> Blue Badge</span>';
        } else {
            vBadgeHtml = '<span class="badge badge-gray" style="padding: 4px 10px; border-radius: 12px;">None</span>';
        }

        const followers = user.followersCount ?? user.followers_count ?? 0;
        const following = user.followingCount ?? user.following_count ?? 0;
        const streak = user.streakCount ?? user.streak_count ?? user.streak ?? 0;
        const collegeDept = [user.college, user.department].filter(Boolean).join(' / ') || 'N/A';
        const levelRole = [user.level ? `Level ${user.level}` : null, user.role || 'STUDENT'].filter(Boolean).join(' • ') || 'Student';
        const phone = user.phoneNumber || user.phone_number || 'N/A';
        const bio = user.bio || 'No biography provided.';

        // Social links matching drawing
        const socialLinks = [];
        const extractRawUsername = (url) => {
            try {
                const u = new URL(url);
                const parts = u.pathname.split('/').filter(Boolean);
                if (parts.length > 0) {
                    const last = parts[parts.length - 1].replace(/^@/, '');
                    if (last !== 'add' && last !== 'in' && last !== 'user' && last !== 'u') return last;
                    if (parts.length > 1) return parts[parts.length - 2].replace(/^@/, '');
                }
            } catch (e) {}
            return '';
        };

        const cleanDisplayUrl = (url) => url.replace(/^https?:\/\/(www\.)?/, '');

        if (user.snapchatUrl || user.snapchat_url) {
            const url = user.snapchatUrl || user.snapchat_url;
            const uName = extractRawUsername(url);
            socialLinks.push({ icon: 'fab fa-snapchat-ghost', brandColor: '#FFFC00', iconColor: '#000', title: uName ? '@' + uName : 'Snapchat', subtitle: cleanDisplayUrl(url), url, avatarUrl: uName ? `https://unavatar.io/snapchat/${uName}` : null });
        }
        if (user.githubUrl || user.github_url) {
            const url = user.githubUrl || user.github_url;
            const uName = extractRawUsername(url);
            socialLinks.push({ icon: 'fab fa-github', brandColor: '#24292E', iconColor: '#fff', title: uName ? '@' + uName : 'GitHub', subtitle: cleanDisplayUrl(url), url, avatarUrl: uName ? `https://github.com/${uName}.png` : null });
        }
        if (user.twitterUrl || user.twitter_url) {
            const url = user.twitterUrl || user.twitter_url;
            const uName = extractRawUsername(url);
            socialLinks.push({ icon: 'fab fa-twitter', brandColor: '#14171A', iconColor: '#fff', title: uName ? '@' + uName : 'Twitter', subtitle: cleanDisplayUrl(url), url, avatarUrl: uName ? `https://unavatar.io/x/${uName}` : null });
        }
        if (user.instagramUrl || user.instagram_url) {
            const url = user.instagramUrl || user.instagram_url;
            const uName = extractRawUsername(url);
            socialLinks.push({ icon: 'fab fa-instagram', brandColor: '#E4405F', iconColor: '#fff', title: uName ? '@' + uName : 'Instagram', subtitle: cleanDisplayUrl(url), url, avatarUrl: uName ? `https://unavatar.io/instagram/${uName}` : null });
        }
        if (user.linkedinUrl || user.linkedin_url) {
            const url = user.linkedinUrl || user.linkedin_url;
            const uName = extractRawUsername(url);
            socialLinks.push({ icon: 'fab fa-linkedin-in', brandColor: '#0A66C2', iconColor: '#fff', title: uName ? '@' + uName : 'LinkedIn', subtitle: cleanDisplayUrl(url), url, avatarUrl: uName ? `https://unavatar.io/linkedin/${uName}` : null });
        }
        if (user.youtubeUrl || user.youtube_url) {
            const url = user.youtubeUrl || user.youtube_url;
            const uName = extractRawUsername(url);
            socialLinks.push({ icon: 'fab fa-youtube', brandColor: '#FF0000', iconColor: '#fff', title: uName ? '@' + uName : 'YouTube', subtitle: cleanDisplayUrl(url), url, avatarUrl: uName ? `https://unavatar.io/youtube/${uName}` : null });
        }
        if (user.tiktokUrl || user.tiktok_url) {
            const url = user.tiktokUrl || user.tiktok_url;
            const uName = extractRawUsername(url);
            socialLinks.push({ icon: 'fab fa-tiktok', brandColor: '#010101', iconColor: '#fff', title: uName ? '@' + uName : 'TikTok', subtitle: cleanDisplayUrl(url), url, avatarUrl: uName ? `https://unavatar.io/tiktok/${uName}` : null });
        }
        if (user.facebookUrl || user.facebook_url) {
            const url = user.facebookUrl || user.facebook_url;
            const uName = extractRawUsername(url);
            socialLinks.push({ icon: 'fab fa-facebook-f', brandColor: '#1877F2', iconColor: '#fff', title: uName ? '@' + uName : 'Facebook', subtitle: cleanDisplayUrl(url), url, avatarUrl: uName ? `https://unavatar.io/facebook/${uName}` : null });
        }
        if (user.twitchUrl || user.twitch_url) {
            const url = user.twitchUrl || user.twitch_url;
            const uName = extractRawUsername(url);
            socialLinks.push({ icon: 'fab fa-twitch', brandColor: '#9146FF', iconColor: '#fff', title: uName ? '@' + uName : 'Twitch', subtitle: cleanDisplayUrl(url), url, avatarUrl: uName ? `https://unavatar.io/twitch/${uName}` : null });
        }
        if (user.websiteUrl || user.website_url) {
            const url = user.websiteUrl || user.website_url;
            const clean = cleanDisplayUrl(url);
            const domain = clean.split('/')[0];
            socialLinks.push({ icon: 'fas fa-globe', brandColor: '#0284C7', iconColor: '#fff', title: domain, subtitle: clean, url, avatarUrl: `https://unavatar.io/${domain}` });
        }

        let socialsHtml = '';
        if (socialLinks.length > 0) {
            socialsHtml = `
                <div style="margin-top:16px;">
                    <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;">
                        <small style="color:var(--text-muted); font-size: 0.75rem; font-weight: 600;">Social Media Profiles</small>
                        ${socialLinks.length > 1 ? '<small style="color:var(--text-muted); font-size: 0.7rem;"><i class="fas fa-arrows-alt-h"></i> Swipe left</small>' : ''}
                    </div>
                    <div style="display:flex; overflow-x:auto; gap:10px; padding-bottom:6px; scrollbar-width: thin;">
                        ${socialLinks.map(s => `
                            <a href="${s.url}" target="_blank" rel="noopener noreferrer" style="display:flex; align-items:center; gap:10px; background:rgba(30, 41, 59, 0.8); border: 1.5px solid ${s.brandColor}; padding:8px 12px; border-radius:14px; text-decoration:none; flex-shrink:0; width: 230px; box-shadow: 0 2px 8px rgba(0,0,0,0.2);">
                                <div style="width: 40px; height: 40px; border-radius: 50%; background: ${s.brandColor}; display:flex; align-items:center; justify-content:center; flex-shrink:0; color: ${s.iconColor}; font-size: 1.1rem; box-shadow: 0 2px 4px rgba(0,0,0,0.3); overflow:hidden;">
                                    ${s.avatarUrl ? `<img src="${s.avatarUrl}" style="width:100%; height:100%; object-fit:cover;" onerror="this.style.display='none'; this.nextElementSibling.style.display='inline-flex';" /><i class="${s.icon}" style="display:none;"></i>` : `<i class="${s.icon}"></i>`}
                                </div>
                                <div style="overflow:hidden; flex:1;">
                                    <div style="color: #ffffff; font-weight: bold; font-size: 0.85rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${s.title}</div>
                                    <div style="color: #22C55E; font-weight: 600; font-size: 0.72rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; margin-top:1px;">${s.subtitle}</div>
                                </div>
                            </a>
                        `).join('')}
                    </div>
                </div>
            `;
        }

        modal.innerHTML = `
            <div class="modal-content" style="width: 540px; border-radius: 16px; overflow: hidden; max-height: 90vh; display: flex; flex-direction: column;">
                ${bannerUrl ? `
                    <div style="height: 120px; background: url('${bannerUrl}') center/cover no-repeat; position: relative;"></div>
                ` : `
                    <div style="height: 80px; background: linear-gradient(135deg, #1e293b, #0f172a); position: relative;"></div>
                `}
                <div class="modal-header" style="padding: 15px 20px; border-bottom: 1px solid rgba(255,255,255,0.1); background: transparent;">
                    <h2 style="margin:0; font-size: 1.3rem;">User Profile Details</h2>
                    <button onclick="document.getElementById('user-detail-modal').style.display='none'" class="btn-close">&times;</button>
                </div>
                <div class="modal-body" style="padding: 20px; overflow-y: auto;">
                    <div style="display:flex; gap:16px; align-items:center; margin-bottom:20px; margin-top: ${bannerUrl ? '-40px' : '0'};">
                        <div class="avatar-initial" style="width:72px; height:72px; font-size:1.8rem; background-color: ${seededColor(displayName)}; border-radius: 50%; overflow: hidden; display: flex; align-items: center; justify-content: center; box-shadow: 0 4px 12px rgba(0,0,0,0.4); border: 3px solid #1e293b;">
                            ${avatarUrl ? `<img src="${avatarUrl}" style="width: 100%; height: 100%; object-fit: cover;" onerror="this.style.display='none'; this.nextElementSibling.style.display='inline';" /><span style="display:none;">${initial}</span>` : initial}
                        </div>
                        <div style="flex:1;">
                            <h2 style="margin:0; font-size: 1.25rem;">${displayName}</h2>
                            <p style="color:var(--text-secondary); margin:2px 0 6px 0; font-size: 0.9rem;">@${handle}</p>
                            <div style="display:flex; gap:8px; align-items:center;">
                                <span class="status-badge ${user.status || 'offline'}">${user.status === 'online' ? '● Online' : (user.status === 'banned' ? '🚫 Banned' : 'Offline')}</span>
                                <span style="font-size:0.8rem; color:#aaa; background:rgba(255,255,255,0.06); padding:2px 8px; border-radius:8px;">${levelRole}</span>
                            </div>
                        </div>
                    </div>

                    <div style="display:grid; grid-template-columns: 1fr 1fr; gap:12px;">
                        <div class="card" style="padding:12px; background:rgba(255,255,255,0.03); border-radius: 10px; border: 1px solid rgba(255,255,255,0.05);">
                            <small style="color:var(--text-muted); font-size: 0.75rem;">Email Address</small>
                            <div style="font-weight:500; word-break:break-all; font-size: 0.9rem; margin-top:2px;">${user.email || 'N/A'}</div>
                        </div>
                        <div class="card" style="padding:12px; background:rgba(255,255,255,0.03); border-radius: 10px; border: 1px solid rgba(255,255,255,0.05);">
                            <small style="color:var(--text-muted); font-size: 0.75rem;">Phone Number</small>
                            <div style="font-weight:500; font-size: 0.9rem; margin-top:2px;">${phone}</div>
                        </div>
                        <div class="card" style="padding:12px; background:rgba(255,255,255,0.03); border-radius: 10px; border: 1px solid rgba(255,255,255,0.05);">
                            <small style="color:var(--text-muted); font-size: 0.75rem;">College / Department</small>
                            <div style="font-weight:500; font-size: 0.9rem; margin-top:2px;">${collegeDept}</div>
                        </div>
                        <div class="card" style="padding:12px; background:rgba(255,255,255,0.03); border-radius: 10px; border: 1px solid rgba(255,255,255,0.05);">
                            <small style="color:var(--text-muted); font-size: 0.75rem;">Verification Tier</small>
                            <div style="font-weight:500; margin-top:4px;">${vBadgeHtml}</div>
                        </div>
                        <div class="card" style="padding:12px; background:rgba(255,255,255,0.03); border-radius: 10px; border: 1px solid rgba(255,255,255,0.05);">
                            <small style="color:var(--text-muted); font-size: 0.75rem;">Followers / Following</small>
                            <div style="font-weight:500; font-size: 0.9rem; margin-top:2px;">${followers} Followers • ${following} Following</div>
                        </div>
                        <div class="card" style="padding:12px; background:rgba(255,255,255,0.03); border-radius: 10px; border: 1px solid rgba(255,255,255,0.05);">
                            <small style="color:var(--text-muted); font-size: 0.75rem;">Streak / Activity</small>
                            <div style="font-weight:500; font-size: 0.9rem; margin-top:2px;">🔥 ${streak} Day Streak</div>
                        </div>
                    </div>

                    <div style="margin-top:16px;">
                        <small style="color:var(--text-muted); font-size: 0.75rem;">Biography</small>
                        <p style="margin-top:4px; line-height:1.4; font-size: 0.9rem; color: ${user.bio ? 'var(--text-primary)' : 'var(--text-muted)'};">${user.bio ? user.bio : '<i>No biography provided.</i>'}</p>
                    </div>

                    ${socialsHtml}

                    <div style="margin-top:16px; padding-top:12px; border-top:1px solid rgba(255,255,255,0.05); display:flex; justify-content:space-between; font-size: 0.8rem; color: var(--text-muted);">
                        <span>📅 Joined ${formatDate(user.createdAt || user.created_at)}</span>
                        ${user.lastSeen || user.last_seen ? `<span>👀 Last Active ${formatDate(user.lastSeen || user.last_seen)}</span>` : ''}
                    </div>
                </div>
                <div class="modal-footer" style="padding: 15px 20px; border-top: 1px solid rgba(255,255,255,0.1); display: flex; gap: 10px;">
                    <button class="btn-primary" style="flex: 1; background: #10B981; border: none; border-radius: 8px; display: flex; align-items: center; justify-content: center; gap: 8px; font-weight: 600;" onclick="document.getElementById('user-detail-modal').style.display='none'; window.usersController.openNotifyModal('${user.id}')">
                        <i class="fas fa-paper-plane"></i> Send Direct Message
                    </button>
                    <button class="btn-text" style="padding: 10px 20px; background: rgba(255,255,255,0.08); color: #fff; border: none; border-radius: 8px; cursor: pointer;" onclick="document.getElementById('user-detail-modal').style.display='none'">Close</button>
                </div>
            </div>
        `;

        modal.style.display = 'flex';
    }

    openNotifyModal(uid) {
        const user = this.users.find(u => u.id === uid);
        if (!user) return;

        let modal = document.getElementById('user-notify-modal');
        if (!modal) {
            modal = document.createElement('div');
            modal.id = 'user-notify-modal';
            modal.className = 'modal-overlay';
            document.body.appendChild(modal);
        }

        const displayName = user.fullName || user.displayName || user.username || 'User';

        modal.innerHTML = `
            <div class="modal-card" style="max-width: 520px; width: 92%; background: #1e293b; border-radius: 16px; overflow: hidden; border: 1px solid rgba(255,255,255,0.12); color: #fff; box-shadow: 0 25px 50px rgba(0,0,0,0.6);">
                <div class="modal-header" style="padding: 18px 22px; border-bottom: 1px solid rgba(255,255,255,0.1); display: flex; justify-content: space-between; align-items: center; background: #0f172a;">
                    <h3 style="margin: 0; font-size: 1.15rem; display: flex; align-items: center; gap: 10px;">
                        <i class="fas fa-paper-plane" style="color: #10B981;"></i> Direct Notification to ${displayName}
                    </h3>
                    <button type="button" class="btn-text" onclick="document.getElementById('user-notify-modal').style.display='none'" style="color: #aaa; background: none; border: none; cursor: pointer; font-size: 1.4rem;">&times;</button>
                </div>
                <form id="admin-user-notify-form" style="padding: 22px;" onsubmit="window.usersController.sendNotificationToUser(event, '${uid}')">
                    <div class="form-group" style="margin-bottom: 16px;">
                        <label style="display: block; font-size: 0.85rem; font-weight: 600; color: #94a3b8; margin-bottom: 6px;">Notification Title</label>
                        <input type="text" id="user-notify-title" placeholder="e.g. Course Registration Alert / Academic Notice" required style="width: 100%; padding: 12px 14px; background: #0f172a; border: 1px solid rgba(255,255,255,0.15); border-radius: 10px; color: #fff; font-size: 0.95rem; box-sizing: border-box;" />
                    </div>
                    <div class="form-group" style="margin-bottom: 16px;">
                        <label style="display: block; font-size: 0.85rem; font-weight: 600; color: #94a3b8; margin-bottom: 6px;">Category / Channel</label>
                        <select id="user-notify-type" style="width: 100%; padding: 12px 14px; background: #0f172a; border: 1px solid rgba(255,255,255,0.15); border-radius: 10px; color: #fff; font-size: 0.95rem; box-sizing: border-box;">
                            <option value="admin_message">💬 Direct Admin Message</option>
                            <option value="academic">🎓 Academic Alert</option>
                            <option value="urgent">🚨 Urgent Priority Notice</option>
                            <option value="verification">✅ Verification Update</option>
                            <option value="system">⚙️ General System Notice</option>
                        </select>
                    </div>
                    <div class="form-group" style="margin-bottom: 20px;">
                        <label style="display: block; font-size: 0.85rem; font-weight: 600; color: #94a3b8; margin-bottom: 6px;">Message Body</label>
                        <textarea id="user-notify-body" rows="4" placeholder="Enter message to deliver immediately to this user's app..." required style="width: 100%; padding: 12px 14px; background: #0f172a; border: 1px solid rgba(255,255,255,0.15); border-radius: 10px; color: #fff; font-size: 0.95rem; resize: vertical; box-sizing: border-box;"></textarea>
                    </div>
                    <div style="display: flex; gap: 12px; justify-content: flex-end;">
                        <button type="button" class="btn-text" onclick="document.getElementById('user-notify-modal').style.display='none'" style="padding: 10px 18px; background: rgba(255,255,255,0.06); color: #cbd5e1; border: none; border-radius: 8px; cursor: pointer;">Cancel</button>
                        <button type="submit" id="user-notify-submit-btn" style="padding: 12px 24px; background: #10B981; color: #fff; border: none; border-radius: 8px; font-weight: 600; cursor: pointer; display: flex; align-items: center; gap: 8px; box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);">
                            <i class="fas fa-paper-plane"></i> Send Notification
                        </button>
                    </div>
                </form>
            </div>
        `;

        modal.style.display = 'flex';
    }

    async sendNotificationToUser(e, uid) {
        e.preventDefault();
        const title = document.getElementById('user-notify-title').value.trim();
        const body = document.getElementById('user-notify-body').value.trim();
        const type = document.getElementById('user-notify-type').value;
        const submitBtn = document.getElementById('user-notify-submit-btn');

        if (!title || !body) return;

        submitBtn.disabled = true;
        submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Dispatching...';

        try {
            const res = await ApiClientAdmin.fetch(`/admin/users/${uid}/notify`, {
                method: 'POST',
                body: JSON.stringify({ title, body, type })
            });
            const data = await res.json();
            if (res.ok && data.success) {
                document.getElementById('user-notify-modal').style.display = 'none';
                alert('✅ Notification dispatched directly to user!');
                if (typeof window.logAdminAction === 'function') {
                    window.logAdminAction('NOTIFY_USER', `Sent notification "${title}" to User ${uid}`, 'user', uid);
                }
            } else {
                throw new Error(data.error || 'Failed to dispatch notification');
            }
        } catch (err) {
            alert('Error sending notification: ' + err.message);
        } finally {
            submitBtn.disabled = false;
            submitBtn.innerHTML = '<i class="fas fa-paper-plane"></i> Send Notification';
        }
    }

    setVerification(uid, type) {
        db.collection('users').doc(uid).update({
            verification_type: type,
            verificationType: type,
            is_verified: type !== 'none',
            isVerified: type !== 'none'
        }).then(() => {
            if (typeof window.logAdminAction === 'function') {
                window.logAdminAction('VERIFY_USER', `Updated verification tier to ${type} for User ${uid}`, 'user', uid);
            }
            this.load();
        }).catch(err => alert("Error setting verification: " + err.message));
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
