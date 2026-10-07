# ☁️ Cloudflare Setup Guide for ABUAD App Backend

Follow these exact steps to obtain your Cloudflare credentials and add them to your `backend/.env` file.

---

## 🔑 1. Cloudflare Account ID & API Tokens

### Step A: Find Your Cloudflare Account ID
1. Log into your [Cloudflare Dashboard](https://dash.cloudflare.com/).
2. Select any domain or go to **Workers & Pages** in the left sidebar.
3. On the right panel, copy your **Account ID** string (a 32-character hexadecimal string).
4. Update `backend/.env`:
   ```env
   CLOUDFLARE_ACCOUNT_ID="your_copied_account_id"
   ```

---

## 🪣 2. Cloudflare R2 Object Storage (For Media & File Uploads)

### Step A: Create an R2 Bucket
1. In the Cloudflare Dashboard sidebar, click **R2**.
2. Click **Create bucket**.
3. Name the bucket: `abuad-media`.
4. Click **Create Bucket**.

### Step B: Generate R2 API Tokens (S3 Access Keys)
1. Go to **R2** > **Manage R2 API Tokens** (on the right sidebar).
2. Click **Create API Token**.
3. Set **Permissions** to **Edit** (Read & Write access).
4. Under **Bucket binding**, select `abuad-media`.
5. Click **Create API Token**.
6. Copy the generated credentials:
   - **Access Key ID** -> `CLOUDFLARE_R2_ACCESS_KEY_ID`
   - **Secret Access Key** -> `CLOUDFLARE_R2_SECRET_ACCESS_KEY`

### Step C: Enable Public Access Domain
1. Open your `abuad-media` bucket page in Cloudflare.
2. Go to **Settings** > **Public Access**.
3. Enable **R2.dev Subdomain** (or attach a custom domain like `cdn.abuad.edu.ng`).
4. Copy the Public URL (e.g. `https://pub-xxxx.r2.dev`).
5. Update `backend/.env`:
   ```env
   CLOUDFLARE_R2_BUCKET_NAME="abuad-media"
   CLOUDFLARE_R2_ACCESS_KEY_ID="your_r2_access_key_id"
   CLOUDFLARE_R2_SECRET_ACCESS_KEY="your_r2_secret_access_key"
   CLOUDFLARE_R2_PUBLIC_DOMAIN="https://pub-xxxx.r2.dev"
   ```

---

## 🤖 3. Cloudflare Workers AI

### Step A: Create Workers AI API Token
1. Go to **My Profile** > **API Tokens** in Cloudflare Dashboard.
2. Click **Create Token**.
3. Choose **Custom Token** template.
4. Set Token Name: `ABUAD Workers AI Token`.
5. Under **Permissions**, add:
   - `Account` -> `Workers AI` -> `Edit` (or `Read`)
6. Click **Continue to summary** -> **Create Token**.
7. Copy your generated token.
8. Update `backend/.env`:
   ```env
   CLOUDFLARE_AI_API_TOKEN="your_copied_workers_ai_token"
   CLOUDFLARE_AI_MODEL="@cf/meta/llama-3-8b-instruct"
   ```

---

## 📋 Summary of `backend/.env` Configuration

```env
PORT=5000
NODE_ENV=development
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/abuad_db?schema=public"

# JWT Authentication
JWT_ACCESS_SECRET="super-secret-access-token-key-abuad-2026"
JWT_REFRESH_SECRET="super-secret-refresh-token-key-abuad-2026"

# Cloudflare Credentials
CLOUDFLARE_ACCOUNT_ID="your_account_id"
CLOUDFLARE_R2_ACCESS_KEY_ID="your_access_key_id"
CLOUDFLARE_R2_SECRET_ACCESS_KEY="your_secret_access_key"
CLOUDFLARE_R2_BUCKET_NAME="abuad-media"
CLOUDFLARE_R2_PUBLIC_DOMAIN="https://pub-xxxx.r2.dev"
CLOUDFLARE_AI_API_TOKEN="your_ai_api_token"
```
