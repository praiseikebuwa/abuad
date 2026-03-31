const analyticsController = {
    init: function () {
        console.log("Analytics Controller Connecting to Firestore...");
        this.fetchRealStats();
    },

    fetchRealStats: async function () {
        const updateStat = (id, val) => this.animateValue(id, 0, val, 1000);

        try {
            // Live Status Listener (System Config Tool)
            db.collection('system').doc('config').onSnapshot(doc => {
                if (doc.exists) {
                    const data = doc.data();
                    const mStatus = document.getElementById('summary-maintenance-status');
                    const sStatus = document.getElementById('summary-signups-status');
                    
                    if (mStatus) {
                        mStatus.innerText = data.maintenanceMode ? '🚫 ACTIVE' : '✅ DISABLED';
                        mStatus.style.color = data.maintenanceMode ? 'var(--color-accent-rose)' : 'var(--color-primary-light)';
                    }
                    if (sStatus) {
                        sStatus.innerText = data.allowSignups !== false ? '✅ OPEN' : '🚫 CLOSED';
                        sStatus.style.color = data.allowSignups !== false ? 'var(--color-primary-light)' : 'var(--color-accent-rose)';
                    }
                }
            });

            // Efficient Counting (Parallelized)
            const [usersSnap, verifiedSnap] = await Promise.all([
                db.collection('users').get(),
                db.collection('users').where('isVerified', '==', true).get()
            ]);
            
            updateStat('stat-total-users', usersSnap.size);
            updateStat('stat-verified-users', verifiedSnap.size);

            // Live Online Count (Listener)
            db.collection('users').where('status', '==', 'online').onSnapshot(snap => {
                const el = document.getElementById('stat-online-users');
                if (el) el.innerText = snap.size;
                this.updateTrafficChart(snap.size);
            });

            // Feature Counts (Parallelized)
            const collections = ['posts', 'groups', 'events', 'marketplace_items'];
            const snaps = await Promise.all(collections.map(c => db.collection(c).get()));

            // Growth Trends (Real Data)
            const growthData = await this.fetchGrowthData();

            this.initCharts({
                posts: snaps[0].size,
                groups: snaps[1].size,
                events: snaps[2].size,
                market: snaps[3].size
            }, growthData);

        } catch (err) {
            console.error("Aggregation Error:", err);
            this.initCharts();
        }
    },

    fetchGrowthData: async function () {
        const now = new Date();
        const promises = [];
        const labels = [];

        for (let i = 6; i >= 0; i--) {
            const d = new Date();
            d.setDate(now.getDate() - i);
            d.setHours(0, 0, 0, 0);

            const start = firebase.firestore.Timestamp.fromDate(d);
            const end = firebase.firestore.Timestamp.fromDate(new Date(d.getTime() + 24 * 60 * 60 * 1000));

            labels.push(d.toLocaleDateString(undefined, { weekday: 'short' }));
            promises.push(
                db.collection('users')
                    .where('createdAt', '>=', start)
                    .where('createdAt', '<', end)
                    .get()
            );
        }

        const results = await Promise.all(promises);
        return { 
            labels, 
            data: results.map(s => s.size) 
        };
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
