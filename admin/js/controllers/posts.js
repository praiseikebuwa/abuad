class PostsController {
    constructor() {
        this.tableBody = document.querySelector('#posts-table tbody');
        this.posts = []; // Cache for modals
    }

    load() {
        this.tableBody.innerHTML = '<tr><td colspan="5" class="loading-text">Loading posts feed...</td></tr>';

        if (this.unsubscribe) this.unsubscribe();

        this.unsubscribe = db.collection('posts')
            .orderBy('timestamp', 'desc')
            .limit(50)
            .onSnapshot(snap => {
                this.posts = [];
                snap.forEach(doc => {
                    this.posts.push({ id: doc.id, ...doc.data() });
                });
                this.render();
            }, err => {
                console.error(err);
                this.tableBody.innerHTML = `<tr><td colspan="5" class="error-text">Error: ${err.message}</td></tr>`;
            });
    }

    render() {
        this.tableBody.innerHTML = '';

        if (this.posts.length === 0) {
            this.tableBody.innerHTML = '<tr><td colspan="5">No posts found.</td></tr>';
            return;
        }

        this.posts.forEach(post => {
            const tr = document.createElement('tr');

            const hasMedia = post.mediaUrl && post.mediaUrl.length > 0;
            const isAnon = post.isAnonymous;

            tr.innerHTML = `
                <td>
                   <div style="max-width: 300px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">
                        ${post.content || '<i style="color:#999">No text content</i>'}
                   </div>
                   ${hasMedia ? `<span class="badge badge-gray"><i class="fas fa-image"></i> Image</span>` : ''}
                </td>
                <td>
                    ${isAnon ?
                    '<span class="badge badge-gray"><i class="fas fa-mask"></i> Anonymous</span>' :
                    `@${post.authorHandle || 'user'}`
                }
                </td>
                <td>
                    <small><i class="fas fa-heart" style="color: #e91e63"></i> ${post.likesCount || 0}</small>
                    <small style="margin-left:8px"><i class="fas fa-comment" style="color: #2196f3"></i> ${post.commentsCount || 0}</small>
                </td>
                <td>${this.timeAgo(post.timestamp)}</td>
                <td>
                    <button class="btn-icon btn-view" 
                            onclick="window.postsController.openPostModal('${post.id}')"
                            title="View Full Post" style="color: var(--color-primary-600); margin-right:8px;">
                        <i class="fas fa-eye"></i>
                    </button>
                    <button class="btn-icon btn-delete" 
                            onclick="window.postsController.deletePost('${post.id}')"
                            title="Remove Content">
                        <i class="fas fa-trash"></i>
                    </button>
                </td>
            `;
            this.tableBody.appendChild(tr);
        });
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

        const mediaHtml = post.mediaUrl ? 
            (Array.isArray(post.mediaUrl) ? 
                post.mediaUrl.map(url => `<img src="${url}" style="width:100%; border-radius:12px; margin-bottom:10px;">`).join('') :
                `<img src="${post.mediaUrl}" style="width:100%; border-radius:12px;">`) : '';

        modal.innerHTML = `
            <div class="modal-content" style="width: 600px;">
                <div class="modal-header">
                    <h2>Content Moderation Preview</h2>
                    <button onclick="document.getElementById('post-detail-modal').style.display='none'" class="btn-close">&times;</button>
                </div>
                <div class="modal-body" style="max-height: 70vh; overflow-y: auto;">
                    <div style="display:flex; justify-content:space-between; margin-bottom:15px;">
                        <div>
                            <span style="font-weight:700; font-size:1.1rem;">${post.authorName || 'User'}</span>
                            <span style="color:var(--text-secondary)"> @${post.authorHandle || 'handle'}</span>
                        </div>
                        <small style="color:var(--text-muted)">${this.timeAgo(post.timestamp)}</small>
                    </div>

                    <div style="font-size:1.1rem; line-height:1.6; margin-bottom:20px; white-space:pre-wrap;">${post.content || ''}</div>
                    
                    <div class="media-container">
                        ${mediaHtml}
                    </div>

                    <div style="display:flex; gap:20px; margin-top:20px; padding-top:15px; border-top:1px solid var(--border-glass)">
                        <span><i class="fas fa-heart" style="color:#e91e63"></i> ${post.likesCount || 0} Likes</span>
                        <span><i class="fas fa-comment" style="color:#2196f3"></i> ${post.commentsCount || 0} Comments</span>
                        <span><i class="fas fa-share" style="color:#4caf50"></i> ${post.sharesCount || 0} Shares</span>
                    </div>
                </div>
                <div class="modal-footer" style="display:flex; gap:10px;">
                    <button class="btn-primary" style="flex:1; background:#444;" onclick="document.getElementById('post-detail-modal').style.display='none'">Close</button>
                    <button class="btn-primary" style="flex:1; background:var(--color-accent-rose);" onclick="window.postsController.deletePost('${postId}')">Delete Post</button>
                </div>
            </div>
        `;
        modal.style.display = 'flex';
    }

    deletePost(postId) {
        if (confirm("Are you sure you want to remove this post? It will be hidden from the feed.")) {
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

