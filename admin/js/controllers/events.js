class EventsController {
    constructor() {
        this.tableBody = document.querySelector('#events-table tbody');
        this.events = [];
    }

    load() {
        console.log("Events Controller Connecting to Firestore...");
        this.subscribeToEvents();
    }

    subscribeToEvents() {
        if (!this.tableBody) return;
        this.tableBody.innerHTML = '<tr><td colspan="5" class="loading-text">Loading events...</td></tr>';

        // Listen to 'events' collection
        this.unsubscribe = db.collection('events').orderBy('date', 'asc').onSnapshot((snapshot) => {
            this.events = [];
            snapshot.forEach((doc) => {
                const data = doc.data();
                this.events.push({
                    id: doc.id,
                    name: data.name || 'Unnamed Event',
                    organizer: data.organizer || 'Unknown',
                    // Convert timestamp to readable date
                    date: data.date ? new Date(data.date).toLocaleDateString() : 'TBD',
                    time: data.date ? new Date(data.date).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '',
                    status: data.status || 'Pending'
                });
            });
            this.renderEvents();
        }, (error) => {
            console.error("Error fetching events:", error);
            this.tableBody.innerHTML = `<tr><td colspan="5" class="error-text">Error loading events: ${error.message}</td></tr>`;
        });
    }

    renderEvents() {
        this.tableBody.innerHTML = '';

        if (this.events.length === 0) {
            this.tableBody.innerHTML = `<tr><td colspan="5" class="loading-text">No upcoming events found.</td></tr>`;
            return;
        }

        this.events.forEach(event => {
            let statusBadge = '';
            // Determine badge style
            if (event.status === 'Approved') statusBadge = '<span class="badge" style="background: rgba(45, 212, 191, 0.15); color: #2dd4bf; border: 1px solid rgba(45, 212, 191, 0.2);">Approved</span>';
            else if (event.status === 'Pending') statusBadge = '<span class="badge" style="background: rgba(251, 191, 36, 0.15); color: #fbbf24; border: 1px solid rgba(251, 191, 36, 0.2);">Pending</span>';
            else statusBadge = '<span class="badge" style="background: rgba(244, 63, 94, 0.15); color: #f43f5e; border: 1px solid rgba(244, 63, 94, 0.2);">Rejected</span>';

            const row = document.createElement('tr');
            row.innerHTML = `
                <td><strong>${event.name}</strong></td>
                <td>${event.organizer}</td>
                <td>${event.date} <span style="color:var(--text-muted); font-size:0.8em">${event.time}</span></td>
                <td>${statusBadge}</td>
                <td style="text-align: right;">
                    <div class="action-group" style="justify-content: flex-end; display: flex; gap: 8px;">
                        <button class="btn-icon btn-approve" title="Approve" style="color: #2dd4bf; background: rgba(45, 212, 191, 0.1); border: none; padding: 6px 10px; border-radius: 4px; cursor: pointer;"><i class="fas fa-check"></i></button>
                        <button class="btn-icon btn-edit" title="Edit" style="color: #60a5fa; background: rgba(96, 165, 250, 0.1); border: none; padding: 6px 10px; border-radius: 4px; cursor: pointer;"><i class="fas fa-edit"></i></button>
                        <button class="btn-icon btn-delete" title="Reject" style="color: #f43f5e; background: rgba(244, 63, 94, 0.1); border: none; padding: 6px 10px; border-radius: 4px; cursor: pointer;"><i class="fas fa-times"></i></button>
                    </div>
                </td>
            `;

            // Attach event listeners for actions
            row.querySelector('.btn-approve').addEventListener('click', () => this.updateEventStatus(event.id, 'Approved'));
            row.querySelector('.btn-edit').addEventListener('click', () => {
                this.openEditModal(event.id);
            });

            // Delete Action
            row.querySelector('.btn-delete').addEventListener('click', () => {
                if (confirm(`Are you sure you want to delete "${event.name}"?`)) {
                    this.deleteEvent(event.id);
                }
            });

            this.tableBody.appendChild(row);
        });
    }

    openEditModal(eventId) {
        const event = this.events.find(e => e.id === eventId);
        if (!event) return;

        let modal = document.getElementById('edit-event-modal');
        if (!modal) {
            modal = document.createElement('div');
            modal.id = 'edit-event-modal';
            modal.className = 'modal-overlay';
            document.body.appendChild(modal);
        }

        modal.innerHTML = `
            <div class="modal-content glass" style="width: 500px; padding: 24px; border-radius: 16px; border: 1px solid var(--border-glass);">
                <div class="modal-header" style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">
                    <h2 style="font-size: 1.5rem; color: var(--text-primary); margin: 0;">Edit Event</h2>
                    <button class="btn-close" onclick="document.getElementById('edit-event-modal').style.display='none'" style="background: none; border: none; color: var(--text-secondary); font-size: 1.5rem; cursor: pointer;">&times;</button>
                </div>
                <form id="edit-event-form" style="display: flex; flex-direction: column; gap: 16px;">
                    <div class="form-group">
                        <label style="display: block; margin-bottom: 8px; color: var(--text-secondary); font-size: 0.9rem;">Event Title</label>
                        <input type="text" id="edit-event-title" value="${event.name}" required style="width: 100%; padding: 10px; border-radius: 8px; background: rgba(255, 255, 255, 0.05); border: 1px solid var(--border-glass); color: var(--text-primary);">
                    </div>
                    <div class="form-group">
                        <label style="display: block; margin-bottom: 8px; color: var(--text-secondary); font-size: 0.9rem;">Status</label>
                        <select id="edit-event-status" style="width: 100%; padding: 10px; border-radius: 8px; background: rgba(255, 255, 255, 0.05); border: 1px solid var(--border-glass); color: var(--text-primary);">
                            <option value="Pending" ${event.status === 'Pending' ? 'selected' : ''}>Pending</option>
                            <option value="Approved" ${event.status === 'Approved' ? 'selected' : ''}>Approved</option>
                            <option value="Rejected" ${event.status === 'Rejected' ? 'selected' : ''}>Rejected</option>
                        </select>
                    </div>
                    <button type="submit" class="btn-primary" style="margin-top: 10px; padding: 12px; border-radius: 8px; font-weight: 600; border: none; background: var(--color-primary); color: white; cursor: pointer;">Save Changes</button>
                </form>
            </div>
        `;

        modal.style.display = 'flex';

        document.getElementById('edit-event-form').onsubmit = (e) => {
            e.preventDefault();
            this.updateEvent(eventId);
        };
    }

    updateEvent(eventId) {
        const name = document.getElementById('edit-event-title').value;
        const status = document.getElementById('edit-event-status').value;

        const updatedData = {
            name, status,
            updatedAt: firebase.firestore.FieldValue.serverTimestamp()
        };

        db.collection('events').doc(eventId).update(updatedData).then(() => {
            document.getElementById('edit-event-modal').style.display = 'none';
            window.logAdminAction('UPDATE_EVENT', `Updated details for event: ${name}`, 'event', eventId);
        }).catch((error) => {
            console.error("Error updating event:", error);
            alert("Failed to update event.");
        });
    }

    updateEventStatus(eventId, status) {
        db.collection('events').doc(eventId).update({
            status: status
        }).then(() => {
            console.log(`Event ${eventId} updated to ${status}`);
            window.logAdminAction('UPDATE_EVENT', `Changed status of event ${eventId} to ${status}`, 'event', eventId);
        }).catch((error) => {
            console.error("Error updating event:", error);
            alert("Failed to update event status.");
        });
    }

    showCreateModal() {
        let modal = document.getElementById('create-event-modal');
        if (!modal) {
            modal = document.createElement('div');
            modal.id = 'create-event-modal';
            modal.className = 'modal-overlay';
            document.body.appendChild(modal);
        }

        modal.innerHTML = `
            <div class="modal-content" style="width: 500px;">
                <div class="modal-header">
                    <h2>Create Campus Event</h2>
                    <button onclick="document.getElementById('create-event-modal').style.display='none'" class="btn-close">&times;</button>
                </div>
                <form id="create-event-form" class="modal-body">
                    <div class="form-group">
                        <label>Event Name</label>
                        <input type="text" id="event-name" placeholder="e.g. Annual Tech Fest" required>
                    </div>
                    <div class="form-group">
                        <label>Organizer</label>
                        <input type="text" id="event-organizer" placeholder="e.g. Computer Science Dept" required>
                    </div>
                    <div class="form-group">
                        <label>Date & Time</label>
                        <input type="datetime-local" id="event-date" required>
                    </div>
                    <div class="form-group">
                        <label>Description</label>
                        <textarea id="event-desc" rows="3" placeholder="Tell students about this event..."></textarea>
                    </div>
                    <button type="submit" class="btn-primary" style="width: 100%; margin-top: 20px;">Create Event</button>
                </form>
            </div>
        `;

        modal.style.display = 'flex';

        document.getElementById('create-event-form').addEventListener('submit', (e) => {
            e.preventDefault();
            this.createEvent();
        });
    }

    createEvent() {
        const name = document.getElementById('event-name').value;
        const organizer = document.getElementById('event-organizer').value;
        const date = document.getElementById('event-date').value;
        const description = document.getElementById('event-desc').value;

        db.collection('events').add({
            name,
            organizer,
            date,
            description,
            status: 'Approved',
            createdAt: firebase.firestore.FieldValue.serverTimestamp()
        }).then(() => {
            document.getElementById('create-event-modal').style.display = 'none';
            window.logAdminAction('CREATE_EVENT', `Admin created new event: ${name}`, 'event');
        }).catch(err => {
            console.error(err);
            alert("Error creating event: " + err.message);
        });
    }
}

