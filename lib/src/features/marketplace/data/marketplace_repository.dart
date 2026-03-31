import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MarketplaceItem {
  final String id;
  final String title;
  final String description;
  final double price;
  final String category;
  final String sellerId;
  final String sellerName;
  final List<String> images;

  // Backwards compatibility getter
  String? get imageUrl => images.isNotEmpty ? images.first : null;
  final String status;
  final DateTime createdAt;

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
      'image_url': imageUrl, // Maintain for older clients/queries
      'status': status,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  factory MarketplaceItem.fromMap(Map<String, dynamic> map) {
    return MarketplaceItem(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      category: map['category'] ?? 'books',
      sellerId: map['seller_id'] ?? '',
      sellerName: map['seller_name'] ?? '',
      images: List<String>.from(
        map['images'] ?? (map['image_url'] != null ? [map['image_url']] : []),
      ),
      status: map['status'] ?? 'available',
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  return MarketplaceRepository(FirebaseFirestore.instance);
});

class MarketplaceRepository {
  final FirebaseFirestore _firestore;

  MarketplaceRepository(this._firestore);

  Stream<List<MarketplaceItem>> watchItems({
    String? category,
    String? searchQuery,
    double? minPrice,
    double? maxPrice,
    String sortBy = 'newest', // newest, price_asc, price_desc
  }) {
    Query query = _firestore
        .collection('marketplace_items')
        .where('status', isEqualTo: 'available');

    if (category != null && category != 'all') {
      query = query.where('category', isEqualTo: category);
    }

    // Server-side price filtering (requires composite indexes if mixed with category)
    if (minPrice != null) {
      query = query.where('price', isGreaterThanOrEqualTo: minPrice);
    }
    if (maxPrice != null) {
      query = query.where('price', isLessThanOrEqualTo: maxPrice);
    }

    // Applying sort
    if (sortBy == 'price_asc') {
      query = query.orderBy('price', descending: false);
    } else if (sortBy == 'price_desc') {
      query = query.orderBy('price', descending: true);
    } else {
      query = query.orderBy('created_at', descending: true);
    }

    return query.snapshots().map((snapshot) {
      var items = snapshot.docs
          .map(
            (doc) =>
                MarketplaceItem.fromMap(doc.data() as Map<String, dynamic>),
          )
          .toList();

      if (searchQuery != null && searchQuery.isNotEmpty) {
        final queryLower = searchQuery.toLowerCase();
        items = items.where((item) {
          final titleLower = item.title.toLowerCase();
          final descLower = item.description.toLowerCase();
          return titleLower.contains(queryLower) ||
              descLower.contains(queryLower);
        }).toList();
      }

      return items;
    });
  }

  Future<void> addItem(MarketplaceItem item) async {
    final itemId = _firestore.collection('marketplace_items').doc().id;
    final itemWithId = MarketplaceItem(
      id: itemId,
      title: item.title,
      description: item.description,
      price: item.price,
      category: item.category,
      sellerId: item.sellerId,
      sellerName: item.sellerName,
      images: item.images,
      status: item.status,
      createdAt: item.createdAt,
    );
    await _firestore
        .collection('marketplace_items')
        .doc(itemId)
        .set(itemWithId.toMap());
  }

  Future<void> updateItemStatus(String itemId, String status) async {
    await _firestore.collection('marketplace_items').doc(itemId).update({
      'status': status,
    });
  }
}
