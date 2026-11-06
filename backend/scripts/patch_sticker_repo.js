const fs = require('fs');
const file = 'lib/src/features/chat/data/sticker_repository.dart';
let content = fs.readFileSync(file, 'utf8');

const oldTrendingRegex = /\/\/\/ Fetch trending stickers sorted by student usage count[\s\S]*?\/\/ Fallback sorted seeds[\s\S]*?return fallback;\s*\}/;

const newTrending = `/// Fetch trending stickers sorted by student usage count
  Future<List<StickerItem>> getTrendingStickers() async {
    try {
      final res = await ApiClient.get('/stickers/trending?limit=50');
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['data'] is List) {
          final list = (decoded['data'] as List)
              .map((e) => StickerItem.fromJson(e as Map<String, dynamic>))
              .toList();
          if (list.isNotEmpty) {
            list.sort((a, b) => b.usageCount.compareTo(a.usageCount));
            return list;
          }
        }
      }
    } catch (e) {
      debugPrint('StickerRepository.getTrendingStickers error: $e');
    }
    return [];
  }`;

const oldCommunityRegex = /\/\/\/ Fetch community public stickers by category or search query[\s\S]*?return filtered;\s*\}/;

const newCommunity = `/// Fetch community public stickers by category or search query
  Future<List<StickerItem>> getCommunityStickers({
    String? category,
    String? search,
  }) async {
    try {
      final params = <String>['limit=150'];
      if (category != null && category.isNotEmpty && category.toUpperCase() != 'ALL') {
        params.add('category=\${Uri.encodeComponent(category.toUpperCase())}');
      }
      if (search != null && search.trim().isNotEmpty) {
        params.add('search=\${Uri.encodeComponent(search.trim())}');
      }
      final queryStr = '?\\$\{params.join('&')}';

      final res = await ApiClient.get('/stickers/community\${queryStr}');
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['data'] is List) {
          final list = (decoded['data'] as List)
              .map((e) => StickerItem.fromJson(e as Map<String, dynamic>))
              .toList();
          return list;
        }
      }
    } catch (e) {
      debugPrint('StickerRepository.getCommunityStickers error: $e');
    }
    return [];
  }`;

if (!oldTrendingRegex.test(content)) {
  console.error('Failed to match old trending');
  process.exit(1);
}
content = content.replace(oldTrendingRegex, newTrending);

if (!oldCommunityRegex.test(content)) {
  console.error('Failed to match old community');
  process.exit(1);
}
content = content.replace(oldCommunityRegex, newCommunity);

fs.writeFileSync(file, content, 'utf8');
console.log('Successfully updated sticker_repository.dart');
