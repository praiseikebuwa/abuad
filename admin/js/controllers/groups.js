const groupsController = {
    init: function () {
        console.log("Groups Controller Connecting to Firestore...");
        this.subscribeToGroups();
    },

    subscribeToGroups: function () {
        const tableBody = document.querySelector('#groups-table tbody');
        if (!tableBody) return;

        // Listen to 'groups' collection
        db.collection('groups').orderBy('memberCount', 'desc').limit(50).onSnapshot((snapshot) => {
            const groups = [];
            snapshot.forEach((doc) => {
                const data = doc.data();
                groups.push({
                    id: doc.id,
                    name: data.name || 'Unnamed Group',
                    members: data.memberCount || 0,
                    category: data.category || 'General',
                    created: data.createdAt ? new Date(data.createdAt).toLocaleDateString() : 'N/A'
                });
            });
            this.renderGroups(groups);
        }, (error) => {
            console.error("Error fetching groups:", error);
            tableBody.innerHTML = `<tr><td colspan="5" class="error-text">Error loading groups: ${error.message}</td></tr>`;
        });
    },

    renderGroups: function (groups) {
        const tableBody = document.querySelector('#groups-table tbody');
        tableBody.innerHTML = '';

        if (groups.length === 0) {
            tableBody.innerHTML = `<tr><td colspan="5" class="loading-text">No groups found.</td></tr>`;
            return;
        }

        groups.forEach(group => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td>
                    <div class="user-cell">
                        <div class="avatar-initial" style="background: var(--color-primary-100); color: var(--color-primary-700);">${group.name.charAt(0).toUpperCase()}</div>
                        <div class="user-details">
                            <span class="user-name">${group.name}</span>
                        </div>
                    </div>
                </td>
                <td>${group.members} members</td>
                <td><span class="badge" style="background: var(--color-neutral-200); color: var(--text-secondary);">${group.category}</span></td>
                <td>${group.created}</td>
                <td style="text-align: right;">
                    <button class="btn-icon btn-delete" title="Delete Group"><i class="fas fa-trash"></i></button>
                </td>
            `;

            // Delete Action
            const deleteBtn = row.querySelector('.btn-delete');
            deleteBtn.addEventListener('click', () => {
                if (confirm(`Are you sure you want to delete "${group.name}"? This cannot be undone.`)) {
                    this.deleteGroup(group.id);
                }
            });

            tableBody.appendChild(row);
        });
    },

    deleteGroup: function (groupId) {
        db.collection('groups').doc(groupId).delete().then(() => {
            console.log(`Group ${groupId} deleted`);
        }).catch((error) => {
            console.error("Error deleting group:", error);
            alert("Failed to delete group.");
        });
    }
};

document.addEventListener('DOMContentLoaded', () => {
    if (!window.groupsControllerInitialized) {
        groupsController.init();
        window.groupsControllerInitialized = true;
    }
});
