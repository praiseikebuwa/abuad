import { Router, Request, Response } from 'express';

const router = Router();

/**
 * GET /reset-password?token=...
 * Self-contained page served by the backend. Submits to POST /api/auth/reset-password.
 */
router.get('/reset-password', (req: Request, res: Response) => {
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('Referrer-Policy', 'no-referrer'); // don't leak the token to other sites
  res.setHeader('X-Frame-Options', 'DENY');
  res.type('html').send(PAGE_HTML);
});

const PAGE_HTML = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>Reset Password | ABUAD App</title>
<meta name="description" content="Choose a new password for your ABUAD App account." />
<meta name="robots" content="noindex" />
<link rel="preconnect" href="https://fonts.googleapis.com" />
<link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;800&display=swap" rel="stylesheet" />
<style>
  :root {
    --ink: #0b1020; --card: rgba(255,255,255,0.07); --border: rgba(255,255,255,0.14);
    --text: #eef1fb; --muted: #a3abc9; --amber: #f5b63c; --teal: #2ec4b6; --danger: #ff6b6b; --ok: #4ade80;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: 'Outfit', system-ui, sans-serif; color: var(--text); min-height: 100vh;
    display: flex; align-items: center; justify-content: center; padding: 24px;
    background: radial-gradient(1200px 600px at 10% -10%, #2a3a8f 0%, transparent 60%),
                radial-gradient(900px 500px at 110% 110%, #0f6b63 0%, transparent 55%), var(--ink);
    overflow: hidden;
  }
  .orb { position: fixed; border-radius: 50%; filter: blur(60px); opacity: .45; animation: float 12s ease-in-out infinite; z-index: 0; }
  .orb.a { width: 280px; height: 280px; background: #4f6bff; top: -60px; right: -60px; }
  .orb.b { width: 340px; height: 340px; background: var(--teal); bottom: -120px; left: -100px; animation-delay: -6s; }
  @keyframes float { 50% { transform: translateY(30px) scale(1.06); } }
  main {
    position: relative; z-index: 1; width: 100%; max-width: 420px; padding: 36px 32px;
    background: var(--card); border: 1px solid var(--border); border-radius: 28px;
    backdrop-filter: blur(18px); -webkit-backdrop-filter: blur(18px);
    box-shadow: 0 30px 80px rgba(0,0,0,.45); animation: rise .6s cubic-bezier(.2,.8,.2,1);
  }
  @keyframes rise { from { opacity: 0; transform: translateY(24px) scale(.98); } }
  .brand { display: flex; align-items: center; gap: 12px; margin-bottom: 26px; }
  .logo { width: 46px; height: 46px; border-radius: 14px; display: grid; place-items: center; font-weight: 800;
          background: linear-gradient(135deg, var(--amber), #ff8a3d); color: var(--ink); font-size: 20px; }
  .brand span { font-weight: 800; letter-spacing: 3px; font-size: 20px; }
  h1 { font-size: 26px; font-weight: 800; margin-bottom: 6px; }
  p.sub { color: var(--muted); font-size: 15px; margin-bottom: 26px; line-height: 1.5; }
  label { display: block; font-size: 13px; font-weight: 600; letter-spacing: .4px; margin-bottom: 8px; }
  .field { position: relative; margin-bottom: 18px; }
  input {
    width: 100%; padding: 15px 48px 15px 16px; font: inherit; font-size: 16px; color: var(--text);
    background: rgba(255,255,255,.05); border: 1px solid var(--border); border-radius: 14px; outline: none;
    transition: border-color .2s, box-shadow .2s, background .2s;
  }
  input:focus { border-color: var(--amber); box-shadow: 0 0 0 4px rgba(245,182,60,.18); background: rgba(255,255,255,.08); }
  .toggle { position: absolute; right: 10px; bottom: 9px; background: none; border: 0; color: var(--muted);
            cursor: pointer; padding: 6px; border-radius: 8px; font-size: 13px; font-family: inherit; }
  .toggle:hover { color: var(--text); }
  .meter { height: 6px; border-radius: 6px; background: rgba(255,255,255,.08); overflow: hidden; margin: -6px 0 6px; }
  .meter i { display: block; height: 100%; width: 0; transition: width .3s, background .3s; }
  .hint { font-size: 12px; color: var(--muted); margin-bottom: 18px; min-height: 16px; }
  button.primary {
    width: 100%; padding: 16px; border: 0; border-radius: 14px; font: inherit; font-weight: 800; font-size: 16px;
    letter-spacing: .5px; color: var(--ink); background: linear-gradient(135deg, var(--amber), #ffcf6b);
    cursor: pointer; box-shadow: 0 12px 30px rgba(245,182,60,.3); transition: transform .15s, box-shadow .2s, opacity .2s;
  }
  button.primary:hover:not(:disabled) { transform: translateY(-2px); box-shadow: 0 16px 36px rgba(245,182,60,.4); }
  button.primary:disabled { opacity: .6; cursor: not-allowed; }
  .spinner { width: 18px; height: 18px; border: 2.5px solid rgba(11,16,32,.3); border-top-color: var(--ink);
             border-radius: 50%; display: inline-block; vertical-align: middle; animation: spin .8s linear infinite; }
  @keyframes spin { to { transform: rotate(360deg); } }
  .alert { padding: 12px 14px; border-radius: 12px; font-size: 14px; margin-bottom: 18px; display: none; }
  .alert.err { display: block; background: rgba(255,107,107,.12); border: 1px solid rgba(255,107,107,.35); color: #ffc2c2; }
  .done { text-align: center; display: none; }
  .check { width: 76px; height: 76px; margin: 4px auto 18px; border-radius: 50%; display: grid; place-items: center;
           background: rgba(74,222,128,.15); border: 2px solid var(--ok); animation: pop .5s cubic-bezier(.2,1.4,.4,1); }
  @keyframes pop { from { transform: scale(.3); opacity: 0; } }
  .check svg { width: 36px; height: 36px; stroke: var(--ok); }
  a.link { color: var(--amber); text-decoration: none; font-weight: 600; }
  footer { margin-top: 24px; text-align: center; font-size: 13px; color: var(--muted); }
</style>
</head>
<body>
<div class="orb a"></div><div class="orb b"></div>
<main>
  <div class="brand"><div class="logo">A</div><span>ABUAD</span></div>

  <section id="formView">
    <h1>Set a new password</h1>
    <p class="sub">Choose a strong password you haven't used before.</p>
    <div id="alert" class="alert" role="alert"></div>
    <form id="resetForm" novalidate>
      <div class="field">
        <label for="password">New password</label>
        <input id="password" type="password" autocomplete="new-password" minlength="8" required placeholder="At least 8 characters" />
        <button type="button" class="toggle" id="togglePassword" aria-label="Show password">Show</button>
      </div>
      <div class="meter"><i id="meterBar"></i></div>
      <div class="hint" id="strengthHint"></div>
      <div class="field">
        <label for="confirm">Confirm password</label>
        <input id="confirm" type="password" autocomplete="new-password" required placeholder="Re-enter password" />
      </div>
      <button class="primary" id="submitBtn" type="submit">Reset Password</button>
    </form>
  </section>

  <section id="doneView" class="done">
    <div class="check"><svg viewBox="0 0 24 24" fill="none" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M5 13l4 4L19 7"/></svg></div>
    <h1>Password updated</h1>
    <p class="sub">You can now return to the ABUAD app and sign in with your new password.</p>
    <a class="link" href="https://www.abuadapp.com.ng">Go to abuadapp.com.ng →</a>
  </section>

  <footer>Need help? <a class="link" href="https://www.abuadapp.com.ng">abuadapp.com.ng</a></footer>
</main>
<script>
(function () {
  var token = new URLSearchParams(location.search).get('token');
  // Strip the token from the address bar / history once read
  if (token) history.replaceState(null, '', location.pathname);

  var form = document.getElementById('resetForm');
  var pw = document.getElementById('password');
  var cf = document.getElementById('confirm');
  var btn = document.getElementById('submitBtn');
  var alertBox = document.getElementById('alert');
  var bar = document.getElementById('meterBar');
  var hint = document.getElementById('strengthHint');

  function showError(msg) { alertBox.textContent = msg; alertBox.className = 'alert err'; }
  function clearError() { alertBox.className = 'alert'; }

  if (!token) {
    showError('This reset link is invalid. Please request a new one from the app.');
    btn.disabled = true;
  }

  document.getElementById('togglePassword').addEventListener('click', function () {
    var show = pw.type === 'password';
    pw.type = cf.type = show ? 'text' : 'password';
    this.textContent = show ? 'Hide' : 'Show';
  });

  pw.addEventListener('input', function () {
    var v = pw.value, s = 0;
    if (v.length >= 8) s++;
    if (v.length >= 12) s++;
    if (/[A-Z]/.test(v) && /[a-z]/.test(v)) s++;
    if (/\\d/.test(v)) s++;
    if (/[^A-Za-z0-9]/.test(v)) s++;
    var colors = ['#ff6b6b', '#ff6b6b', '#f5b63c', '#f5b63c', '#4ade80', '#4ade80'];
    var labels = ['Too short', 'Weak', 'Fair', 'Good', 'Strong', 'Very strong'];
    bar.style.width = (v ? Math.max(10, s * 20) : 0) + '%';
    bar.style.background = colors[s];
    hint.textContent = v ? labels[s] : '';
  });

  form.addEventListener('submit', async function (e) {
    e.preventDefault();
    clearError();
    if (pw.value.length < 8) return showError('Password must be at least 8 characters.');
    if (pw.value !== cf.value) return showError('Passwords do not match.');

    btn.disabled = true;
    btn.innerHTML = '<span class="spinner"></span>';
    try {
      var res = await fetch('/api/auth/reset-password', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ resetToken: token, newPassword: pw.value })
      });
      var data = await res.json().catch(function () { return {}; });
      if (res.ok && data.success) {
        document.getElementById('formView').style.display = 'none';
        document.getElementById('doneView').style.display = 'block';
      } else {
        showError(data.error || 'Something went wrong. Please try again.');
        btn.disabled = false; btn.textContent = 'Reset Password';
      }
    } catch (err) {
      showError('Network error. Check your connection and try again.');
      btn.disabled = false; btn.textContent = 'Reset Password';
    }
  });
})();
</script>
</body>
</html>`;

export default router;
