import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../../../core/utils/url_validator.dart';

class MarketplaceItem {
  final String id;
  final String title;
  final String description;
  final double price;
  final String category;
  final String sellerId;
  final String sellerName;
  final List<String> images;

  String? get imageUrl => images.isNotEmpty ? images.first : null;
  final String status;
  final DateTime createdAt;
  final bool isBoosted;
  final Map<String, String> reactions;
  final String? condition;
  final String? location;

  MarketplaceItem({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.sellerId,
    required this.sellerName,
    this.images = const [],
    this.status = 'available',
    required this.createdAt,
    this.isBoosted = false,
    this.reactions = const {},
    this.condition,
    this.location,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      'seller_id': sellerId,
      'seller_name': sellerName,
      'images': images,
      'image_url': imageUrl,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'is_boosted': isBoosted,
      'reactions': reactions,
      'condition': condition,
      'location': location,
    };
  }

  factory MarketplaceItem.fromMap(Map<String, dynamic> map) {
    DateTime parseTime(dynamic raw) {
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
      return DateTime.now();
    }

    List<String> parseImages(dynamic raw) {
      List<String> rawList = [];
      if (raw is List) {
        rawList = raw.map((e) => e.toString()).toList();
      } else if (raw is String && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            rawList = decoded.map((e) => e.toString()).toList();
          } else {
            rawList = [raw];
          }
        } catch (_) {
          rawList = [raw];
        }
      }
      return rawList
          .map((url) => UrlValidator.formatImageUrl(url))
          .where((url) => url.isNotEmpty)
          .toList();
    }

    return MarketplaceItem(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      category: map['category'] ?? 'books',
      sellerId: map['seller_id'] ?? map['sellerId'] ?? '',
      sellerName: map['seller_name'] ?? map['seller']?['fullName'] ?? '',
      images: parseImages(map['images'] ?? map['image_url']),
      status: map['status'] ?? 'available',
      createdAt: parseTime(map['created_at'] ?? map['createdAt']),
      isBoosted: map['is_boosted'] ?? false,
      reactions: Map<String, String>.from(map['reactions'] ?? {}),
      condition: map['condition'],
      location: map['location'],
    );
  }
}

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  return MarketplaceRepository();
});

class MarketplaceRepository {
  MarketplaceRepository([dynamic _]);

  Stream<List<MarketplaceItem>> watchItems({
    String? category,
    String? searchQuery,
    double? minPrice,
    double? maxPrice,
    String sortBy = 'newest',
  }) {
    return _watchItemsInternal(
      category: category,
      searchQuery: searchQuery,
      minPrice: minPrice,
      maxPrice: maxPrice,
      sortBy: sortBy,
    ).asBroadcastStream();
  }

  Stream<List<MarketplaceItem>> _watchItemsInternal({
    String? category,
    String? searchQuery,
    double? minPrice,
    double? maxPrice,
    String sortBy = 'newest',
  }) async* {
    try {
      final queryParam = (category != null && category.isNotEmpty && category.toLowerCase() != 'all')
          ? '?category=$category'
          : '';
      final response = await ApiClient.get('/marketplace$queryParam');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          yield (data['data'] as List).map((x) => MarketplaceItem.fromMap(x)).toList();
          return;
        }
      }
    } catch (_) {
      // Fall back to empty list on error
    }
    yield [];
  }

  Future<void> addItem(MarketplaceItem item) async {
    final response = await ApiClient.post('/marketplace', item.toMap());
    if (response.statusCode != 200 && response.statusCode != 201) {
      try {
        final body = jsonDecode(response.body);
        throw Exception(body['error'] ?? 'Failed to create marketplace item (${response.statusCode})');
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('Failed to create marketplace item (status: ${response.statusCode})');
      }
    }
  }

  Future<void> boostItem(String itemId) async {}

  Future<void> toggleReaction(String itemId, String userId, String emoji) async {}

  Future<void> updateItemStatus(String itemId, String status) async {}

  Future<void> deleteItem(String itemId) async {}
}
