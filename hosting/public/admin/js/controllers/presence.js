class PresenceController {
    constructor() {
        this.grid = document.getElementById('live-users-grid');
        this.onlineCountEl = document.getElementById('stat-online-users');
        this.map = null;
        this.markers = {};
    }

    load() {
        if (!this.grid) return;
        this.grid.innerHTML = '<div class="loading-spinner"></div>';

        // Initialize Map if not already done
        if (!this.map) {
            this.initMap();
        }

        // Listen for online/active users (last seen in 1 hour)
        const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000); // Client-side approx or Firestore Timestamp

        // Note: To use Timestamp in query, we need Firebase Timestamp object. 
        // For simplicity in this script, we'll fetch 'online' users OR users with location.
        // A composite query might be needed: status == 'online'

        db.collection('users')
            .where('status', '==', 'online')
            .onSnapshot(snap => {
                this.render(snap);
                if (this.onlineCountEl) {
                    this.onlineCountEl.innerText = snap.size;
                }
            }, err => {
                console.error("Presence Error:", err);
                this.grid.innerHTML = `<div class="error-text">Failed to load live tracking: ${err.message}</div>`;
            });
    }

    initMap() {
        // Create map container if it doesn't exist
        if (!document.getElementById('map-container')) {
            const mapContainer = document.createElement('div');
            mapContainer.id = 'map-container';
            mapContainer.style.height = '400px';
            mapContainer.style.borderRadius = '16px';
            mapContainer.style.marginBottom = '20px';
            mapContainer.style.zIndex = '0';
            this.grid.parentElement.insertBefore(mapContainer, this.grid);

            this.map = L.map('map-container').setView([7.60250, 5.30610], 16); // ABUAD Coordinates (Real)

            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                attribution: '&copy; OpenStreetMap contributors'
            }).addTo(this.map);

            // Add Campus Circle/Marker for reference
            L.circle([7.60250, 5.30610], {
                color: 'blue',
                fillColor: '#30f',
                fillOpacity: 0.1,
                radius: 500
            }).addTo(this.map).bindPopup("ABUAD Campus");
        }
    }

    render(snap) {
        this.grid.innerHTML = '';
        const currentIds = [];

        if (snap.empty) {
            this.grid.innerHTML = '<div class="no-data">No users currently online.</div>';
            // Clear markers
            Object.keys(this.markers).forEach(id => {
                this.map.removeLayer(this.markers[id]);
                delete this.markers[id];
            });
            return;
        }

        snap.forEach(doc => {
            const user = doc.data();
            currentIds.push(doc.id);

            // 1. Render Card
            const card = document.createElement('div');
            card.className = 'live-user-card';

            const initial = user.displayName ? user.displayName[0].toUpperCase() : '?';
            const color = this.seededColor(user.displayName);

            card.innerHTML = `
                <div class="card-glow"></div>
                <div class="user-avatar-large" style="background: ${color}">
                    ${user.avatar_url ? `<img src="${user.avatar_url}" alt="${user.displayName}">` : initial}
                    <div class="online-indicator-ping"></div>
                </div>
                <div class="user-info">
                    <div class="user-name">${user.display_name || 'Anonymous'}</div>
                    <div class="user-handle">@${user.handle || 'user'}</div>
                    <div class="user-meta">
                        ${user.college || 'ABUAD'} 
                        ${user.latitude ? '<br><i class="fas fa-map-marker-alt"></i> Location Active' : ''}
                    </div>
                </div>
            `;
            this.grid.appendChild(card);

            // 2. Update Map Marker
            if (this.map && user.latitude && user.longitude) {
                if (this.markers[doc.id]) {
                    // Update position
                    this.markers[doc.id].setLatLng([user.latitude, user.longitude]);
                    this.markers[doc.id].setPopupContent(`<b>${user.display_name}</b><br>${user.email}`);
                } else {
                    // Create new marker
                    const marker = L.marker([user.latitude, user.longitude])
                        .addTo(this.map)
                        .bindPopup(`<b>${user.display_name}</b><br>${user.email}`);
                    this.markers[doc.id] = marker;
                }
            }
        });

        // Remove old markers
        Object.keys(this.markers).forEach(id => {
            if (!currentIds.includes(id)) {
                this.map.removeLayer(this.markers[id]);
                delete this.markers[id];
            }
        });
    }

    seededColor(name) {
        if (!name) return '#9e9e9e';
        const colors = ['#1976d2', '#388e3c', '#d32f2f', '#7b1fa2', '#f57c00', '#0097a7'];
        let hash = 0;
        for (let i = 0; i < name.length; i++) {
            hash = name.charCodeAt(i) + ((hash << 5) - hash);
        }
        return colors[Math.abs(hash) % colors.length];
    }
}
