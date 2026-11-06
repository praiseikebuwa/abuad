const fs = require('fs');
const file = 'lib/src/features/chat/presentation/chat_list_screen.dart';
const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/);

let targetIndex = -1;
for (let i = 0; i < lines.length; i++) {
  if (lines[i].includes("child: Text(") && lines[i+1] && lines[i+1].includes("'Opened · ${formatTime(channel.lastMessageTime)}'")) {
    targetIndex = i;
    break;
  }
}

if (targetIndex === -1) {
  console.error('Target not found');
  process.exit(1);
}

// Find the start of the 'else {' around targetIndex
let elseIndex = -1;
for (let i = targetIndex; i >= targetIndex - 20; i--) {
  if (lines[i].trim() === '} else {') {
    elseIndex = i;
    break;
  }
}

if (elseIndex === -1) {
  console.error('else { not found');
  process.exit(1);
}

// Find the matching close bracket '}' for this else
let closeIndex = -1;
for (let i = targetIndex; i <= targetIndex + 20; i++) {
  if (lines[i].trim() === '}') {
    closeIndex = i;
    break;
  }
}

console.log(`Replacing lines ${elseIndex} to ${closeIndex}`);

const replacementLines = [
  '        } else {',
  '          final snapViews = (msg[\x27snap_views\x27] is Map)',
  '              ? Map<String, dynamic>.from(msg[\x27snap_views\x27])',
  '              : ((msg[\x27snapViews\x27] is Map) ? Map<String, dynamic>.from(msg[\x27snapViews\x27]) : <String, dynamic>{});',
  '          final isOpenedByMe = currentUserId != null &&',
  '              snapViews[currentUserId] != null &&',
  '              (snapViews[currentUserId] is num && (snapViews[currentUserId] as num) > 0);',
  '          final timeStr = formatTime(channel.lastMessageTime);',
  '',
  '          if (!isOpenedByMe) {',
  '            return Row(',
  '              mainAxisSize: MainAxisSize.min,',
  '              children: [',
  '                Container(',
  '                  width: 12,',
  '                  height: 12,',
  '                  decoration: BoxDecoration(',
  '                    color: snapColor,',
  '                    borderRadius: BorderRadius.circular(3),',
  '                  ),',
  '                ),',
  '                const SizedBox(width: 6),',
  '                Flexible(',
  '                  child: Text(',
  '                    \x27\x24{isVideoSnap ? "New Video Snap" : "New Snap"} · \x24timeStr\x27,',
  '                    maxLines: 1,',
  '                    overflow: TextOverflow.ellipsis,',
  '                    style: TextStyle(',
  '                      fontSize: 14,',
  '                      fontWeight: FontWeight.bold,',
  '                      color: snapColor,',
  '                    ),',
  '                  ),',
  '                ),',
  '              ],',
  '            );',
  '          } else {',
  '            return Row(',
  '              mainAxisSize: MainAxisSize.min,',
  '              children: [',
  '                Container(',
  '                  width: 11,',
  '                  height: 11,',
  '                  decoration: BoxDecoration(',
  '                    border: Border.all(color: snapColor, width: 1.8),',
  '                    borderRadius: BorderRadius.circular(3),',
  '                  ),',
  '                ),',
  '                const SizedBox(width: 6),',
  '                Flexible(',
  '                  child: Text(',
  '                    \x27Opened · \x24timeStr\x27,',
  '                    maxLines: 1,',
  '                    overflow: TextOverflow.ellipsis,',
  '                    style: TextStyle(',
  '                      fontSize: 14,',
  '                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),',
  '                    ),',
  '                  ),',
  '                ),',
  '              ],',
  '            );',
  '          }',
  '        }'
];

lines.splice(elseIndex, closeIndex - elseIndex + 1, ...replacementLines);
fs.writeFileSync(file, lines.join('\r\n'), 'utf8');
console.log('Successfully updated chat_list_screen.dart');
