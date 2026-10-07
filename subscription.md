Great idea! Let me design a subscription system that makes sense for ABUAD's campus app. Here's my full proposal:

---

## 💳 Subscription Tiers

I'd recommend **3 tiers** on top of Free:

| Feature | 🆓 Free | ⚡ Plus | 🔥 Pro | 👑 Ultra |
|---|---|---|---|---|
| **Price (monthly)** | ₦0 | ₦500 | ₦1,500 | ₦3,500 |
| **Price (yearly)** | — | ₦4,500 | ₦13,500 | ₦30,000 |
| Feed posts per day | 5 | 15 | Unlimited | Unlimited |
| Story uploads | 1/day | 5/day | 15/day | Unlimited |
| Marketplace listings | 3 | 10 | 30 | Unlimited |
| Chat message history | 7 days | 30 days | 90 days | Forever |
| Media upload size | 10MB | 50MB | 200MB | 1GB |
| AI assistant (ask AI) | 5/day | 20/day | 60/day | Unlimited |
| **Verification badge** | ❌ | Blue ✓ | Blue ✓ | Gold ✓ |
| Profile customization | Basic | Banner + bio | Full themes | Exclusive themes |
| Post boost / reach | ❌ | ❌ | 2/month | 5/month |
| Analytics (post stats) | ❌ | Basic | Full | Full + export |
| Priority support | ❌ | ❌ | ✅ | ✅ |
| Ad-free experience | ❌ | ❌ | ✅ | ✅ |
| Early access features | ❌ | ❌ | ❌ | ✅ |
| Close friends (stories) | ❌ | 10 | 30 | Unlimited |
| Exclusive Ultra badge | ❌ | ❌ | ❌ | 👑 |

---

## 🏗️ How We'll Build It

### Architecture

```
Flutter App
    │
    ├── Flutterwave SDK (payment)
    │       └── /api/payments/initiate  (backend creates transaction)
    │       └── /api/payments/verify    (backend verifies with Flutterwave)
    │
    └── /api/subscriptions/me          (current plan)
        /api/subscriptions/upgrade     (trigger payment)
        /api/subscriptions/cancel
```

### Database (Prisma)
Add `Subscription` and `Payment` models to `schema.prisma`, and a `plan` field on `User`.

### Flutterwave Flow
1. User taps **Upgrade** in app
2. Flutter calls `POST /api/payments/initiate` → backend creates a Flutterwave transaction with `tx_ref`
3. Flutter opens **Flutterwave payment sheet** (using their Flutter SDK)
4. After payment, Flutterwave redirects/calls webhook → `POST /api/payments/webhook`
5. Backend verifies transaction with Flutterwave API → updates user's plan in DB
6. User instantly gets their new features

---

**Should I go ahead and implement it?** I'll need to:
1. Add `Subscription` + `Payment` to the Prisma schema
2. Build `/api/payments` and `/api/subscriptions` backend routes
3. Add `flutterwave_flutter` package to Flutter
4. Build the **Subscription/Upgrade screen** in Flutter
5. Add feature-gating logic (check plan before allowing actions)

Just say **"yes, build it"** and I'll implement the full system. Or let me know if you want to adjust the tiers/pricing/features first.