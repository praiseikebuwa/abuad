// snap_camerakit_bridge.js
// Dedicated Web Bridge between Snap Camera Kit Web SDK and Flutter Web.

(function () {
  'use strict';

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
      this.statusListeners = [];
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

    async initSession(apiToken, lensGroupId) {
      if (this.isInitialized && this.session) {
        return { success: true, alreadyInitialized: true };
      }
      if (this.isStarting) {
        // Wait if in progress
        await new Promise(r => setTimeout(r, 500));
        if (this.isInitialized) return { success: true };
      }
      this.isStarting = true;

      try {
        if (!window.SnapCameraKit || typeof window.SnapCameraKit.bootstrapCameraKit !== 'function') {
          throw new Error('Snap Camera Kit Web SDK bundle not loaded on window.');
        }

        const token = apiToken || (window.SNAP_CAMERA_KIT_CONFIG && window.SNAP_CAMERA_KIT_CONFIG.productionToken);
        if (!token) {
          throw new Error('No Snap Camera Kit API token configured.');
        }

        this.cameraKit = await window.SnapCameraKit.bootstrapCameraKit({ apiToken: token });
        this.session = await this.cameraKit.createSession();

        const canvas = this.session.output && this.session.output.live;
        if (canvas) {
          canvas.id = 'snap-camerakit-canvas';
          canvas.style.width = '100%';
          canvas.style.height = '100%';
          canvas.style.objectFit = 'cover';
          canvas.style.position = 'absolute';
          canvas.style.top = '0';
          canvas.style.left = '0';

          const container = this.getOrCreateContainer();
          if (!container.contains(canvas)) {
            container.innerHTML = '';
            container.appendChild(canvas);
          }
        }

        // Start user camera stream
        await this.startCamera(this.currentFacingMode);

        // Load lenses from group if groupId provided
        const targetGroupId = lensGroupId || (window.SNAP_CAMERA_KIT_CONFIG && window.SNAP_CAMERA_KIT_CONFIG.lensGroupId);
        if (targetGroupId) {
          await this.loadLensGroup(targetGroupId);
        }

        this.isInitialized = true;
        this.isStarting = false;
        return { success: true, lensCount: this.activeLenses.length };
      } catch (err) {
        this.isStarting = false;
        this.isInitialized = false;
        console.error('Failed to initialize Snap Camera Kit Web SDK:', err && err.message ? err.message : err);
        return { success: false, error: err && err.message ? err.message : String(err) };
      }
    }

    async startCamera(facingMode) {
      this.currentFacingMode = facingMode || 'user';
      try {
        if (this.mediaStream) {
          this.mediaStream.getTracks().forEach(t => t.stop());
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

        this.mediaStream = await navigator.mediaDevices.getUserMedia(constraints);
        if (this.session) {
          const source = window.SnapCameraKit.createMediaStreamSource(this.mediaStream, {
            cameraType: this.currentFacingMode === 'user' ? 'front' : 'back'
          });
          await this.session.setSource(source);
          await this.session.play('live');
        }
        return { success: true };
      } catch (err) {
        console.error('Failed to start camera for Snap Camera Kit:', err);
        return { success: false, error: err && err.message ? err.message : String(err) };
      }
    }

    async switchCamera() {
      const nextFacingMode = this.currentFacingMode === 'user' ? 'environment' : 'user';
      return await this.startCamera(nextFacingMode);
    }

    async loadLensGroup(groupId) {
      if (!this.cameraKit || !this.cameraKit.lensRepository) {
        return { success: false, error: 'Camera Kit not initialized' };
      }
      try {
        const result = await this.cameraKit.lensRepository.loadLensGroups([groupId]);
        this.activeLenses = (result && result.lenses) || [];
        const mapped = this.activeLenses.map(l => ({
          id: l.id,
          name: l.name || 'Snap Lens',
          iconUrl: l.iconUrl || (l.preview && l.preview.imageUrl) || '',
          groupId: l.groupId || groupId
        }));
        return { success: true, lenses: mapped };
      } catch (err) {
        console.error('Failed to load lens group:', err);
        return { success: false, error: err && err.message ? err.message : String(err), lenses: [] };
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
      if (!this.session) {
        return { success: false, error: 'Session not initialized' };
      }
      try {
        const lens = this.activeLenses.find(l => l.id === lensId);
        if (!lens) {
          return { success: false, error: 'Lens not found in active lens group' };
        }
        await this.session.applyLens(lens);
        this.selectedLens = lens;
        return { success: true, lensId: lens.id, name: lens.name };
      } catch (err) {
        console.error('Failed to apply lens:', err);
        return { success: false, error: err && err.message ? err.message : String(err) };
      }
    }

    async removeLens() {
      if (!this.session) return { success: true };
      try {
        await this.session.removeLens();
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
          this.mediaRecorder.stop();
        }
        if (this.mediaStream) {
          this.mediaStream.getTracks().forEach(t => t.stop());
          this.mediaStream = null;
        }
        if (this.session) {
          this.session.destroy().catch(() => {});
          this.session = null;
        }
        if (this.container) {
          this.container.innerHTML = '';
        }
        this.activeLenses = [];
        this.selectedLens = null;
        this.isInitialized = false;
        this.isStarting = false;
        return { success: true };
      } catch (err) {
        return { success: false, error: String(err) };
      }
    }

    async initSessionJson(token, groupId) {
      const res = await this.initSession(token, groupId);
      return JSON.stringify(res);
    }

    async loadLensGroupJson(groupId) {
      const res = await this.loadLensGroup(groupId);
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
