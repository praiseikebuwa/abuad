class ResourcesController {
    constructor() {
        this.tableBody = document.querySelector('#resources-table tbody');
        this.formListenerAttached = false;
        this.modeListenerAttached = false;
    }

    load() {
        console.log("Resources Controller: Loading academic resources from backend...");
        this.initUploadModeToggle();
        this.fetchResources();

        // Add form listener
        const form = document.getElementById('resource-form');
        if (form && !this.formListenerAttached) {
            form.addEventListener('submit', (e) => this.handleUpload(e));
            this.formListenerAttached = true;
        }

        // Add refresh button listener
        const refreshBtn = document.getElementById('btn-refresh-resources');
        if (refreshBtn && !refreshBtn.dataset.listener) {
            refreshBtn.addEventListener('click', () => this.fetchResources());
            refreshBtn.dataset.listener = 'true';
        }

        // File count indicator listener
        const fileInput = document.getElementById('res-files');
        const countDisplay = document.getElementById('res-file-count');
        if (fileInput && !fileInput.dataset.listener) {
            fileInput.addEventListener('change', () => {
                const count = fileInput.files ? fileInput.files.length : 0;
                if (countDisplay) {
                    if (count === 0) {
                        countDisplay.innerText = '';
                    } else if (count === 1) {
                        countDisplay.innerText = `Selected 1 file: ${fileInput.files[0].name}`;
                    } else {
                        countDisplay.innerText = `Selected ${count} files ready for upload.`;
                    }
                }
            });
            fileInput.dataset.listener = 'true';
        }
    }

    initUploadModeToggle() {
        if (this.modeListenerAttached) return;
        const modeFiles = document.getElementById('mode-files');
        const modeLink = document.getElementById('mode-link');
        const groupFiles = document.getElementById('group-file-upload');
        const groupLink = document.getElementById('group-link-url');
        const resTitle = document.getElementById('res-title');
        const resUrl = document.getElementById('res-url');
        const resFiles = document.getElementById('res-files');

        if (modeFiles && modeLink && groupFiles && groupLink) {
            const updateMode = () => {
                if (modeFiles.checked) {
                    groupFiles.style.display = 'block';
                    groupLink.style.display = 'none';
                    if (resTitle) resTitle.required = false;
                    if (resUrl) resUrl.required = false;
                    if (resFiles) resFiles.required = true;
                } else {
                    groupFiles.style.display = 'none';
                    groupLink.style.display = 'block';
                    if (resTitle) resTitle.required = true;
                    if (resUrl) resUrl.required = true;
                    if (resFiles) resFiles.required = false;
                }
            };

            modeFiles.addEventListener('change', updateMode);
            modeLink.addEventListener('change', updateMode);
            updateMode();
            this.modeListenerAttached = true;
        }
    }

    async fetchResources() {
        if (!this.tableBody) return;
        this.tableBody.innerHTML = `<tr><td colspan="5" class="loading-text"><i class="fas fa-spinner fa-spin"></i> Loading academic resources...</td></tr>`;

        try {
            const token = ApiClientAdmin.getAccessToken();
            const res = await ApiClientAdmin.fetch('/resources');
            if (res.ok) {
                const data = await res.json();
                const resources = data.data || [];
                this.renderResources(resources);
                return;
            }
        } catch (apiErr) {
            console.warn("Backend /resources fetch error, checking fallback:", apiErr);
        }

        // Firestore fallback
        if (typeof db !== 'undefined' && db && db.collection) {
            try {
                const snapshot = await db.collection('resources').orderBy('uploadedAt', 'desc').get();
                const resources = [];
                snapshot.forEach(doc => {
                    const data = doc.data();
                    resources.push({
                        id: doc.id,
                        title: data.title || 'Untitled',
                        category: data.category || 'General',
                        courseCode: data.category || 'General',
                        level: data.level || '100',
                        url: data.url || data.fileUrl || '#',
                        date: data.uploadedAt ? new Date(data.uploadedAt.toDate ? data.uploadedAt.toDate() : data.uploadedAt).toLocaleDateString() : 'N/A'
                    });
                });
                this.renderResources(resources);
                return;
            } catch (fsErr) {
                console.error("Firestore resources fetch error:", fsErr);
            }
        }

        this.tableBody.innerHTML = `<tr><td colspan="5" class="error-text">Failed to connect to resources service.</td></tr>`;
    }

    renderResources(resources) {
        if (!this.tableBody) return;
        this.tableBody.innerHTML = '';

        if (!resources || resources.length === 0) {
            this.tableBody.innerHTML = `<tr><td colspan="5" class="loading-text" style="text-align: center; color: var(--text-secondary); padding: 24px;">No academic resources uploaded yet. Upload lecture notes, past questions, or PDFs above to feed the app and AI.</td></tr>`;
            return;
        }

        resources.forEach(res => {
            const row = document.createElement('tr');
            const courseCode = res.courseCode || res.category || 'General';
            const title = res.title || res.name || res.fileName || `${courseCode} Course Material`;
            const fileUrl = res.fileUrl || res.url || '#';
            const level = res.level ? `${res.level}L` : 'All Levels';
            const dateStr = res.createdAt ? new Date(res.createdAt).toLocaleDateString() : (res.created_at ? new Date(res.created_at).toLocaleDateString() : (res.date || 'Recent'));

            row.innerHTML = `
                <td>
                    <div style="font-weight: 600; color: var(--text-primary);">${title}</div>
                    <small>
                        <a href="${fileUrl}" target="_blank" rel="noopener noreferrer" style="color: var(--color-primary-600); text-decoration: none; display: inline-flex; align-items: center; gap: 4px; margin-top: 2px;">
                            <i class="fas fa-external-link-alt"></i> View / Download File
                        </a>
                    </small>
                </td>
                <td>
                    <span class="badge" style="background: #EEF2FF; color: #4F46E5; font-weight: bold; padding: 4px 8px; border-radius: 6px;">
                        ${courseCode}
                    </span>
                    <small style="display: block; color: var(--text-secondary); margin-top: 2px;">${level}</small>
                </td>
                <td>
                    <span class="badge" style="background: var(--bg-surface); border: 1px solid var(--border-subtle); color: var(--text-secondary);">
                        ${res.category || 'Course Material'}
                    </span>
                </td>
                <td style="color: var(--text-secondary); font-size: 13px;">${dateStr}</td>
                <td style="text-align: right;">
                    <button class="btn-icon btn-delete" title="Delete Resource" style="color: #EF4444; background: transparent; border: none; cursor: pointer; padding: 6px;">
                        <i class="fas fa-trash-alt"></i>
                    </button>
                </td>
            `;

            row.querySelector('.btn-delete').addEventListener('click', () => {
                if (confirm(`Are you sure you want to delete "${title}"? This will remove it from student study materials and AI context.`)) {
                    this.deleteResource(res.id, title);
                }
            });

            this.tableBody.appendChild(row);
        });
    }

    async handleUpload(e) {
        e.preventDefault();
        const btn = document.getElementById('btn-upload-resource');
        const progressEl = document.getElementById('res-upload-progress');
        const progressText = document.getElementById('res-progress-text');
        const courseInput = document.getElementById('res-course');
        const levelInput = document.getElementById('res-level');
        const categoryInput = document.getElementById('res-category');
        const isFilesMode = document.getElementById('mode-files')?.checked ?? true;

        const courseCode = courseInput.value.trim().toUpperCase();
        const level = levelInput.value;
        const category = categoryInput.value;

        if (!courseCode) {
            alert("Please enter a course code (e.g. GST 111, MTH 101).");
            return;
        }

        btn.disabled = true;
        progressEl.style.display = 'block';

        try {
            if (isFilesMode) {
                // Multiple files upload
                const fileInput = document.getElementById('res-files');
                const files = fileInput.files;

                if (!files || files.length === 0) {
                    alert("Please select at least one file to upload.");
                    btn.disabled = false;
                    progressEl.style.display = 'none';
                    return;
                }

                progressText.innerText = `Uploading ${files.length} file(s) to Cloudflare R2 & creating resources...`;

                const formData = new FormData();
                for (let i = 0; i < files.length; i++) {
                    formData.append('files', files[i]);
                }
                formData.append('courseCode', courseCode);
                formData.append('category', category);
                formData.append('level', level);

                const token = ApiClientAdmin.getAccessToken();
                let uploadRes = await fetch(`${API_BASE_URL}/resources/upload-multiple`, {
                    method: 'POST',
                    headers: {
                        ...(token ? { 'Authorization': `Bearer ${token}` } : {})
                    },
                    body: formData
                });

                // Fallback if the remote backend has not yet mounted /resources/upload-multiple
                if (uploadRes.status === 404) {
                    console.log("Direct /resources/upload-multiple 404, using /media/upload-multiple fallback...");
                    progressText.innerText = `Uploading ${files.length} file(s) to Cloudflare R2 via storage service...`;

                    const mediaFormData = new FormData();
                    for (let i = 0; i < files.length; i++) {
                        mediaFormData.append('files', files[i]);
                    }

                    const mediaRes = await fetch(`${API_BASE_URL}/media/upload-multiple`, {
                        method: 'POST',
                        headers: {
                            ...(token ? { 'Authorization': `Bearer ${token}` } : {})
                        },
                        body: mediaFormData
                    });

                    if (mediaRes.ok) {
                        const mediaData = await mediaRes.json();
                        const uploadedFiles = mediaData.data?.files || [];
                        let createdCount = 0;
                        progressText.innerText = `Registering ${uploadedFiles.length} course material(s)...`;

                        for (const item of uploadedFiles) {
                            const rawName = item.filename || item.key || 'Material';
                            const title = rawName.replace(/\.[^/.]+$/, '').replace(/^[0-9]+-/, '').replace(/[_-]/g, ' ');
                            const payload = {
                                title: `${courseCode} - ${title}`,
                                courseCode,
                                category,
                                level,
                                fileUrl: item.publicUrl
                            };
                            try {
                                const regRes = await ApiClientAdmin.fetch('/resources', {
                                    method: 'POST',
                                    body: JSON.stringify(payload)
                                });
                                if (regRes.ok) {
                                    createdCount++;
                                } else if (typeof db !== 'undefined' && db && db.collection) {
                                    await db.collection('resources').add({
                                        ...payload,
                                        uploadedAt: firebase.firestore.FieldValue.serverTimestamp()
                                    });
                                    createdCount++;
                                }
                            } catch (_) {
                                if (typeof db !== 'undefined' && db && db.collection) {
                                    await db.collection('resources').add({
                                        ...payload,
                                        uploadedAt: firebase.firestore.FieldValue.serverTimestamp()
                                    });
                                    createdCount++;
                                }
                            }
                        }
                        alert(`Successfully uploaded ${createdCount || uploadedFiles.length} resource(s) for ${courseCode}!`);
                        e.target.reset();
                        document.getElementById('res-file-count').innerText = '';
                        this.initUploadModeToggle();
                        this.fetchResources();
                        return;
                    }
                }

                if (!uploadRes.ok) {
                    const errData = await uploadRes.json().catch(() => ({}));
                    throw new Error(errData.error || `Upload failed with status ${uploadRes.status}`);
                }

                const result = await uploadRes.json();
                alert(`Successfully uploaded ${result.count || files.length} resource(s) for ${courseCode}!`);
                e.target.reset();
                document.getElementById('res-file-count').innerText = '';
                this.initUploadModeToggle();
                this.fetchResources();
            } else {
                // Single Link URL upload
                const titleInput = document.getElementById('res-title');
                const urlInput = document.getElementById('res-url');

                if (!urlInput.value.trim()) {
                    alert("Please enter a valid file URL.");
                    btn.disabled = false;
                    progressEl.style.display = 'none';
                    return;
                }

                progressText.innerText = "Registering resource URL with backend...";

                const payload = {
                    title: titleInput.value.trim() || `${courseCode} Course Material`,
                    courseCode,
                    category,
                    level,
                    fileUrl: urlInput.value.trim()
                };

                const res = await ApiClientAdmin.fetch('/resources', {
                    method: 'POST',
                    body: JSON.stringify(payload)
                });

                if (!res.ok) {
                    const errData = await res.json().catch(() => ({}));
                    throw new Error(errData.error || `Failed with status ${res.status}`);
                }

                alert(`Successfully added resource "${payload.title}"!`);
                e.target.reset();
                this.initUploadModeToggle();
                this.fetchResources();
            }
        } catch (err) {
            console.error("Resource upload error:", err);
            alert("Upload failed: " + err.message);
        } finally {
            btn.disabled = false;
            progressEl.style.display = 'none';
        }
    }

    async deleteResource(id, title) {
        try {
            const res = await ApiClientAdmin.fetch(`/resources/${id}`, {
                method: 'DELETE'
            });

            if (res.ok) {
                alert(`Deleted "${title}" successfully.`);
                this.fetchResources();
                return;
            }

            // Fallback to Firestore delete
            if (typeof db !== 'undefined' && db && db.collection) {
                await db.collection('resources').doc(id).delete();
                alert(`Deleted "${title}".`);
                this.fetchResources();
                return;
            }

            throw new Error(`Delete failed with status ${res.status}`);
        } catch (err) {
            alert("Delete failed: " + err.message);
        }
    }
}
