import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/socket_service.dart';
import '../domain/advertisement.dart';
import '../../auth/data/auth_repository.dart';

class AdsEnabledNotifier extends StateNotifier<bool> {
  static const _cacheKey = 'system_ads_enabled';
  StreamSubscription? _socketSub;

  AdsEnabledNotifier() : super(true) {
    _init();
  }

  Future<void> _init() async {
    // 1. Load cached state immediately
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_cacheKey)) {
        state = prefs.getBool(_cacheKey) ?? true;
      }
    } catch (_) {}

    // 2. Listen to real-time socket updates from admin
    _socketSub = SocketService.instance.onConfigUpdated.listen((data) {
      if (data.containsKey('adsEnabled')) {
        final enabled = data['adsEnabled'] == true;
        _updateState(enabled);
      } else if (data['key'] == 'ads_enabled' || data['key'] == 'adsEnabled') {
        final val = data['value'];
        final enabled = val != false && val != 'false' && val != 0 && val != '0';
        _updateState(enabled);
      }
    });

    // 3. Fetch latest platform config from server
    await syncWithServer();
  }

  Future<void> syncWithServer() async {
    try {
      final res = await ApiClient.get('/admin/settings/ads');
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['adsEnabled'] != null) {
          final enabled = decoded['adsEnabled'] == true;
          await _updateState(enabled);
          return;
        }
      }
    } catch (_) {}

    try {
      final res = await ApiClient.get('/system/config');
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['data'] != null) {
          final data = decoded['data'];
          if (data is Map) {
            final rawAds = data['ads_enabled'] ?? data['adsEnabled'];
            if (rawAds != null) {
              final enabled = rawAds != false && rawAds != 'false';
              await _updateState(enabled);
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _updateState(bool enabled) async {
    if (state != enabled) {
      state = enabled;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_cacheKey, enabled);
    } catch (_) {}
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    super.dispose();
  }
}

final adsEnabledProvider = StateNotifierProvider<AdsEnabledNotifier, bool>((ref) {
  return AdsEnabledNotifier();
});

final advertisementRepositoryProvider = Provider<AdvertisementRepository>((ref) {
  return AdvertisementRepository();
});

final activeAdsProvider = StreamProvider<List<Advertisement>>((ref) {
  final isEnabled = ref.watch(adsEnabledProvider);
  if (!isEnabled) {
    return Stream.value(<Advertisement>[]);
  }
  final repo = ref.watch(advertisementRepositoryProvider);
  return repo.watchActiveAds();
});

final feedAdsProvider = StreamProvider<List<Advertisement>>((ref) {
  final isEnabled = ref.watch(adsEnabledProvider);
  if (!isEnabled) {
    return Stream.value(<Advertisement>[]);
  }
  final repo = ref.watch(advertisementRepositoryProvider);
  return repo.watchActiveAds(placement: 'feed');
});

final storyAdsProvider = StreamProvider<List<Advertisement>>((ref) {
  final isEnabled = ref.watch(adsEnabledProvider);
  if (!isEnabled) {
    return Stream.value(<Advertisement>[]);
  }
  final repo = ref.watch(advertisementRepositoryProvider);
  return repo.watchActiveAds(placement: 'story');
});

final marketplaceAdsProvider = StreamProvider<List<Advertisement>>((ref) {
  final isEnabled = ref.watch(adsEnabledProvider);
  if (!isEnabled) {
    return Stream.value(<Advertisement>[]);
  }
  final repo = ref.watch(advertisementRepositoryProvider);
  return repo.watchActiveAds(placement: 'marketplace');
});

final myAdsProvider = StreamProvider<List<Advertisement>>((ref) {
  final isEnabled = ref.watch(adsEnabledProvider);
  if (!isEnabled) {
    return Stream.value(<Advertisement>[]);
  }
  final repo = ref.watch(advertisementRepositoryProvider);
  final userId = ref.watch(authRepositoryProvider).currentUser?.uid ?? '';
  return repo.watchMyAds(userId);
});

class AdvertisementRepository {
  final List<Advertisement> _ads = [];
  final StreamController<List<Advertisement>> _adsController =
      StreamController<List<Advertisement>>.broadcast();

  AdvertisementRepository() {
    _seedInitialCampusAds();
  }

  void _seedInitialCampusAds() {
    if (_ads.isNotEmpty) return;

    _ads.addAll([
      Advertisement(
        id: 'ad_campus_thrift_1',
        advertiserId: 'official_abuad_thrift',
        advertiserName: 'Campus Vintage & Thrift Hub',
        advertiserAvatarUrl:
            'https://images.unsplash.com/photo-1558769132-cb1aea458c5e?w=150',
        title: '🔥 Vintage Campus Oversized Hoodies & Baggy Cargoes!',
        description:
            'Premium thrift fashion curated directly for ABUAD students. Fast hostel delivery across A & B wings. Limited pieces in stock!',
        mediaUrl:
            'https://images.unsplash.com/photo-1523381210434-271e8be1f52b?w=800',
        targetUrl: 'https://abuad.edu.ng',
        ctaLabel: 'Shop Now',
        marketplaceItemTitle: 'Vintage Acid-Wash Hoodie',
        marketplaceItemPrice: 8500,
        placements: ['feed', 'story', 'marketplace'],
        durationDays: 14,
        impressionsCount: 234,
        clicksCount: 42,
      ),
      Advertisement(
        id: 'ad_abuad_tech_2',
        advertiserId: 'abuad_tech_society',
        advertiserName: 'ABUAD DevHub & AI Club',
        advertiserAvatarUrl:
            'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
        title: '🚀 Learn Mobile & AI Engineering on Campus',
        description:
            'Join weekly hands-on workshops with student builders. Build production Flutter and Cloud apps with peer mentorship.',
        mediaUrl:
            'https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?w=800',
        targetUrl: 'https://abuad.edu.ng',
        ctaLabel: 'Learn More',
        placements: ['feed', 'story'],
        durationDays: 30,
        impressionsCount: 512,
        clicksCount: 88,
      ),
      Advertisement(
        id: 'ad_campus_eats_3',
        advertiserId: 'cafeteria_express',
        advertiserName: 'ABUAD Gourmet & Smoothies',
        advertiserAvatarUrl:
            'https://images.unsplash.com/photo-1577219491135-ce391730fb2c?w=150',
        title: '🍔 Late Night Shawarma & Fresh Parfait Deliveries',
        description:
            'Study sessions made delicious. Fresh fruit smoothies, spicy grills, and shawarma right to your hostel doorsteps till 11 PM.',
        mediaUrl:
            'https://images.unsplash.com/photo-1561758033-d89a9ad46330?w=800',
        targetUrl: 'https://abuad.edu.ng',
        ctaLabel: 'Order Now',
        placements: ['feed', 'marketplace'],
        durationDays: 7,
        impressionsCount: 389,
        clicksCount: 65,
      ),
    ]);

    _emit();
  }

  void _emit() {
    _adsController.add(List<Advertisement>.from(_ads));
  }

  Stream<List<Advertisement>> watchActiveAds({String? placement}) async* {
    yield _getActiveAdsList(placement: placement);
    await for (final list in _adsController.stream) {
      yield _filterActive(list, placement: placement);
    }
  }

  List<Advertisement> _getActiveAdsList({String? placement}) {
    return _filterActive(_ads, placement: placement);
  }

  List<Advertisement> _filterActive(List<Advertisement> source, {String? placement}) {
    return source.where((ad) {
      if (!ad.isActive) return false;
      if (placement != null && !ad.hasPlacement(placement)) return false;
      return true;
    }).toList();
  }

  Stream<List<Advertisement>> watchMyAds(String userId) async* {
    yield _ads.where((ad) => ad.advertiserId == userId).toList();
    await for (final list in _adsController.stream) {
      yield list.where((ad) => ad.advertiserId == userId).toList();
    }
  }

  Future<Advertisement> createAdvertisement({
    required String advertiserId,
    required String advertiserName,
    String? advertiserAvatarUrl,
    required String title,
    required String description,
    required String mediaUrl,
    String mediaType = 'image',
    required String targetUrl,
    String? marketplaceItemId,
    String? marketplaceItemTitle,
    double? marketplaceItemPrice,
    required String ctaLabel,
    required List<String> placements,
    int durationDays = 7,
  }) async {
    final ad = Advertisement(
      advertiserId: advertiserId,
      advertiserName: advertiserName,
      advertiserAvatarUrl: advertiserAvatarUrl,
      title: title,
      description: description,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      targetUrl: targetUrl,
      marketplaceItemId: marketplaceItemId,
      marketplaceItemTitle: marketplaceItemTitle,
      marketplaceItemPrice: marketplaceItemPrice,
      ctaLabel: ctaLabel,
      placements: placements,
      durationDays: durationDays,
    );

    _ads.insert(0, ad);
    _emit();
    return ad;
  }

  void recordImpression(String adId) {
    final index = _ads.indexWhere((a) => a.id == adId);
    if (index != -1) {
      final ad = _ads[index];
      _ads[index] = ad.copyWith(impressionsCount: ad.impressionsCount + 1);
      _emit();
    }
  }

  Future<void> recordClickAndLaunch(Advertisement ad) async {
    final index = _ads.indexWhere((a) => a.id == ad.id);
    if (index != -1) {
      _ads[index] = ad.copyWith(clicksCount: ad.clicksCount + 1);
      _emit();
    }

    if (ad.targetUrl.trim().isNotEmpty) {
      try {
        var rawUrl = ad.targetUrl.trim();
        if (!rawUrl.startsWith('http://') && !rawUrl.startsWith('https://')) {
          rawUrl = 'https://$rawUrl';
        }
        final uri = Uri.parse(rawUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        debugPrint('Error launching ad URL: $e');
      }
    }
  }

  void toggleAdStatus(String adId) {
    final index = _ads.indexWhere((a) => a.id == adId);
    if (index != -1) {
      final current = _ads[index];
      final newStatus = current.status == AdStatus.active
          ? AdStatus.paused
          : AdStatus.active;
      _ads[index] = current.copyWith(status: newStatus);
      _emit();
    }
  }

  void deleteAd(String adId) {
    _ads.removeWhere((a) => a.id == adId);
    _emit();
  }
}
