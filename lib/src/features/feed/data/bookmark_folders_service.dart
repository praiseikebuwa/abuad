import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/data/auth_repository.dart';

class BookmarkFolder {
  final String id;
  final String name;
  final String emoji;
  final Set<String> postIds;
  final bool isDefault;

  const BookmarkFolder({
    required this.id,
    required this.name,
    required this.emoji,
    required this.postIds,
    this.isDefault = false,
  });

  BookmarkFolder copyWith({
    String? id,
    String? name,
    String? emoji,
    Set<String>? postIds,
    bool? isDefault,
  }) {
    return BookmarkFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      postIds: postIds ?? this.postIds,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'postIds': postIds.toList(),
      'isDefault': isDefault,
    };
  }

  factory BookmarkFolder.fromJson(Map<String, dynamic> json) {
    return BookmarkFolder(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String? ?? '📁',
      postIds: ((json['postIds'] as List<dynamic>?) ?? []).map((e) => e.toString()).toSet(),
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}

class BookmarkFoldersNotifier extends Notifier<List<BookmarkFolder>> {
  static List<BookmarkFolder> get defaultFolders => [
        const BookmarkFolder(
          id: 'academic',
          name: 'Academic',
          emoji: '📚',
          postIds: {},
          isDefault: true,
        ),
        const BookmarkFolder(
          id: 'events',
          name: 'Events',
          emoji: '🎟️',
          postIds: {},
          isDefault: true,
        ),
        const BookmarkFolder(
          id: 'marketplace',
          name: 'Marketplace',
          emoji: '🛍️',
          postIds: {},
          isDefault: true,
        ),
        const BookmarkFolder(
          id: 'memes',
          name: 'Memes & Fun',
          emoji: '😂',
          postIds: {},
          isDefault: true,
        ),
        const BookmarkFolder(
          id: 'favorites',
          name: 'Favorites',
          emoji: '⭐',
          postIds: {},
          isDefault: true,
        ),
      ];

  String get _prefsKey {
    final userId = ref.read(currentUserIdProvider) ?? 'guest';
    return 'abuad_bookmark_folders_$userId';
  }

  @override
  List<BookmarkFolder> build() {
    _loadFromPrefs();
    return defaultFolders;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
        final loaded = list.map((e) => BookmarkFolder.fromJson(e as Map<String, dynamic>)).toList();
        
        final existingIds = loaded.map((f) => f.id).toSet();
        for (final def in defaultFolders) {
          if (!existingIds.contains(def.id)) {
            loaded.add(def);
          }
        }
        state = loaded;
      }
    } catch (e) {
      debugPrint('Error loading bookmark folders: $e');
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(state.map((f) => f.toJson()).toList());
      await prefs.setString(_prefsKey, jsonStr);
    } catch (e) {
      debugPrint('Error saving bookmark folders: $e');
    }
  }

  Future<void> createFolder(String name, {String emoji = '📁'}) async {
    if (name.trim().isEmpty) return;
    final id = 'folder_${DateTime.now().millisecondsSinceEpoch}';
    final newFolder = BookmarkFolder(
      id: id,
      name: name.trim(),
      emoji: emoji,
      postIds: {},
      isDefault: false,
    );
    state = [...state, newFolder];
    await _saveToPrefs();
  }

  Future<void> deleteFolder(String folderId) async {
    state = state.where((f) => f.id != folderId || f.isDefault).toList();
    await _saveToPrefs();
  }

  Future<void> togglePostInFolder(String postId, String folderId) async {
    state = [
      for (final folder in state)
        if (folder.id == folderId)
          folder.copyWith(
            postIds: folder.postIds.contains(postId)
                ? (Set<String>.from(folder.postIds)..remove(postId))
                : (Set<String>.from(folder.postIds)..add(postId)),
          )
        else
          folder,
    ];
    await _saveToPrefs();
  }

  Future<void> assignPostToFolders(String postId, Set<String> targetFolderIds) async {
    state = [
      for (final folder in state)
        folder.copyWith(
          postIds: targetFolderIds.contains(folder.id)
              ? (Set<String>.from(folder.postIds)..add(postId))
              : (Set<String>.from(folder.postIds)..remove(postId)),
        ),
    ];
    await _saveToPrefs();
  }

  Set<String> getFolderIdsForPost(String postId) {
    return state.where((f) => f.postIds.contains(postId)).map((f) => f.id).toSet();
  }
}

final bookmarkFoldersProvider =
    NotifierProvider<BookmarkFoldersNotifier, List<BookmarkFolder>>(
  BookmarkFoldersNotifier.new,
);
