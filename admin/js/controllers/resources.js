class ResourcesController {
    constructor() {
        this.tableBody = document.querySelector('#resources-table tbody');
        this.formListenerAttached = false;
        this.modeListenerAttached = false;
        this.modalsInitialized = false;
        this.pollTimer = null;
        this.cachedText = '';
    }

    load() {
        console.log("Resources Controller: Loading academic resources & OCR manager...");
        this.initUploadModeToggle();
        this.initModals();
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
            refreshBtn.addEventListener('click', () => this.fetchResources(true));
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
                        countDisplay.innerText = `Selected ${count} files ready for upload and OCR.`;
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

    initModals() {
        if (this.modalsInitialized) return;

        const textModal = document.getElementById('modal-resource-text');
        const previewModal = document.getElementById('modal-resource-preview');

        // Close buttons for text modal
        const closeTextBtn1 = document.getElementById('btn-close-text-modal');
        const closeTextBtn2 = document.getElementById('btn-close-text-modal-2');
        if (closeTextBtn1) closeTextBtn1.addEventListener('click', () => this.closeTextModal());
        if (closeTextBtn2) closeTextBtn2.addEventListener('click', () => this.closeTextModal());

        // Close buttons for preview modal
        const closePreviewBtn = document.getElementById('btn-close-preview-modal');
        if (closePreviewBtn) closePreviewBtn.addEventListener('click', () => this.closePreviewModal());

        // Click outside overlay to close
        if (textModal) {
            textModal.addEventListener('click', (e) => {
                if (e.target === textModal) this.closeTextModal();
            });
        }
        if (previewModal) {
            previewModal.addEventListener('click', (e) => {
                if (e.target === previewModal) this.closePreviewModal();
            });
        }

        // Copy text button
        const copyBtn = document.getElementById('btn-copy-extracted-text');
        if (copyBtn) {
            copyBtn.addEventListener('click', () => {
                const text = this.cachedText || document.getElementById('res-modal-text-content')?.innerText || '';
                if (!text) return;
                navigator.clipboard.writeText(text).then(() => {
                    const origHtml = copyBtn.innerHTML;
                    copyBtn.innerHTML = '<i class="fas fa-check"></i> Copied!';
                    copyBtn.style.background = '#10B981';
                    copyBtn.style.color = '#FFF';
                    setTimeout(() => {
                        copyBtn.innerHTML = origHtml;
                        copyBtn.style.background = '';
                        copyBtn.style.color = '';
                    }, 2000);
                }).catch(() => {
                    alert('Copied text to clipboard.');
                });
            });
        }

        // Text search filter inside modal
        const searchInput = document.getElementById('res-text-search');
        if (searchInput) {
            searchInput.addEventListener('input', (e) => {
                const query = e.target.value.toLowerCase().trim();
                const container = document.getElementById('res-modal-text-content');
                if (!container || !this.cachedText) return;

                if (!query) {
                    container.innerText = this.cachedText;
                    document.getElementById('res-modal-stats').innerText = `${this.cachedText.split(/\s+/).filter(Boolean).length} words`;
                    return;
                }

                // Filter lines or count occurrences
                const occurrences = (this.cachedText.toLowerCase().match(new RegExp(query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g')) || []).length;
                document.getElementById('res-modal-stats').innerText = `Found ${occurrences} match${occurrences === 1 ? '' : 'es'}`;
            });
        }

        // Keyboard Esc key
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                this.closeTextModal();
                this.closePreviewModal();
            }
        });

        this.modalsInitialized = true;
    }

    closeTextModal() {
        const textModal = document.getElementById('modal-resource-text');
        if (textModal) textModal.style.display = 'none';
        this.cachedText = '';
        const searchInput = document.getElementById('res-text-search');
        if (searchInput) searchInput.value = '';
    }

    closePreviewModal() {
        const previewModal = document.getElementById('modal-resource-preview');
        if (previewModal) previewModal.style.display = 'none';
        const iframe = document.getElementById('resource-pdf-frame');
        if (iframe) iframe.src = 'about:blank';
    }

    async openTextModal(resourceId, title, method) {
        const textModal = document.getElementById('modal-resource-text');
        const modalTitle = document.getElementById('res-modal-title');
        const badgesContainer = document.getElementById('res-modal-badges');
        const statsEl = document.getElementById('res-modal-stats');
        const contentEl = document.getElementById('res-modal-text-content');

        if (!textModal || !contentEl) return;

        modalTitle.innerText = title;
        badgesContainer.innerHTML = `<span class="badge" style="background: rgba(99, 102, 241, 0.15); color: #4F46E5;"><i class="fas fa-spinner fa-spin"></i> Loading extracted text...</span>`;
        statsEl.innerText = '';
        contentEl.innerText = 'Retrieving full extracted document text from database and Cloudflare R2...';
        textModal.style.display = 'flex';

        try {
            let docData = null;
            let res = null;
            try {
                res = await ApiClientAdmin.fetch(`/resources/${resourceId}/text`);
                const contentType = res.headers ? (res.headers.get('content-type') || '') : '';
                if (res.ok && contentType.includes('application/json')) {
                    const data = await res.json();
                    if (data.success && data.data) {
                        docData = data.data;
                    }
                }
            } catch (netErr) {
                console.warn("Direct API /resources/:id/text fetch failed:", netErr);
            }

            // Fallback 1: Local resources map
            if (!docData) {
                const cachedRes = this.resourcesMap?.get(resourceId);
                if (cachedRes && cachedRes.extractedText) {
                    docData = {
                        text: cachedRes.extractedText,
                        extractionMethod: cachedRes.extractionMethod || method || 'TEXT',
                        totalPages: cachedRes.totalPages || 1,
                        wordCount: cachedRes.extractedText.trim().split(/\s+/).length,
                        charCount: cachedRes.extractedText.length
                    };
                }
            }

            // Fallback 2: Firestore
            if (!docData && typeof db !== 'undefined' && db && db.collection) {
                try {
                    const snap = await db.collection('resources').doc(resourceId).get();
                    if (snap.exists) {
                        const data = snap.data();
                        if (data.extractedText) {
                            docData = {
                                text: data.extractedText,
                                extractionMethod: data.extractionMethod || method || 'DIGITAL_TEXT',
                                totalPages: data.totalPages || 1,
                                wordCount: data.extractedText.trim().split(/\s+/).length,
                                charCount: data.extractedText.length
                            };
                        }
                    }
                } catch (fsErr) {
                    console.warn("Firestore text fetch failed:", fsErr);
                }
            }

            if (!docData || !docData.text) {
                contentEl.innerText = 'Extracted text is not yet available for this document.\n\nPossible reasons:\n1. The document is currently queued or being processed by the OCR engine.\n2. The backend server is pending deployment with the new OCR worker.\n3. The PDF was uploaded prior to OCR extraction.\n\nYou can click "Reprocess / Retry OCR" in the actions menu once the backend is updated.';
                badgesContainer.innerHTML = `<span class="badge" style="background: #FEF3C7; color: #D97706;"><i class="fas fa-clock"></i> Not Ready</span>`;
                return;
            }

            this.cachedText = docData.text || '';
            contentEl.innerText = this.cachedText;

            // Badges
            let methodBadgeColor = '#4F46E5';
            let methodBadgeBg = '#EEF2FF';
            let methodLabel = docData.extractionMethod || method || 'TEXT';
            if (methodLabel === 'OCR') {
                methodBadgeColor = '#7C3AED';
                methodBadgeBg = '#F5F3FF';
                methodLabel = 'Tesseract OCR';
            } else if (methodLabel === 'HYBRID') {
                methodBadgeColor = '#059669';
                methodBadgeBg = '#ECFDF5';
                methodLabel = 'Hybrid OCR + Digital';
            } else if (methodLabel === 'DIGITAL_TEXT') {
                methodBadgeColor = '#2563EB';
                methodBadgeBg = '#EFF6FF';
                methodLabel = 'Digital Text';
            }

            badgesContainer.innerHTML = `
                <span class="badge" style="background: ${methodBadgeBg}; color: ${methodBadgeColor}; font-weight: 600; padding: 2px 8px; border-radius: 6px;">
                    <i class="fas fa-microchip"></i> ${methodLabel}
                </span>
                <span class="badge" style="background: var(--bg-surface); border: 1px solid var(--border-subtle); color: var(--text-secondary); padding: 2px 8px; border-radius: 6px;">
                    ${docData.totalPages || 1} Page${docData.totalPages === 1 ? '' : 's'}
                </span>
                <span class="badge" style="background: var(--bg-surface); border: 1px solid var(--border-subtle); color: var(--text-secondary); padding: 2px 8px; border-radius: 6px;">
                    ${docData.wordCount || 0} Words
                </span>
            `;

            statsEl.innerText = `${docData.charCount || this.cachedText.length} characters`;
        } catch (err) {
            contentEl.innerText = 'Failed to load document text: ' + err.message;
            badgesContainer.innerHTML = `<span class="badge" style="background: #FEE2E2; color: #DC2626;">Error</span>`;
        }
    }

    openPreviewModal(title, fileUrl) {
        const previewModal = document.getElementById('modal-resource-preview');
        const modalTitle = document.getElementById('res-preview-title');
        const urlDisplay = document.getElementById('res-preview-url');
        const externalLink = document.getElementById('res-preview-external-link');
        const iframe = document.getElementById('resource-pdf-frame');

        if (!previewModal || !iframe) return;

        modalTitle.innerText = title;
        urlDisplay.innerText = fileUrl;
        if (externalLink) externalLink.href = fileUrl;
        iframe.src = fileUrl;
        previewModal.style.display = 'flex';
    }

    async reprocessResource(id, title) {
        try {
            const res = await ApiClientAdmin.fetch(`/resources/${id}/reprocess`, {
                method: 'POST'
            });
            const contentType = res.headers ? (res.headers.get('content-type') || '') : '';
            if (res.ok && contentType.includes('application/json')) {
                const data = await res.json();
                if (data.success) {
                    alert(`Reprocessing queued for "${title}". OCR worker will re-extract text in background.`);
                    this.fetchResources(true);
                    return;
                }
            }
            alert(`Reprocessing endpoint returned status ${res.status}. Note that if backend changes have not been deployed to the remote VPS server yet, please deploy the backend code first.`);
        } catch (err) {
            alert(`Reprocess request failed: ${err.message}. If the remote server is not yet updated with the new OCR routes, please deploy the backend to your VPS.`);
        }
    }

    async fetchResources(isManualRefresh = false) {
        if (!this.tableBody) return;
        if (isManualRefresh && !this.pollTimer) {
            this.tableBody.innerHTML = `<tr><td colspan="6" class="loading-text"><i class="fas fa-spinner fa-spin"></i> Loading academic resources...</td></tr>`;
        }

        try {
            const res = await ApiClientAdmin.fetch('/resources');
            if (res.ok) {
                const data = await res.json();
                const resources = data.data || [];
                this.renderResources(resources);
                this.managePolling(resources);
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
                        processingStatus: data.processingStatus || 'COMPLETED',
                        extractionMethod: data.extractionMethod || 'DIGITAL_TEXT',
                        date: data.uploadedAt ? new Date(data.uploadedAt.toDate ? data.uploadedAt.toDate() : data.uploadedAt).toLocaleDateString() : 'N/A'
                    });
                });
                this.renderResources(resources);
                return;
            } catch (fsErr) {
                console.error("Firestore resources fetch error:", fsErr);
            }
        }

        this.tableBody.innerHTML = `<tr><td colspan="6" class="error-text">Failed to connect to resources service.</td></tr>`;
    }

    managePolling(resources) {
        const activeJobs = resources.filter(r => 
            ['PENDING', 'EXTRACTING', 'RUNNING_OCR', 'UPLOADING'].includes(r.processingStatus)
        );
        const failedJobs = resources.filter(r => r.processingStatus === 'FAILED');

        const banner = document.getElementById('res-processing-banner');

        if (activeJobs.length > 0) {
            if (banner) {
                banner.style.display = 'flex';
                banner.style.alignItems = 'center';
                banner.style.justifyContent = 'space-between';
                banner.style.flexWrap = 'wrap';
                banner.style.gap = '8px';
                banner.style.background = '#EEF2FF';
                banner.style.border = '1px solid #C7D2FE';
                banner.style.color = '#3730A3';

                const inProgress = activeJobs.filter(j => ['EXTRACTING', 'RUNNING_OCR', 'UPLOADING'].includes(j.processingStatus));
                const pendingCount = activeJobs.filter(j => j.processingStatus === 'PENDING').length;

                let statusMsg = '';
                if (inProgress.length > 0) {
                    const current = inProgress[0];
                    statusMsg = `<strong>Actively Processing:</strong> ${current.title.slice(0, 25)}... (${current.processingStatus} ${current.processingProgress || 0}%)`;
                    if (pendingCount > 0) statusMsg += ` • ${pendingCount} more queued`;
                } else {
                    statusMsg = `<strong>${activeJobs.length} document(s) queued for OCR & AI extraction.</strong>`;
                }

                banner.innerHTML = `
                    <div style="display: flex; align-items: center; gap: 8px;">
                        <i class="fas ${inProgress.length > 0 ? 'fa-cog fa-spin' : 'fa-clock'}" style="color: #4F46E5;"></i>
                        <span>${statusMsg}</span>
                    </div>
                    <div style="display: flex; align-items: center; gap: 8px;">
                        <button id="btn-process-all-pending" style="background: #4F46E5; color: white; border: none; border-radius: 6px; padding: 5px 12px; font-size: 12px; font-weight: 600; cursor: pointer; display: inline-flex; align-items: center; gap: 6px;">
                            <i class="fas fa-play"></i> Process All (${activeJobs.length})
                        </button>
                    </div>
                `;

                const btnProcess = document.getElementById('btn-process-all-pending');
                if (btnProcess) {
                    btnProcess.onclick = () => this.processAllPending();
                }
            }

            if (!this.pollTimer) {
                this.pollTimer = setInterval(() => {
                    this.fetchResources(false);
                }, 3500);
            }
        } else if (failedJobs.length > 0) {
            if (banner) {
                banner.style.display = 'flex';
                banner.style.alignItems = 'center';
                banner.style.justifyContent = 'space-between';
                banner.style.flexWrap = 'wrap';
                banner.style.gap = '8px';
                banner.style.background = '#FEF2F2';
                banner.style.border = '1px solid #FECACA';
                banner.style.color = '#991B1B';

                banner.innerHTML = `
                    <div style="display: flex; align-items: center; gap: 8px;">
                        <i class="fas fa-exclamation-triangle" style="color: #DC2626;"></i>
                        <span><strong>${failedJobs.length} document(s)</strong> failed initial extraction (e.g. before OCR tools were installed on server).</span>
                    </div>
                    <div style="display: flex; align-items: center; gap: 8px;">
                        <button id="btn-process-all-pending" style="background: #DC2626; color: white; border: none; border-radius: 6px; padding: 5px 12px; font-size: 12px; font-weight: 600; cursor: pointer; display: inline-flex; align-items: center; gap: 6px;">
                            <i class="fas fa-redo"></i> Retry All Failed OCR (${failedJobs.length})
                        </button>
                    </div>
                `;

                const btnProcess = document.getElementById('btn-process-all-pending');
                if (btnProcess) {
                    btnProcess.onclick = () => this.processAllPending();
                }
            }

            if (this.pollTimer) {
                clearInterval(this.pollTimer);
                this.pollTimer = null;
            }
        } else {
            if (banner) banner.style.display = 'none';
            if (this.pollTimer) {
                clearInterval(this.pollTimer);
                this.pollTimer = null;
            }
        }
    }

    async processAllPending() {
        const btn = document.getElementById('btn-process-all-pending');
        if (btn) {
            btn.disabled = true;
            btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Triggering OCR...';
        }

        try {
            const res = await ApiClientAdmin.fetch('/resources/process-all-pending', {
                method: 'POST'
            });
            const data = await res.json().catch(() => ({}));
            if (res.ok && data.success) {
                alert(`Started background OCR processing for ${data.count} document(s)! You will see live progress update.`);
                this.fetchResources(true);
            } else {
                alert(data.error || 'Server is processing pending jobs.');
                this.fetchResources(true);
            }
        } catch (err) {
            alert('Failed to trigger pending OCR: ' + err.message);
        } finally {
            if (btn) btn.disabled = false;
        }
    }

    renderResources(resources) {
        if (!this.tableBody) return;
        this.tableBody.innerHTML = '';
        this.resourcesMap = new Map();

        if (!resources || resources.length === 0) {
            this.tableBody.innerHTML = `<tr><td colspan="6" class="loading-text" style="text-align: center; color: var(--text-secondary); padding: 24px;">No academic resources uploaded yet. Upload course lecture notes, past questions, or scanned PDFs above.</td></tr>`;
            return;
        }

        resources.forEach(res => {
            if (res.id) {
                this.resourcesMap.set(res.id, res);
            }
            const row = document.createElement('tr');
            const courseCode = res.courseCode || res.category || 'General';
            const title = res.title || res.name || res.fileName || `${courseCode} Course Material`;
            const fileUrl = res.fileUrl || res.url || '#';
            const level = res.level ? `${res.level}L` : 'All Levels';
            const dateStr = res.createdAt ? new Date(res.createdAt).toLocaleDateString() : (res.created_at ? new Date(res.created_at).toLocaleDateString() : (res.date || 'Recent'));
            const status = res.processingStatus || 'COMPLETED';
            const method = res.extractionMethod || 'DIGITAL_TEXT';
            const progress = res.processingProgress || 0;
            const hasText = !!res.hasExtractedText || status === 'COMPLETED';

            // Determine status badge
            let statusBadgeHtml = '';
            if (status === 'UPLOADING') {
                statusBadgeHtml = `<span class="badge" style="background: #EFF6FF; color: #2563EB; font-weight: 600;"><i class="fas fa-spinner fa-spin"></i> Uploading</span>`;
            } else if (status === 'PENDING') {
                statusBadgeHtml = `<span class="badge" style="background: #FEF3C7; color: #D97706; font-weight: 600;"><i class="fas fa-clock"></i> Queued for OCR</span>`;
            } else if (status === 'EXTRACTING') {
                statusBadgeHtml = `
                    <div style="display: flex; flex-direction: column; gap: 3px;">
                        <span class="badge" style="background: #EFF6FF; color: #1D4ED8; font-weight: 600;">
                            <i class="fas fa-file-invoice fa-spin"></i> Extracting (${progress}%)
                        </span>
                        <div style="width: 100%; max-width: 110px; background: #DBEAFE; height: 4px; border-radius: 2px; overflow: hidden;">
                            <div style="background: #2563EB; width: ${Math.max(10, progress)}%; height: 100%;"></div>
                        </div>
                    </div>`;
            } else if (status === 'RUNNING_OCR') {
                statusBadgeHtml = `
                    <div style="display: flex; flex-direction: column; gap: 3px;">
                        <span class="badge" style="background: #F3E8FF; color: #7E22CE; font-weight: 600;">
                            <i class="fas fa-eye fa-spin"></i> Running OCR (${progress}%)
                        </span>
                        <div style="width: 100%; max-width: 110px; background: #E9D5FF; height: 4px; border-radius: 2px; overflow: hidden;">
                            <div style="background: #9333EA; width: ${Math.max(15, progress)}%; height: 100%;"></div>
                        </div>
                    </div>`;
            } else if (status === 'COMPLETED') {
                let methodLabel = 'Digital Text';
                let methodBg = '#EFF6FF';
                let methodColor = '#2563EB';
                if (method === 'OCR') {
                    methodLabel = 'Tesseract OCR';
                    methodBg = '#F3E8FF';
                    methodColor = '#7E22CE';
                } else if (method === 'HYBRID') {
                    methodLabel = 'Hybrid OCR';
                    methodBg = '#ECFDF5';
                    methodColor = '#059669';
                }

                statusBadgeHtml = `
                    <div style="display: flex; flex-direction: column; gap: 2px;">
                        <span class="badge" style="background: #ECFDF5; color: #047857; font-weight: 600; display: inline-flex; align-items: center; gap: 4px;">
                            <i class="fas fa-check-circle"></i> AI Ready
                        </span>
                        <small style="color: var(--text-secondary); font-size: 11px;">
                            <span style="display: inline-block; padding: 1px 4px; border-radius: 4px; background: ${methodBg}; color: ${methodColor}; font-weight: 600;">
                                ${methodLabel}
                            </span>
                            ${res.totalPages ? ` • ${res.totalPages} pgs` : ''}
                        </small>
                    </div>`;
            } else if (status === 'FAILED') {
                const errMsg = res.processingError || 'Extraction failed';
                statusBadgeHtml = `
                    <div style="display: flex; flex-direction: column; gap: 2px;" title="${errMsg}">
                        <span class="badge" style="background: #FEE2E2; color: #B91C1C; font-weight: 600; display: inline-flex; align-items: center; gap: 4px;">
                            <i class="fas fa-exclamation-triangle"></i> Failed
                        </span>
                        <small style="color: #DC2626; font-size: 11px; max-width: 130px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">
                            ${errMsg}
                        </small>
                    </div>`;
            }

            row.innerHTML = `
                <td>
                    <div style="font-weight: 600; color: var(--text-primary); max-width: 280px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">${title}</div>
                    <small>
                        <a href="${fileUrl}" target="_blank" rel="noopener noreferrer" style="color: var(--color-primary-600); text-decoration: none; display: inline-flex; align-items: center; gap: 4px; margin-top: 2px;">
                            <i class="fas fa-external-link-alt"></i> Direct Link
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
                <td>
                    ${statusBadgeHtml}
                </td>
                <td style="color: var(--text-secondary); font-size: 13px;">${dateStr}</td>
                <td style="text-align: right; white-space: nowrap;">
                    <button class="btn-icon btn-view-text" title="View Extracted Text for AI" style="color: #4F46E5; background: transparent; border: none; cursor: pointer; padding: 6px 8px; font-size: 14px;" ${!hasText && status !== 'COMPLETED' ? 'disabled style="opacity: 0.4; cursor: not-allowed;"' : ''}>
                        <i class="fas fa-file-alt"></i>
                    </button>
                    <button class="btn-icon btn-preview-pdf" title="Preview Original Document" style="color: #0284C7; background: transparent; border: none; cursor: pointer; padding: 6px 8px; font-size: 14px;">
                        <i class="fas fa-eye"></i>
                    </button>
                    <button class="btn-icon btn-reprocess" title="Reprocess / Retry OCR" style="color: #D97706; background: transparent; border: none; cursor: pointer; padding: 6px 8px; font-size: 14px;">
                        <i class="fas fa-redo"></i>
                    </button>
                    <button class="btn-icon btn-delete" title="Delete Resource" style="color: #EF4444; background: transparent; border: none; cursor: pointer; padding: 6px 8px; font-size: 14px;">
                        <i class="fas fa-trash-alt"></i>
                    </button>
                </td>
            `;

            // Action: View Extracted Text
            const viewTextBtn = row.querySelector('.btn-view-text');
            if (viewTextBtn && !viewTextBtn.disabled) {
                viewTextBtn.addEventListener('click', () => {
                    this.openTextModal(res.id, title, method);
                });
            }

            // Action: Preview PDF
            const previewPdfBtn = row.querySelector('.btn-preview-pdf');
            if (previewPdfBtn) {
                previewPdfBtn.addEventListener('click', () => {
                    this.openPreviewModal(title, fileUrl);
                });
            }

            // Action: Reprocess / Retry
            const reprocessBtn = row.querySelector('.btn-reprocess');
            if (reprocessBtn) {
                reprocessBtn.addEventListener('click', () => {
                    if (confirm(`Trigger OCR reprocessing for "${title}"?`)) {
                        reprocessBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i>';
                        this.reprocessResource(res.id, title);
                    }
                });
            }

            // Action: Delete
            const deleteBtn = row.querySelector('.btn-delete');
            if (deleteBtn) {
                deleteBtn.addEventListener('click', () => {
                    if (confirm(`Are you sure you want to delete "${title}"? This will remove it from student study materials and AI context.`)) {
                        this.deleteResource(res.id, title);
                    }
                });
            }

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

                progressText.innerText = `Uploading ${files.length} file(s) to Cloudflare R2 & initiating background OCR...`;

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
                                if (regRes.ok) createdCount++;
                            } catch (_) {}
                        }
                        alert(`Successfully uploaded ${createdCount || uploadedFiles.length} resource(s) for ${courseCode}! Background OCR processing started.`);
                        e.target.reset();
                        document.getElementById('res-file-count').innerText = '';
                        this.initUploadModeToggle();
                        this.fetchResources(true);
                        return;
                    }
                }

                if (!uploadRes.ok) {
                    const errData = await uploadRes.json().catch(() => ({}));
                    throw new Error(errData.error || `Upload failed with status ${uploadRes.status}`);
                }

                const result = await uploadRes.json();
                alert(`Successfully uploaded ${result.count || files.length} resource(s) for ${courseCode}! Background OCR text extraction is running.`);
                e.target.reset();
                document.getElementById('res-file-count').innerText = '';
                this.initUploadModeToggle();
                this.fetchResources(true);
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

                progressText.innerText = "Registering resource URL and queuing OCR...";

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

                alert(`Successfully registered resource "${payload.title}"! OCR extraction initiated.`);
                e.target.reset();
                this.initUploadModeToggle();
                this.fetchResources(true);
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
                this.fetchResources(true);
                return;
            }

            // Fallback to Firestore delete
            if (typeof db !== 'undefined' && db && db.collection) {
                await db.collection('resources').doc(id).delete();
                this.fetchResources(true);
                return;
            }

            throw new Error(`Delete failed with status ${res.status}`);
        } catch (err) {
            alert("Delete failed: " + err.message);
        }
    }
}
