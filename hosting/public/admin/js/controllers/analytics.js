const analyticsController = {
    init: function () {
        console.log("Analytics Controller Connecting to Firestore...");
        this.fetchRealStats();
    },

    fetchRealStats: async function () {
        const updateStat = (id, val) => this.animateValue(id, 0, val, 1000);

        try {
            // Efficient Counting (Fallback to size for compat)
            const usersSnap = await db.collection('users').get();
            updateStat('stat-total-users', usersSnap.size);

            const verifiedSnap = await db.collection('users').where('isVerified', '==', true).get();
            updateStat('stat-verified-users', verifiedSnap.size);

            // Live Online Count (Listener)
            db.collection('users').where('status', '==', 'online').onSnapshot(snap => {
                const el = document.getElementById('stat-online-users');
                if (el) el.innerText = snap.size;
                this.updateTrafficChart(snap.size);
            });

            // Feature Counts
            const [posts, groups, events, market] = await Promise.all([
                db.collection('posts').get(),
                db.collection('groups').get(),
                db.collection('events').get(),
                db.collection('marketplace_items').get()
            ]);

            // Growth Trends (Real Data)
            const growthData = await this.fetchGrowthData();

            this.initCharts({
                posts: posts.size,
                groups: groups.size,
                events: events.size,
                market: market.size
            }, growthData);

        } catch (err) {
            console.error("Aggregation Error:", err);
            this.initCharts();
        }
    },

    fetchGrowthData: async function () {
        // Fetch last 7 days of user signups
        const labels = [];
        const data = [];
        const now = new Date();

        for (let i = 6; i >= 0; i--) {
            const d = new Date();
            d.setDate(now.getDate() - i);
            d.setHours(0, 0, 0, 0);

            const start = firebase.firestore.Timestamp.fromDate(d);
            const end = firebase.firestore.Timestamp.fromDate(new Date(d.getTime() + 24 * 60 * 60 * 1000));

            const snap = await db.collection('users')
                .where('createdAt', '>=', start)
                .where('createdAt', '<', end)
                .get();

            labels.push(d.toLocaleDateString(undefined, { weekday: 'short' }));
            data.push(snap.size);
        }
        return { labels, data };
    },

    initCharts: function (realData, growth) {
        // Growth Chart
        const ctxGrowth = document.getElementById('growthChart');
        if (ctxGrowth) {
            const chartData = growth || {
                labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
                data: [0, 0, 0, 0, 0, 0, 0]
            };
            new Chart(ctxGrowth, {
                type: 'line',
                data: {
                    labels: chartData.labels,
                    datasets: [{
                        label: 'New Users',
                        data: chartData.data,
                        borderColor: '#00897b',
                        backgroundColor: 'rgba(0, 137, 123, 0.1)',
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
            const counts = realData || { posts: 0, groups: 0, events: 0, market: 0 };
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

    animateValue: function (id, start, end, duration) {
        const obj = document.getElementById(id);
        if (!obj) return;
        let startTimestamp = null;
        const step = (timestamp) => {
            if (!startTimestamp) startTimestamp = timestamp;
            const progress = Math.min((timestamp - startTimestamp) / duration, 1);
            obj.innerHTML = Math.floor(progress * (end - start) + start);
            if (progress < 1) {
                window.requestAnimationFrame(step);
            }
        };
        window.requestAnimationFrame(step);
    },

    updateTrafficChart: function (currentOnline) {
        // Placeholder for future live chart
    },
};

// Auto-init removed. Will be called by NavigationController after Auth.
