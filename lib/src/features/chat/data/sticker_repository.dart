import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/api_client.dart';
import '../domain/sticker_item.dart';

final stickerRepositoryProvider = Provider<StickerRepository>((ref) {
  return StickerRepository();
});

class StickerRepository {
  static const String _savedStickersKey = 'saved_stickers_tray_v1';
  static const String _myCreationsKey = 'my_created_stickers_v1';

  final List<StickerItem> _curatedSeeds = [
    const StickerItem(
      id: 'seed_hostel_curfew',
      title: 'Hostel Curfew 🏃‍♂️💨',
      imageUrl: 'https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=400&q=80',
      type: 'MEME',
      category: 'CAMPUS',
      tags: ['hostel', 'curfew', 'abuad', 'run'],
      usageCount: 142,
      isPublic: true,
      authorName: 'ABUAD Campus Life',
      isSaved: true,
    ),
    const StickerItem(
      id: 'seed_cafeteria_rice',
      title: 'Cafeteria Rice & Turkey 🍗',
      imageUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=400&q=80',
      type: 'PHOTO',
      category: 'CAMPUS',
      tags: ['food', 'cafeteria', 'turkey', 'lunch'],
      usageCount: 98,
      isPublic: true,
      authorName: 'ABUAD Foodies',
      isSaved: true,
    ),
    const StickerItem(
      id: 'seed_exam_mood',
      title: 'Exam TDB Mood 📚😵',
      imageUrl: 'https://images.unsplash.com/photo-1509062522246-3755977927d7?auto=format&fit=crop&w=400&q=80',
      type: 'MEME',
      category: 'STUDY',
      tags: ['exam', 'tdb', 'nightclass', 'reading'],
      usageCount: 215,
      isPublic: true,
      authorName: 'Study Committee',
      isSaved: true,
    ),
    const StickerItem(
      id: 'seed_chapel_sunday',
      title: 'Chapel 75% Attendance 🙏👔',
      imageUrl: 'https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&w=400&q=80',
      type: 'PHOTO',
      category: 'CAMPUS',
      tags: ['chapel', 'sunday', 'attendance', 'smart'],
      usageCount: 180,
      isPublic: true,
      authorName: 'Chapel Fellowship',
      isSaved: true,
    ),
    const StickerItem(
      id: 'seed_fire_reaction',
      title: 'ABUAD On Fire 🔥',
      imageUrl: 'https://images.unsplash.com/photo-1519750783826-e2420f4d687f?auto=format&fit=crop&w=400&q=80',
      type: 'DOODLE',
      category: 'REACTION',
      tags: ['fire', 'lit', 'hype', 'vibes'],
      usageCount: 310,
      isPublic: true,
      authorName: 'Campus Trends',
      isSaved: true,
    ),
    const StickerItem(
      id: 'seed_engineer_vibes',
      title: 'Engineering Lab Stress ⚙️',
      imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=400&q=80',
      type: 'MEME',
      category: 'STUDY',
      tags: ['engineering', 'coe', 'lab', 'abuad'],
      usageCount: 88,
      isPublic: true,
      authorName: 'COE ABUAD',
    ),
  ];

  /// Fetch trending stickers sorted by student usage count
  Future<List<StickerItem>> getTrendingStickers() async {
    try {
      final res = await ApiClient.get('/stickers/trending');
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['data'] is List) {
          final list = (decoded['data'] as List)
              .map((e) => StickerItem.fromJson(e as Map<String, dynamic>))
              .toList();
          if (list.isNotEmpty) return list;
        }
      }
    } catch (e) {
      debugPrint('StickerRepository.getTrendingStickers error: $e');
    }

    // Fallback sorted seeds
    final fallback = List<StickerItem>.from(_curatedSeeds)
      ..sort((a, b) => b.usageCount.compareTo(a.usageCount));
    return fallback;
  }

  /// Fetch community public stickers by category or search query
  Future<List<StickerItem>> getCommunityStickers({
    String? category,
    String? search,
  }) async {
    try {
      final params = <String>[];
      if (category != null && category.isNotEmpty && category.toUpperCase() != 'ALL') {
        params.add('category=${Uri.encodeComponent(category.toUpperCase())}');
      }
      if (search != null && search.trim().isNotEmpty) {
        params.add('search=${Uri.encodeComponent(search.trim())}');
      }
      final queryStr = params.isNotEmpty ? '?${params.join('&')}' : '';

      final res = await ApiClient.get('/stickers/community$queryStr');
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['data'] is List) {
          final list = (decoded['data'] as List)
              .map((e) => StickerItem.fromJson(e as Map<String, dynamic>))
              .toList();
          if (list.isNotEmpty) return list;
        }
      }
    } catch (e) {
      debugPrint('StickerRepository.getCommunityStickers error: $e');
    }

    // Fallback filtered seeds
    var filtered = _curatedSeeds.where((s) => s.isPublic).toList();
    if (category != null && category.isNotEmpty && category.toUpperCase() != 'ALL') {
      filtered = filtered.where((s) => s.category.toUpperCase() == category.toUpperCase()).toList();
    }
    if (search != null && search.trim().isNotEmpty) {
      final q = search.toLowerCase();
      filtered = filtered.where((s) =>
        s.title.toLowerCase().contains(q) ||
        s.tags.any((t) => t.toLowerCase().contains(q))
      ).toList();
    }
    return filtered;
  }

  /// Fetch user's saved favorites tray and personal creations
  Future<List<StickerItem>> getMyStickers() async {
    List<StickerItem> localSaved = await _loadLocalSavedStickers();
    List<StickerItem> localCreated = await _loadLocalCreatedStickers();

    try {
      final res = await ApiClient.get('/stickers/my');
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['data'] is List) {
          final serverItems = (decoded['data'] as List)
              .map((e) => StickerItem.fromJson(e as Map<String, dynamic>))
              .toList();

          // Merge server items with local items (avoiding duplicates)
          final map = <String, StickerItem>{};
          for (final item in serverItems) {
            map[item.id] = item;
          }
          for (final item in localCreated) {
            map[item.id] = item;
          }
          for (final item in localSaved) {
            map[item.id] = item;
          }
          return map.values.toList();
        }
      }
    } catch (e) {
      debugPrint('StickerRepository.getMyStickers error: $e');
    }

    // Merge local creations + saved seeds
    final map = <String, StickerItem>{};
    for (final s in _curatedSeeds.where((s) => s.isSaved)) {
      map[s.id] = s;
    }
    for (final s in localSaved) {
      map[s.id] = s;
    }
    for (final s in localCreated) {
      map[s.id] = s;
    }
    return map.values.toList();
  }

  /// Create and publish/save a new sticker
  Future<StickerItem?> createSticker({
    required String title,
    required String imageUrl,
    String? animatedUrl,
    required String type,
    required String category,
    List<String> tags = const [],
    bool isPublic = true,
  }) async {
    final body = {
      'title': title,
      'imageUrl': imageUrl,
      if (animatedUrl != null && animatedUrl.isNotEmpty) 'animatedUrl': animatedUrl,
      'type': type.toUpperCase(),
      'category': category.toUpperCase(),
      'tags': tags,
      'isPublic': isPublic,
    };

    StickerItem? createdItem;

    try {
      final res = await ApiClient.post('/stickers', body);
      if (res.statusCode == 201 || res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['data'] != null) {
          createdItem = StickerItem.fromJson(decoded['data']);
        }
      }
    } catch (e) {
      debugPrint('StickerRepository.createSticker server call error: $e');
    }

    // Always create local fallback instance so user has 0-latency creation
    createdItem ??= StickerItem(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      imageUrl: imageUrl,
      animatedUrl: animatedUrl,
      type: type.toUpperCase(),
      category: category.toUpperCase(),
      tags: tags,
      isPublic: isPublic,
      usageCount: 1,
      isSaved: true,
      createdAt: DateTime.now(),
    );

    await _saveLocalCreatedSticker(createdItem);
    return createdItem;
  }

  /// Record usage count
  Future<void> useSticker(String stickerId) async {
    try {
      await ApiClient.post('/stickers/$stickerId/use', {});
    } catch (_) {}
  }

  /// Save sticker to collection
  Future<void> saveSticker(StickerItem sticker) async {
    try {
      await ApiClient.post('/stickers/${sticker.id}/save', {});
    } catch (_) {}
    await _addLocalSavedSticker(sticker.copyWith(isSaved: true));
  }

  /// Remove sticker from collection
  Future<void> unsaveSticker(String stickerId) async {
    try {
      await ApiClient.delete('/stickers/$stickerId/save');
    } catch (_) {}
    await _removeLocalSavedSticker(stickerId);
  }

  // ── Local Storage Cache ──────────────────────────────────────────────────

  Future<List<StickerItem>> _loadLocalSavedStickers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_savedStickersKey);
      if (str != null && str.isNotEmpty) {
        final list = (jsonDecode(str) as List)
            .map((e) => StickerItem.fromJson(e as Map<String, dynamic>))
            .toList();
        return list;
      }
    } catch (e) {
      debugPrint('Error loading saved stickers: $e');
    }
    return [];
  }

  Future<void> _addLocalSavedSticker(StickerItem item) async {
    try {
      final list = await _loadLocalSavedStickers();
      list.removeWhere((s) => s.id == item.id || (s.imageUrl.isNotEmpty && s.imageUrl == item.imageUrl));
      list.insert(0, item);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_savedStickersKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('Error adding saved sticker: $e');
    }
  }

  Future<void> _removeLocalSavedSticker(String stickerId) async {
    try {
      final list = await _loadLocalSavedStickers();
      list.removeWhere((s) => s.id == stickerId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_savedStickersKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('Error removing saved sticker: $e');
    }
  }

  Future<List<StickerItem>> _loadLocalCreatedStickers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_myCreationsKey);
      if (str != null && str.isNotEmpty) {
        final list = (jsonDecode(str) as List)
            .map((e) => StickerItem.fromJson(e as Map<String, dynamic>))
            .toList();
        return list;
      }
    } catch (e) {
      debugPrint('Error loading created stickers: $e');
    }
    return [];
  }

  Future<void> _saveLocalCreatedSticker(StickerItem item) async {
    try {
      final list = await _loadLocalCreatedStickers();
      list.removeWhere((s) => s.id == item.id);
      list.insert(0, item);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_myCreationsKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('Error saving created sticker: $e');
    }
  }
}
