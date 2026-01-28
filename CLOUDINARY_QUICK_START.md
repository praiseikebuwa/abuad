# 🌥️ CLOUDINARY QUICK REFERENCE

## 📍 Your Credentials Location
**File:** `lib/src/core/config/cloudinary_config.dart`

## ⚡ Quick Setup (3 Steps)

### 1️⃣ Get Your Cloud Name
1. Go to https://cloudinary.com/console
2. Find "Cloud name" in Account Details (top-left)
3. Copy it (example: `djsdhkmgx`)

### 2️⃣ Create Upload Preset
1. Settings → Upload → Upload presets
2. Click "Add upload preset"
3. Name: `abuad_app`
4. **Signing Mode: "Unsigned"** ⚠️
5. Save and copy the name

### 3️⃣ Update Config File
Open: `lib/src/core/config/cloudinary_config.dart`

Replace:
```dart
static const String cloudName = 'YOUR_CLOUD_NAME_HERE';
static const String uploadPreset = 'YOUR_UPLOAD_PRESET_HERE';
```

With your actual values:
```dart
static const String cloudName = 'djsdhkmgx';        // ← Your cloud name
static const String uploadPreset = 'abuad_app';     // ← Your preset name
```

## ✅ That's It!
Save, rebuild, and test uploading an image in the Profile screen.

---

## 📂 Files Updated

✅ `lib/src/core/config/cloudinary_config.dart` - **Main config** (UPDATE THIS!)
✅ `lib/src/core/services/cloudinary_service.dart` - Image/video upload service
✅ `lib/src/core/services/image_upload_service.dart` - Chat image upload service
✅ `CLOUDINARY_SETUP.md` - Full setup guide with troubleshooting

---

## 🧪 Test Locations

Upload images in these screens to verify:
- ✅ Profile → Camera icon (avatar/banner)
- ✅ Feed → Create Post → Add images
- ✅ Auth → Complete Profile → Add photo

---

## 🆘 Common Errors

| Error | Solution |
|-------|----------|
| "Cloudinary is not configured" | Update `cloudinary_config.dart` with real values |
| "Invalid cloud name" | Check cloud name in Cloudinary dashboard |
| "Upload preset not found" | Verify preset name and ensure it's "Unsigned" |
| "401 Unauthorized" | Change preset to "Unsigned" mode |

---

## 📊 Free Tier Limits
- **Storage:** 25 GB
- **Bandwidth:** 25 GB/month
- **Enough for:** 25,000+ images or 100+ hours of video

---

**Full Guide:** See `CLOUDINARY_SETUP.md` for detailed instructions
