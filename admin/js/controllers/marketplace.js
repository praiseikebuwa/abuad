class MarketplaceController {
    constructor() {
        this.tableBody = document.querySelector('#marketplace-table tbody');
    }

    load() {
        if (!this.tableBody) return;
        this.tableBody.innerHTML = '<tr><td colspan="5" class="loading-text">Loading marketplace listings...</td></tr>';

        if (this.unsubscribe) this.unsubscribe();

        this.unsubscribe = db.collection('marketplace_items')
            .orderBy('createdAt', 'desc')
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
        this.items = [];

        if (snap.empty) {
            this.tableBody.innerHTML = '<tr><td colspan="5">No active listings found.</td></tr>';
            return;
        }

        snap.forEach(doc => {
            const item = { id: doc.id, ...doc.data() };
            this.items.push(item);
            
            const tr = document.createElement('tr');
            const isVerified = item.isExpertVerified === true;

            tr.innerHTML = `
                <td>
                    <div style="font-weight: 600">${item.title || 'Untitled'} ${isVerified ? '<i class="fas fa-check-circle" style="color:var(--color-primary-light); font-size:0.8rem;"></i>' : ''}</div>
                    <small class="text-muted">${item.category || 'General'}</small>
                </td>
                <td>
                    <small><b>${item.sellerName || 'Seller'}</b></small><br>
                    <small class="text-muted">${item.sellerId?.substring(0, 6)}</small>
                </td>
                <td><b style="color: var(--color-primary-600)">₦${item.price?.toLocaleString() || '0'}</b></td>
                <td><span class="badge badge-gray">${item.condition || 'Used'}</span></td>
                <td style="text-align: right;">
                    <div class="action-buttons">
                        <button class="btn-icon btn-view" onclick="window.marketplaceController.openItemModal('${item.id}')" title="View Details">
                            <i class="fas fa-eye"></i>
                        </button>
                        <button class="btn-icon btn-delete" onclick="window.marketplaceController.deleteItem('${item.id}')" title="Delete Listing">
                            <i class="fas fa-trash-alt"></i>
                        </button>
                    </div>
                </td>
            `;
            this.tableBody.appendChild(tr);
        });
    }

    openItemModal(id) {
        const item = this.items.find(i => i.id === id);
        if (!item) return;

        let modal = document.getElementById('marketplace-detail-modal');
        if (!modal) {
            modal = document.createElement('div');
            modal.id = 'marketplace-detail-modal';
            modal.className = 'modal-overlay';
            document.body.appendChild(modal);
        }

        const imagesHtml = (item.images || [item.imageUrl]).filter(Boolean).map(url => 
            `<img src="${url}" style="width:100px; height:100px; object-fit:cover; border-radius:8px; cursor:zoom-in;" onclick="window.open('${url}')">`
        ).join('');

        modal.innerHTML = `
            <div class="modal-content" style="width: 500px;">
                <div class="modal-header">
                    <h2>Marketplace Review</h2>
                    <button onclick="document.getElementById('marketplace-detail-modal').style.display='none'" class="btn-close">&times;</button>
                </div>
                <div class="modal-body overflow-y">
                    <div style="display:flex; gap:10px; margin-bottom:20px; overflow-x:auto; padding-bottom:10px;">
                        ${imagesHtml || '<div class="empty-media">No images provided</div>'}
                    </div>
                    
                    <h3 style="margin-bottom:5px;">${item.title}</h3>
                    <div style="color:var(--color-primary-light); font-weight:700; font-size:1.2rem; margin-bottom:15px;">₦${item.price?.toLocaleString()}</div>
                    
                    <p style="margin-bottom:20px; color:var(--text-secondary); line-height:1.5;">${item.description || 'No description provided.'}</p>
                    
                    <div class="card" style="background:rgba(255,255,255,0.02); border-color:var(--border-subtle);">
                        <div style="display:flex; justify-content:space-between; align-items:center;">
                            <div>
                                <b>Expert Verification</b><br>
                                <small class="text-muted">Manually verify item authenticity</small>
                            </div>
                            <label class="switch">
                                <input type="checkbox" ${item.isExpertVerified ? 'checked' : ''} onchange="window.marketplaceController.toggleVerification('${item.id}', this.checked)">
                                <span class="slider round"></span>
                            </label>
                        </div>
                    </div>
                </div>
                <div class="modal-footer">
                   <small>Listed by ${item.sellerName} on ${new Date(item.createdAt?.toDate?.() || item.createdAt).toLocaleDateString()}</small>
                </div>
            </div>
        `;
        modal.style.display = 'flex';
    }

    async toggleVerification(id, status) {
        try {
            await db.collection('marketplace_items').doc(id).update({ isExpertVerified: status });
            window.logAdminAction('VERIFY_MARKETPLACE', `Admin set verification for ${id} to ${status}`, 'marketplace_item', id);
        } catch (err) {
            alert("Error: " + err.message);
        }
    }

    async deleteItem(id) {
        if (confirm("Remove this marketplace listing? This will notify the seller.")) {
            try {
                await db.collection('marketplace_items').doc(id).delete();
                window.logAdminAction('DELETE_MARKETPLACE', `Admin deleted marketplace item ${id}`, 'marketplace_item', id);
                const modal = document.getElementById('marketplace-detail-modal');
                if (modal) modal.style.display = 'none';
            } catch (err) {
                alert("Error: " + err.message);
            }
        }
    }
}
