class StoriesController {
    constructor() {
        this.tableBody = document.querySelector('#stories-table tbody');
    }

    load() {
        this.tableBody.innerHTML = '<tr><td colspan="5" class="loading-text">Loading status feed...</td></tr>';

        if (this.unsubscribe) this.unsubscribe();

        // Load active stories
        this.unsubscribe = db.collection('stories')
            .orderBy('expires_at', 'desc')
            .limit(50)
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
            this.tableBody.innerHTML = '<tr><td colspan="5">No active stories found.</td></tr>';
            return;
        }

        snap.forEach(doc => {
            const story = doc.data();
            const tr = document.createElement('tr');

            const isText = story.type === 'text';
            const hasLink = story.link_url && story.link_url.length > 0;
            const hasMentions = story.mentions && story.mentions.length > 0;
            const visibility = story.visibility || 'everyone';

            tr.innerHTML = `
                <td>
                    <div style="display: flex; align-items: center; gap: 12px;">
                        ${isText ? 
                            `<div style="width: 40px; height: 40px; border-radius: 8px; background: ${this.formatColor(story.background_color)}; display: flex; align-items: center; justify-content: center; font-size: 10px; color: ${this.formatColor(story.text_color)}">T</div>` : 
                            `<img src="${story.content}" style="width: 40px; height: 40px; border-radius: 8px; object-fit: cover; border: 1px solid var(--border-subtle)">`
                        }
                        <div style="max-width: 200px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; font-size: 0.85rem;">
                            ${isText ? story.content : (story.caption || '<i>No caption</i>')}
                        </div>
                    </div>
                </td>
                <td>
                    <div class="user-cell-mini">
                        <strong>${story.user_name || 'User'}</strong><br>
                        <small style="color: var(--text-secondary)">ID: ${story.author_id.substring(0, 8)}...</small>
                    </div>
                </td>
                <td>
                    <div style="display: flex; flex-wrap: wrap; gap: 4px;">
                        <span class="status-badge ${visibility === 'everyone' ? 'online' : 'offline'}" style="font-size: 9px;">${visibility}</span>
                        ${hasLink ? `<span class="badge badge-gray" title="${story.link_url}"><i class="fas fa-link"></i> Link</span>` : ''}
                        ${hasMentions ? `<span class="badge badge-gray"><i class="fas fa-at"></i> ${story.mentions.length} Mentions</span>` : ''}
                    </div>
                </td>
                <td>
                    <small style="color: var(--text-secondary)">${this.timeUntil(story.expires_at)}</small>
                </td>
                <td style="text-align: right;">
                    <button class="btn-icon btn-delete" 
                            onclick="window.storiesController.deleteStory('${doc.id}')"
                            title="Remove Story">
                        <i class="fas fa-trash"></i>
                    </button>
                </td>
            `;
            this.tableBody.appendChild(tr);
        });
    }

    deleteStory(storyId) {
        if (confirm("Permanently delete this story from the platform? This cannot be undone.")) {
            db.collection('stories').doc(storyId).delete().then(() => {
                window.logAdminAction('DELETE_STORY', `Admin deleted story ${storyId}`, 'story', storyId);
            })
            .catch(err => alert("Error: " + err.message));
        }
    }

    formatColor(intColor) {
        if (!intColor) return '#ccc';
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
