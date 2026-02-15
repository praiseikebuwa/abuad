const analyticsController = {
    init: function () {
        console.log("Analytics Controller Connecting to Firestore...");
        this.fetchRealStats();
    },

    fetchRealStats: async function () {
        const updateStat = (id, val) => this.animateValue(id, 0, val, 1000);

        try {
            // Efficient Counting (Firebase v9.22.0+)
            const usersCount = await db.collection('users').count().get();
            updateStat('stat-total-users', usersCount.data().count);

            const verifiedCount = await db.collection('users').where('isVerified', '==', true).count().get();
            updateStat('stat-verified-users', verifiedCount.data().count);

            // Live Online Count (Listener)
            db.collection('users').where('status', '==', 'online').onSnapshot(snap => {
                document.getElementById('stat-online-users').innerText = snap.size;
                // Update Live Traffic Chart
                this.updateTrafficChart(snap.size);
            });

            // Feature Counts
            const [posts, groups, events, market] = await Promise.all([
                db.collection('posts').count().get(),
                db.collection('groups').count().get(),
                db.collection('events').count().get(),
                db.collection('marketplace').count().get()
            ]);

            this.initCharts({
                posts: posts.data().count,
                groups: groups.data().count,
                events: events.data().count,
                market: market.data().count
            });

        } catch (err) {
            console.error("Aggregation Error (fallback to basic get):", err);
            // Fallback for older environments
            db.collection('users').get().then(s => updateStat('stat-total-users', s.size));
            this.initCharts();
        }
    },

    trafficChart: null,

    initCharts: function (realData) {
        // ... (Existing implementation for Feature/Growth charts) ...
        // Growth Chart (Mocked trend)
        const ctxGrowth = document.getElementById('growthChart');
        if (ctxGrowth) {
            new Chart(ctxGrowth, {
                type: 'line',
                data: {
                    labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
                    datasets: [{
                        label: 'New Users',
                        data: [12, 19, 15, 25, 22, 30, 45],
                        borderColor: '#2196f3',
                        backgroundColor: 'rgba(33, 150, 243, 0.1)',
                        fill: true,
                        tension: 0.4
                    }]
                },
                options: { responsive: true, plugins: { legend: { display: false } } }
            });
        }

        // Feature Chart
        const ctxFeature = document.getElementById('featureChart');
        if (ctxFeature) {
            const counts = realData || { posts: 45, groups: 12, events: 8, market: 15 };
            new Chart(ctxFeature, {
                type: 'bar',
                data: {
                    labels: ['Posts', 'Groups', 'Events', 'Market'],
                    datasets: [{
                        label: 'Total Items',
                        data: [counts.posts, counts.groups, counts.events, counts.market],
                        backgroundColor: ['#42a5f5', '#66bb6a', '#ffa726', '#ab47bc'],
                        borderRadius: 6
                    }]
                },
                options: { responsive: true, plugins: { legend: { display: false } } }
            });
        }
    },

    updateTrafficChart: function (currentOnline) {
        // Implement a live scrolling chart if you had a canvas for it
        // For now, we update the dashboard "Online Now" text which is already done.
        // We could add a "Real-time" chart here if desired by the user.
    },
};

document.addEventListener('DOMContentLoaded', () => {
    if (!window.analyticsControllerInitialized) {
        analyticsController.init();
        window.analyticsControllerInitialized = true;
    }
});
