const fs = require('fs');
const file = 'lib/src/features/feed/presentation/widgets/comment_thread_view.dart';
let c = fs.readFileSync(file, 'utf8');
const target = ": 'View $replyCount ${replyCount == 1 ? 'reply' : 'replies'}',";
const replacement = ": (replyCount == 1 ? 'Show reply' : 'Show replies ($replyCount)'),";
if (!c.includes(target)) {
  console.error('Target not found in comment_thread_view.dart');
  process.exit(1);
}
c = c.replace(target, replacement);
fs.writeFileSync(file, c, 'utf8');
console.log('Successfully replaced in comment_thread_view.dart');
