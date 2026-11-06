const fs = require('fs');

// 1. post_card.dart
let f1 = 'lib/src/features/feed/presentation/widgets/post_card.dart';
let c1 = fs.readFileSync(f1, 'utf8');
c1 = c1.replace(
  'final isOwnPost = currentUserId != null && post.authorId == currentUserId;',
  'final isOwnPost = (currentUserId != null && post.authorId == currentUserId) || post.isOwner;'
);
fs.writeFileSync(f1, c1, 'utf8');

// 2. post_detail_screen.dart
let f2 = 'lib/src/features/feed/presentation/post_detail_screen.dart';
let c2 = fs.readFileSync(f2, 'utf8');
c2 = c2.replace(
  'final isOwnPost = post.authorId == currentUserId;',
  'final isOwnPost = (currentUserId != null && post.authorId == currentUserId) || post.isOwner;'
);
fs.writeFileSync(f2, c2, 'utf8');

console.log('Successfully updated post_card.dart and post_detail_screen.dart');
