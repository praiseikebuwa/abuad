import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/api_client.dart';
import '../../../core/services/image_upload_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/sticker_repository.dart';

/// Status of a single sticker draft in the bulk upload pipeline.
enum _DraftStatus { queued, uploading, labeling, ready, publishing, published, failed }

class _StickerDraft {
  _StickerDraft({
    required this.id,
    required this.fileName,
    required this.bytes,
    required this.isAnimated,
  })  : titleCtrl = TextEditingController(text: _titleFromFileName(fileName)),
        tagsCtrl = TextEditingController();

  final String id;
  final String fileName;
  final Uint8List bytes;
  final bool isAnimated;
  final TextEditingController titleCtrl;
  final TextEditingController tagsCtrl;
  String category = 'REACTION';
  bool isPublic = true;
  bool selected = false;
  bool aiLabeled = false;
  String? uploadedUrl;
  String? error;
  _DraftStatus status = _DraftStatus.queued;

  bool get isBusy =>
      status == _DraftStatus.uploading ||
      status == _DraftStatus.labeling ||
      status == _DraftStatus.publishing;

  List<String> get tags => tagsCtrl.text
      .split(',')
      .map((t) => t.trim().replaceAll('#', '').toLowerCase())
      .where((t) => t.isNotEmpty)
      .toList();

  void dispose() {
    titleCtrl.dispose();
    tagsCtrl.dispose();
  }

  static String _titleFromFileName(String name) {
    final base = name
        .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAll(RegExp(r'\d{3,}'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (base.isEmpty) return 'Campus Sticker';
    return base
        .split(' ')
        .take(4)
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }
}

/// Upload many stickers at once (100+), let AI name them, edit everything,
/// then publish them all to the campus sticker place in one tap.
class BulkStickerUploadScreen extends ConsumerStatefulWidget {
  const BulkStickerUploadScreen({super.key});

  @override
  ConsumerState<BulkStickerUploadScreen> createState() => _BulkStickerUploadScreenState();
}

class _BulkStickerUploadScreenState extends ConsumerState<BulkStickerUploadScreen> {
  static const int _maxStickers = 300;
  static const int _concurrency = 4;
  static const List<String> _categories = [
    'CAMPUS',
    'MEME',
    'REACTION',
    'STUDY',
    'SPORTS',
    'LIFESTYLE',
  ];

  final List<_StickerDraft> _drafts = [];
  bool _autoAiTitles = true;
  bool _isProcessing = false;
  bool _isPublishing = false;
  int _publishedCount = 0;

  @override
  void dispose() {
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────────────
  // Derived state
  // ────────────────────────────────────────────────────────────────────────
  List<_StickerDraft> get _selected => _drafts.where((d) => d.selected).toList();
  List<_StickerDraft> get _targets => _selected.isNotEmpty ? _selected : _drafts;
  int get _readyCount => _drafts.where((d) => d.status == _DraftStatus.ready).length;
  int get _doneCount => _drafts.where((d) => d.status == _DraftStatus.published).length;
  int get _busyCount => _drafts.where((d) => d.isBusy || d.status == _DraftStatus.queued).length;

  // ────────────────────────────────────────────────────────────────────────
  // Picking
  // ────────────────────────────────────────────────────────────────────────
  Future<void> _pickStickers() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'gif'],
        allowMultiple: true,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final room = _maxStickers - _drafts.length;
      var skipped = 0;
      final newDrafts = <_StickerDraft>[];
      for (final f in result.files) {
        if (newDrafts.length >= room) {
          skipped++;
          continue;
        }
        final bytes = f.bytes;
        if (bytes == null || bytes.isEmpty) {
          skipped++;
          continue;
        }
        final ext = (f.extension ?? '').toLowerCase();
        newDrafts.add(_StickerDraft(
          id: '${DateTime.now().microsecondsSinceEpoch}_${newDrafts.length}',
          fileName: f.name,
          bytes: bytes,
          isAnimated: ext == 'gif' || ext == 'webp',
        ));
      }

      setState(() => _drafts.addAll(newDrafts));
      if (skipped > 0 && mounted) {
        _toast('Added ${newDrafts.length} stickers · skipped $skipped (limit $_maxStickers)');
      }
      _processQueue();
    } catch (e) {
      debugPrint('Bulk sticker pick failed: $e');
      _toast('Could not open files: $e', error: true);
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // Upload + AI label pipeline (worker pool)
  // ────────────────────────────────────────────────────────────────────────
  Future<void> _processQueue() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    Future<void> worker() async {
      while (mounted) {
        final next = _drafts.where((d) => d.status == _DraftStatus.queued).firstOrNull;
        if (next == null) return;
        next.status = _DraftStatus.uploading;
        if (mounted) setState(() {});
        await _uploadDraft(next);
        if (next.status == _DraftStatus.failed) continue;
        if (_autoAiTitles) {
          await _labelDraft(next);
        } else {
          next.status = _DraftStatus.ready;
          if (mounted) setState(() {});
        }
      }
    }

    await Future.wait(List.generate(_concurrency, (_) => worker()));
    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _uploadDraft(_StickerDraft d) async {
    if (d.uploadedUrl != null) return;
    try {
      final ext = d.fileName.contains('.') ? d.fileName.split('.').last.toLowerCase() : 'png';
      final mime = switch (ext) {
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'jpg' || 'jpeg' => 'image/jpeg',
        _ => 'image/png',
      };
      final xfile = XFile.fromData(
        d.bytes,
        name: 'sticker_${DateTime.now().millisecondsSinceEpoch}_${d.id.hashCode.abs()}.$ext',
        mimeType: mime,
      );
      final result = await ref.read(imageUploadServiceProvider).uploadImage(xfile);
      if (result.url.isEmpty) throw Exception('Empty upload URL');
      d.uploadedUrl = result.url;
    } catch (e) {
      d.status = _DraftStatus.failed;
      d.error = 'Upload failed';
      debugPrint('Bulk sticker upload error (${d.fileName}): $e');
    }
    if (mounted) setState(() {});
  }

  Future<void> _labelDraft(_StickerDraft d) async {
    if (d.uploadedUrl == null) return;
    d.status = _DraftStatus.labeling;
    if (mounted) setState(() {});
    try {
      final res = await ApiClient.post('/ai/sticker-label', {
        'imageUrl': d.uploadedUrl,
        'fileName': d.fileName,
      });
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final title = (data['title'] ?? '').toString().trim();
        if (title.isNotEmpty) d.titleCtrl.text = title;
        final cat = (data['category'] ?? '').toString().toUpperCase();
        if (_categories.contains(cat)) d.category = cat;
        final tags = data['tags'];
        if (tags is List && tags.isNotEmpty) {
          d.tagsCtrl.text = tags.map((t) => t.toString()).join(', ');
        }
        d.aiLabeled = data['source'] == 'ai';
      }
    } catch (e) {
      debugPrint('AI sticker label error (${d.fileName}): $e');
    }
    d.status = _DraftStatus.ready;
    if (mounted) setState(() {});
  }

  Future<void> _aiLabelTargets() async {
    final targets = _targets.where((d) => d.status == _DraftStatus.ready).toList();
    if (targets.isEmpty) {
      _toast('No uploaded stickers ready for AI titles yet');
      return;
    }
    var i = 0;
    Future<void> worker() async {
      while (i < targets.length && mounted) {
        final d = targets[i++];
        await _labelDraft(d);
      }
    }

    await Future.wait(List.generate(_concurrency, (_) => worker()));
    _toast('✨ AI titled ${targets.length} stickers');
  }

  void _retryFailed() {
    for (final d in _drafts.where((d) => d.status == _DraftStatus.failed)) {
      d.status = d.uploadedUrl != null ? _DraftStatus.ready : _DraftStatus.queued;
      d.error = null;
    }
    setState(() {});
    _processQueue();
  }

  // ────────────────────────────────────────────────────────────────────────
  // Publishing
  // ────────────────────────────────────────────────────────────────────────
  Future<void> _publishAll() async {
    final toPublish = _targets.where((d) => d.status == _DraftStatus.ready).toList();
    if (toPublish.isEmpty) {
      _toast('Nothing ready to publish yet');
      return;
    }
    setState(() {
      _isPublishing = true;
      _publishedCount = 0;
    });

    final repo = ref.read(stickerRepositoryProvider);
    var i = 0;
    Future<void> worker() async {
      while (i < toPublish.length && mounted) {
        final d = toPublish[i++];
        d.status = _DraftStatus.publishing;
        if (mounted) setState(() {});
        try {
          final title = d.titleCtrl.text.trim().isEmpty ? 'Campus Sticker' : d.titleCtrl.text.trim();
          final created = await repo.createSticker(
            title: title,
            imageUrl: d.uploadedUrl!,
            animatedUrl: d.isAnimated ? d.uploadedUrl : null,
            type: d.isAnimated ? 'ANIMATED' : 'STATIC',
            category: d.category,
            tags: d.tags,
            isPublic: d.isPublic,
          );
          if (created != null) await repo.saveSticker(created);
          d.status = _DraftStatus.published;
          _publishedCount++;
        } catch (e) {
          d.status = _DraftStatus.failed;
          d.error = 'Publish failed';
        }
        if (mounted) setState(() {});
      }
    }

    await Future.wait(List.generate(3, (_) => worker()));
    if (!mounted) return;
    setState(() => _isPublishing = false);
    _toast('🎉 Published $_publishedCount stickers to the Sticker Place & your tray');
  }

  // ────────────────────────────────────────────────────────────────────────
  // Bulk edit helpers
  // ────────────────────────────────────────────────────────────────────────
  void _toggleSelectAll() {
    final allSelected = _drafts.isNotEmpty && _drafts.every((d) => d.selected);
    setState(() {
      for (final d in _drafts) {
        d.selected = !allSelected;
      }
    });
  }

  void _removeTargets() {
    final targets = _selected.isNotEmpty
        ? _selected
        : _drafts.where((d) => d.status == _DraftStatus.published).toList();
    if (targets.isEmpty) return;
    setState(() {
      for (final d in targets) {
        if (d.isBusy) continue;
        _drafts.remove(d);
        d.dispose();
      }
    });
  }

  Future<void> _bulkCategory() async {
    final cat = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              title: Text(
                'Set category for ${_targets.length} stickers',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ..._categories.map((c) => ListTile(
                  leading: const Icon(Icons.label_rounded),
                  title: Text(c),
                  onTap: () => Navigator.pop(ctx, c),
                )),
          ],
        ),
      ),
    );
    if (cat == null) return;
    setState(() {
      for (final d in _targets) {
        d.category = cat;
      }
    });
  }

  Future<void> _bulkTags() async {
    final ctrl = TextEditingController();
    final tags = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add tags to ${_targets.length} stickers'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. funny, exam, hostel'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Add')),
        ],
      ),
    );
    ctrl.dispose();
    if (tags == null || tags.trim().isEmpty) return;
    setState(() {
      for (final d in _targets) {
        final merged = {...d.tags, ...tags.split(',').map((t) => t.trim().toLowerCase())}
          ..removeWhere((t) => t.isEmpty);
        d.tagsCtrl.text = merged.join(', ');
      }
    });
  }

  Future<void> _bulkPrefixTitle() async {
    final ctrl = TextEditingController();
    final prefix = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rename ${_targets.length} stickers'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Base name, e.g. "Hostel Vibes"',
            helperText: 'Stickers become "Hostel Vibes 1", "Hostel Vibes 2"…',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Rename')),
        ],
      ),
    );
    ctrl.dispose();
    if (prefix == null || prefix.trim().isEmpty) return;
    setState(() {
      var n = 1;
      for (final d in _targets) {
        d.titleCtrl.text = '${prefix.trim()} ${n++}';
        d.aiLabeled = false;
      }
    });
  }

  void _bulkVisibility(bool isPublic) {
    setState(() {
      for (final d in _targets) {
        d.isPublic = isPublic;
      }
    });
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.redAccent : const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // Single sticker editor
  // ────────────────────────────────────────────────────────────────────────
  void _openEditor(_StickerDraft d, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void refresh() {
            setSheet(() {});
            setState(() {});
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 170,
                      child: Image.memory(d.bytes, fit: BoxFit.contain, gaplessPlayback: true),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: d.titleCtrl,
                      maxLength: 40,
                      onChanged: (_) => d.aiLabeled = false,
                      decoration: InputDecoration(
                        labelText: 'Sticker title',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        suffixIcon: IconButton(
                          tooltip: 'Let AI name it',
                          icon: d.status == _DraftStatus.labeling
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.auto_awesome, color: Color(0xFFF59E0B)),
                          onPressed: d.uploadedUrl == null || d.isBusy
                              ? null
                              : () async {
                                  final future = _labelDraft(d);
                                  refresh();
                                  await future;
                                  if (ctx.mounted) refresh();
                                },
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: d.tagsCtrl,
                      decoration: InputDecoration(
                        labelText: 'Tags (comma separated)',
                        hintText: 'funny, exam, hostel',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _categories
                          .map((c) => ChoiceChip(
                                label: Text(c, style: const TextStyle(fontSize: 11)),
                                selected: d.category == c,
                                selectedColor: AppColors.secondaryTeal.withValues(alpha: 0.25),
                                onSelected: (_) {
                                  d.category = c;
                                  refresh();
                                },
                              ))
                          .toList(),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: d.isPublic,
                      activeThumbColor: AppColors.secondaryTeal,
                      title: const Text('Publish to campus Sticker Place'),
                      subtitle: Text(d.isPublic ? 'Everyone can find & use it' : 'Only in your tray'),
                      onChanged: (v) {
                        d.isPublic = v;
                        refresh();
                      },
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            label: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
                            onPressed: d.isBusy
                                ? null
                                : () {
                                    Navigator.pop(ctx);
                                    setState(() {
                                      _drafts.remove(d);
                                      d.dispose();
                                    });
                                  },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: AppColors.secondaryTeal),
                            icon: const Icon(Icons.check),
                            label: const Text('Done'),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // UI
  // ────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = _drafts.length;
    final progress = total == 0 ? 0.0 : (total - _busyCount) / total;

    return PopScope(
      canPop: !_isPublishing,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bulk Sticker Upload', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              if (total > 0)
                Text(
                  '$total added · $_readyCount ready · $_doneCount published',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                ),
            ],
          ),
          actions: [
            if (total > 0)
              IconButton(
                tooltip: 'Select all',
                icon: Icon(
                  _drafts.every((d) => d.selected) ? Icons.deselect : Icons.select_all,
                ),
                onPressed: _toggleSelectAll,
              ),
            IconButton(
              tooltip: 'Add stickers',
              icon: const Icon(Icons.add_photo_alternate_rounded),
              onPressed: _isPublishing ? null : _pickStickers,
            ),
          ],
          bottom: (_isProcessing || _isPublishing)
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    value: _isPublishing ? null : progress,
                    color: AppColors.secondaryTeal,
                    minHeight: 3,
                  ),
                )
              : null,
        ),
        body: total == 0 ? _buildEmpty(isDark) : _buildEditor(isDark),
        bottomNavigationBar: total == 0 ? null : _buildBottomBar(isDark),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEC4899)]),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: const Icon(Icons.collections_rounded, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 22),
            const Text(
              'Upload plenty stickers at once',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick up to $_maxStickers PNG, JPG, WebP or GIF stickers (animated ones stay animated). '
              'AI writes a title, category and tags for each one, and you can edit anything before publishing.',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              value: _autoAiTitles,
              onChanged: (v) => setState(() => _autoAiTitles = v),
              activeThumbColor: const Color(0xFFF59E0B),
              secondary: const Icon(Icons.auto_awesome, color: Color(0xFFF59E0B)),
              title: const Text('Auto-name with AI', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Turn off to type titles yourself'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.secondaryTeal,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _pickStickers,
              icon: const Icon(Icons.upload_rounded),
              label: const Text('Choose Stickers', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor(bool isDark) {
    final failed = _drafts.where((d) => d.status == _DraftStatus.failed).length;
    return Column(
      children: [
        // Bulk tools row
        Container(
          color: isDark ? const Color(0xFF111C2E) : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    _selected.isNotEmpty ? '${_selected.length} selected' : 'All ${_drafts.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                _toolChip(Icons.auto_awesome, 'AI titles', _aiLabelTargets, color: const Color(0xFFF59E0B)),
                _toolChip(Icons.drive_file_rename_outline, 'Rename', _bulkPrefixTitle),
                _toolChip(Icons.label_rounded, 'Category', _bulkCategory),
                _toolChip(Icons.tag, 'Tags', _bulkTags),
                _toolChip(Icons.public, 'Public', () => _bulkVisibility(true)),
                _toolChip(Icons.lock_outline, 'Private', () => _bulkVisibility(false)),
                if (failed > 0) _toolChip(Icons.refresh, 'Retry $failed', _retryFailed, color: Colors.redAccent),
                _toolChip(
                  Icons.delete_sweep_outlined,
                  _selected.isNotEmpty ? 'Remove' : 'Clear published',
                  _removeTargets,
                  color: Colors.redAccent,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 190,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.70,
            ),
            itemCount: _drafts.length + 1,
            itemBuilder: (context, index) {
              if (index == _drafts.length) return _buildAddTile(isDark);
              return _buildDraftTile(_drafts[index], isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _toolChip(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        avatar: Icon(icon, size: 16, color: color ?? AppColors.secondaryTeal),
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        onPressed: _isPublishing ? null : onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildAddTile(bool isDark) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _isPublishing ? null : _pickStickers,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.secondaryTeal.withValues(alpha: 0.5), width: 1.5),
          color: AppColors.secondaryTeal.withValues(alpha: 0.06),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 36, color: AppColors.secondaryTeal),
            SizedBox(height: 6),
            Text('Add more', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondaryTeal)),
          ],
        ),
      ),
    );
  }

  Widget _buildDraftTile(_StickerDraft d, bool isDark) {
    final (statusLabel, statusColor) = switch (d.status) {
      _DraftStatus.queued => ('Queued', Colors.grey),
      _DraftStatus.uploading => ('Uploading…', Colors.blueAccent),
      _DraftStatus.labeling => ('AI naming…', const Color(0xFFF59E0B)),
      _DraftStatus.ready => ('Ready', AppColors.secondaryTeal),
      _DraftStatus.publishing => ('Publishing…', Colors.purpleAccent),
      _DraftStatus.published => ('Published ✓', Colors.green),
      _DraftStatus.failed => (d.error ?? 'Failed', Colors.redAccent),
    };

    return GestureDetector(
      onTap: () => _openEditor(d, isDark),
      onLongPress: () => setState(() => d.selected = !d.selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: d.selected
                ? AppColors.secondaryTeal
                : (isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.2)),
            width: d.selected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Opacity(
                      opacity: d.status == _DraftStatus.published ? 0.55 : 1,
                      child: Image.memory(d.bytes, fit: BoxFit.contain, gaplessPlayback: true),
                    ),
                  ),
                  if (d.isBusy)
                    const Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      ),
                    ),
                  Positioned(
                    top: 0,
                    left: 0,
                    child: GestureDetector(
                      onTap: () => setState(() => d.selected = !d.selected),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: d.selected ? AppColors.secondaryTeal : Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          d.selected ? Icons.check : Icons.circle_outlined,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Row(
                      children: [
                        if (d.isAnimated) _badge('GIF', Colors.purple),
                        if (d.aiLabeled) _badge('AI', const Color(0xFFF59E0B)),
                        if (!d.isPublic) _badge('🔒', Colors.black54),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: d.titleCtrl,
              enabled: !d.isBusy && d.status != _DraftStatus.published,
              maxLines: 1,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              onChanged: (_) => d.aiLabeled = false,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    d.category,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.black54),
                  ),
                ),
                Text(
                  statusLabel,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 3),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    final targets = _targets.where((d) => d.status == _DraftStatus.ready).length;
    final allDone = _drafts.isNotEmpty && _drafts.every((d) => d.status == _DraftStatus.published);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _isPublishing
                    ? 'Publishing… $_publishedCount done'
                    : (_busyCount > 0 ? 'Processing $_busyCount…' : '$targets ready to publish'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (allDone)
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.done_all),
                label: const Text('Finish'),
              )
            else
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.secondaryTeal,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                onPressed: (_isPublishing || targets == 0) ? null : _publishAll,
                icon: const Icon(Icons.rocket_launch_rounded),
                label: Text(
                  _selected.isNotEmpty ? 'Publish selected ($targets)' : 'Publish all ($targets)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
