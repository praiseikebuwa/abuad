class SOSController {
    constructor() {
        this.tableBody = document.querySelector('#sos-table tbody');
        this.badge = document.getElementById('sos-alert-badge');
        this.map = null;
        this.markers = {};
    }

    load() {
        if (!this.tableBody) return;
        this.tableBody.innerHTML = '<tr><td colspan="5" class="loading-text">Monitoring alerts...</td></tr>';

        if (this.unsubscribe) this.unsubscribe();

        // Listen for active SOS alerts
        this.unsubscribe = db.collection('sos_alerts')
            .orderBy('timestamp', 'desc')
            .limit(20)
            .onSnapshot(snap => {
                this.render(snap);
                this.updateBadge(snap);
            }, err => {
                console.error("SOS Error:", err);
                this.tableBody.innerHTML = `<tr><td colspan="5" class="error-text">Connection lost: ${err.message}</td></tr>`;
            });

        if (!this.map) this.initMap();
    }

    initMap() {
        const mapEl = document.getElementById('sos-map');
        if (!mapEl) return;
        
        this.map = L.map('sos-map').setView([7.60250, 5.30610], 15);
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png').addTo(this.map);
    }

    render(snap) {
        this.tableBody.innerHTML = '';
        if (snap.empty) {
            this.tableBody.innerHTML = '<tr><td colspan="5">No active SOS alerts. Campus is secure.</td></tr>';
            return;
        }

        snap.forEach(doc => {
            const alert = doc.data();
            const tr = document.createElement('tr');
            const isActive = alert.status !== 'resolved';

            tr.innerHTML = `
                <td>
                    <span class="status-badge ${isActive ? 'banned' : 'online'}">
                        ${isActive ? 'CRITICAL' : 'RESOLVED'}
                    </span>
                </td>
                <td>
                    <b>${alert.userName || 'Unknown Student'}</b><br>
                    <small class="text-muted">${alert.userId.substring(0,8)}...</small>
                </td>
                <td>
                    <small>Lat: ${alert.latitude.toFixed(4)}</small><br>
                    <small>Lng: ${alert.longitude.toFixed(4)}</small>
                </td>
                <td>${this.formatTime(alert.timestamp)}</td>
                <td style="text-align: right;">
                    <div class="action-buttons">
                        <button class="btn-icon btn-approve" onclick="window.sosController.resolve('${doc.id}')" title="Mark Resolved">
                            <i class="fas fa-check"></i>
                        </button>
                        <button class="btn-icon btn-view" onclick="window.sosController.focusMap(${alert.latitude}, ${alert.longitude})" title="Locate on Map">
                            <i class="fas fa-location-arrow"></i>
                        </button>
                    </div>
                </td>
            `;

            if (isActive) {
                tr.style.background = 'rgba(244, 63, 94, 0.05)';
                this.addMarker(doc.id, alert);
            }
            this.tableBody.appendChild(tr);
        });
    }

    updateBadge(snap) {
        const activeCount = snap.docs.filter(d => d.data().status !== 'resolved').length;
        if (this.badge) {
            if (activeCount > 0) {
                this.badge.classList.remove('hidden');
                this.badge.innerText = `${activeCount} Active Alerts`;
            } else {
                this.badge.classList.add('hidden');
            }
        }
    }

    addMarker(id, alert) {
        if (!this.map) return;
        if (this.markers[id]) {
            this.markers[id].setLatLng([alert.latitude, alert.longitude]);
        } else {
            const marker = L.circleMarker([alert.latitude, alert.longitude], {
                radius: 10,
                color: '#f43f5e',
                fillOpacity: 0.8
            }).addTo(this.map).bindPopup(`<b>${alert.userName}</b><br>SOS ALERT`);
            this.markers[id] = marker;
            this.map.panTo([alert.latitude, alert.longitude]);
        }
    }

    focusMap(lat, lng) {
        if (this.map) this.map.setView([lat, lng], 18);
    }

    async resolve(id) {
        if (!confirm("Confirm this emergency has been handled?")) return;
        await db.collection('sos_alerts').doc(id).update({ status: 'resolved' });
        window.logAdminAction('RESOLVE_SOS', `SOS alert ${id} resolved`, 'sos', id);
    }

    formatTime(ts) {
        if (!ts) return 'Unknown';
        const d = ts.toDate ? ts.toDate() : new Date(ts);
        return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }
}
