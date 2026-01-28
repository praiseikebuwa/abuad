const eventsController = {
    init: function () {
        console.log("Events Controller Connecting to Firestore...");
        this.subscribeToEvents();
    },

    subscribeToEvents: function () {
        const tableBody = document.querySelector('#events-table tbody');
        if (!tableBody) return;

        // Listen to 'events' collection
        db.collection('events').orderBy('date', 'asc').onSnapshot((snapshot) => {
            const events = [];
            snapshot.forEach((doc) => {
                const data = doc.data();
                events.push({
                    id: doc.id,
                    name: data.name || 'Unnamed Event',
                    organizer: data.organizer || 'Unknown',
                    // Convert timestamp to readable date
                    date: data.date ? new Date(data.date).toLocaleDateString() : 'TBD',
                    time: data.date ? new Date(data.date).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '',
                    status: data.status || 'Pending'
                });
            });
            this.renderEvents(events);
        }, (error) => {
            console.error("Error fetching events:", error);
            tableBody.innerHTML = `<tr><td colspan="5" class="error-text">Error loading events: ${error.message}</td></tr>`;
        });
    },

    renderEvents: function (events) {
        const tableBody = document.querySelector('#events-table tbody');
        tableBody.innerHTML = '';

        if (events.length === 0) {
            tableBody.innerHTML = `<tr><td colspan="5" class="loading-text">No upcoming events found.</td></tr>`;
            return;
        }

        events.forEach(event => {
            let statusBadge = '';
            // Determine badge style
            if (event.status === 'Approved') statusBadge = '<span class="badge" style="background: #e8f5e9; color: #2e7d32;">Approved</span>';
            else if (event.status === 'Pending') statusBadge = '<span class="badge" style="background: #fff3e0; color: #ef6c00;">Pending</span>';
            else statusBadge = '<span class="badge" style="background: #ffebee; color: #c62828;">Rejected</span>';

            const row = document.createElement('tr');
            row.innerHTML = `
                <td><strong>${event.name}</strong></td>
                <td>${event.organizer}</td>
                <td>${event.date} <span style="color:#888; font-size:0.8em">${event.time}</span></td>
                <td>${statusBadge}</td>
                <td style="text-align: right;">
                    <div class="action-group" style="justify-content: flex-end;">
                        <button class="btn-icon btn-approve" title="Approve"><i class="fas fa-check"></i></button>
                        <button class="btn-icon btn-delete" title="Reject"><i class="fas fa-times"></i></button>
                    </div>
                </td>
            `;

            // Attach event listeners for actions
            const approveBtn = row.querySelector('.btn-approve');
            const rejectBtn = row.querySelector('.btn-delete');

            approveBtn.addEventListener('click', () => this.updateEventStatus(event.id, 'Approved'));
            rejectBtn.addEventListener('click', () => this.updateEventStatus(event.id, 'Rejected'));

            tableBody.appendChild(row);
        });
    },

    updateEventStatus: function (eventId, status) {
        db.collection('events').doc(eventId).update({
            status: status
        }).then(() => {
            // Toast or console log not needed as UI updates via snapshot
            console.log(`Event ${eventId} updated to ${status}`);
        }).catch((error) => {
            console.error("Error updating event:", error);
            alert("Failed to update event status.");
        });
    }
};

document.addEventListener('DOMContentLoaded', () => {
    // Basic check to prevent multiple inits if scripts reused
    if (!window.eventsControllerInitialized) {
        eventsController.init();
        window.eventsControllerInitialized = true;
    }
});
