import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gal/gal.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';

class MediaSaver {
  /// Save a local captured XFile directly to gallery (for photo or video)
  static Future<bool> saveLocalFile(XFile file, {bool isVideo = false}) async {
    // 1. Web fallback: trigger browser download
    if (kIsWeb) {
      try {
        final ext = isVideo ? 'mp4' : 'png';
        await file.saveTo('abuad_${DateTime.now().millisecondsSinceEpoch}.$ext');
        return true;
      } catch (e) {
        debugPrint('MediaSaver web save error: $e');
        return false;
      }
    }

    // 2. Prepare file with guaranteed extension on mobile
    String filePath = file.path;
    try {
      final ext = isVideo ? '.mp4' : '.png';
      final lower = filePath.toLowerCase();
      final hasExt = lower.endsWith('.png') ||
          lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.mp4') ||
          lower.endsWith('.mov') ||
          lower.endsWith('.webp');

      if (!hasExt) {
        final tempDir = await getTemporaryDirectory();
        final safePath =
            '${tempDir.path}/abuad_export_${DateTime.now().millisecondsSinceEpoch}$ext';
        final bytes = await file.readAsBytes();
        final safeFile = File(safePath);
        await safeFile.writeAsBytes(bytes);
        filePath = safeFile.path;
      }
    } catch (e) {
      debugPrint('MediaSaver prepare file error: $e');
    }

    // 3. Request permissions via Gal and permission_handler if needed
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          if (isVideo) {
            await Permission.videos.request();
          } else {
            await Permission.photos.request();
          }
          await Permission.storage.request();
        }
      }
    } catch (e) {
      debugPrint('MediaSaver permission request error: $e');
    }

    // 4. Primary attempt: save using Gal
    try {
      if (isVideo) {
        await Gal.putVideo(filePath);
      } else {
        final bytes = await file.readAsBytes();
        await Gal.putImageBytes(
          bytes,
          name: 'abuad_${DateTime.now().millisecondsSinceEpoch}',
        );
      }
      return true;
    } catch (galError) {
      debugPrint('Gal save failed ($galError), attempting PhotoManager fallback...');
    }

    // 5. Secondary fallback: save using PhotoManager
    try {
      if (isVideo) {
        await PhotoManager.editor.saveVideo(
          File(filePath),
          title: 'abuad_${DateTime.now().millisecondsSinceEpoch}.mp4',
        );
        return true;
      } else {
        final bytes = await file.readAsBytes();
        await PhotoManager.editor.saveImage(
          bytes,
          filename: 'abuad_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        return true;
      }
    } catch (pmError) {
      debugPrint('PhotoManager fallback failed: $pmError');
    }

    return false;
  }

  /// Save an image URL to gallery or download via browser if on Web/Desktop without Gal channel
  static Future<bool> saveImage(String url) async {
    if (url.isEmpty) return false;

    if (kIsWeb) {
      try {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return true;
        }
      } catch (e) {
        debugPrint('Error launching image URL on web: $e');
      }
      return false;
    }

    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) return false;
      }

      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}/abuad_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await Dio().download(url, path);
      await Gal.putImage(path);
      return true;
    } catch (e) {
      debugPrint('Gal saveImage error: $e');
      // Fallback for web / unsupported platform channels
      try {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return true;
        }
      } catch (_) {}
      return false;
    }
  }

  /// Save a video URL to gallery or download via browser if on Web/Desktop
  static Future<bool> saveVideo(String url) async {
    if (url.isEmpty) return false;

    if (kIsWeb) {
      try {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return true;
        }
      } catch (e) {
        debugPrint('Error launching video URL on web: $e');
      }
      return false;
    }

    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) return false;
      }

      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}/abuad_${DateTime.now().millisecondsSinceEpoch}.mp4';

      await Dio().download(url, path);
      await Gal.putVideo(path);
      return true;
    } catch (e) {
      debugPrint('Gal saveVideo error: $e');
      try {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return true;
        }
      } catch (_) {}
      return false;
    }
  }
}
