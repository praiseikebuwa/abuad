import 'package:flutter/material.dart';
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
  final String? imageUrl;
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
    this.imageUrl,
    this.status = 'available',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'imageUrl': imageUrl,
      'status': status,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory MarketplaceItem.fromMap(String id, Map<String, dynamic> map) {
    return MarketplaceItem(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      category: map['category'] ?? 'books',
      sellerId: map['sellerId'] ?? '',
      sellerName: map['sellerName'] ?? '',
      imageUrl: map['imageUrl'],
      status: map['status'] ?? 'available',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  return MarketplaceRepository(FirebaseFirestore.instance);
});

class MarketplaceRepository {
  final FirebaseFirestore _firestore;

  MarketplaceRepository(this._firestore);

  Stream<List<MarketplaceItem>> watchItems({String? category}) {
    var query = _firestore
        .collection('marketplace_items')
        .where('status', isEqualTo: 'available')
        .orderBy('createdAt', descending: true);

    if (category != null && category != 'all') {
      query =
          query.where('category', isEqualTo: category);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return MarketplaceItem.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  Future<void> addItem(MarketplaceItem item) async {
    await _firestore.collection('marketplace_items').add(item.toMap());
  }
}
