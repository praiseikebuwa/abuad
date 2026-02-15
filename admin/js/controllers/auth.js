class AuthController {
    constructor() {
        this.loginSection = document.getElementById('login-section');
        this.dashboardSection = document.getElementById('dashboard-section');
        this.loginForm = document.getElementById('login-form');
        this.logoutBtn = document.getElementById('logout-btn');

        this.init();
    }

    init() {
        // Auth Listener
        auth.onAuthStateChanged(async (user) => {
            if (user) {
                try {
                    // Check if user has admin role
                    const userDoc = await db.collection('users').doc(user.uid).get();
                    if (userDoc.exists && userDoc.data().role === 'admin') {
                        this.showDashboard();
                    } else {
                        alert("Access Denied: You do not have administrator privileges.");
                        await auth.signOut();
                        this.showLogin();
                    }
                } catch (error) {
                    console.error("Error verifying admin status:", error);
                    alert("System Error: Could not verify permissions. Please try again.");
                    await auth.signOut();
                    this.showLogin();
                }
            } else {
                this.showLogin();
            }
        });

        // Login Handler
        this.loginForm.addEventListener('submit', (e) => {
            e.preventDefault();
            const email = document.getElementById('login-email').value;
            const password = document.getElementById('login-password').value;
            const btn = this.loginForm.querySelector('button');

            btn.disabled = true;
            btn.innerText = 'Signing in...';

            auth.signInWithEmailAndPassword(email, password)
                .then(() => {
                    // Success handled by onAuthStateChanged
                })
                .catch(error => {
                    alert("Login Failed: " + error.message);
                    btn.disabled = false;
                    btn.innerText = 'Login';
                });
        });

        // Logout Handler
        this.logoutBtn.addEventListener('click', () => {
            if (confirm('Are you sure you want to logout?')) {
                auth.signOut();
            }
        });
    }

    showLogin() {
        this.loginSection.classList.remove('hidden-section');
        this.dashboardSection.classList.add('hidden-section');
        // Reset login button state if needed
        const btn = this.loginForm.querySelector('button');
        if (btn) {
            btn.disabled = false;
            btn.innerText = 'Ans In';
        }
    }

    showDashboard() {
        this.loginSection.classList.add('hidden-section');
        this.dashboardSection.classList.remove('hidden-section');
        // Trigger initial data load via global event or direct call if we had a main controller
        // For now, relies on the default tab being triggered
        if (window.navigationController) {
            window.navigationController.loadCurrentTab();
        }
    }
}
