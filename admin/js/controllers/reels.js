class ReelsController {
    constructor() {
        this.container = document.getElementById('reels-container');
        this.reels = [];
    }

    load() {
        if (!this.container) return;
        this.container.innerHTML = '<div class="loading-text">Fetching vertical content...</div>';

        if (this.unsubscribe) this.unsubscribe();

        // Query posts with media_type 'video'
        this.unsubscribe = db.collection('posts')
            .where('media_type', '==', 'video')
            .orderBy('created_at', 'desc')
            .limit(40)
            .onSnapshot(snap => {
                this.reels = [];
                snap.forEach(doc => {
                    this.reels.push({ id: doc.id, ...doc.data() });
                });
                this.render();
            }, err => {
                console.error(err);
                if (err.code === 'failed-precondition') {
                    this.container.innerHTML = '<div class="error-text">Indexing required for video posts. Please check Firestore console.</div>';
                } else {
                    this.container.innerHTML = `<div class="error-text">Error: ${err.message}</div>`;
                }
            });
    }

    render() {
        this.container.innerHTML = '';

        if (this.reels.length === 0) {
            this.container.innerHTML = '<div class="empty-state">No video reels found.</div>';
            return;
        }

        this.reels.forEach(reel => {
            const card = document.createElement('div');
            card.className = 'card reel-card';
            card.style.padding = '0';
            card.style.overflow = 'hidden';
            card.style.position = 'relative';
            card.style.aspectRatio = '9 / 16';
            card.style.cursor = 'pointer';

            const thumbnailUrl = reel.thumbnail_url || (reel.mediaUrl ? reel.mediaUrl : '');
            
            card.innerHTML = `
                <div class="reel-thumbnail" style="width:100%; height:100%; background: #000 url('${thumbnailUrl}') center/cover no-repeat;">
                    <div class="reel-overlay" style="position:absolute; bottom:0; left:0; right:0; padding:15px; background:linear-gradient(transparent, rgba(0,0,0,0.8));">
                        <div style="font-weight:600; font-size:0.9rem; margin-bottom:4px;">@${reel.authorHandle || 'user'}</div>
                        <div style="font-size:0.8rem; color:rgba(255,255,255,0.7); display:flex; gap:10px;">
                            <span><i class="fas fa-heart"></i> ${reel.likes_count || 0}</span>
                            <span><i class="fas fa-play"></i> ${reel.views_count || 0}</span>
                        </div>
                    </div>
                    <div class="reel-play-icon" style="position:absolute; top:50%; left:50%; transform:translate(-50%, -50%); font-size:2rem; opacity:0; transition:0.3s;">
                        <i class="fas fa-play-circle"></i>
                    </div>
                </div>
                <div class="reel-actions" style="position:absolute; top:10px; right:10px; display:flex; flex-direction:column; gap:8px;">
                    <button class="btn-icon" onclick="event.stopPropagation(); window.reelsController.deleteReel('${reel.id}')" 
                            style="background:rgba(244,63,94,0.8); color:white; border-radius:50%; width:32px; height:32px; display:flex; align-items:center; justify-content:center;">
                        <i class="fas fa-trash-alt" style="font-size:0.8rem;"></i>
                    </button>
                    <button class="btn-icon" onclick="event.stopPropagation(); window.reelsController.toggleTrending('${reel.id}')" 
                            style="background:rgba(251,191,36,0.8); color:white; border-radius:50%; width:32px; height:32px; display:flex; align-items:center; justify-content:center;">
                        <i class="fas fa-bolt" style="font-size:0.8rem;"></i>
                    </button>
                </div>
            `;

            card.onclick = () => this.previewVideo(reel);
            this.container.appendChild(card);
        });

        // Add hover effect style if not exists
        if (!document.getElementById('reel-hover-style')) {
            const style = document.createElement('style');
            style.id = 'reel-hover-style';
            style.textContent = `
                .reel-card:hover .reel-play-icon { opacity: 1 !important; }
                .reel-card:hover .reel-thumbnail { transform: scale(1.05); transition: 0.5s; }
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

        modal.innerHTML = `
            <div class="modal-content" style="width: 400px; height: 80vh; padding: 0; background: #000; border-radius: 20px; position: relative;">
                <button onclick="document.getElementById('reel-preview-modal').style.display='none'" 
                        class="btn-close" style="position:absolute; top:20px; right:20px; z-index:100; color:white; text-shadow:0 2px 4px rgba(0,0,0,0.5)">&times;</button>
                
                <video src="${reel.mediaUrl}" controls autoplay loop style="width:100%; height:100%; object-fit: cover; border-radius:20px;"></video>
                
                <div class="reel-info" style="position:absolute; bottom:20px; left:20px; right:20px; pointer-events:none;">
                    <div style="font-weight:700; font-size:1.1rem; color:white;">${reel.authorName || 'User'}</div>
                    <div style="font-size:0.9rem; color:rgba(255,255,255,0.9); margin-top:8px;">${reel.content || ''}</div>
                </div>
            </div>
        `;
        modal.style.display = 'flex';
    }

    async deleteReel(id) {
        if (confirm("Permanently remove this reel? This cannot be undone.")) {
            try {
                await db.collection('posts').doc(id).delete();
                window.logAdminAction('DELETE_REEL', `Admin deleted video reel ${id}`, 'reel', id);
            } catch (err) {
                alert("Error: " + err.message);
            }
        }
    }

    async toggleTrending(id) {
        const reel = this.reels.find(r => r.id === id);
        const newState = !reel.isTrending;
        try {
            await db.collection('posts').doc(id).update({ isTrending: newState });
            window.logAdminAction('TOGGLE_TRENDING', `Admin set reel ${id} trending to ${newState}`, 'reel', id);
            alert(`Reel is now ${newState ? 'Trending' : 'Not Trending'}`);
        } catch (err) {
            alert("Error: " + err.message);
        }
    }
}

window.reelsController = new ReelsController();
