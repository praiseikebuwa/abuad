import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../domain/audio_track.dart';

final musicRepositoryProvider = Provider<MusicRepository>((ref) {
  return MusicRepository();
});

final trendingTracksProvider = FutureProvider<List<AudioTrack>>((ref) async {
  final repo = ref.watch(musicRepositoryProvider);
  return repo.getTrendingTracks();
});

final categoryTracksProvider =
    FutureProvider.family<List<AudioTrack>, String>((ref, category) async {
  final repo = ref.watch(musicRepositoryProvider);
  return repo.getTracksByCategory(category);
});

final musicSearchProvider =
    FutureProvider.family<List<AudioTrack>, String>((ref, query) async {
  final repo = ref.watch(musicRepositoryProvider);
  return repo.searchTracks(query);
});

/// Production Music Repository connecting to backend music service (/api/music).
/// Returns real tracks, official preview streams, HD artwork, and campus hits.
class MusicRepository {
  final Map<String, List<AudioTrack>> _cache = {};

  /// Fetch trending viral tracks
  Future<List<AudioTrack>> getTrendingTracks() async {
    const cacheKey = 'trending';
    if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.isNotEmpty) {
      return _cache[cacheKey]!;
    }

    final results = await _fetchFromBackend('/music/trending', cacheKey: cacheKey);
    if (results.isNotEmpty) return results;

    return _fallbackCatalog;
  }

  /// Fetch tracks by category with caching and offline fallback
  Future<List<AudioTrack>> getTracksByCategory(String category) async {
    final cacheKey = 'cat_${category.toLowerCase()}';
    if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.isNotEmpty) {
      return _cache[cacheKey]!;
    }

    final endpoint = '/music/category?name=${Uri.encodeComponent(category)}';
    final results = await _fetchFromBackend(endpoint, cacheKey: cacheKey);
    if (results.isNotEmpty) return results;

    // Fallback if offline or API limit
    return _getFallbackCategoryTracks(category);
  }

  /// Live search across backend music catalog
  Future<List<AudioTrack>> searchTracks(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return getTrendingTracks();
    }

    final cacheKey = 'q_${cleanQuery.toLowerCase()}';
    if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.isNotEmpty) {
      return _cache[cacheKey]!;
    }

    final endpoint = '/music/search?q=${Uri.encodeComponent(cleanQuery)}';
    final results = await _fetchFromBackend(endpoint, cacheKey: cacheKey);
    if (results.isNotEmpty) return results;

    // Fallback local search
    return _fallbackCatalog.where((t) {
      final q = cleanQuery.toLowerCase();
      final albumMatch = t.album?.toLowerCase().contains(q) ?? false;
      return t.title.toLowerCase().contains(q) ||
          t.artist.toLowerCase().contains(q) ||
          albumMatch ||
          t.tags.any((tag) => tag.toLowerCase().contains(q));
    }).toList();
  }

  /// Fetch tracks from Express backend service
  Future<List<AudioTrack>> _fetchFromBackend(String endpoint, {required String cacheKey}) async {
    try {
      final response = await ApiClient.get(endpoint).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['data'] as List<dynamic>? ?? [];

        final tracks = list
            .whereType<Map<String, dynamic>>()
            .map((item) => AudioTrack.fromMap(item))
            .where((t) => t.audioUrl.isNotEmpty && t.title.isNotEmpty)
            .toList();

        if (tracks.isNotEmpty) {
          _cache[cacheKey] = tracks;
          return tracks;
        }
      }
    } catch (e) {
      debugPrint('MusicRepository API error ($endpoint): $e');
    }
    return [];
  }

  List<AudioTrack> _getFallbackCategoryTracks(String category) {
    if (category == 'All' || category == 'Trending') {
      return _fallbackCatalog;
    }
    final filtered = _fallbackCatalog
        .where((t) => t.category.toLowerCase() == category.toLowerCase())
        .toList();
    return filtered.isNotEmpty ? filtered : _fallbackCatalog;
  }

  AudioTrack? getTrackById(String id) {
    for (final list in _cache.values) {
      final found = list.where((t) => t.id == id).firstOrNull;
      if (found != null) return found;
    }
    return _fallbackCatalog.where((t) => t.id == id).firstOrNull;
  }

  // Pre-cached resilient fallback catalog
  static const List<AudioTrack> _fallbackCatalog = [
    AudioTrack(
      id: 'fallback_asake_01',
      title: 'Lonely At The Top',
      artist: 'Asake',
      album: 'Work of Art',
      coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&auto=format&fit=crop&q=80',
      audioUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/9f/05/52/9f0552e5-8d75-cb72-f6bd-098ef8441cf2/mzaf_214968037439787785.plus.aac.p.m4a',
      duration: 30,
      category: 'Afrobeats',
      usesCount: 428000,
      isVerified: true,
      isTrending: true,
      tags: ['afrobeats', 'asake', 'viral', 'top'],
    ),
    AudioTrack(
      id: 'fallback_burna_02',
      title: 'City Boys',
      artist: 'Burna Boy',
      album: 'I Told Them...',
      coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=600&auto=format&fit=crop&q=80',
      audioUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/f0/b1/3e/f0b13efa-90fd-8227-060f-2d2ec8f98ded/mzaf_16033116745463791140.plus.aac.p.m4a',
      duration: 30,
      category: 'Afrobeats',
      usesCount: 512000,
      isVerified: true,
      isTrending: true,
      tags: ['afrobeats', 'burna', 'cityboys', 'dance'],
    ),
    AudioTrack(
      id: 'fallback_amapiano_03',
      title: 'Amapiano Log Drum Euphoria',
      artist: 'Kabza & DJ Maphi',
      album: 'Piano to the World',
      coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=600&auto=format&fit=crop&q=80',
      audioUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/9f/05/52/9f0552e5-8d75-cb72-f6bd-098ef8441cf2/mzaf_214968037439787785.plus.aac.p.m4a',
      duration: 32,
      category: 'Trending',
      usesCount: 194200,
      isVerified: true,
      isTrending: true,
      tags: ['amapiano', 'logdrum', 'dance', 'reels'],
    ),
    AudioTrack(
      id: 'fallback_lofi_04',
      title: 'College Library Midnight Chill',
      artist: 'Lo-Fi Chill Hop Beat',
      album: 'Night Owl Studies',
      coverUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=600&auto=format&fit=crop&q=80',
      audioUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/f0/b1/3e/f0b13efa-90fd-8227-060f-2d2ec8f98ded/mzaf_16033116745463791140.plus.aac.p.m4a',
      duration: 35,
      category: 'Chill & Lo-Fi',
      usesCount: 65400,
      isVerified: false,
      isTrending: false,
      tags: ['lofi', 'chill', 'study', 'relax', 'vlog'],
    ),
  ];
}
