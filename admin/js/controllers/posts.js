class PostsController {
    constructor() {
        this.tableBody = document.querySelector('#posts-table tbody');
    }

    load() {
        this.tableBody.innerHTML = '<tr><td colspan="5" class="loading-text">Loading posts feed...</td></tr>';

        if (this.unsubscribe) this.unsubscribe();

        this.unsubscribe = db.collection('posts')
            .orderBy('timestamp', 'desc')
            .limit(20)
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
            this.tableBody.innerHTML = '<tr><td colspan="5">No posts found.</td></tr>';
            return;
        }

        snap.forEach(doc => {
            const post = doc.data();
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
                    <button class="btn-icon btn-delete" 
                            onclick="window.postsController.deletePost('${doc.id}')"
                            title="Remove Content">
                        <i class="fas fa-trash"></i>
                    </button>
                </td>
            `;
            this.tableBody.appendChild(tr);
        });
    }

    deletePost(postId) {
        if (confirm("Are you sure you want to remove this post? It will be hidden from the feed.")) {
            db.collection('posts').doc(postId).delete()
                .catch(err => alert("Error deleting post: " + err.message));
        }
    }

    timeAgo(dateParam) {
        if (!dateParam) return null;
        const date = typeof dateParam === 'object' ? dateParam : new Date(dateParam); // Handle Firestore Timestamps if raw or ISO Strings
        const DAY_IN_MS = 86400000;
        const today = new Date();
        // Simple fallback
        try {
            const seconds = Math.round((today - new Date(date)) / 1000);
            if (seconds < 60) return 'Just now';
            if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
            if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
            return new Date(date).toLocaleDateString();
        } catch (e) {
            return 'N/A';
        }
    }
}
