class ReelsController {
    constructor() {
        this.container = document.getElementById('reels-container');
        this.reels = [];
        this.filteredReels = [];

        this.searchInput = document.getElementById('reels-search');
        this.filterSelect = document.getElementById('reels-filter');
        this.countBadge = document.getElementById('reels-count-badge');
        this.refreshBtn = document.getElementById('reels-refresh-btn');

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
        if (!this.container) return;
        this.container.innerHTML = '<div class="loading-text"><i class="fas fa-spinner fa-spin"></i> Fetching campus reels...</div>';

        if (this.unsubscribe) this.unsubscribe();

        // Query posts with media_type 'video'
        this.unsubscribe = db.collection('posts')
            .where('media_type', '==', 'video')
            .orderBy('created_at', 'desc')
            .limit(50)
            .onSnapshot(snap => {
                this.reels = [];
                snap.forEach(doc => {
                    this.reels.push({ id: doc.id, ...doc.data() });
                });
                this.applyFilters();
            }, err => {
                console.error(err);
                if (err.code === 'failed-precondition') {
                    // Fallback without orderBy
                    db.collection('posts').where('media_type', '==', 'video').limit(50).get().then(snap => {
                        this.reels = [];
                        snap.forEach(doc => {
                            this.reels.push({ id: doc.id, ...doc.data() });
                        });
                        this.applyFilters();
                    }).catch(e => {
                        this.container.innerHTML = `<div class="error-text">Error loading reels: ${e.message}</div>`;
                    });
                } else {
                    this.container.innerHTML = `<div class="error-text">Error: ${err.message}</div>`;
                }
            });
    }

    applyFilters() {
        const query = (this.searchInput?.value || '').toLowerCase().trim();
        const filterType = this.filterSelect?.value || 'all';

        this.filteredReels = this.reels.filter(reel => {
            const handle = (reel.author_handle || reel.authorHandle || '').toLowerCase();
            const authorName = (reel.author_name || reel.authorName || '').toLowerCase();
            const caption = (reel.content || reel.caption || '').toLowerCase();

            const matchesQuery = !query || handle.includes(query) || authorName.includes(query) || caption.includes(query);
            if (!matchesQuery) return false;

            const isTrending = !!(reel.is_trending || reel.isTrending);
            const isFlagged = !!(reel.is_flagged || reel.reports_count > 0);

            if (filterType === 'trending' && !isTrending) return false;
            if (filterType === 'flagged' && !isFlagged) return false;

            return true;
        });

        if (this.countBadge) {
            this.countBadge.textContent = `${this.filteredReels.length} Reels`;
        }

        this.render();
    }

    render() {
        this.container.innerHTML = '';

        if (this.filteredReels.length === 0) {
            this.container.innerHTML = '<div class="empty-state" style="grid-column: 1 / -1; text-align: center; padding: 40px; color: var(--text-muted);"><i class="fas fa-video-slash" style="font-size: 2rem; margin-bottom: 12px; display: block;"></i>No reels match your filter criteria.</div>';
            return;
        }

        this.filteredReels.forEach(reel => {
            const card = document.createElement('div');
            card.className = 'card reel-card';
            card.style.padding = '0';
            card.style.overflow = 'hidden';
            card.style.position = 'relative';
            card.style.aspectRatio = '9 / 16';
            card.style.borderRadius = '16px';
            card.style.border = '1px solid var(--border-glass)';
            card.style.background = '#000000';
            card.style.cursor = 'pointer';
            card.style.transition = 'transform 0.25s ease, box-shadow 0.25s ease';

            const thumbnailUrl = reel.thumbnail_url || reel.thumbnailUrl || (reel.media_url || reel.mediaUrl || '');
            const isTrending = !!(reel.is_trending || reel.isTrending);
            
            card.innerHTML = `
                <div class="reel-thumbnail" style="width:100%; height:100%; background: #000 url('${thumbnailUrl}') center/cover no-repeat; position:relative;">
                    ${isTrending ? `
                    <div style="position:absolute; top:12px; left:12px; background:linear-gradient(135deg, #f59e0b, #ef4444); color:white; font-size:0.7rem; font-weight:700; padding:4px 8px; border-radius:20px; display:flex; align-items:center; gap:4px; box-shadow:0 4px 10px rgba(0,0,0,0.5);">
                        <i class="fas fa-fire"></i> TRENDING
                    </div>` : ''}

                    <div class="reel-overlay" style="position:absolute; bottom:0; left:0; right:0; padding:16px; background:linear-gradient(transparent 0%, rgba(0,0,0,0.85) 100%);">
                        <div style="font-weight:700; font-size:0.92rem; color:white; margin-bottom:2px;">${reel.author_name || reel.authorName || 'Student'}</div>
                        <div style="font-size:0.8rem; color:#94a3b8; margin-bottom:8px;">@${reel.author_handle || reel.authorHandle || 'user'}</div>
                        <div style="font-size:0.8rem; color:rgba(255,255,255,0.85); display:flex; gap:12px;">
                            <span><i class="fas fa-heart" style="color:#e91e63"></i> ${reel.likes_count || reel.likesCount || 0}</span>
                            <span><i class="fas fa-eye" style="color:#0284c7"></i> ${reel.views_count || reel.viewsCount || 0}</span>
                        </div>
                    </div>

                    <div class="reel-play-icon" style="position:absolute; top:42%; left:50%; transform:translate(-50%, -50%); font-size:2.4rem; color:white; opacity:0; transition:0.3s; filter:drop-shadow(0 4px 8px rgba(0,0,0,0.6));">
                        <i class="fas fa-play-circle"></i>
                    </div>
                </div>

                <div class="reel-actions" style="position:absolute; top:12px; right:12px; display:flex; flex-direction:column; gap:8px; z-index:10;">
                    <button class="btn-icon" onclick="event.stopPropagation(); window.reelsController.toggleTrending('${reel.id}')" 
                            title="${isTrending ? 'Remove from Trending' : 'Feature as Trending'}"
                            style="background: ${isTrending ? 'rgba(234,179,8,0.95)' : 'rgba(15,23,42,0.8)'}; color: ${isTrending ? '#000' : '#fbbf24'}; border-radius:50%; width:34px; height:34px; display:flex; align-items:center; justify-content:center; backdrop-filter:blur(6px); border:1px solid rgba(255,255,255,0.15);">
                        <i class="fas fa-fire" style="font-size:0.85rem;"></i>
                    </button>
                    <button class="btn-icon" onclick="event.stopPropagation(); window.reelsController.deleteReel('${reel.id}')" 
                            title="Delete Reel"
                            style="background:rgba(239,68,68,0.85); color:white; border-radius:50%; width:34px; height:34px; display:flex; align-items:center; justify-content:center; backdrop-filter:blur(6px); border:1px solid rgba(255,255,255,0.15);">
                        <i class="fas fa-trash-alt" style="font-size:0.82rem;"></i>
                    </button>
                </div>
            `;

            card.onmouseenter = () => { card.style.transform = 'translateY(-4px)'; card.style.boxShadow = '0 12px 24px rgba(0,0,0,0.6)'; };
            card.onmouseleave = () => { card.style.transform = 'translateY(0)'; card.style.boxShadow = 'none'; };
            card.onclick = () => this.previewVideo(reel);
            this.container.appendChild(card);
        });

        // Add hover effect style if not exists
        if (!document.getElementById('reel-hover-style')) {
            const style = document.createElement('style');
            style.id = 'reel-hover-style';
            style.textContent = `
                .reel-card:hover .reel-play-icon { opacity: 0.9 !important; }
            `;
            document.head.appendChild(style);
        }
    }

    previewVideo(reel) {
        let modal = document.getElementById('reel-preview-modal');
        if (!modal) {
            modal = document.createElement('div');
            modal.id = 'reel-preview-modal';
            modal.className = 'modal-overlay';
            document.body.appendChild(modal);
        }

        const videoSrc = reel.media_url || reel.mediaUrl;

        modal.innerHTML = `
            <div class="modal-content" style="width: 420px; height: 82vh; padding: 0; background: #000; border-radius: 20px; position: relative; overflow: hidden; border: 1px solid var(--border-glass);">
                <button onclick="document.getElementById('reel-preview-modal').style.display='none'" 
                        class="btn-close" style="position:absolute; top:16px; right:16px; z-index:100; color:white; background:rgba(0,0,0,0.6); border-radius:50%; width:36px; height:36px; display:flex; align-items:center; justify-content:center; text-shadow:0 2px 4px rgba(0,0,0,0.5)">&times;</button>
                
                <video src="${videoSrc}" controls autoplay loop style="width:100%; height:100%; object-fit: contain; background: #000;"></video>
                
                <div class="reel-info" style="position:absolute; bottom:20px; left:20px; right:20px; pointer-events:none; background: linear-gradient(transparent, rgba(0,0,0,0.9)); padding: 20px 10px 10px 10px; border-radius: 12px;">
                    <div style="font-weight:700; font-size:1.1rem; color:white;">${reel.author_name || reel.authorName || 'Campus User'}</div>
                    <div style="font-size:0.85rem; color:#94a3b8; margin-top:2px;">@${reel.author_handle || reel.authorHandle || 'handle'}</div>
                    <div style="font-size:0.9rem; color:rgba(255,255,255,0.9); margin-top:8px; line-height: 1.4;">${reel.content || reel.caption || ''}</div>
                </div>
            </div>
        `;
        modal.style.display = 'flex';
    }

    async deleteReel(id) {
        if (confirm("Permanently remove this vertical reel from the campus feed?")) {
            try {
                await db.collection('posts').doc(id).delete();
                window.logAdminAction('DELETE_REEL', `Admin deleted video reel ${id}`, 'reel', id);
                const modal = document.getElementById('reel-preview-modal');
                if (modal) modal.style.display = 'none';
            } catch (err) {
                alert("Error deleting reel: " + err.message);
            }
        }
    }

    async toggleTrending(id) {
        const reel = this.reels.find(r => r.id === id);
        if (!reel) return;
        const newState = !(reel.is_trending || reel.isTrending);
        try {
            await db.collection('posts').doc(id).update({
                is_trending: newState,
                isTrending: newState
            });
            window.logAdminAction('TOGGLE_TRENDING', `Admin set reel ${id} trending to ${newState}`, 'reel', id);
            reel.is_trending = newState;
            reel.isTrending = newState;
            this.render();
        } catch (err) {
            alert("Error: " + err.message);
        }
    }
}

window.reelsController = new ReelsController();

