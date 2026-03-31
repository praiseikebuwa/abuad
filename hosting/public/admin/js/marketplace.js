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

        if (snap.empty) {
            this.tableBody.innerHTML = '<tr><td colspan="5">No active listings found.</td></tr>';
            return;
        }

        snap.forEach(doc => {
            const item = doc.data();
            const tr = document.createElement('tr');

            tr.innerHTML = `
                <td>
                    <div style="font-weight: 600">${item.title || 'Untitled'}</div>
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
                        <button class="btn-icon btn-delete" onclick="window.marketplaceController.deleteItem('${doc.id}')" title="Delete Listing">
                            <i class="fas fa-trash-alt"></i>
                        </button>
                    </div>
                </td>
            `;
            this.tableBody.appendChild(tr);
        });
    }

    async deleteItem(id) {
        if (confirm("Remove this marketplace listing? This will notify the seller.")) {
            try {
                await db.collection('marketplace_items').doc(id).delete();
                window.logAdminAction('DELETE_MARKETPLACE', `Admin deleted marketplace item ${id}`, 'marketplace_item', id);
                alert("Listing removed.");
            } catch (err) {
                alert("Error: " + err.message);
            }
        }
    }
}
window.marketplaceController = new MarketplaceController();
