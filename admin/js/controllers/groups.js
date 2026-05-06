class GroupsController {
    constructor() {
        this.tableBody = document.querySelector('#groups-table tbody');
        this.groups = [];
    }

    load() {
        console.log("Groups Controller Connecting to Firestore...");
        this.subscribeToGroups();
    }

    subscribeToGroups() {
        if (!this.tableBody) return;
        this.tableBody.innerHTML = '<tr><td colspan="5" class="loading-text">Loading groups...</td></tr>';

        // Listen to 'groups' collection
        this.unsubscribe = db.collection('groups').orderBy('member_count', 'desc').limit(50).onSnapshot((snapshot) => {
            this.groups = [];
            snapshot.forEach((doc) => {
                const data = doc.data();
                this.groups.push({
                    id: doc.id,
                    name: data.name || 'Unnamed Group',
                    members: data.member_count || 0,
                    category: data.category || 'General',
                    created: data.createdAt ? new Date(data.createdAt.toDate ? data.createdAt.toDate() : data.createdAt).toLocaleDateString() : 'N/A'
                });
            });
            this.renderGroups();
        }, (error) => {
            console.error("Error fetching groups:", error);
            this.tableBody.innerHTML = `<tr><td colspan="5" class="error-text">Error loading groups: ${error.message}</td></tr>`;
        });
    }

    renderGroups() {
        this.tableBody.innerHTML = '';

        if (this.groups.length === 0) {
            this.tableBody.innerHTML = `<tr><td colspan="5" class="loading-text">No groups found.</td></tr>`;
            return;
        }

        this.groups.forEach(group => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td>
                    <div class="user-cell" style="display: flex; align-items: center; gap: 12px;">
                        <div class="avatar-initial" style="background: rgba(45, 212, 191, 0.1); color: #2dd4bf; width: 36px; height: 36px; border-radius: 8px; display: flex; align-items: center; justify-content: center; font-weight: bold;">
                            ${group.name.charAt(0).toUpperCase()}
                        </div>
                        <div class="user-details">
                            <span class="user-name" style="font-weight: 600;">${group.name}</span>
                        </div>
                    </div>
                </td>
                <td><span style="color: var(--color-primary-light); font-weight: 500;">${group.members}</span> members</td>
                <td><span class="badge" style="background: rgba(255, 255, 255, 0.05); color: var(--text-secondary); border: 1px solid var(--border-subtle);">${group.category}</span></td>
                <td>${group.created}</td>
                <td style="text-align: right;">
                    <button class="btn-icon btn-delete" title="Delete Group" style="color: #f43f5e; background: rgba(244, 63, 94, 0.1); border: none; padding: 6px 10px; border-radius: 4px; cursor: pointer;"><i class="fas fa-trash"></i></button>
                </td>
            `;

            // Delete Action
            row.querySelector('.btn-delete').addEventListener('click', () => {
                if (confirm(`Are you sure you want to delete "${group.name}"? This cannot be undone.`)) {
                    this.deleteGroup(group.id);
                }
            });

            this.tableBody.appendChild(row);
        });
    }

    deleteGroup(groupId) {
        db.collection('groups').doc(groupId).delete().then(() => {
            console.log(`Group ${groupId} deleted`);
            window.logAdminAction('DELETE_GROUP', `Permanently deleted community group: ${groupId}`, 'group', groupId);
        }).catch((error) => {
            console.error("Error deleting group:", error);
            alert("Failed to delete group.");
        });
    }
}

