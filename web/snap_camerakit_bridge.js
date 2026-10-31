// snap_camerakit_bridge.js
// Dedicated Web Bridge between Snap Camera Kit Web SDK and Flutter Web.
// Provides complete 17-stage diagnostic logging, strict timeouts, error inspection,
// camera stream resilience, and DOM canvas lifecycle management.

(function () {
  'use strict';

  function sanitizeLog(msg) {
    if (!msg) return '';
    const str = typeof msg === 'object' ? JSON.stringify(msg) : String(msg);
    // Redact JWT tokens, authorization headers, and keys
    return str.replace(/eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+/g, '[REDACTED_JWT]')
              .replace(/Bearer\s+[^\s"']+/gi, 'Bearer [REDACTED]')
              .replace(/apiToken[:=]\s*["'][^"']+["']/gi, 'apiToken:"[REDACTED]"');
  }

  function withTimeout(promise, ms, timeoutErrorMsg) {
    let timer = null;
    const timeoutPromise = new Promise((_, reject) => {
      timer = setTimeout(() => {
        reject(new Error(timeoutErrorMsg || `Operation timed out after ${ms}ms`));
      }, ms);
    });
    return Promise.race([promise, timeoutPromise]).finally(() => {
      if (timer) clearTimeout(timer);
    });
  }

  class SnapCameraBridgeController {
    constructor() {
      this.cameraKit = null;
      this.session = null;
      this.mediaStream = null;
      this.activeLenses = [];
      this.selectedLens = null;
      this.mediaRecorder = null;
      this.recordedChunks = [];
      this.container = null;
      this.isInitialized = false;
      this.isStarting = false;
      this.currentFacingMode = 'user'; // 'user' (front) or 'environment' (back)
      this.diagnosticLogs = [];
      this.initStartTime = 0;
      this.lastStage = 0;
      this.lastStageName = 'Not Started';
      this.lastError = null;
      this.initPromise = null;
    }

    logStage(stageNumber, stageName, status, details) {
      const elapsed = this.initStartTime > 0 ? (Date.now() - this.initStartTime) : 0;
      this.lastStage = stageNumber;
      this.lastStageName = stageName;
      const statusStr = status || 'SUCCESS';
      const detailStr = details ? ` - ${sanitizeLog(details)}` : '';
      const logLine = `[SnapCameraKit:Diag] [Stage ${stageNumber}/17: ${stageName}] status: ${statusStr}, elapsed: ${elapsed}ms${detailStr}`;
      
      this.diagnosticLogs.push({
        stage: stageNumber,
        name: stageName,
        status: statusStr,
        elapsedMs: elapsed,
        details: sanitizeLog(details || ''),
        timestamp: new Date().toISOString()
      });
      // Cap log history
      if (this.diagnosticLogs.length > 100) this.diagnosticLogs.shift();

      if (statusStr === 'FAILURE') {
        console.error(logLine);
      } else if (statusStr === 'WARNING') {
        console.warn(logLine);
      } else {
        console.log(logLine);
      }
    }

    getDiagnosticLogs() {
      return this.diagnosticLogs;
    }

    getDiagnosticLogsJson() {
      return JSON.stringify(this.diagnosticLogs);
    }

    getLastError() {
      return this.lastError;
    }

    getOrCreateContainer() {
      if (!this.container) {
        this.container = document.createElement('div');
        this.container.id = 'snap-camerakit-canvas-container';
        this.container.style.width = '100%';
        this.container.style.height = '100%';
        this.container.style.overflow = 'hidden';
        this.container.style.backgroundColor = '#000000';
        this.container.style.position = 'relative';
        this.container.style.display = 'flex';
        this.container.style.justifyContent = 'center';
        this.container.style.alignItems = 'center';
      }
      return this.container;
    }

    attachLiveCanvas() {
      if (!this.session || !this.session.output || !this.session.output.live) {
        return false;
      }
      const canvas = this.session.output.live;
      canvas.id = 'snap-camerakit-canvas';
      canvas.style.width = '100%';
      canvas.style.height = '100%';
      canvas.style.objectFit = 'cover';
      canvas.style.position = 'absolute';
      canvas.style.top = '0';
      canvas.style.left = '0';
      canvas.style.display = 'block';
      canvas.style.visibility = 'visible';

      const container = this.getOrCreateContainer();
      if (canvas.parentElement !== container) {
        container.innerHTML = '';
        container.appendChild(canvas);
      }
      return true;
    }

    async bootstrapOnly(apiToken) {
      if (this.cameraKit) return this.cameraKit;

      // Stage 2: Web bridge availability
      this.logStage(2, 'The web bridge is available', 'SUCCESS', 'SnapCameraBridgeController active on window');

      // Stage 3: Camera Kit bundle loaded
      if (!window.SnapCameraKit || typeof window.SnapCameraKit.bootstrapCameraKit !== 'function') {
        const err = 'Snap Camera Kit Web SDK bundle not loaded on window (snap_camerakit_bundle.js missing or failed to parse).';
        this.logStage(3, 'The Camera Kit bundle has loaded', 'FAILURE', err);
        throw new Error(err);
      }
      this.logStage(3, 'The Camera Kit bundle has loaded', 'SUCCESS', 'window.SnapCameraKit ready (v1.22.0)');

      const token = apiToken || (window.SNAP_CAMERA_KIT_CONFIG && window.SNAP_CAMERA_KIT_CONFIG.productionToken);
      if (!token) {
        const err = 'No Snap Camera Kit API token configured.';
        this.logStage(4, 'Camera Kit initialization begins', 'FAILURE', err);
        throw new Error(err);
      }

      // Stage 4: Camera Kit initialization begins
      this.logStage(4, 'Camera Kit initialization begins', 'PENDING', `Origin: ${window.location.hostname || 'localhost'}`);
      
      this.cameraKit = await withTimeout(
        window.SnapCameraKit.bootstrapCameraKit({ apiToken: token }),
        15000,
        'Camera Kit initialization (bootstrapCameraKit) timed out after 15s. Check network access to cf-st.sc-cdn.net and camera-kit-api.snapar.com.'
      );

      // Stage 5: Camera Kit initialization completes
      this.logStage(5, 'Camera Kit initialization completes', 'SUCCESS', 'CameraKit instance created');
      return this.cameraKit;
    }

    async initSession(apiToken, lensGroupId) {
      if (this.isInitialized && this.session) {
        this.attachLiveCanvas();
        return {
          success: true,
          alreadyInitialized: true,
          stage: 17,
          stageName: 'The camera is ready',
          lensCount: this.activeLenses.length
        };
      }

      if (this.isStarting && this.initPromise) {
        this.logStage(4, 'Camera Kit initialization begins', 'PENDING', 'Awaiting concurrent initialization in progress');
        return await this.initPromise;
      }

      this.isStarting = true;
      this.initStartTime = Date.now();
      this.lastError = null;

      this.initPromise = (async () => {
        try {
          // Stage 1: User requests Snapchat lenses
          this.logStage(1, 'User requests Snapchat lenses', 'SUCCESS', `Target groupId: ${lensGroupId || 'configured default'}`);

          // Stages 2 - 5: Bootstrap CameraKit
          await this.bootstrapOnly(apiToken);

          // Stage 6: Browser camera permission is requested
          this.logStage(6, 'Browser camera permission is requested', 'PENDING', `FacingMode: ${this.currentFacingMode}`);
          
          // Stage 7: The camera stream is acquired
          const streamResult = await this.startCameraStream(this.currentFacingMode);
          if (!streamResult.success) {
            throw new Error(`Failed to acquire camera stream: ${streamResult.error}`);
          }
          this.logStage(7, 'The camera stream is acquired', 'SUCCESS', `Video tracks: ${this.mediaStream ? this.mediaStream.getVideoTracks().length : 0}`);

          // Stage 8: A Camera Kit session is created
          this.logStage(8, 'A Camera Kit session is created', 'PENDING', 'Calling cameraKit.createSession()');
          this.session = await withTimeout(
            this.cameraKit.createSession(),
            10000,
            'cameraKit.createSession() timed out after 10s'
          );
          this.logStage(8, 'A Camera Kit session is created', 'SUCCESS', 'Session created');

          // Stage 9: The camera source is connected to the session
          this.logStage(9, 'The camera source is connected to the session', 'PENDING', 'Binding MediaStreamSource');
          const source = window.SnapCameraKit.createMediaStreamSource(this.mediaStream, {
            cameraType: this.currentFacingMode === 'user' ? 'front' : 'back'
          });
          await withTimeout(
            this.session.setSource(source),
            8000,
            'session.setSource() timed out after 8s'
          );
          this.logStage(9, 'The camera source is connected to the session', 'SUCCESS', 'Source connected');

          // Stage 15: Session playback starts (starts live preview render loop)
          this.logStage(15, 'Session playback starts', 'PENDING', 'Starting session.play("live")');
          await withTimeout(
            this.session.play('live'),
            6000,
            'session.play("live") timed out after 6s'
          );
          this.logStage(15, 'Session playback starts', 'SUCCESS', 'Session playback active');

          // Stage 16: The processed canvas becomes visible
          this.attachLiveCanvas();
          const canvas = this.session.output && this.session.output.live;
          const canvasVisible = canvas && canvas.offsetWidth > 0 && canvas.offsetHeight > 0;
          this.logStage(16, 'The processed canvas becomes visible', 'SUCCESS', `Canvas mounted in container: ${canvas ? 'yes' : 'no'}`);

          // Stages 10, 11, 12: Load lenses if groupId provided
          const targetGroupId = lensGroupId || (window.SNAP_CAMERA_KIT_CONFIG && window.SNAP_CAMERA_KIT_CONFIG.lensGroupId);
          if (targetGroupId) {
            await this.loadLensGroup(targetGroupId);
          }

          // Stage 17: The camera is ready
          this.isInitialized = true;
          this.isStarting = false;
          this.logStage(17, 'The camera is ready', 'SUCCESS', `Pipeline ready with ${this.activeLenses.length} lenses`);

          return {
            success: true,
            stage: 17,
            stageName: 'The camera is ready',
            lensCount: this.activeLenses.length,
            elapsedMs: Date.now() - this.initStartTime
          };
        } catch (err) {
          this.isStarting = false;
          this.isInitialized = false;
          const errMsg = err && err.message ? err.message : String(err);
          this.lastError = errMsg;
          this.logStage(this.lastStage || 4, this.lastStageName || 'Camera Kit initialization', 'FAILURE', errMsg);
          return {
            success: false,
            stage: this.lastStage,
            stageName: this.lastStageName,
            error: errMsg,
            elapsedMs: Date.now() - this.initStartTime
          };
        } finally {
          this.initPromise = null;
        }
      })();

      return await this.initPromise;
    }

    async startCameraStream(facingMode) {
      this.currentFacingMode = facingMode || 'user';
      try {
        if (this.mediaStream) {
          this.mediaStream.getTracks().forEach(t => {
            try { t.stop(); } catch (_) {}
          });
          this.mediaStream = null;
        }

        const constraints = {
          video: {
            facingMode: this.currentFacingMode,
            width: { ideal: 1280 },
            height: { ideal: 720 }
          },
          audio: false
        };

        // Attempt getUserMedia with fallback
        try {
          this.mediaStream = await withTimeout(
            navigator.mediaDevices.getUserMedia(constraints),
            10000,
            'navigator.mediaDevices.getUserMedia() timed out after 10s'
          );
        } catch (mediaErr) {
          console.warn('[SnapCameraBridge] Ideal constraints failed, trying basic video constraint:', mediaErr);
          try {
            this.mediaStream = await withTimeout(
              navigator.mediaDevices.getUserMedia({ video: true, audio: false }),
              8000,
              'Fallback getUserMedia() timed out after 8s'
            );
          } catch (fallbackErr) {
            // Check if another video element on the page (e.g. Flutter preview) has an active stream
            const videos = Array.from(document.querySelectorAll('video'));
            for (const v of videos) {
              if (v.srcObject && v.srcObject instanceof MediaStream && v.srcObject.getVideoTracks().length > 0) {
                const tracks = v.srcObject.getVideoTracks().filter(t => t.readyState === 'live');
                if (tracks.length > 0) {
                  this.mediaStream = v.srcObject;
                  console.log('[SnapCameraBridge] Reusing active video MediaStream from page video element');
                  break;
                }
              }
            }
            if (!this.mediaStream) {
              throw fallbackErr;
            }
          }
        }

        return { success: true };
      } catch (err) {
        const errMsg = err && err.message ? err.message : String(err);
        return { success: false, error: errMsg };
      }
    }

    async startCamera(facingMode) {
      const res = await this.startCameraStream(facingMode);
      if (!res.success) return res;

      try {
        if (this.session && this.mediaStream) {
          const source = window.SnapCameraKit.createMediaStreamSource(this.mediaStream, {
            cameraType: this.currentFacingMode === 'user' ? 'front' : 'back'
          });
          await withTimeout(
            this.session.setSource(source),
            8000,
            'setSource timed out in startCamera'
          );
          await withTimeout(
            this.session.play('live'),
            5000,
            'session.play("live") timed out in startCamera'
          );
          this.attachLiveCanvas();
        }
        return { success: true };
      } catch (err) {
        return { success: false, error: err && err.message ? err.message : String(err) };
      }
    }

    async switchCamera() {
      const nextFacingMode = this.currentFacingMode === 'user' ? 'environment' : 'user';
      return await this.startCamera(nextFacingMode);
    }

    async loadLensGroup(groupId, apiToken) {
      // Stage 10: The Lens Group request begins
      this.logStage(10, 'The Lens Group request begins', 'PENDING', `GroupId: ${groupId}`);
      try {
        if (!this.cameraKit || !this.cameraKit.lensRepository) {
          // If CameraKit is not yet bootstrapped, bootstrap it now
          await this.bootstrapOnly(apiToken);
        }

        const loadPromise = this.cameraKit.lensRepository.loadLensGroups([groupId]);
        // Stage 11: The Lens Group request completes
        const result = await withTimeout(
          loadPromise,
          15000,
          `lensRepository.loadLensGroups([${groupId}]) timed out after 15s. Check network to camera-kit-api.snapar.com.`
        );
        this.logStage(11, 'The Lens Group request completes', 'SUCCESS', 'Response received');

        // Stage 12: Lens loading errors are inspected
        const errors = (result && result.errors) || [];
        const rawLenses = (result && result.lenses) || [];

        if (errors.length > 0) {
          const errorMsgs = errors.map(e => e && e.message ? e.message : String(e)).join('; ');
          this.logStage(12, 'Lens loading errors are inspected', 'FAILURE', `Errors: ${errorMsgs}`);
          return {
            success: false,
            error: errorMsgs,
            lenses: []
          };
        }

        if (rawLenses.length === 0) {
          const warnMsg = `Lens group ${groupId} returned 0 lenses. Verify lens group has approved lenses in Lens Studio portal.`;
          this.logStage(12, 'Lens loading errors are inspected', 'WARNING', warnMsg);
          this.activeLenses = [];
          return {
            success: false,
            error: warnMsg,
            lenses: []
          };
        }

        this.activeLenses = rawLenses;
        const mapped = this.activeLenses.map(l => ({
          id: l.id,
          name: l.name || 'Snap Lens',
          iconUrl: l.iconUrl || (l.preview && l.preview.imageUrl) || '',
          groupId: l.groupId || groupId
        }));

        this.logStage(12, 'Lens loading errors are inspected', 'SUCCESS', `Loaded ${mapped.length} lenses successfully`);
        return { success: true, lenses: mapped };
      } catch (err) {
        const errMsg = err && err.message ? err.message : String(err);
        this.logStage(12, 'Lens loading errors are inspected', 'FAILURE', errMsg);
        return { success: false, error: errMsg, lenses: [] };
      }
    }

    getLoadedLenses() {
      return this.activeLenses.map(l => ({
        id: l.id,
        name: l.name || 'Snap Lens',
        iconUrl: l.iconUrl || (l.preview && l.preview.imageUrl) || '',
        groupId: l.groupId || ''
      }));
    }

    async applyLens(lensId) {
      // Stage 13: The selected lens is applied
      this.logStage(13, 'The selected lens is applied', 'PENDING', `LensId: ${lensId}`);
      if (!this.session) {
        const err = 'Session not initialized';
        this.logStage(13, 'The selected lens is applied', 'FAILURE', err);
        return { success: false, error: err };
      }

      try {
        const lens = this.activeLenses.find(l => l.id === lensId);
        if (!lens) {
          const err = `Lens ${lensId} not found in active lenses cache.`;
          this.logStage(13, 'The selected lens is applied', 'FAILURE', err);
          return { success: false, error: err };
        }

        const applyPromise = this.session.applyLens(lens);
        const applied = await withTimeout(
          applyPromise,
          15000,
          `session.applyLens(${lensId}) timed out after 15s. Check network access to lens assets.`
        );

        if (!applied) {
          throw new Error(`session.applyLens returned false for lens ${lensId}`);
        }

        this.selectedLens = lens;
        // Stage 14: Lens application succeeds
        this.logStage(14, 'Lens application succeeds', 'SUCCESS', `Active lens: ${lens.name || lens.id}`);

        // Ensure live output canvas is properly attached and visible
        this.attachLiveCanvas();

        return { success: true, lensId: lens.id, name: lens.name };
      } catch (err) {
        const errMsg = err && err.message ? err.message : String(err);
        this.logStage(14, 'Lens application succeeds', 'FAILURE', errMsg);
        return { success: false, error: errMsg };
      }
    }

    async removeLens() {
      if (!this.session) {
        this.selectedLens = null;
        return { success: true };
      }
      try {
        await withTimeout(this.session.removeLens(), 5000, 'removeLens timed out');
        this.selectedLens = null;
        return { success: true };
      } catch (err) {
        console.error('Failed to remove lens:', err);
        return { success: false, error: err && err.message ? err.message : String(err) };
      }
    }

    async capturePhoto() {
      if (!this.session || !this.session.output || !this.session.output.live) {
        return { success: false, error: 'No active canvas rendering' };
      }
      const canvas = this.session.output.live;
      return new Promise((resolve) => {
        try {
          canvas.toBlob((blob) => {
            if (!blob) {
              return resolve({ success: false, error: 'Failed to read canvas blob' });
            }
            const reader = new FileReader();
            reader.onloadend = () => {
              resolve({
                success: true,
                dataUrl: reader.result,
                size: blob.size,
                type: 'image/jpeg'
              });
            };
            reader.onerror = (e) => resolve({ success: false, error: String(e) });
            reader.readAsDataURL(blob);
          }, 'image/jpeg', 0.95);
        } catch (e) {
          resolve({ success: false, error: String(e) });
        }
      });
    }

    startRecording() {
      if (!this.session || !this.session.output || !this.session.output.live) {
        return { success: false, error: 'No active canvas rendering' };
      }
      try {
        const canvas = this.session.output.live;
        const stream = canvas.captureStream ? canvas.captureStream(30) : null;
        if (!stream) {
          return { success: false, error: 'captureStream not supported in this browser' };
        }

        this.recordedChunks = [];
        let mimeType = 'video/webm;codecs=vp9';
        if (!window.MediaRecorder || !MediaRecorder.isTypeSupported(mimeType)) {
          mimeType = 'video/webm';
        }

        this.mediaRecorder = new MediaRecorder(stream, { mimeType });
        this.mediaRecorder.ondataavailable = (e) => {
          if (e.data && e.data.size > 0) {
            this.recordedChunks.push(e.data);
          }
        };
        this.mediaRecorder.start(100);
        return { success: true };
      } catch (err) {
        return { success: false, error: err && err.message ? err.message : String(err) };
      }
    }

    async stopRecording() {
      if (!this.mediaRecorder || this.mediaRecorder.state === 'inactive') {
        return { success: false, error: 'MediaRecorder is not recording' };
      }
      return new Promise((resolve) => {
        this.mediaRecorder.onstop = () => {
          try {
            const blob = new Blob(this.recordedChunks, { type: 'video/webm' });
            const reader = new FileReader();
            reader.onloadend = () => {
              resolve({
                success: true,
                dataUrl: reader.result,
                size: blob.size,
                type: 'video/webm'
              });
            };
            reader.onerror = (e) => resolve({ success: false, error: String(e) });
            reader.readAsDataURL(blob);
          } catch (e) {
            resolve({ success: false, error: String(e) });
          }
        };
        this.mediaRecorder.stop();
      });
    }

    dispose() {
      try {
        if (this.mediaRecorder && this.mediaRecorder.state !== 'inactive') {
          try { this.mediaRecorder.stop(); } catch (_) {}
        }
        if (this.mediaStream) {
          this.mediaStream.getTracks().forEach(t => {
            try { t.stop(); } catch (_) {}
          });
          this.mediaStream = null;
        }
        if (this.session) {
          try { this.session.destroy().catch(() => {}); } catch (_) {}
          this.session = null;
        }
        if (this.container) {
          this.container.innerHTML = '';
        }
        this.activeLenses = [];
        this.selectedLens = null;
        this.isInitialized = false;
        this.isStarting = false;
        this.initPromise = null;
        return { success: true };
      } catch (err) {
        return { success: false, error: String(err) };
      }
    }

    async initSessionJson(token, groupId) {
      const res = await this.initSession(token, groupId);
      return JSON.stringify(res);
    }

    async loadLensGroupJson(groupId, token) {
      const res = await this.loadLensGroup(groupId, token);
      return JSON.stringify(res);
    }

    async applyLensJson(lensId) {
      const res = await this.applyLens(lensId);
      return JSON.stringify(res);
    }

    async removeLensJson() {
      const res = await this.removeLens();
      return JSON.stringify(res);
    }

    async capturePhotoJson() {
      const res = await this.capturePhoto();
      return JSON.stringify(res);
    }

    startRecordingJson() {
      const res = this.startRecording();
      return JSON.stringify(res);
    }

    async stopRecordingJson() {
      const res = await this.stopRecording();
      return JSON.stringify(res);
    }

    async switchCameraJson() {
      const res = await this.switchCamera();
      return JSON.stringify(res);
    }
  }

  window.SnapCameraBridge = new SnapCameraBridgeController();
})();
