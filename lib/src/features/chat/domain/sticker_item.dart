import 'package:flutter/material.dart';

enum StickerType {
  draw,
  photo,
  motion,
  meme,
  doodle,
}

enum StickerCategory {
  campus,
  meme,
  reaction,
  study,
  doodle,
}

class StickerItem {
  final String id;
  final String title;
  final String imageUrl;
  final String? animatedUrl;
  final String type; // 'DRAW', 'PHOTO', 'MOTION', 'MEME', 'DOODLE'
  final String category; // 'CAMPUS', 'MEME', 'REACTION', 'STUDY', 'DOODLE'
  final List<String> tags;
  final bool isPublic;
  final int usageCount;
  final String? authorId;
  final String? authorName;
  final bool isSaved;
  final DateTime? createdAt;

  const StickerItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.animatedUrl,
    this.type = 'PHOTO',
    this.category = 'CAMPUS',
    this.tags = const [],
    this.isPublic = true,
    this.usageCount = 0,
    this.authorId,
    this.authorName,
    this.isSaved = false,
    this.createdAt,
  });

  bool get isAnimated =>
      animatedUrl != null && animatedUrl!.isNotEmpty ||
      imageUrl.toLowerCase().endsWith('.gif') ||
      imageUrl.toLowerCase().endsWith('.webp');

  factory StickerItem.fromJson(Map<String, dynamic> json) {
    List<String> parsedTags = [];
    if (json['tags'] is List) {
      parsedTags = (json['tags'] as List).map((e) => e.toString()).toList();
    } else if (json['tags'] is String && (json['tags'] as String).isNotEmpty) {
      parsedTags = (json['tags'] as String).split(',').map((e) => e.trim()).toList();
    }

    return StickerItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Sticker',
      imageUrl: json['imageUrl']?.toString() ?? '',
      animatedUrl: json['animatedUrl']?.toString(),
      type: (json['type']?.toString() ?? 'PHOTO').toUpperCase(),
      category: (json['category']?.toString() ?? 'CAMPUS').toUpperCase(),
      tags: parsedTags,
      isPublic: json['isPublic'] == true || json['isPublic'] == 1 || json['isPublic'] == 'true',
      usageCount: int.tryParse(json['usageCount']?.toString() ?? '0') ?? 0,
      authorId: json['authorId']?.toString(),
      authorName: json['authorName']?.toString() ?? (json['author'] is Map ? json['author']['name']?.toString() : null),
      isSaved: json['isSaved'] == true || json['isSaved'] == 1,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'imageUrl': imageUrl,
      'animatedUrl': animatedUrl,
      'type': type,
      'category': category,
      'tags': tags,
      'isPublic': isPublic,
      'usageCount': usageCount,
      'authorId': authorId,
      'authorName': authorName,
      'isSaved': isSaved,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  StickerItem copyWith({
    String? id,
    String? title,
    String? imageUrl,
    String? animatedUrl,
    String? type,
    String? category,
    List<String>? tags,
    bool? isPublic,
    int? usageCount,
    String? authorId,
    String? authorName,
    bool? isSaved,
    DateTime? createdAt,
  }) {
    return StickerItem(
      id: id ?? this.id,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      animatedUrl: animatedUrl ?? this.animatedUrl,
      type: type ?? this.type,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      isPublic: isPublic ?? this.isPublic,
      usageCount: usageCount ?? this.usageCount,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      isSaved: isSaved ?? this.isSaved,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// Backward-compatible alias for existing screens
class CreatedStickerItem {
  final String id;
  final String title;
  final String type; // 'draw', 'photo', 'gif'
  final String? emojiOrText;
  final Color? baseColor;
  final String? localPath;
  final bool isFavorite;
  final String? cloudUrl;
  final String? animatedUrl;
  final bool isPublic;
  final String category;
  final List<String> tags;

  const CreatedStickerItem({
    required this.id,
    required this.title,
    required this.type,
    this.emojiOrText,
    this.baseColor,
    this.localPath,
    this.isFavorite = true,
    this.cloudUrl,
    this.animatedUrl,
    this.isPublic = true,
    this.category = 'CAMPUS',
    this.tags = const [],
  });

  StickerItem toStickerItem() {
    return StickerItem(
      id: id,
      title: title,
      imageUrl: cloudUrl ?? localPath ?? '',
      animatedUrl: animatedUrl,
      type: type.toUpperCase(),
      category: category.toUpperCase(),
      tags: tags,
      isPublic: isPublic,
      isSaved: isFavorite,
    );
  }

  factory CreatedStickerItem.fromStickerItem(StickerItem item) {
    return CreatedStickerItem(
      id: item.id,
      title: item.title,
      type: item.type.toLowerCase(),
      localPath: item.imageUrl.startsWith('http') ? null : item.imageUrl,
      cloudUrl: item.imageUrl.startsWith('http') ? item.imageUrl : null,
      animatedUrl: item.animatedUrl,
      isFavorite: item.isSaved,
      isPublic: item.isPublic,
      category: item.category,
      tags: item.tags,
      emojiOrText: item.title,
    );
  }
}
