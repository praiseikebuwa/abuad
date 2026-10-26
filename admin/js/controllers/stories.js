class StoriesController {
    constructor() {
        this.tableBody = document.querySelector('#stories-table tbody');
        this.stories = [];
        this.filteredStories = [];

        this.searchInput = document.getElementById('stories-search');
        this.filterSelect = document.getElementById('stories-filter');
        this.countBadge = document.getElementById('stories-count-badge');
        this.refreshBtn = document.getElementById('stories-refresh-btn');

        if (this.searchInput) {
            this.searchInput.addEventListener('input', () => this.applyFilters());
        }

        if (this.filterSelect) {
            this.filterSelect.addEventListener('change', () => this.applyFilters());
        }

        if (this.refreshBtn) {
            this.refreshBtn.addEventListener('click', () => this.load());
        }
    }

    load() {
        this.tableBody.innerHTML = '<tr><td colspan="5" class="loading-text"><i class="fas fa-spinner fa-spin"></i> Loading active status feed...</td></tr>';

        if (this.unsubscribe) this.unsubscribe();

        // Load active stories
        this.unsubscribe = db.collection('stories')
            .orderBy('expires_at', 'desc')
            .limit(60)
            .onSnapshot(snap => {
                this.stories = [];
                snap.forEach(doc => {
                    this.stories.push({ id: doc.id, ...doc.data() });
                });
                this.applyFilters();
            }, err => {
                console.error(err);
                this.tableBody.innerHTML = `<tr><td colspan="5" class="error-text">Error: ${err.message}</td></tr>`;
            });
    }

    applyFilters() {
        const query = (this.searchInput?.value || '').toLowerCase().trim();
        const filterType = this.filterSelect?.value || 'all';

        const now = new Date().getTime();

        this.filteredStories = this.stories.filter(story => {
            const author = (story.user_name || story.userName || story.author_name || '').toLowerCase();
            const caption = (story.caption || story.content || '').toLowerCase();

            const matchesQuery = !query || author.includes(query) || caption.includes(query);
            if (!matchesQuery) return false;

            const isText = story.type === 'text';
            const isMedia = !isText;

            if (filterType === 'media' && !isMedia) return false;
            if (filterType === 'text' && !isText) return false;

            if (filterType === 'expiring') {
                const expDate = story.expires_at?.toDate ? story.expires_at.toDate() : new Date(story.expires_at);
                const diffHours = (expDate.getTime() - now) / (1000 * 3600);
                if (diffHours > 4 || diffHours <= 0) return false;
            }

            return true;
        });

        if (this.countBadge) {
            this.countBadge.textContent = `${this.filteredStories.length} Active Stories`;
        }

        this.render();
    }

    render() {
        this.tableBody.innerHTML = '';

        if (this.filteredStories.length === 0) {
            this.tableBody.innerHTML = '<tr><td colspan="5" style="text-align:center; padding:30px; color:var(--text-muted)">No active stories found matching your filter.</td></tr>';
            return;
        }

        this.filteredStories.forEach(story => {
            const tr = document.createElement('tr');

            const isText = story.type === 'text';
            const hasLink = story.link_url && story.link_url.length > 0;
            const hasMentions = story.mentions && story.mentions.length > 0;
            const visibility = story.visibility || 'everyone';

            tr.innerHTML = `
                <td>
                    <div style="display: flex; align-items: center; gap: 12px; cursor: pointer;" onclick="window.storiesController.previewStory('${story.id}')">
                        ${isText ? 
                            `<div style="width: 44px; height: 44px; border-radius: 10px; background: ${this.formatColor(story.background_color)}; display: flex; align-items: center; justify-content: center; font-size: 13px; font-weight:700; color: ${this.formatColor(story.text_color)}; border: 2px solid rgba(255,255,255,0.1);">Aa</div>` : 
                            `<div style="position:relative; width:44px; height:44px;">
                                <img src="${story.content || story.media_url}" style="width: 44px; height: 44px; border-radius: 10px; object-fit: cover; border: 2px solid var(--color-primary-light);">
                            </div>`
                        }
                        <div style="max-width: 240px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; font-size: 0.9rem; font-weight:500;">
                            ${isText ? story.content : (story.caption || '<i style="color:var(--text-muted)">Image Story</i>')}
                        </div>
                    </div>
                </td>
                <td>
                    <div class="user-cell-mini">
                        <strong style="color:var(--text-primary);">${story.user_name || story.userName || 'Campus User'}</strong><br>
                        <small style="color: var(--text-secondary)">Author: ${(story.author_id || 'ID').substring(0, 8)}...</small>
                    </div>
                </td>
                <td>
                    <div style="display: flex; flex-wrap: wrap; gap: 6px; align-items: center;">
                        <span class="badge ${visibility === 'everyone' ? 'badge-primary' : 'badge-gray'}" style="font-size: 10px; text-transform: capitalize;">${visibility}</span>
                        ${isText ? `<span class="badge badge-gray" style="font-size:10px;"><i class="fas fa-font"></i> Text Snap</span>` : `<span class="badge badge-gray" style="font-size:10px;"><i class="fas fa-image"></i> Photo</span>`}
                        ${hasLink ? `<span class="badge badge-gray" title="${story.link_url}" style="font-size:10px;"><i class="fas fa-link"></i> Link</span>` : ''}
                        ${hasMentions ? `<span class="badge badge-gray" style="font-size:10px;"><i class="fas fa-at"></i> ${story.mentions.length}</span>` : ''}
                    </div>
                </td>
                <td>
                    <span style="font-size: 0.85rem; font-weight: 500; color: var(--color-primary-light);">
                        <i class="far fa-clock"></i> ${this.timeUntil(story.expires_at)}
                    </span>
                </td>
                <td style="text-align: right;">
                    <div style="display: inline-flex; gap: 6px;">
                        <button class="btn-icon btn-view" 
                                onclick="window.storiesController.previewStory('${story.id}')"
                                title="Preview Story">
                            <i class="fas fa-eye"></i>
                        </button>
                        <button class="btn-icon btn-delete" 
                                onclick="window.storiesController.deleteStory('${story.id}')"
                                title="Remove Story Immediately">
                            <i class="fas fa-trash"></i>
                        </button>
                    </div>
                </td>
            `;
            this.tableBody.appendChild(tr);
        });
    }

    previewStory(storyId) {
        const story = this.stories.find(s => s.id === storyId);
        if (!story) return;

        let modal = document.getElementById('story-preview-modal');
        if (!modal) {
            modal = document.createElement('div');
            modal.id = 'story-preview-modal';
            modal.className = 'modal-overlay';
            document.body.appendChild(modal);
        }

        const isText = story.type === 'text';

        modal.innerHTML = `
            <div class="modal-content" style="width: 380px; height: 640px; padding: 0; background: #000; border-radius: 20px; position: relative; overflow: hidden; border: 1px solid var(--border-glass);">
                <button onclick="document.getElementById('story-preview-modal').style.display='none'" 
                        class="btn-close" style="position:absolute; top:16px; right:16px; z-index:100; color:white; background:rgba(0,0,0,0.6); border-radius:50%; width:36px; height:36px; display:flex; align-items:center; justify-content:center;">&times;</button>
                
                ${isText ? `
                    <div style="width:100%; height:100%; background:${this.formatColor(story.background_color)}; color:${this.formatColor(story.text_color)}; display:flex; align-items:center; justify-content:center; padding:30px; text-align:center; font-size:1.4rem; font-weight:600; line-height:1.5;">
                        ${story.content}
                    </div>
                ` : `
                    <img src="${story.content || story.media_url}" style="width:100%; height:100%; object-fit:cover;">
                    ${story.caption ? `
                        <div style="position:absolute; bottom:20px; left:20px; right:20px; background:rgba(0,0,0,0.7); backdrop-filter:blur(8px); padding:12px 16px; border-radius:12px; color:white; font-size:0.95rem;">
                            ${story.caption}
                        </div>
                    ` : ''}
                `}

                <div style="position:absolute; top:16px; left:16px; display:flex; align-items:center; gap:10px; background:rgba(0,0,0,0.5); backdrop-filter:blur(6px); padding:6px 12px; border-radius:20px;">
                    <div style="font-weight:700; color:white; font-size:0.85rem;">${story.user_name || story.userName || 'User'}</div>
                    <span style="font-size:0.75rem; color:#94a3b8;">${this.timeUntil(story.expires_at)}</span>
                </div>
            </div>
        `;
        modal.style.display = 'flex';
    }

    deleteStory(storyId) {
        if (confirm("Permanently delete this story from the platform? This cannot be undone.")) {
            db.collection('stories').doc(storyId).delete().then(() => {
                window.logAdminAction('DELETE_STORY', `Admin deleted story ${storyId}`, 'story', storyId);
                const modal = document.getElementById('story-preview-modal');
                if (modal) modal.style.display = 'none';
            })
            .catch(err => alert("Error: " + err.message));
        }
    }

    formatColor(intColor) {
        if (!intColor) return '#10b981';
        if (typeof intColor === 'string' && intColor.startsWith('#')) return intColor;
        return '#' + (intColor & 0xFFFFFF).toString(16).padStart(6, '0');
    }

    timeUntil(dateParam) {
        if (!dateParam) return 'N/A';
        const date = dateParam.toDate ? dateParam.toDate() : new Date(dateParam);
        const now = new Date();
        const diff = date - now;
        
        if (diff <= 0) return 'Expired';
        
        const hours = Math.floor(diff / 3600000);
        const minutes = Math.floor((diff % 3600000) / 60000);
        
        if (hours > 0) return `${hours}h ${minutes}m left`;
        return `${minutes}m left`;
    }
}

