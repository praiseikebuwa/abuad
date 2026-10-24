import 'package:uuid/uuid.dart';

enum AdPlacement {
  feed,
  story,
  marketplace,
}

enum AdStatus {
  active,
  paused,
  completed,
}

class Advertisement {
  final String id;
  final String advertiserId;
  final String advertiserName;
  final String? advertiserAvatarUrl;
  final String title;
  final String description;
  final String mediaUrl;
  final String mediaType; // 'image' or 'video'
  final String targetUrl; // destination link (https://...)
  final String? marketplaceItemId;
  final String? marketplaceItemTitle;
  final double? marketplaceItemPrice;
  final String ctaLabel; // 'Visit Website', 'Shop Now', 'Learn More', 'Contact Seller'
  final List<String> placements; // ['feed', 'story', 'marketplace']
  final AdStatus status;
  final int durationDays;
  final int impressionsCount;
  final int clicksCount;
  final DateTime createdAt;
  final DateTime expiresAt;

  Advertisement({
    String? id,
    required this.advertiserId,
    required this.advertiserName,
    this.advertiserAvatarUrl,
    required this.title,
    required this.description,
    required this.mediaUrl,
    this.mediaType = 'image',
    required this.targetUrl,
    this.marketplaceItemId,
    this.marketplaceItemTitle,
    this.marketplaceItemPrice,
    this.ctaLabel = 'Visit Website',
    required this.placements,
    this.status = AdStatus.active,
    this.durationDays = 7,
    this.impressionsCount = 0,
    this.clicksCount = 0,
    DateTime? createdAt,
    DateTime? expiresAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        expiresAt = expiresAt ??
            DateTime.now().add(Duration(days: durationDays));

  bool get isActive =>
      status == AdStatus.active && DateTime.now().isBefore(expiresAt);

  bool hasPlacement(String placement) =>
      placements.contains(placement.toLowerCase());

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'advertiserId': advertiserId,
      'advertiserName': advertiserName,
      'advertiserAvatarUrl': advertiserAvatarUrl,
      'title': title,
      'description': description,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'targetUrl': targetUrl,
      'marketplaceItemId': marketplaceItemId,
      'marketplaceItemTitle': marketplaceItemTitle,
      'marketplaceItemPrice': marketplaceItemPrice,
      'ctaLabel': ctaLabel,
      'placements': placements,
      'status': status.name,
      'durationDays': durationDays,
      'impressionsCount': impressionsCount,
      'clicksCount': clicksCount,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  factory Advertisement.fromMap(Map<String, dynamic> map) {
    return Advertisement(
      id: map['id']?.toString() ?? const Uuid().v4(),
      advertiserId: map['advertiserId']?.toString() ?? '',
      advertiserName: map['advertiserName']?.toString() ?? 'ABUAD Partner',
      advertiserAvatarUrl: map['advertiserAvatarUrl']?.toString(),
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      mediaUrl: map['mediaUrl']?.toString() ?? '',
      mediaType: map['mediaType']?.toString() ?? 'image',
      targetUrl: map['targetUrl']?.toString() ?? '',
      marketplaceItemId: map['marketplaceItemId']?.toString(),
      marketplaceItemTitle: map['marketplaceItemTitle']?.toString(),
      marketplaceItemPrice: map['marketplaceItemPrice'] != null
          ? (map['marketplaceItemPrice'] as num).toDouble()
          : null,
      ctaLabel: map['ctaLabel']?.toString() ?? 'Visit Website',
      placements: map['placements'] is List
          ? (map['placements'] as List).map((e) => e.toString()).toList()
          : ['feed'],
      status: AdStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => AdStatus.active,
      ),
      durationDays: (map['durationDays'] as num?)?.toInt() ?? 7,
      impressionsCount: (map['impressionsCount'] as num?)?.toInt() ?? 0,
      clicksCount: (map['clicksCount'] as num?)?.toInt() ?? 0,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      expiresAt: map['expiresAt'] != null
          ? DateTime.tryParse(map['expiresAt'].toString())
          : null,
    );
  }

  Advertisement copyWith({
    String? title,
    String? description,
    String? mediaUrl,
    String? mediaType,
    String? targetUrl,
    String? ctaLabel,
    List<String>? placements,
    AdStatus? status,
    int? impressionsCount,
    int? clicksCount,
  }) {
    return Advertisement(
      id: id,
      advertiserId: advertiserId,
      advertiserName: advertiserName,
      advertiserAvatarUrl: advertiserAvatarUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      targetUrl: targetUrl ?? this.targetUrl,
      marketplaceItemId: marketplaceItemId,
      marketplaceItemTitle: marketplaceItemTitle,
      marketplaceItemPrice: marketplaceItemPrice,
      ctaLabel: ctaLabel ?? this.ctaLabel,
      placements: placements ?? this.placements,
      status: status ?? this.status,
      durationDays: durationDays,
      impressionsCount: impressionsCount ?? this.impressionsCount,
      clicksCount: clicksCount ?? this.clicksCount,
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }
}
