const fs = require('fs');

// 1. chat_message.dart: parse stringified snap_views
const fMsg = 'lib/src/features/chat/domain/chat_message.dart';
let cMsg = fs.readFileSync(fMsg, 'utf8');

const oldSnapViewsBlock = `Map<String, int> snapViewsMap = {};
    final rawViews = map['snap_views'] ?? map['snapViews'] ?? reactionsMap['_snapViews'];
    if (rawViews is Map) {
      rawViews.forEach((key, val) {
        if (val is num) {
          snapViewsMap[key.toString()] = val.toInt();
        }
      });
    }`;

const newSnapViewsBlock = `Map<String, int> snapViewsMap = {};
    dynamic rawViews = map['snap_views'] ?? map['snapViews'] ?? reactionsMap['_snapViews'];
    if (rawViews is String && rawViews.isNotEmpty) {
      try {
        rawViews = jsonDecode(rawViews);
      } catch (_) {}
    }
    if (rawViews is Map) {
      rawViews.forEach((key, val) {
        if (val is num) {
          snapViewsMap[key.toString()] = val.toInt();
        }
      });
    }`;

if (cMsg.includes(oldSnapViewsBlock)) {
  cMsg = cMsg.replace(oldSnapViewsBlock, newSnapViewsBlock);
  fs.writeFileSync(fMsg, cMsg, 'utf8');
  console.log('Successfully patched chat_message.dart');
} else {
  console.log('Could not find snapViewsBlock in chat_message.dart');
}

// 2. chat_list_screen.dart: check if currentUserId opened the received snap
const fList = 'lib/src/features/chat/presentation/chat_list_screen.dart';
let cList = fs.readFileSync(fList, 'utf8');

const oldReceivedSnapBlock = `        } else {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  border: Border.all(color: snapColor, width: 1.8),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Opened · \${formatTime(channel.lastMessageTime)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          );
        }`;

const newReceivedSnapBlock = `        } else {
          final snapViews = (msg['snap_views'] is Map)
              ? Map<String, dynamic>.from(msg['snap_views'])
              : ((msg['snapViews'] is Map) ? Map<String, dynamic>.from(msg['snapViews']) : <String, dynamic>{});
          final isOpenedByMe = currentUserId != null &&
              snapViews[currentUserId] != null &&
              (snapViews[currentUserId] is num && (snapViews[currentUserId] as num) > 0);
          final timeStr = formatTime(channel.lastMessageTime);

          if (!isOpenedByMe) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: snapColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '\${isVideoSnap ? "New Video Snap" : "New Snap"} · \$timeStr',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: snapColor,
                    ),
                  ),
                ),
              ],
            );
          } else {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    border: Border.all(color: snapColor, width: 1.8),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Opened · \$timeStr',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            );
          }
        }`;

if (cList.includes(oldReceivedSnapBlock)) {
  cList = cList.replace(oldReceivedSnapBlock, newReceivedSnapBlock);
  fs.writeFileSync(fList, cList, 'utf8');
  console.log('Successfully patched chat_list_screen.dart');
} else {
  console.log('Could not find oldReceivedSnapBlock in chat_list_screen.dart');
}

// 3. chat_screen.dart: sticker bubble sizing & input area styling
const fChat = 'lib/src/features/chat/presentation/chat_screen.dart';
let cChat = fs.readFileSync(fChat, 'utf8');

// Reduce sticker bubble max constraints
cChat = cChat.replace(
  'constraints: const BoxConstraints(maxWidth: 140, maxHeight: 140),',
  'constraints: const BoxConstraints(maxWidth: 105, maxHeight: 105),'
);

// Enhance input bar styling
cChat = cChat.replace(
  `color: isDark\r\n                                                  ? Colors.white.withValues(alpha: 0.08)\r\n                                                  : const Color(0xFFF1F5F9),\r\n                                              borderRadius: BorderRadius.circular(24),\r\n                                              border: Border.all(\r\n                                                color: isDark\r\n                                                    ? Colors.white12\r\n                                                    : Colors.black.withValues(alpha: 0.06),\r\n                                                width: 1,\r\n                                              ),`,
  `color: isDark\r\n                                                  ? const Color(0xFF1E293B).withValues(alpha: 0.95)\r\n                                                  : Colors.white,\r\n                                              borderRadius: BorderRadius.circular(24),\r\n                                              border: Border.all(\r\n                                                color: isDark\r\n                                                    ? const Color(0xFF334155)\r\n                                                    : const Color(0xFFE2E8F0),\r\n                                                width: 1.2,\r\n                                              ),`
);

// Fallback for LF line endings
cChat = cChat.replace(
  `color: isDark\n                                                  ? Colors.white.withValues(alpha: 0.08)\n                                                  : const Color(0xFFF1F5F9),\n                                              borderRadius: BorderRadius.circular(24),\n                                              border: Border.all(\n                                                color: isDark\n                                                    ? Colors.white12\n                                                    : Colors.black.withValues(alpha: 0.06),\n                                                width: 1,\n                                              ),`,
  `color: isDark\n                                                  ? const Color(0xFF1E293B).withValues(alpha: 0.95)\n                                                  : Colors.white,\n                                              borderRadius: BorderRadius.circular(24),\n                                              border: Border.all(\n                                                color: isDark\n                                                    ? const Color(0xFF334155)\n                                                    : const Color(0xFFE2E8F0),\n                                                width: 1.2,\n                                              ),`
);

fs.writeFileSync(fChat, cChat, 'utf8');
console.log('Successfully patched chat_screen.dart');
