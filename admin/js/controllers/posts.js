class PostsController {
    constructor() {
        this.tableBody = document.querySelector('#posts-table tbody');
        this.posts = []; // Cache for modals & filters
        this.filteredPosts = [];
        this.selectedPostIds = new Set();

        this.aiPostingToggle = document.getElementById('posts-ai-posting-toggle');
        this.aiStatusBadge = document.getElementById('posts-ai-status-badge');
        this.cleanAiBtn = document.getElementById('posts-clean-ai-btn');

        this.searchInput = document.getElementById('post-search');
        this.typeFilter = document.getElementById('post-filter-type');
        this.countBadge = document.getElementById('posts-count-badge');
        this.selectAllCheckbox = document.getElementById('posts-select-all');

        if (this.aiPostingToggle) {
            this.aiPostingToggle.addEventListener('change', () => this.toggleAiPosting());
        }

        if (this.cleanAiBtn) {
            this.cleanAiBtn.addEventListener('click', () => this.cleanAiPosts());
        }

        if (this.searchInput) {
            this.searchInput.addEventListener('input', () => this.applyFilters());
        }

        if (this.typeFilter) {
            this.typeFilter.addEventListener('change', () => this.applyFilters());
        }

        if (this.selectAllCheckbox) {
            this.selectAllCheckbox.addEventListener('change', (e) => this.toggleSelectAll(e.target.checked));
        }
    }

    async loadAiStatus() {
        try {
            const res = await ApiClientAdmin.fetch('/admin/settings/ai-posting');
            const data = await res.json();
            const enabled = !!data.enabled;
            if (this.aiPostingToggle) this.aiPostingToggle.checked = enabled;
            if (this.aiStatusBadge) {
                this.aiStatusBadge.textContent = enabled ? 'ACTIVE' : 'DISABLED';
                this.aiStatusBadge.style.background = enabled ? '#10b981' : '#64748b';
            }
        } catch (e) {
            if (this.aiStatusBadge) {
                this.aiStatusBadge.textContent = 'OFF';
                this.aiStatusBadge.style.background = '#64748b';
            }
        }
    }

    async toggleAiPosting() {
        if (!this.aiPostingToggle) return;
        const isEnabled = this.aiPostingToggle.checked;
        try {
            const res = await ApiClientAdmin.fetch('/admin/settings/ai-posting', {
                method: 'POST',
                body: JSON.stringify({ enabled: isEnabled }),
            });
            const data = await res.json();
            if (data.success) {
                if (this.aiStatusBadge) {
                    this.aiStatusBadge.textContent = isEnabled ? 'ACTIVE' : 'DISABLED';
                    this.aiStatusBadge.style.background = isEnabled ? '#10b981' : '#64748b';
                }
                alert(`ABUAD AI Autonomous Feed Posting is now ${isEnabled ? 'ACTIVE' : 'DISABLED'}`);
            } else {
                alert('Failed to update AI posting: ' + (data.error || 'Server error'));
                this.aiPostingToggle.checked = !isEnabled;
            }
        } catch (e) {
            alert('Error updating AI posting: ' + e.message);
            this.aiPostingToggle.checked = !isEnabled;
        }
    }

    async cleanAiPosts() {
        const confirmed = confirm("Are you sure you want to remove all automated ABUAD AI posts from the campus feed?\n\nThis will instantly delete prior AI posts so real student posts take full priority.");
        if (!confirmed) return;

        if (this.cleanAiBtn) {
            this.cleanAiBtn.disabled = true;
            this.cleanAiBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Cleaning...';
        }

        try {
            const res = await ApiClientAdmin.fetch('/admin/ai-posts/clean', {
                method: 'POST',
                body: JSON.stringify({}),
            });
            const data = await res.json();
            if (data.success) {
                alert(data.message || `Removed ${data.count} AI posts from the feed`);
                this.load();
            } else {
                alert('Failed to clean AI posts: ' + (data.error || 'Server error'));
            }
        } catch (e) {
            alert('Error cleaning AI posts: ' + e.message);
        } finally {
            if (this.cleanAiBtn) {
                this.cleanAiBtn.disabled = false;
                this.cleanAiBtn.innerHTML = '<i class="fas fa-trash"></i> Clean AI Posts';
            }
        }
    }

    load() {
        this.loadAiStatus();
        this.tableBody.innerHTML = '<tr><td colspan="6" class="loading-text">Loading posts feed...</td></tr>';

        if (this.unsubscribe) this.unsubscribe();

        this.unsubscribe = db.collection('posts')
            .orderBy('created_at', 'desc')
            .limit(60)
            .onSnapshot(snap => {
                this.posts = [];
                snap.forEach(doc => {
                    this.posts.push({ id: doc.id, ...doc.data() });
                });
                this.applyFilters();
            }, err => {
                console.error(err);
                this.tableBody.innerHTML = `<tr><td colspan="6" class="error-text">Error: ${err.message}</td></tr>`;
            });
    }

    applyFilters() {
        const query = (this.searchInput?.value || '').toLowerCase().trim();
        const typeFilter = this.typeFilter?.value || 'all';

        this.filteredPosts = this.posts.filter(p => {
            const content = (p.content || '').toLowerCase();
            const author = (p.author_handle || p.authorHandle || p.author_name || p.authorName || '').toLowerCase();
            const matchesQuery = !query || content.includes(query) || author.includes(query);

            if (!matchesQuery) return false;

            const hasMedia = (p.mediaUrl && p.mediaUrl.length > 0) || (p.media_url && p.media_url.length > 0);
            const isAnon = !!p.isAnonymous;

            if (typeFilter === 'media' && !hasMedia) return false;
            if (typeFilter === 'anonymous' && !isAnon) return false;

            return true;
        });

        if (this.countBadge) {
            this.countBadge.textContent = `${this.filteredPosts.length} Posts`;
        }

        this.render();
    }

    toggleSelectAll(checked) {
        if (checked) {
            this.filteredPosts.forEach(p => this.selectedPostIds.add(p.id));
        } else {
            this.selectedPostIds.clear();
        }
        this.render();
    }

    toggleSelectPost(id, checked) {
        if (checked) {
            this.selectedPostIds.add(id);
        } else {
            this.selectedPostIds.delete(id);
        }
        if (this.selectAllCheckbox) {
            this.selectAllCheckbox.checked = this.filteredPosts.length > 0 && this.selectedPostIds.size === this.filteredPosts.length;
        }
    }

    render() {
        this.tableBody.innerHTML = '';

        if (this.filteredPosts.length === 0) {
            this.tableBody.innerHTML = '<tr><td colspan="6" style="text-align:center; padding:30px; color:var(--text-muted)">No matching posts found.</td></tr>';
            return;
        }

        this.filteredPosts.forEach(post => {
            const tr = document.createElement('tr');

            const hasMedia = (post.mediaUrl && post.mediaUrl.length > 0) || (post.media_url && post.media_url.length > 0);
            const isAnon = !!post.isAnonymous;
            const isPinned = !!(post.isPinned || post.is_pinned || post.isFeatured);
            const isSelected = this.selectedPostIds.has(post.id);

            tr.innerHTML = `
                <td>
                    <input type="checkbox" ${isSelected ? 'checked' : ''} onchange="window.postsController.toggleSelectPost('${post.id}', this.checked)">
                </td>
                <td>
                   <div style="max-width: 320px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; font-weight: 500;">
                        ${isPinned ? '<span class="badge" style="background:rgba(234,179,8,0.2); color:#fbbf24; border:1px solid rgba(234,179,8,0.4); margin-right:6px;"><i class="fas fa-thumbtack"></i> PINNED</span>' : ''}
                        ${post.content || '<i style="color:#94a3b8">No text caption</i>'}
                   </div>
                   <div style="display: flex; gap: 6px; margin-top: 4px;">
                        ${hasMedia ? `<span class="badge badge-gray" style="font-size: 0.72rem;"><i class="fas fa-image"></i> Media Attached</span>` : ''}
                        ${isAnon ? `<span class="badge badge-gray" style="font-size: 0.72rem;"><i class="fas fa-user-secret"></i> Anonymous</span>` : ''}
                   </div>
                </td>
                <td>
                    ${isAnon ?
                    '<span class="badge badge-gray"><i class="fas fa-mask"></i> Anonymous</span>' :
                    `<div style="font-weight: 600;">${post.author_name || post.authorName || 'Campus User'}</div>
                     <small style="color:var(--text-secondary)">@${post.author_handle || post.authorHandle || 'user'}</small>`
                }
                </td>
                <td>
                    <div style="display:flex; align-items:center; gap:10px;">
                        <span style="font-size:0.85rem;"><i class="fas fa-heart" style="color: #e91e63"></i> ${post.likesCount || post.likes_count || 0}</span>
                        <span style="font-size:0.85rem;"><i class="fas fa-comment" style="color: #0284c7"></i> ${post.commentsCount || post.comments_count || 0}</span>
                    </div>
                </td>
                <td><small style="color:var(--text-secondary);">${this.timeAgo(post.created_at || post.timestamp)}</small></td>
                <td style="text-align: right;">
                    <div style="display: inline-flex; gap: 6px;">
                        <button class="btn-icon btn-view" 
                                onclick="window.postsController.openPostModal('${post.id}')"
                                title="Inspect Post Details">
                            <i class="fas fa-eye"></i>
                        </button>
                        <button class="btn-icon" 
                                onclick="window.postsController.togglePinPost('${post.id}')"
                                style="color: ${isPinned ? '#fbbf24' : 'var(--text-secondary)'}; border-color: ${isPinned ? 'rgba(251,191,36,0.5)' : 'var(--border-subtle)'};"
                                title="${isPinned ? 'Unpin from Campus Bulletin' : 'Pin to Campus Bulletin'}">
                            <i class="fas fa-thumbtack"></i>
                        </button>
                        ${!isAnon && post.author_id ? `
                        <button class="btn-icon btn-notify" 
                                onclick="window.postsController.warnAuthor('${post.author_id}', '${(post.author_name || post.authorName || 'User').replace(/'/g, "\\'")}')"
                                title="Send Moderation Notice / Warning">
                            <i class="fas fa-paper-plane"></i>
                        </button>
                        ` : ''}
                        <button class="btn-icon btn-delete" 
                                onclick="window.postsController.deletePost('${post.id}')"
                                title="Delete Post Permanently">
                            <i class="fas fa-trash"></i>
                        </button>
                    </div>
                </td>
            `;
            this.tableBody.appendChild(tr);
        });
    }

    async togglePinPost(postId) {
        const post = this.posts.find(p => p.id === postId);
        if (!post) return;
        const current = !!(post.isPinned || post.is_pinned || post.isFeatured);
        const nextState = !current;

        try {
            await db.collection('posts').doc(postId).update({
                isPinned: nextState,
                is_pinned: nextState,
                isFeatured: nextState
            });
            window.logAdminAction('PIN_POST', `Admin ${nextState ? 'pinned' : 'unpinned'} post ${postId}`, 'post', postId);
            post.isPinned = nextState;
            post.is_pinned = nextState;
            this.render();
        } catch (e) {
            alert("Error updating post pin state: " + e.message);
        }
    }

    warnAuthor(authorId, authorName) {
        if (window.usersController && typeof window.usersController.openNotifyModal === 'function') {
            window.usersController.openNotifyModal(authorId, authorName);
        } else {
            const note = prompt(`Send moderation alert notice to ${authorName}:`, "Please ensure your post follows ABUAD Student Code of Conduct guidelines.");
            if (!note) return;
            ApiClientAdmin.fetch('/admin/notifications', {
                method: 'POST',
                body: JSON.stringify({
                    userId: authorId,
                    title: 'ABUAD Moderation Notice',
                    body: note
                })
            }).then(() => alert("Warning notification dispatched."))
              .catch(e => alert("Failed to send notice: " + e.message));
        }
    }

    openPostModal(postId) {
        const post = this.posts.find(p => p.id === postId);
        if (!post) return;

        let modal = document.getElementById('post-detail-modal');
        if (!modal) {
            modal = document.createElement('div');
            modal.id = 'post-detail-modal';
            modal.className = 'modal-overlay';
            document.body.appendChild(modal);
        }

        const rawMedia = post.mediaUrl || post.media_url;
        let mediaHtml = '';
        if (rawMedia) {
            if (Array.isArray(rawMedia)) {
                mediaHtml = rawMedia.map(url => `<img src="${url}" style="width:100%; max-height:400px; object-fit:contain; border-radius:12px; margin-bottom:10px; background:#000;">`).join('');
            } else {
                mediaHtml = `<img src="${rawMedia}" style="width:100%; max-height:400px; object-fit:contain; border-radius:12px; background:#000;">`;
            }
        }

        const isPinned = !!(post.isPinned || post.is_pinned || post.isFeatured);

        modal.innerHTML = `
            <div class="modal-content" style="width: 600px; max-width: 95%;">
                <div class="modal-header">
                    <h2><i class="fas fa-shield-alt" style="color:var(--color-primary-light);"></i> Content Moderation Review</h2>
                    <button onclick="document.getElementById('post-detail-modal').style.display='none'" class="btn-close">&times;</button>
                </div>
                <div class="modal-body" style="max-height: 70vh; overflow-y: auto;">
                    <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:15px; padding-bottom:10px; border-bottom:1px solid var(--border-subtle);">
                        <div>
                            <span style="font-weight:700; font-size:1.1rem; color:var(--text-primary);">${post.author_name || post.authorName || 'Campus User'}</span>
                            <span style="color:var(--text-secondary)"> @${post.author_handle || post.authorHandle || 'anonymous'}</span>
                        </div>
                        <span class="badge badge-gray">${this.timeAgo(post.created_at || post.timestamp)}</span>
                    </div>

                    <div style="font-size:1.05rem; line-height:1.6; margin-bottom:20px; white-space:pre-wrap; color:var(--text-primary);">${post.content || '<i style="color:var(--text-muted)">No caption text provided</i>'}</div>
                    
                    <div class="media-container" style="border-radius:12px; overflow:hidden;">
                        ${mediaHtml}
                    </div>

                    <div style="display:flex; gap:20px; margin-top:20px; padding-top:15px; border-top:1px solid var(--border-subtle); color:var(--text-secondary); font-size:0.9rem;">
                        <span><i class="fas fa-heart" style="color:#e91e63"></i> ${post.likesCount || post.likes_count || 0} Likes</span>
                        <span><i class="fas fa-comment" style="color:#0284c7"></i> ${post.commentsCount || post.comments_count || 0} Comments</span>
                        <span><i class="fas fa-share" style="color:#10b981"></i> ${post.sharesCount || 0} Shares</span>
                    </div>
                </div>
                <div class="modal-footer" style="display:flex; gap:10px; justify-content: flex-end;">
                    <button class="btn btn-secondary" onclick="document.getElementById('post-detail-modal').style.display='none'">Close</button>
                    <button class="btn btn-secondary" onclick="window.postsController.togglePinPost('${postId}')">
                        <i class="fas fa-thumbtack"></i> ${isPinned ? 'Unpin Bulletin' : 'Pin to Bulletin'}
                    </button>
                    <button class="btn btn-danger" onclick="window.postsController.deletePost('${postId}')">
                        <i class="fas fa-trash-alt"></i> Delete Post
                    </button>
                </div>
            </div>
        `;
        modal.style.display = 'flex';
    }

    deletePost(postId) {
        if (confirm("Are you sure you want to remove this post? It will be hidden from the campus feed immediately.")) {
            db.collection('posts').doc(postId).delete().then(() => {
                window.logAdminAction('DELETE_POST', `Admin deleted post ${postId}`, 'post', postId);
                const modal = document.getElementById('post-detail-modal');
                if (modal) modal.style.display = 'none';
            })
            .catch(err => alert("Error deleting post: " + err.message));
        }
    }

    timeAgo(dateParam) {
        if (!dateParam) return 'N/A';
        const date = dateParam.toDate ? dateParam.toDate() : new Date(dateParam);
        const seconds = Math.round((new Date() - date) / 1000);
        if (seconds < 60) return 'Just now';
        if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
        if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
        return date.toLocaleDateString();
    }
}


