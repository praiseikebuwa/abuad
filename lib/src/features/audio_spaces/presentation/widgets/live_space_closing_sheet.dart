import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/audio_room.dart';
import '../controllers/audio_room_controller.dart';

class LiveSpaceClosingSheet extends ConsumerStatefulWidget {
  final AudioRoom room;
  final bool isHost;

  const LiveSpaceClosingSheet({
    super.key,
    required this.room,
    required this.isHost,
  });

  @override
  ConsumerState<LiveSpaceClosingSheet> createState() => _LiveSpaceClosingSheetState();
}

class _LiveSpaceClosingSheetState extends ConsumerState<LiveSpaceClosingSheet> {
  String? _selectedProposedHostId;
  bool _isTransferring = false;
  bool _showTransferList = false;

  Future<void> _handleLeaveQuietly() async {
    Navigator.of(context).pop(true);
    await ref.read(activeAudioRoomNotifierProvider.notifier).leaveRoom();
  }

  Future<void> _handleEndSpaceForEveryone() async {
    Navigator.of(context).pop(true);
    await ref.read(activeAudioRoomNotifierProvider.notifier).endRoom();
  }

  Future<void> _handleTransferAndLeave() async {
    if (_selectedProposedHostId == null) return;
    setState(() => _isTransferring = true);

    try {
      await ref
          .read(activeAudioRoomNotifierProvider.notifier)
          .proposeHostTransfer(_selectedProposedHostId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Host transfer requested! Leaving space...'),
            backgroundColor: Color(0xFF7C4DFF),
          ),
        );
        Navigator.of(context).pop(true);
        await ref.read(activeAudioRoomNotifierProvider.notifier).leaveRoom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTransferring = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transfer failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isHost) {
      // Non-host listener/speaker leave confirmation
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: Color(0xFF161622),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.exit_to_app_rounded, color: Colors.white70, size: 30),
            ),
            const SizedBox(height: 14),
            const Text(
              'Leave this Live Space?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You will disconnect from audio. You can rejoin at any time while the space is active.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Stay in Space', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                      foregroundColor: Colors.redAccent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Colors.redAccent, width: 0.8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _handleLeaveQuietly,
                    child: const Text('Leave Quietly', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Host Leave / End Space Sheet
    final otherParticipants = widget.room.participants
        .where((p) => p.userId != widget.room.hostId)
        .toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF161622),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.shield_rounded, color: Colors.amber, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Host Options',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'You are the primary host of "${widget.room.title}"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white54),
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),

          const Divider(color: Colors.white10, height: 24),

          if (!_showTransferList) ...[
            // Option 1: End Space for Everyone
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent, size: 22),
                ),
                title: const Text(
                  'End Space for Everyone',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                subtitle: Text(
                  'Immediately terminate this audio session for all ${widget.room.totalParticipants} participants.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.redAccent),
                onTap: () {
                  _showEndConfirmDialog();
                },
              ),
            ),

            // Option 2: Transfer Host & Leave
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF222232),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.3)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF7C4DFF), size: 22),
                ),
                title: const Text(
                  'Transfer Host & Leave',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                subtitle: Text(
                  otherParticipants.isEmpty
                      ? 'No other participants available to take over.'
                      : 'Pass ownership to an active co-host, speaker, or listener so the space continues.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                enabled: otherParticipants.isNotEmpty,
                onTap: () => setState(() => _showTransferList = true),
              ),
            ),

            // Option 3: Leave with Grace Period
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF222232),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.timer_outlined, color: Colors.amber, size: 22),
                ),
                title: const Text(
                  'Leave Temporarily',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                subtitle: Text(
                  'Starts a 60-second grace period. If you do not return in 60s, a co-host will take over.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                onTap: _handleLeaveQuietly,
              ),
            ),
          ] else ...[
            // Transfer participant selection list
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
                  onPressed: () => setState(() => _showTransferList = false),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Choose New Primary Host',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: otherParticipants.length,
                itemBuilder: (context, index) {
                  final p = otherParticipants[index];
                  final isSelected = _selectedProposedHostId == p.userId;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF7C4DFF).withValues(alpha: 0.2)
                          : const Color(0xFF222232),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF7C4DFF) : Colors.transparent,
                      ),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF323246),
                        backgroundImage: (p.user.avatarUrl != null && p.user.avatarUrl!.isNotEmpty)
                            ? NetworkImage(p.user.avatarUrl!)
                            : null,
                        child: (p.user.avatarUrl == null || p.user.avatarUrl!.isEmpty)
                            ? Text(
                                p.user.fullName.isNotEmpty ? p.user.fullName[0].toUpperCase() : 'U',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      title: Text(
                        p.user.fullName.isNotEmpty ? p.user.fullName : p.user.username,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Role: ${p.role}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                      ),
                      trailing: Radio<String>(
                        value: p.userId,
                        groupValue: _selectedProposedHostId,
                        activeColor: const Color(0xFF7C4DFF),
                        onChanged: (val) => setState(() => _selectedProposedHostId = val),
                      ),
                      onTap: () => setState(() => _selectedProposedHostId = p.userId),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C4DFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: (_selectedProposedHostId == null || _isTransferring)
                  ? null
                  : _handleTransferAndLeave,
              child: _isTransferring
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Transfer Host & Exit',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  void _showEndConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('End Space for Everyone?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will permanently disconnect all speakers and listeners and conclude the Live Space.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('End Space'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleEndSpaceForEveryone();
            },
          ),
        ],
      ),
    );
  }
}

