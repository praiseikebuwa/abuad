with open('lib/src/features/chat/presentation/chat_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Remove announcement banner from group chat rendering
old_banner_call = "if (isGroup) _buildAnnouncementBanner(channel, isDark),"
new_banner_call = "// Dummy announcement banner removed per user request"
if old_banner_call in content:
    content = content.replace(old_banner_call, new_banner_call)
    print("Announcement banner call removed")
else:
    print("Announcement banner call not found")

# Also update _buildAnnouncementBanner method to return SizedBox.shrink()
old_banner_method = """  Widget _buildAnnouncementBanner(ChatChannel? channel, bool isDark) {
    if (_hideAnnouncement) return const SizedBox.shrink();
    const text = "Midterm on Friday, Room 402 @ 10 AM — Liam (Class Rep)";"""

new_banner_method = """  Widget _buildAnnouncementBanner(ChatChannel? channel, bool isDark) {
    return const SizedBox.shrink();
    if (_hideAnnouncement) return const SizedBox.shrink();
    const text = "Midterm on Friday, Room 402 @ 10 AM — Liam (Class Rep)";"""
if old_banner_method in content:
    content = content.replace(old_banner_method, new_banner_method)
    print("Announcement banner method silenced")

# 2. Add ABUAD AI to user mention suggestions
old_fetch_suggestions = """    final everyone = AppUser(
      uid: 'all',
      displayName: 'All Members',
      email: 'all@abuad.edu.ng',
      handle: 'all',
    );

    final suggestions = [everyone, ...members]"""

new_fetch_suggestions = """    final everyone = AppUser(
      uid: 'all',
      displayName: 'All Members',
      email: 'all@abuad.edu.ng',
      handle: 'all',
    );

    final aiBot = AppUser(
      uid: 'abuad_ai',
      displayName: 'ABUAD AI',
      email: 'ai@abuad.edu.ng',
      handle: 'ai',
      avatarUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=400&q=80',
      isVerified: true,
      verificationType: 'GOLD',
    );

    final suggestions = [aiBot, everyone, ...members]"""

if old_fetch_suggestions in content:
    content = content.replace(old_fetch_suggestions, new_fetch_suggestions)
    print("ABUAD AI added to mention suggestions")
else:
    print("old_fetch_suggestions not found")

# Update _applyMention to insert @Abuad AI for ABUAD AI
old_apply_mention = """  void _applyMention(AppUser user) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final textBeforeCursor = text.substring(0, selection.baseOffset);
    final textAfterCursor = text.substring(selection.baseOffset);
    final lastAtPos = textBeforeCursor.lastIndexOf('@');
    if (lastAtPos != -1) {
      final newText =
          '${textBeforeCursor.substring(0, lastAtPos)}@${user.displayName} $textAfterCursor';
      _messageController.text = newText;
      _messageController.selection = TextSelection.collapsed(
        offset: lastAtPos + user.displayName.length + 2,
      );
    }
    setState(() => _userSuggestions = []);
  }"""

new_apply_mention = """  void _applyMention(AppUser user) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final textBeforeCursor = text.substring(0, selection.baseOffset);
    final textAfterCursor = text.substring(selection.baseOffset);
    final lastAtPos = textBeforeCursor.lastIndexOf('@');
    if (lastAtPos != -1) {
      final mentionTag = user.uid == 'abuad_ai' ? '@Abuad AI ' : '@${user.displayName} ';
      final newText =
          '${textBeforeCursor.substring(0, lastAtPos)}$mentionTag$textAfterCursor';
      _messageController.text = newText;
      _messageController.selection = TextSelection.collapsed(
        offset: lastAtPos + mentionTag.length,
      );
    }
    setState(() => _userSuggestions = []);
  }"""

if old_apply_mention in content:
    content = content.replace(old_apply_mention, new_apply_mention)
    print("_applyMention updated")
else:
    print("old_apply_mention not found")

# 3. Add product inquiry banner above input bar
old_input_stack = """                          _buildLiveTypingBanner(channel, displayName, isDark),
                          if (_replyingTo != null)
                            _buildReplyPreview(
                              isDark,
                              channel: channel,
                              currentUserId: repo.currentUserId,
                            ),"""

new_input_stack = """                          _buildLiveTypingBanner(channel, displayName, isDark),
                          if (_inquiryProduct != null)
                            _buildProductInquiryBanner(_inquiryProduct!, isDark),
                          if (_replyingTo != null)
                            _buildReplyPreview(
                              isDark,
                              channel: channel,
                              currentUserId: repo.currentUserId,
                            ),"""

if old_input_stack in content:
    content = content.replace(old_input_stack, new_input_stack)
    print("Product inquiry banner inserted into input bar")
else:
    print("old_input_stack not found")

# 4. In _sendMessage, if _inquiryProduct != null, include product info
old_send_msg = """  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    if (_editingMessage != null) {"""

new_send_msg = """  void _sendMessage() {
    final rawContent = _messageController.text.trim();
    if (rawContent.isEmpty) return;

    String content = rawContent;
    if (_inquiryProduct != null) {
      content = '🛍️ Inquiring about "${_inquiryProduct!.title}" (₦${_inquiryProduct!.price.toStringAsFixed(0)})\\n$rawContent';
    }

    if (_editingMessage != null) {"""

if old_send_msg in content:
    content = content.replace(old_send_msg, new_send_msg)
    print("_sendMessage updated to handle product inquiries")
else:
    print("old_send_msg not found")

# 5. Add _buildProductInquiryBanner method before _buildLiveTypingBanner
old_live_typing = "  Widget _buildLiveTypingBanner(ChatChannel? channel, String displayName, bool isDark) {"
banner_method = """  Widget _buildProductInquiryBanner(MarketplaceItem item, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.accentAmber.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 44,
              height: 44,
              child: item.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: UrlValidator.formatImageUrl(item.imageUrl),
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.grey[800]),
                      errorWidget: (_, __, ___) => const Icon(Icons.shopping_bag_outlined, size: 24),
                    )
                  : const Icon(Icons.shopping_bag_outlined, size: 24),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: const [
                    Icon(Icons.storefront_rounded, size: 12, color: AppColors.accentAmber),
                    SizedBox(width: 4),
                    Text(
                      'PRODUCT INQUIRY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accentAmber,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  '₦${item.price.toStringAsFixed(0)} · ${item.category}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryTeal,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () => setState(() => _inquiryProduct = null),
            color: isDark ? Colors.white60 : Colors.black54,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTypingBanner(ChatChannel? channel, String displayName, bool isDark) {"""

if old_live_typing in content:
    content = content.replace(old_live_typing, banner_method)
    print("_buildProductInquiryBanner method added")
else:
    print("old_live_typing not found")

with open('lib/src/features/chat/presentation/chat_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("chat_screen.dart successfully updated!")
