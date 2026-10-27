"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const db_1 = require("../config/db");
const router = (0, express_1.Router)();
function safeParseImages(imagesRaw) {
    if (Array.isArray(imagesRaw))
        return imagesRaw;
    if (typeof imagesRaw === 'string') {
        try {
            const parsed = JSON.parse(imagesRaw);
            if (Array.isArray(parsed))
                return parsed;
            return [imagesRaw];
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
/**
 * GET /share/marketplace/:id
 * Dynamic Open Graph & Twitter Card preview for campus marketplace listings.
 * Compatible with WhatsApp, Facebook, iMessage, Twitter/X, Telegram, Slack, and OpenGraph.io
 */
router.get('/marketplace/:id', async (req, res) => {
    try {
        const id = String(req.params.id);
        let item = null;
        try {
            item = await db_1.prisma.marketplaceItem.findUnique({
                where: { id },
                include: {
                    seller: {
                        select: {
                            id: true,
                            username: true,
                            fullName: true,
                            avatarUrl: true,
                        },
                    },
                },
            });
        }
        catch (dbErr) {
            console.warn('Share preview DB query fallback:', dbErr);
        }
        const title = item?.title ? `${item.title} — ₦${Number(item.price || 0).toLocaleString()} | ABUAD Marketplace` : 'ABUAD Campus Marketplace';
        const rawDesc = item?.description || 'Browse student listings, electronics, textbooks, fashion, and campus essentials on the ABUAD Marketplace.';
        const description = rawDesc.length > 200 ? rawDesc.substring(0, 197) + '...' : rawDesc;
        const images = safeParseImages(item?.images);
        const imageUrl = images.length > 0 ? images[0] : 'https://abuadapp.com.ng/og-image.jpg';
        const priceText = item?.price ? `₦${Number(item.price).toLocaleString()}` : '';
        const sellerName = item?.seller?.fullName || item?.seller?.username || 'ABUAD Student';
        const canonicalUrl = `https://abuadapp.com.ng/marketplace/detail?id=${encodeURIComponent(id)}`;
        const deepLinkUrl = `abuad://marketplace/detail?id=${encodeURIComponent(id)}`;
        res.setHeader('Cache-Control', 'public, max-age=3600, s-maxage=86400');
        res.type('html').send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(title)}</title>
  <meta name="description" content="${escapeHtml(description)}">
  <meta name="robots" content="index, follow">
  <link rel="canonical" href="${escapeHtml(canonicalUrl)}">
  <meta name="theme-color" content="#14B8A6">

  <!-- Open Graph / WhatsApp / Facebook / LinkedIn -->
  <meta property="og:type" content="product">
  <meta property="og:site_name" content="ABUAD Campus Marketplace">
  <meta property="og:url" content="${escapeHtml(canonicalUrl)}">
  <meta property="og:title" content="${escapeHtml(title)}">
  <meta property="og:description" content="${escapeHtml(description)}">
  <meta property="og:image" content="${escapeHtml(imageUrl)}">
  <meta property="og:image:secure_url" content="${escapeHtml(imageUrl)}">
  <meta property="og:image:alt" content="${escapeHtml(item?.title || 'ABUAD Marketplace Item')}">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="product:price:amount" content="${escapeHtml(String(item?.price || 0))}">
  <meta property="product:price:currency" content="NGN">

  <!-- Twitter / X / Discord -->
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:site" content="@abuad_app">
  <meta name="twitter:url" content="${escapeHtml(canonicalUrl)}">
  <meta name="twitter:title" content="${escapeHtml(title)}">
  <meta name="twitter:description" content="${escapeHtml(description)}">
  <meta name="twitter:image" content="${escapeHtml(imageUrl)}">
  <meta name="twitter:image:alt" content="${escapeHtml(item?.title || 'ABUAD Marketplace Item')}">

  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;600;700;800&display=swap" rel="stylesheet">

  <style>
    :root {
      --bg: #0b0f19;
      --card: rgba(255, 255, 255, 0.05);
      --border: rgba(255, 255, 255, 0.1);
      --text: #f8fafc;
      --muted: #94a3b8;
      --teal: #14b8a6;
      --teal-glow: rgba(20, 184, 166, 0.35);
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Plus Jakarta Sans', system-ui, -apple-system, sans-serif;
      background: radial-gradient(1200px 800px at 50% -10%, #1e1b4b 0%, #0b0f19 100%);
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
      backdrop-filter: blur(20px);
      -webkit-backdrop-filter: blur(20px);
      overflow: hidden;
      box-shadow: 0 25px 60px rgba(0, 0, 0, 0.6);
      animation: fadeIn 0.4s ease-out;
    }
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(16px); }
      to { opacity: 1; transform: translateY(0); }
    }
    .img-wrap {
      width: 100%;
      height: 280px;
      position: relative;
      background: #020617;
      display: flex;
      align-items: center;
      justify-content: center;
      overflow: hidden;
    }
    .img-wrap img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
    .price-pill {
      position: absolute;
      bottom: 14px;
      left: 14px;
      background: rgba(15, 23, 42, 0.85);
      backdrop-filter: blur(10px);
      border: 1px solid rgba(255, 255, 255, 0.15);
      padding: 6px 14px;
      border-radius: 20px;
      font-weight: 800;
      color: #38bdf8;
      font-size: 17px;
    }
    .badge {
      position: absolute;
      top: 14px;
      right: 14px;
      background: var(--teal);
      color: #042f2e;
      font-size: 11px;
      font-weight: 800;
      padding: 4px 10px;
      border-radius: 12px;
      letter-spacing: 0.5px;
    }
    .content {
      padding: 24px;
    }
    h1 {
      font-size: 20px;
      font-weight: 800;
      line-height: 1.35;
      margin-bottom: 8px;
    }
    .seller {
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 13px;
      color: var(--muted);
      margin-bottom: 14px;
    }
    p.desc {
      font-size: 14px;
      color: var(--muted);
      line-height: 1.5;
      margin-bottom: 24px;
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
    // Intelligent Redirect: If accessed by a student via regular browser, attempt app deep-link
    (function() {
      var isCrawler = /bot|googlebot|crawler|spider|robot|crawling|facebookexternalhit|whatsapp|slack|twitterbot|telegram|discord/i.test(navigator.userAgent);
      if (!isCrawler) {
        var deepLink = "${escapeHtml(deepLinkUrl)}";
        var webFallback = "${escapeHtml(canonicalUrl)}";
        
        // Try deep link
        window.location.href = deepLink;
        setTimeout(function() {
          // If app doesn't open within 1.2s, user stays on this card or clicks Web
        }, 1200);
      }
    })();
  </script>
</head>
<body>
  <div class="preview-card">
    <div class="img-wrap">
      <img src="${escapeHtml(imageUrl)}" alt="${escapeHtml(item?.title || 'Item')}" onerror="this.src='https://abuadapp.com.ng/og-image.jpg'">
      ${priceText ? `<div class="price-pill">${escapeHtml(priceText)}</div>` : ''}
      <div class="badge">ABUAD VERIFIED</div>
    </div>
    <div class="content">
      <h1>${escapeHtml(item?.title || 'Campus Marketplace Listing')}</h1>
      <div class="seller">
        <span>👤 Listed by <strong>${escapeHtml(sellerName)}</strong></span>
        <span>•</span>
        <span>${escapeHtml(item?.category || 'Student Deal')}</span>
      </div>
      <p class="desc">${escapeHtml(description)}</p>
      <div class="actions">
        <a href="${escapeHtml(deepLinkUrl)}" class="btn-primary">📲 Open in ABUAD App</a>
        <a href="${escapeHtml(canonicalUrl)}" class="btn-secondary">🌐 View on Web App</a>
      </div>
      <div class="footer-note">ABUAD Student Super-App • Campus Safety Verified</div>
    </div>
  </div>
</body>
</html>`);
    }
    catch (error) {
        console.error('Share preview error:', error);
        res.redirect('https://abuadapp.com.ng/marketplace');
    }
});
exports.default = router;
