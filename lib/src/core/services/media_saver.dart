import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class MediaSaver {
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
