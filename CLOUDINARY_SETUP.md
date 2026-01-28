# 🌥️ Cloudinary Setup Guide for ABUAD App

This guide will walk you through setting up Cloudinary for image and video uploads in your ABUAD application.

## 📋 Table of Contents
1. [Why Cloudinary?](#why-cloudinary)
2. [Getting Your Credentials](#getting-your-credentials)
3. [Configuring the App](#configuring-the-app)
4. [Testing the Integration](#testing-the-integration)
5. [Troubleshooting](#troubleshooting)

---

## 🤔 Why Cloudinary?

Cloudinary is a cloud-based media management service that provides:
- ✅ **Free tier** (25 GB storage, 25 GB bandwidth/month)
- ✅ **Automatic image optimization**
- ✅ **CDN delivery** (fast worldwide)
- ✅ **Image transformations** (resize, crop, filters)
- ✅ **Video support**
- ✅ **Easy integration**

---

## 🔑 Getting Your Credentials

### Step 1: Create a Cloudinary Account
1. Go to [https://cloudinary.com/](https://cloudinary.com/)
2. Click **"Sign Up for Free"**
3. Fill in your details or sign up with Google
4. Verify your email address

### Step 2: Find Your Cloud Name
1. After logging in, you'll see your **Dashboard**
2. Look for the **"Account Details"** section (top-left)
3. Find your **Cloud name** (e.g., `dxxxxxx` or `my-cloud-name`)
4. **Copy this value** - you'll need it!

### Step 3: Create an Upload Preset
An upload preset allows your app to upload files without exposing your API secret.

1. In Cloudinary Dashboard, click **Settings** (gear icon, bottom-left)
2. Go to the **"Upload"** tab
3. Scroll down to **"Upload presets"** section
4. Click **"Add upload preset"**
5. Configure the preset:
   - **Preset name**: `abuad_app` (or any name you prefer)
   - **Signing Mode**: Select **"Unsigned"** ⚠️ (Important!)
   - **Folder**: `abuad_app` (optional, helps organize)
   - Leave other settings as default
6. Click **"Save"**
7. **Copy the preset name** - you'll need it!

### Step 4: (Optional) Configure Upload Settings
While still in Upload presets settings:
- **Auto tagging**: Disabled (leave default)
- **Incoming transformations**: None (leave default)
- **Eager transformations**: Add thumbnail generation if needed
- **Access control**: Leave as default

---

## ⚙️ Configuring the App

### Option 1: Direct Configuration (Quick Start)

1. **Open the config file:**
   ```
   lib/src/core/config/cloudinary_config.dart
   ```

2. **Replace the placeholder values:**
   ```dart
   class CloudinaryConfig {
     // Replace with your actual cloud name
     static const String cloudName = 'YOUR_CLOUD_NAME_HERE';  // ← Change this
     
     // Replace with your upload preset name
     static const String uploadPreset = 'YOUR_UPLOAD_PRESET_HERE';  // ← Change this
     
     // Optional: Change folder name if you used a different one
     static const String uploadFolder = 'abuad_app';
   }
   ```

3. **Example with real values:**
   ```dart
   class CloudinaryConfig {
     static const String cloudName = 'djsdhkmgx';      // Your cloud name
     static const String uploadPreset = 'abuad_app';    // Your preset name
     static const String uploadFolder = 'abuad_app';
   }
   ```

4. **Save the file** and rebuild your app

### Option 2: Environment Variables (Production Best Practice)

For better security in production, use environment variables:

1. **Create `.env` file in project root:**
   ```
   CLOUDINARY_CLOUD_NAME=your_cloud_name_here
   CLOUDINARY_UPLOAD_PRESET=your_preset_here
   ```

2. **Add `flutter_dotenv` to `pubspec.yaml`:**
   ```yaml
   dependencies:
     flutter_dotenv: ^5.1.0
   ```

3. **Load in `main.dart`:**
   ```dart
   import 'package:flutter_dotenv/flutter_dotenv.dart';
   
   Future<void> main() async {
     await dotenv.load(fileName: ".env");
     runApp(MyApp());
   }
   ```

4. **Update `cloudinary_config.dart`:**
   ```dart
   import 'package:flutter_dotenv/flutter_dotenv.dart';
   
   class CloudinaryConfig {
     static String get cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
     static String get uploadPreset => dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';
     static const String uploadFolder = 'abuad_app';
   }
   ```

5. **Add `.env` to `.gitignore`:**
   ```
   .env
   ```

---

## 🧪 Testing the Integration

### 1. Build and Run the App
```bash
flutter pub get
flutter run
```

### 2. Test Image Upload
1. Open the app
2. Go to **Profile** screen
3. Tap the **camera icon** on your avatar or banner
4. Select an image from gallery or take a photo
5. Wait for upload (you'll see loading indicator)
6. Check if image appears

### 3. Verify Upload in Cloudinary
1. Go to Cloudinary Dashboard
2. Click **"Media Library"** (left sidebar)
3. Navigate to the `abuad_app` folder
4. You should see your uploaded image!

### 4. Test in Other Screens
Try uploading images in:
- ✅ Profile (avatar & banner)
- ✅ Create Post (post images)
- ✅ Complete Profile (onboarding)

---

## 🐛 Troubleshooting

### Error: "Cloudinary is not configured"
**Problem:** You haven't updated the credentials in `cloudinary_config.dart`

**Solution:**
1. Open `lib/src/core/config/cloudinary_config.dart`
2. Replace `YOUR_CLOUD_NAME_HERE` with your actual cloud name
3. Replace `YOUR_UPLOAD_PRESET_HERE` with your actual preset name
4. Rebuild the app

---

### Error: "Invalid cloud name"
**Problem:** The cloud name is incorrect

**Solution:**
1. Go to Cloudinary Dashboard
2. Check the **Cloud name** in Account Details (top-left)
3. Copy it exactly as shown
4. Update `cloudinary_config.dart`

---

### Error: "Upload preset not found"
**Problem:** The upload preset doesn't exist or is misspelled

**Solution:**
1. Go to Cloudinary Settings > Upload > Upload presets
2. Verify the preset name (case-sensitive!)
3. Make sure **Signing Mode** is set to **"Unsigned"**
4. Update `cloudinary_config.dart` with the exact preset name

---

### Error: "Upload failed: 401 Unauthorized"
**Problem:** The upload preset is not set to "Unsigned"

**Solution:**
1. Go to Cloudinary Settings > Upload > Upload presets
2. Edit your preset
3. Change **Signing Mode** to **"Unsigned"**
4. Save and try again

---

### Upload is Very Slow
**Problem:** Network or file size issue

**Solution:**
- Check your internet connection
- Images are automatically compressed before upload
- For very large images, it may take 10-30 seconds
- Consider reducing image quality in `image_picker` settings

---

### Images Not Appearing
**Problem:** URL might be incorrect or CORS issue

**Solution:**
1. Check the uploaded image URL in console logs
2. Open the URL in a browser to verify it works
3. Make sure the URL starts with `https://`
4. Check Cloudinary Media Library to confirm upload

---

## 📊 Cloudinary Limits (Free Tier)

| Resource | Limit |
|----------|-------|
| Storage | 25 GB |
| Bandwidth | 25 GB/month |
| Transformations | 25 credits/month |
| Total images/videos | Unlimited |
| Request rate | 500/hour |

**Tip:** Monitor usage in Cloudinary Dashboard > Reports

---

## 🔒 Security Best Practices

1. ✅ **Use unsigned presets** for client uploads
2. ✅ **Never commit API credentials** to Git
3. ✅ **Use `.env` files** for production
4. ✅ **Enable Upload restrictions** in preset settings:
   - Max file size: 10 MB
   - Allowed formats: jpg, png, gif, mp4
5. ✅ **Configure Firestore rules** to validate Cloudinary URLs
6. ✅ **Set up webhooks** for upload notifications (optional)

---

## 📚 Additional Resources

- [Cloudinary Documentation](https://cloudinary.com/documentation)
- [Flutter Upload Guide](https://cloudinary.com/documentation/flutter_integration)
- [Upload Presets Guide](https://cloudinary.com/documentation/upload_presets)
- [Media Optimization](https://cloudinary.com/documentation/image_optimization)

---

## ✅ Quick Checklist

Before going to production, make sure:

- [ ] Created Cloudinary account
- [ ] Copied Cloud Name
- [ ] Created unsigned upload preset
- [ ] Updated `cloudinary_config.dart` with real credentials
- [ ] Tested image upload in Profile screen
- [ ] Tested image upload in Create Post screen
- [ ] Verified images appear in Cloudinary Media Library
- [ ] Set up `.env` file for production (optional but recommended)
- [ ] Added `.env` to `.gitignore`
- [ ] Configured upload restrictions in preset
- [ ] Tested on both iOS and Android (if applicable)

---

## 🎉 You're All Set!

Your ABUAD app is now configured to upload images and videos to Cloudinary. Users can:
- Upload profile pictures and banners
- Share photos in posts
- Upload media in chats
- Create stories with images/videos

All media is automatically optimized, stored securely, and delivered via CDN for fast loading worldwide! 🚀

---

**Need Help?** Check the [Troubleshooting](#troubleshooting) section or contact Cloudinary support at support@cloudinary.com
