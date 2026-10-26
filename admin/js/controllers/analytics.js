class AnalyticsController {
    constructor() {
        this.growthChartInstance = null;
        this.featureChartInstance = null;
    }

    async load() {
        console.log("Analytics Controller Connecting to Firestore...");
        this.fetchRealStats();
    }

    async fetchRealStats() {
        const updateStat = (id, val) => this.animateValue(id, 0, val, 1000);

        try {
            // Live Status Listener (System Config Tool)
            db.collection('system').doc('config').onSnapshot(doc => {
                if (doc.exists) {
                    const data = doc.data();
                    const mStatus = document.getElementById('summary-maintenance-status');
                    const sStatus = document.getElementById('summary-signups-status');
                    
                    const aStatus = document.getElementById('summary-ads-status');
                    
                    if (mStatus) {
                        mStatus.innerText = data.maintenanceMode ? '🚫 ACTIVE' : '✅ DISABLED';
                        mStatus.style.color = data.maintenanceMode ? 'var(--color-accent-rose)' : 'var(--color-primary-light)';
                    }
                    if (sStatus) {
                        sStatus.innerText = data.allowSignups !== false ? '✅ OPEN' : '🚫 CLOSED';
                        sStatus.style.color = data.allowSignups !== false ? 'var(--color-primary-light)' : 'var(--color-accent-rose)';
                    }
                    if (aStatus) {
                        const isAdsOn = (data.ads_enabled !== false && data.ads_enabled !== 'false' && data.adsEnabled !== false && data.adsEnabled !== 'false');
                        aStatus.innerText = isAdsOn ? '✅ ACTIVE' : '🚫 SHUT DOWN';
                        aStatus.style.color = isAdsOn ? 'var(--color-primary-light)' : 'var(--color-accent-rose)';
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
    }

    async fetchGrowthData() {
        const now = new Date();
        const promises = [];
        const labels = [];
        const daysToFetch = 14; 

        for (let i = daysToFetch - 1; i >= 0; i--) {
            const d = new Date();
            d.setDate(now.getDate() - i);
            d.setHours(0, 0, 0, 0);

            const start = d.toISOString();
            const end = new Date(d.getTime() + 24 * 60 * 60 * 1000).toISOString();

            labels.push(d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' }));
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
    }

    initCharts(realData, growth) {
        const commonOptions = {
            responsive: true,
            maintainAspectRatio: true,
            plugins: {
                legend: {
                    display: false
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    grid: { color: 'rgba(255, 255, 255, 0.05)' },
                    ticks: { color: '#64748b', font: { size: 10 } }
                },
                x: {
                    grid: { display: false },
                    ticks: { color: '#64748b', font: { size: 10 } }
                }
            }
        };

        // Growth Chart (Line)
        const ctxGrowth = document.getElementById('growthChart');
        const ctxGrowthOverview = document.getElementById('growthChartOverview');
        
        const renderGrowth = (ctx) => {
            if (!ctx) return;
            return new Chart(ctx, {
                type: 'line',
                data: {
                    labels: (growth && growth.labels) ? growth.labels : [],
                    datasets: [{
                        label: 'New Users',
                        data: (growth && growth.data) ? growth.data : [],
                        borderColor: '#2dd4bf',
                        backgroundColor: 'rgba(45, 212, 191, 0.1)',
                        borderWidth: 3,
                        pointRadius: 4,
                        pointBackgroundColor: '#2dd4bf',
                        fill: true,
                        tension: 0.4
                    }]
                },
                options: commonOptions
            });
        };

        if (ctxGrowth) {
            if (this.growthChartInstance) this.growthChartInstance.destroy();
            this.growthChartInstance = renderGrowth(ctxGrowth);
        }
        
        if (ctxGrowthOverview) {
            if (this.growthChartOverviewInstance) this.growthChartOverviewInstance.destroy();
            this.growthChartOverviewInstance = renderGrowth(ctxGrowthOverview);
        }

        // Feature Chart (Doughnut for diversity)
        const ctxFeature = document.getElementById('featureChart');
        const ctxUserOverview = document.getElementById('userChart');

        if (ctxFeature) {
            if (this.featureChartInstance) this.featureChartInstance.destroy();
            const counts = realData || { posts: 0, groups: 0, events: 0, market: 0 };
            this.featureChartInstance = new Chart(ctxFeature, {
                type: 'doughnut',
                data: {
                    labels: ['Posts', 'Groups', 'Events', 'Market'],
                    datasets: [{
                        data: [counts.posts, counts.groups, counts.events, counts.market],
                        backgroundColor: [
                            'rgba(45, 212, 191, 0.8)',
                            'rgba(129, 140, 248, 0.8)',
                            'rgba(251, 191, 36, 0.8)',
                            'rgba(244, 63, 94, 0.8)'
                        ],
                        borderWidth: 0,
                        hoverOffset: 10
                    }]
                },
                options: {
                    ...commonOptions,
                    cutout: '70%',
                    plugins: { legend: { display: true, position: 'bottom', labels: { color: '#94a3b8', padding: 20 } } }
                }
            });
        }

        if (ctxUserOverview) {
            if (this.userChartInstance) this.userChartInstance.destroy();
            this.userChartInstance = new Chart(ctxUserOverview, {
                type: 'bar',
                data: {
                    labels: ['Users', 'Verified', 'Staff'],
                    datasets: [{
                        data: [realData.users || 0, realData.verified || 0, realData.staff || 0],
                        backgroundColor: ['#2dd4bf', '#818cf8', '#fbbf24']
                    }]
                },
                options: commonOptions
            });
        }
    }

    animateValue(id, start, end, duration) {
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
    }

    updateTrafficChart(currentOnline) {
        // Dynamic traffic update logic could go here
    }
}


// Auto-init removed. Will be called by NavigationController after Auth.
