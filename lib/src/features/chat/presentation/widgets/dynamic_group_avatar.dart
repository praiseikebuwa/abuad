import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/chat_channel.dart';
import '../../data/chat_repository.dart';

class DynamicGroupAvatar extends ConsumerWidget {
  final ChatChannel channel;
  final double size;
  final Color? borderColor;

  const DynamicGroupAvatar({
    super.key,
    required this.channel,
    this.size = 48.0,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveBorderColor = borderColor ?? (isDark ? const Color(0xFF0F172A) : Colors.white);

    // If custom group avatar is explicitly set, display it
    final customAvatar = channel.displayAvatarUrl;
    if (customAvatar != null && customAvatar.trim().isNotEmpty && !customAvatar.contains('default')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: effectiveBorderColor.withValues(alpha: 0.3), width: 1.5),
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: customAvatar,
            fit: BoxFit.cover,
            placeholder: (_, _) => _buildInitialsFallback(channel.displayName ?? 'G'),
            errorWidget: (_, _, _) => _buildInitialsFallback(channel.displayName ?? 'G'),
          ),
        ),
      );
    }

    // Otherwise, compute the recent 3 distinct chatting members
    final repo = ref.watch(chatRepositoryProvider);
    final cachedMsgs = repo.getCachedMessages(channel.id);

    final recentSenders = <String>[];
    for (int i = cachedMsgs.length - 1; i >= 0; i--) {
      final senderId = cachedMsgs[i].senderId;
      if (senderId.isNotEmpty && !recentSenders.contains(senderId)) {
        recentSenders.add(senderId);
        if (recentSenders.length >= 3) break;
      }
    }

    // Fill remaining slots from memberIds
    for (final memberId in channel.memberIds) {
      if (recentSenders.length >= 3) break;
      if (!recentSenders.contains(memberId)) {
        recentSenders.add(memberId);
      }
    }

    // Extract avatars & initials for the 3 people
    final people = <_PersonAvatarInfo>[];
    for (int i = 0; i < 3; i++) {
      if (i < recentSenders.length) {
        final id = recentSenders[i];
        final avatar = channel.memberAvatars[id];
        final name = channel.memberNames[id] ?? 'Student';
        people.add(_PersonAvatarInfo(
          id: id,
          avatarUrl: (avatar != null && avatar.isNotEmpty) ? avatar : null,
          name: name,
        ));
      } else {
        people.add(_PersonAvatarInfo(
          id: 'placeholder_$i',
          avatarUrl: null,
          name: i == 0 ? 'A' : (i == 1 ? 'B' : 'C'),
        ));
      }
    }

    final keyString = people.map((p) => '${p.id}_${p.avatarUrl ?? ""}').join('|');

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: SizedBox(
        key: ValueKey(keyString),
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Top Left Avatar (Person 1)
            Positioned(
              left: 0,
              top: 0,
              child: _buildAvatarCircle(
                person: people[0],
                diameter: size * 0.54,
                borderColor: effectiveBorderColor,
                backgroundColor: const Color(0xFF6366F1),
              ),
            ),

            // Top Right Avatar (Person 2)
            Positioned(
              right: 0,
              top: 0,
              child: _buildAvatarCircle(
                person: people[1],
                diameter: size * 0.54,
                borderColor: effectiveBorderColor,
                backgroundColor: const Color(0xFF10B981),
              ),
            ),

            // Bottom Center Avatar (Person 3 - Overlapping in front)
            Positioned(
              bottom: 0,
              child: _buildAvatarCircle(
                person: people[2],
                diameter: size * 0.58,
                borderColor: effectiveBorderColor,
                borderWidth: 2.2,
                backgroundColor: const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarCircle({
    required _PersonAvatarInfo person,
    required double diameter,
    required Color borderColor,
    double borderWidth = 1.6,
    required Color backgroundColor,
  }) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipOval(
        child: person.avatarUrl != null
            ? CachedNetworkImage(
                imageUrl: person.avatarUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => _buildInitials(person.name, diameter),
                placeholder: (_, _) => _buildInitials(person.name, diameter),
              )
            : _buildInitials(person.name, diameter),
      ),
    );
  }

  Widget _buildInitials(String name, double diameter) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: diameter * 0.44,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInitialsFallback(String name) {
    return Container(
      color: const Color(0xFF10B981),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'G',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _PersonAvatarInfo {
  final String id;
  final String? avatarUrl;
  final String name;

  _PersonAvatarInfo({
    required this.id,
    required this.avatarUrl,
    required this.name,
  });
}

