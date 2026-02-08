import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      'seller_id': sellerId,
      'seller_name': sellerName,
      'image_url': imageUrl,
      'status': status,
      'created_at': createdAt.millisecondsSinceEpoch,
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
      imageUrl: map['image_url'],
      status: map['status'] ?? 'available',
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'])
          : DateTime.now(),
    );
  }
}

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  return MarketplaceRepository(Supabase.instance.client);
});

class MarketplaceRepository {
  final SupabaseClient _supabase;

  MarketplaceRepository(this._supabase);

  Stream<List<MarketplaceItem>> watchItems({String? category}) {
    return _supabase
        .from('marketplace_items')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) {
          var items = data.map((map) => MarketplaceItem.fromMap(map));

          // Client-side filtering
          items = items.where((item) => item.status == 'available');

          if (category != null && category != 'all') {
            items = items.where((item) => item.category == category);
          }

          return items.toList();
        });
  }

  Future<void> addItem(MarketplaceItem item) async {
    await _supabase.from('marketplace_items').insert(item.toMap());
  }
}
