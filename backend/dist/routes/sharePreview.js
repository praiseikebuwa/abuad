"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const db_1 = require("../config/db");
const router = (0, express_1.Router)();
function safeParseJson(raw, fallback) {
    if (!raw)
        return fallback;
    if (typeof raw !== 'string')
        return raw;
    try {
        return JSON.parse(raw);
    }
    catch (_) {
        return fallback;
    }
}
function safeParseImages(imagesRaw) {
    if (Array.isArray(imagesRaw))
        return imagesRaw;
    if (typeof imagesRaw === 'string') {
        try {
            const parsed = JSON.parse(imagesRaw);
            if (Array.isArray(parsed))
                return parsed;
            return imagesRaw.length > 0 ? [imagesRaw] : [];
        }
        catch (_) {
            return imagesRaw.length > 0 ? [imagesRaw] : [];
        }
    }
    return [];
}
function escapeHtml(str) {
    if (!str)
        return '';
    return str
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}
function renderHtmlPreview(opts) {
    const ogType = opts.ogType || 'website';
    const imgUrl = opts.imageUrl || 'https://abuadapp.com.ng/og-image.jpg';
    const cleanTitle = escapeHtml(opts.title);
    const cleanDesc = escapeHtml(opts.description);
    const cleanImg = escapeHtml(imgUrl);
    const cleanCanonical = escapeHtml(opts.canonicalUrl);
    const cleanDeepLink = escapeHtml(opts.deepLinkUrl);
    const cleanBadge = escapeHtml(opts.badgeText || 'ABUAD APP');
    const cleanSubtitle = escapeHtml(opts.metaSubtitle || '');
    const cleanAuthor = escapeHtml(opts.authorName || 'ABUAD Student');
    const cleanAvatar = escapeHtml(opts.authorAvatar || 'https://abuadapp.com.ng/icons/Icon-192.png');
    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${cleanTitle}</title>
  <meta name="description" content="${cleanDesc}">
  <meta name="robots" content="index, follow">
  <link rel="canonical" href="${cleanCanonical}">
  <meta name="theme-color" content="#14B8A6">

  <!-- Open Graph / WhatsApp / Facebook / LinkedIn / Telegram -->
  <meta property="og:type" content="${ogType}">
  <meta property="og:site_name" content="ABUAD Life — Student Super-App">
  <meta property="og:url" content="${cleanCanonical}">
  <meta property="og:title" content="${cleanTitle}">
  <meta property="og:description" content="${cleanDesc}">
  <meta property="og:image" content="${cleanImg}">
  <meta property="og:image:secure_url" content="${cleanImg}">
  <meta property="og:image:alt" content="${cleanTitle}">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  ${opts.priceAmount ? `<meta property="product:price:amount" content="${escapeHtml(String(opts.priceAmount))}">` : ''}
  ${opts.priceCurrency ? `<meta property="product:price:currency" content="${escapeHtml(opts.priceCurrency)}">` : ''}

  <!-- Twitter / X / Discord -->
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:site" content="@abuad_app">
  <meta name="twitter:url" content="${cleanCanonical}">
  <meta name="twitter:title" content="${cleanTitle}">
  <meta name="twitter:description" content="${cleanDesc}">
  <meta name="twitter:image" content="${cleanImg}">
  <meta name="twitter:image:alt" content="${cleanTitle}">

  <!-- App Deep Link Metadata (iOS & Android) -->
  <meta property="al:android:url" content="${cleanDeepLink}">
  <meta property="al:android:package" content="com.pronown.abuad">
  <meta property="al:android:app_name" content="ABUAD">
  <meta property="al:ios:url" content="${cleanDeepLink}">
  <meta property="al:ios:app_store_id" content="6741476901">
  <meta property="al:ios:app_name" content="ABUAD">
  <meta property="al:web:url" content="${cleanCanonical}">

  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">

  <style>
    :root {
      --bg: #090d16;
      --card: rgba(255, 255, 255, 0.05);
      --border: rgba(255, 255, 255, 0.12);
      --text: #f8fafc;
      --muted: #94a3b8;
      --teal: #14b8a6;
      --teal-glow: rgba(20, 184, 166, 0.35);
      --emerald: #10b981;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Plus Jakarta Sans', system-ui, -apple-system, sans-serif;
      background: radial-gradient(1200px 800px at 50% -10%, #1e1b4b 0%, #090d16 100%);
      color: var(--text);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    .preview-card {
      width: 100%;
      max-width: 480px;
      background: var(--card);
      border: 1px solid var(--border);
      border-radius: 28px;
      backdrop-filter: blur(24px);
      -webkit-backdrop-filter: blur(24px);
      overflow: hidden;
      box-shadow: 0 25px 60px rgba(0, 0, 0, 0.6);
      animation: fadeIn 0.35s ease-out;
    }
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(14px); }
      to { opacity: 1; transform: translateY(0); }
    }
    .media-wrap {
      width: 100%;
      height: 250px;
      position: relative;
      background: #020617;
      display: flex;
      align-items: center;
      justify-content: center;
      overflow: hidden;
    }
    .media-wrap img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
    .badge {
      position: absolute;
      top: 14px;
      right: 14px;
      background: var(--teal);
      color: #042f2e;
      font-size: 11px;
      font-weight: 800;
      padding: 5px 12px;
      border-radius: 12px;
      letter-spacing: 0.5px;
      text-transform: uppercase;
      box-shadow: 0 4px 12px rgba(0,0,0,0.3);
    }
    .status-live {
      background: #ef4444 !important;
      color: #ffffff !important;
      display: flex;
      align-items: center;
      gap: 5px;
    }
    .status-live::before {
      content: '';
      display: inline-block;
      width: 7px;
      height: 7px;
      background: #ffffff;
      border-radius: 50%;
      animation: pulse 1s infinite;
    }
    @keyframes pulse {
      0% { opacity: 1; transform: scale(1); }
      50% { opacity: 0.4; transform: scale(1.3); }
      100% { opacity: 1; transform: scale(1); }
    }
    .price-pill {
      position: absolute;
      bottom: 14px;
      left: 14px;
      background: rgba(15, 23, 42, 0.9);
      backdrop-filter: blur(10px);
      border: 1px solid rgba(255, 255, 255, 0.15);
      padding: 6px 14px;
      border-radius: 20px;
      font-weight: 800;
      color: #38bdf8;
      font-size: 17px;
    }
    .content {
      padding: 24px;
    }
    .author-row {
      display: flex;
      align-items: center;
      gap: 10px;
      margin-bottom: 14px;
    }
    .author-avatar {
      width: 38px;
      height: 38px;
      border-radius: 50%;
      object-fit: cover;
      border: 1.5px solid var(--border);
    }
    .author-meta {
      display: flex;
      flex-direction: column;
    }
    .author-name {
      font-weight: 700;
      font-size: 14px;
    }
    .subtitle {
      font-size: 12px;
      color: var(--muted);
    }
    h1 {
      font-size: 19px;
      font-weight: 800;
      line-height: 1.35;
      margin-bottom: 10px;
    }
    p.desc {
      font-size: 14px;
      color: var(--muted);
      line-height: 1.55;
      margin-bottom: 22px;
    }
    .actions {
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .btn-primary {
      display: block;
      width: 100%;
      text-align: center;
      background: var(--teal);
      color: #042f2e;
      padding: 14px;
      border-radius: 16px;
      font-weight: 700;
      font-size: 15px;
      text-decoration: none;
      box-shadow: 0 4px 20px var(--teal-glow);
      transition: transform 0.15s;
    }
    .btn-secondary {
      display: block;
      width: 100%;
      text-align: center;
      background: rgba(255, 255, 255, 0.08);
      color: var(--text);
      padding: 13px;
      border-radius: 16px;
      font-weight: 600;
      font-size: 14px;
      text-decoration: none;
      border: 1px solid var(--border);
    }
    .footer-note {
      text-align: center;
      margin-top: 16px;
      font-size: 11px;
      color: var(--muted);
    }
  </style>

  <script>
    // Smart redirect: If opened in a regular mobile browser (not social bot), try opening the app
    (function() {
      var ua = navigator.userAgent || '';
      var isBot = /bot|googlebot|crawler|spider|robot|crawling|facebookexternalhit|whatsapp|slack|twitterbot|telegram|discord|applebot|linkedin|preview|meta|pinterest/i.test(ua);
      if (!isBot) {
        var deepLink = "${cleanDeepLink}";
        var webUrl = "${cleanCanonical}";
        // Try launching app scheme
        window.location.href = deepLink;
        // If still in browser after 1.4s, redirect to web app
        setTimeout(function() {
          window.location.href = webUrl;
        }, 1400);
      }
    })();
  </script>
</head>
<body>
  <div class="preview-card">
    <div class="media-wrap">
      <img src="${cleanImg}" alt="${cleanTitle}" onerror="this.src='https://abuadapp.com.ng/og-image.jpg'">
      ${opts.priceAmount ? `<div class="price-pill">₦${Number(opts.priceAmount).toLocaleString()}</div>` : ''}
      <div class="badge ${cleanBadge.toLowerCase().includes('live') ? 'status-live' : ''}">${cleanBadge}</div>
    </div>
    <div class="content">
      <div class="author-row">
        <img class="author-avatar" src="${cleanAvatar}" alt="${cleanAuthor}" onerror="this.src='https://abuadapp.com.ng/icons/Icon-192.png'">
        <div class="author-meta">
          <span class="author-name">${cleanAuthor}</span>
          ${cleanSubtitle ? `<span class="subtitle">${cleanSubtitle}</span>` : ''}
        </div>
      </div>
      <h1>${cleanTitle}</h1>
      <p class="desc">${cleanDesc}</p>
      <div class="actions">
        <a href="${cleanDeepLink}" class="btn-primary">📲 Open in ABUAD App</a>
        <a href="${cleanCanonical}" class="btn-secondary">🌐 Open Web Version</a>
      </div>
      <div class="footer-note">ABUAD Student Super-App • Campus Verified</div>
    </div>
  </div>
</body>
</html>`;
}
/**
 * GET /share/marketplace/:id (and /share/marketplace/item/:id, /share/marketplace/detail?id=...)
 */
async function handleMarketplacePreview(req, res) {
    try {
        const id = String(req.params.id || req.query.id || req.query.itemId || '');
        let item = null;
        try {
            item = await db_1.prisma.marketplaceItem.findUnique({
                where: { id },
                include: {
                    seller: {
                        select: { id: true, username: true, fullName: true, avatarUrl: true, department: true },
                    },
                },
            });
        }
        catch (dbErr) {
            console.warn('Share preview marketplace query fallback:', dbErr);
        }
        const title = item?.title
            ? `${item.title} — ₦${Number(item.price || 0).toLocaleString()} | ABUAD Marketplace`
            : 'ABUAD Campus Marketplace';
        const rawDesc = item?.description || 'Browse student listings, textbooks, gadgets, and campus essentials.';
        const description = rawDesc.length > 200 ? rawDesc.substring(0, 197) + '...' : rawDesc;
        const images = safeParseImages(item?.images);
        const imageUrl = images.length > 0 ? images[0] : 'https://abuadapp.com.ng/og-image.jpg';
        const sellerName = item?.seller?.fullName || item?.seller?.username || 'ABUAD Student';
        const canonicalUrl = `https://abuadapp.com.ng/marketplace/detail?id=${encodeURIComponent(id)}`;
        const deepLinkUrl = `abuad://marketplace/detail?id=${encodeURIComponent(id)}`;
        res.setHeader('Cache-Control', 'public, max-age=1800, s-maxage=86400');
        res.type('html').send(renderHtmlPreview({
            title,
            description,
            imageUrl,
            canonicalUrl,
            deepLinkUrl,
            badgeText: item?.category || 'MARKETPLACE',
            authorName: sellerName,
            authorAvatar: item?.seller?.avatarUrl,
            metaSubtitle: item?.seller?.department ? `${item.seller.department} • Verified Seller` : 'Verified Seller',
            ogType: 'product',
            priceAmount: item?.price,
            priceCurrency: 'NGN',
        }));
    }
    catch (err) {
        console.error('Marketplace preview error:', err);
        res.redirect('https://abuadapp.com.ng/marketplace');
    }
}
router.get('/marketplace/detail', handleMarketplacePreview);
router.get('/marketplace/:id', handleMarketplacePreview);
router.get('/marketplace/item/:id', handleMarketplacePreview);
/**
 * GET /share/post/:id (and /share/p/:id)
 */
async function handlePostPreview(req, res) {
    try {
        const id = String(req.params.id);
        let post = null;
        try {
            post = await db_1.prisma.post.findUnique({
                where: { id },
                include: {
                    author: {
                        select: { id: true, username: true, fullName: true, avatarUrl: true, department: true },
                    },
                },
            });
        }
        catch (dbErr) {
            console.warn('Share preview post query fallback:', dbErr);
        }
        const authorName = post?.isAnonymous
            ? 'Anonymous Student'
            : (post?.author?.fullName || post?.author?.username || 'ABUAD Student');
        const authorAvatar = post?.isAnonymous
            ? 'https://abuadapp.com.ng/icons/Icon-192.png'
            : (post?.author?.avatarUrl || 'https://abuadapp.com.ng/icons/Icon-192.png');
        const postContent = post?.content || 'Check out this post on ABUAD Life!';
        const title = `${authorName} on ABUAD Life`;
        const description = postContent.length > 220 ? postContent.substring(0, 217) + '...' : postContent;
        // Detect media image
        let imageUrl = 'https://abuadapp.com.ng/og-image.jpg';
        if (post?.mediaUrl && post.mediaType === 'image') {
            imageUrl = post.mediaUrl;
        }
        else if (post?.mediaUrls) {
            const parsedUrls = safeParseJson(post.mediaUrls, []);
            if (parsedUrls.length > 0 && parsedUrls[0]) {
                imageUrl = parsedUrls[0];
            }
        }
        const canonicalUrl = `https://abuadapp.com.ng/post/${encodeURIComponent(id)}`;
        const deepLinkUrl = `abuad://post/${encodeURIComponent(id)}`;
        const likesText = post?.likesCount ? `${post.likesCount} likes` : '';
        const commentsText = post?.commentsCount ? `${post.commentsCount} comments` : '';
        const statsArr = [likesText, commentsText].filter(Boolean);
        const subtitle = statsArr.length > 0
            ? `${post?.author?.department ? post.author.department + ' • ' : ''}${statsArr.join(' • ')}`
            : (post?.author?.department || 'Campus Buzz');
        res.setHeader('Cache-Control', 'public, max-age=600, s-maxage=3600');
        res.type('html').send(renderHtmlPreview({
            title,
            description,
            imageUrl,
            canonicalUrl,
            deepLinkUrl,
            badgeText: 'CAMPUS POST',
            authorName,
            authorAvatar,
            metaSubtitle: subtitle,
            ogType: 'article',
        }));
    }
    catch (err) {
        console.error('Post preview error:', err);
        res.redirect('https://abuadapp.com.ng');
    }
}
router.get('/post/:id', handlePostPreview);
router.get('/p/:id', handlePostPreview);
/**
 * GET /share/spaces/:id (and /share/space/:id)
 */
async function handleSpacePreview(req, res) {
    try {
        const id = String(req.params.id);
        let room = null;
        try {
            room = await db_1.prisma.audioRoom.findUnique({
                where: { id },
                include: {
                    host: {
                        select: { id: true, username: true, fullName: true, avatarUrl: true, department: true },
                    },
                    participants: {
                        take: 5,
                        select: { id: true, role: true, user: { select: { fullName: true, avatarUrl: true } } },
                    },
                },
            });
        }
        catch (dbErr) {
            console.warn('Share preview space query fallback:', dbErr);
        }
        const hostName = room?.host?.fullName || room?.host?.username || 'ABUAD Host';
        const isLive = room?.status === 'LIVE';
        const badgeText = isLive ? '🔴 LIVE NOW' : (room?.status || 'AUDIO SPACE');
        const title = room?.title ? `🎙️ ${room.title} — Live Audio Space` : '🎙️ ABUAD Campus Audio Space';
        const rawDesc = room?.description || `Join ${hostName} in live campus voice conversation on ABUAD Life. Listen, ask questions, and speak on stage.`;
        const description = rawDesc.length > 220 ? rawDesc.substring(0, 217) + '...' : rawDesc;
        const imageUrl = room?.host?.avatarUrl || 'https://abuadapp.com.ng/og-image.jpg';
        const canonicalUrl = `https://abuadapp.com.ng/spaces/${encodeURIComponent(id)}`;
        const deepLinkUrl = `abuad://spaces/${encodeURIComponent(id)}`;
        const subtitle = `${room?.category || 'CAMPUS'} • Hosted by ${hostName}`;
        res.setHeader('Cache-Control', 'public, max-age=120, s-maxage=300');
        res.type('html').send(renderHtmlPreview({
            title,
            description,
            imageUrl,
            canonicalUrl,
            deepLinkUrl,
            badgeText,
            authorName: hostName,
            authorAvatar: room?.host?.avatarUrl,
            metaSubtitle: subtitle,
            ogType: 'music.radio_station',
        }));
    }
    catch (err) {
        console.error('Space preview error:', err);
        res.redirect('https://abuadapp.com.ng/spaces');
    }
}
router.get('/spaces/:id', handleSpacePreview);
router.get('/space/:id', handleSpacePreview);
/**
 * GET /share/user/:id (and /share/profile/:id)
 */
async function handleUserPreview(req, res) {
    try {
        const idOrUsername = String(req.params.id);
        let user = null;
        try {
            user = await db_1.prisma.user.findFirst({
                where: {
                    OR: [
                        { id: idOrUsername },
                        { username: idOrUsername.toLowerCase() },
                    ],
                },
                select: {
                    id: true,
                    username: true,
                    fullName: true,
                    avatarUrl: true,
                    bio: true,
                    department: true,
                    level: true,
                    college: true,
                },
            });
        }
        catch (dbErr) {
            console.warn('Share preview user query fallback:', dbErr);
        }
        const displayName = user?.fullName || (user?.username ? `@${user.username}` : 'ABUAD Student');
        const title = `${displayName} on ABUAD Life`;
        const rawBio = user?.bio || `Connect with ${displayName} on the official ABUAD student app.`;
        const description = rawBio.length > 200 ? rawBio.substring(0, 197) + '...' : rawBio;
        const imageUrl = user?.avatarUrl || 'https://abuadapp.com.ng/icons/Icon-512.png';
        const canonicalUrl = `https://abuadapp.com.ng/user/${encodeURIComponent(user?.id || idOrUsername)}`;
        const deepLinkUrl = `abuad://user/${encodeURIComponent(user?.id || idOrUsername)}`;
        const subtitle = [user?.department, user?.level ? `${user.level}L` : ''].filter(Boolean).join(' • ') || 'ABUAD Member';
        res.setHeader('Cache-Control', 'public, max-age=1800, s-maxage=86400');
        res.type('html').send(renderHtmlPreview({
            title,
            description,
            imageUrl,
            canonicalUrl,
            deepLinkUrl,
            badgeText: 'STUDENT PROFILE',
            authorName: displayName,
            authorAvatar: imageUrl,
            metaSubtitle: subtitle,
            ogType: 'profile',
        }));
    }
    catch (err) {
        console.error('User preview error:', err);
        res.redirect('https://abuadapp.com.ng');
    }
}
router.get('/user/:id', handleUserPreview);
router.get('/profile/:id', handleUserPreview);
router.get('/u/:id', handleUserPreview);
/**
 * GET /share/group/:id (and /share/join/group/:id)
 */
async function handleGroupPreview(req, res) {
    try {
        const id = String(req.params.id);
        let channel = null;
        try {
            channel = await db_1.prisma.chatChannel.findUnique({
                where: { id },
                select: {
                    id: true,
                    name: true,
                    description: true,
                    avatarUrl: true,
                    isGroup: true,
                    _count: { select: { messages: true } },
                },
            });
        }
        catch (dbErr) {
            console.warn('Share preview group query fallback:', dbErr);
        }
        const groupName = channel?.name || 'ABUAD Campus Group';
        const title = `Join "${groupName}" on ABUAD Life`;
        const rawDesc = channel?.description || `Join this campus group on ABUAD Life to chat with course mates, share updates, and collaborate.`;
        const description = rawDesc.length > 200 ? rawDesc.substring(0, 197) + '...' : rawDesc;
        const imageUrl = channel?.avatarUrl || 'https://abuadapp.com.ng/icons/Icon-512.png';
        const canonicalUrl = `https://abuadapp.com.ng/join/group/${encodeURIComponent(id)}`;
        const deepLinkUrl = `abuad://join/group/${encodeURIComponent(id)}`;
        res.setHeader('Cache-Control', 'public, max-age=1800, s-maxage=86400');
        res.type('html').send(renderHtmlPreview({
            title,
            description,
            imageUrl,
            canonicalUrl,
            deepLinkUrl,
            badgeText: 'CAMPUS GROUP',
            authorName: groupName,
            authorAvatar: imageUrl,
            metaSubtitle: 'ABUAD Verified Student Channel',
            ogType: 'website',
        }));
    }
    catch (err) {
        console.error('Group preview error:', err);
        res.redirect('https://abuadapp.com.ng');
    }
}
router.get('/group/:id', handleGroupPreview);
router.get('/join/group/:id', handleGroupPreview);
/**
 * GET /share/event/:id
 */
async function handleEventPreview(req, res) {
    try {
        const id = String(req.params.id);
        let event = null;
        try {
            event = await db_1.prisma.event.findUnique({
                where: { id },
                include: {
                    organizer: { select: { fullName: true, username: true, avatarUrl: true } },
                },
            });
        }
        catch (dbErr) {
            console.warn('Share preview event query fallback:', dbErr);
        }
        const eventTitle = event?.title || 'ABUAD Campus Event';
        const title = `📅 ${eventTitle} — Campus Events | ABUAD`;
        const rawDesc = event?.description || `Check out this campus event on ABUAD Life. Venue: ${event?.location || 'ABUAD Campus'}.`;
        const description = rawDesc.length > 200 ? rawDesc.substring(0, 197) + '...' : rawDesc;
        const imageUrl = event?.imageUrl || 'https://abuadapp.com.ng/og-image.jpg';
        const canonicalUrl = `https://abuadapp.com.ng/event/${encodeURIComponent(id)}`;
        const deepLinkUrl = `abuad://event/${encodeURIComponent(id)}`;
        const subtitle = event?.location ? `📍 ${event.location}` : 'ABUAD Campus';
        res.setHeader('Cache-Control', 'public, max-age=1800, s-maxage=86400');
        res.type('html').send(renderHtmlPreview({
            title,
            description,
            imageUrl,
            canonicalUrl,
            deepLinkUrl,
            badgeText: 'CAMPUS EVENT',
            authorName: event?.organizer?.fullName || 'Event Organizer',
            authorAvatar: event?.organizer?.avatarUrl,
            metaSubtitle: subtitle,
            ogType: 'event',
        }));
    }
    catch (err) {
        console.error('Event preview error:', err);
        res.redirect('https://abuadapp.com.ng');
    }
}
router.get('/event/:id', handleEventPreview);
exports.default = router;
