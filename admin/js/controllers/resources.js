class ResourcesController {
    constructor() {
        this.tableBody = document.querySelector('#resources-table tbody');
    }

    load() {
        console.log("Resources Controller Connecting to Firestore...");
        this.subscribeToResources();

        // Add form listener
        const form = document.getElementById('resource-form');
        if (form && !this.formListenerAttached) {
            form.addEventListener('submit', (e) => this.uploadResource(e));
            this.formListenerAttached = true;
        }
    }

    subscribeToResources() {
        if (!this.tableBody) return;

        if (this.unsubscribe) this.unsubscribe();

        this.unsubscribe = db.collection('resources').orderBy('uploadedAt', 'desc').onSnapshot((snapshot) => {
            const resources = [];
            snapshot.forEach((doc) => {
                const data = doc.data();
                resources.push({
                    id: doc.id,
                    title: data.title || 'Untitled',
                    category: data.category || 'General',
                    url: data.url || '#',
                    downloads: data.downloads || 0,
                    date: data.uploadedAt ? new Date(data.uploadedAt.toDate()).toLocaleDateString() : 'N/A'
                });
            });
            this.renderResources(resources);
        }, (error) => {
            console.error("Error fetching resources:", error);
            this.tableBody.innerHTML = `<tr><td colspan="5" class="error-text">Error loading resources: ${error.message}</td></tr>`;
        });
    }

    renderResources(resources) {
        if (!this.tableBody) return;
        this.tableBody.innerHTML = '';

        if (resources.length === 0) {
            this.tableBody.innerHTML = `<tr><td colspan="5" class="loading-text">No resources uploaded yet.</td></tr>`;
            return;
        }

        resources.forEach(res => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td>
                    <div style="font-weight: 500">${res.title}</div>
                    <small><a href="${res.url}" target="_blank" style="color: var(--color-primary-600)">View File</a></small>
                </td>
                <td><span class="badge" style="background: var(--color-neutral-200); color: var(--text-secondary);">${res.category}</span></td>
                <td>${res.downloads}</td>
                <td>${res.date}</td>
                <td style="text-align: right;">
                    <button class="btn-icon btn-delete" title="Delete Resource"><i class="fas fa-trash"></i></button>
                </td>
            `;

            row.querySelector('.btn-delete').addEventListener('click', () => {
                if (confirm(`Delete "${res.title}"?`)) {
                    this.deleteResource(res.id, res.title);
                }
            });

            this.tableBody.appendChild(row);
        });
    }

    async uploadResource(e) {
        e.preventDefault();
        const btn = e.target.querySelector('button');
        const titleInput = document.getElementById('res-title');
        const categoryInput = document.getElementById('res-category');
        const urlInput = document.getElementById('res-url'); 

        btn.disabled = true;
        btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Uploading...';

        try {
            const docRef = await db.collection('resources').add({
                title: titleInput.value,
                category: categoryInput.value,
                url: urlInput.value,
                downloads: 0,
                uploadedAt: firebase.firestore.FieldValue.serverTimestamp()
            });

            window.logAdminAction('UPLOAD_RESOURCE', `Uploaded resource: ${titleInput.value}`, 'resource', docRef.id);
            
            e.target.reset();
            alert("Resource added successfully!");
        } catch (err) {
            alert("Upload failed: " + err.message);
        } finally {
            btn.disabled = false;
            btn.innerText = "Upload Resource";
        }
    }

    async deleteResource(id, title) {
        try {
            await db.collection('resources').doc(id).delete();
            window.logAdminAction('DELETE_RESOURCE', `Deleted resource: ${title}`, 'resource', id);
        } catch (err) {
            alert("Delete failed: " + err.message);
        }
    }
}


// Auto-init removed.
