import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import '../../../core/theme/app_colors.dart';

/// A unified image editor screen for the ABUAD app.
///
/// **How it works**: the editor pops with the edited [XFile] as its result.
/// The caller `await`s [open] and checks the return value — no callback
/// dependency on a potentially-disposed widget tree.
///
/// Usage:
/// ```dart
/// final edited = await UnifiedImageEditor.open(context, file: myFile);
/// if (edited != null && mounted) setState(() => _selectedImage = edited);
/// ```
class UnifiedImageEditor extends StatefulWidget {
  final File file;

  const UnifiedImageEditor({
    super.key,
    required this.file,
  });

  /// Pushes the editor and returns the edited [XFile], or `null` if cancelled.
  ///
  /// The optional [onDone] callback is supported for backwards compatibility
  /// but is called **after** the route has already popped — callers should
  /// prefer awaiting the return value directly.
  static Future<XFile?> open(
    BuildContext context, {
    required File file,
    Function(XFile editedFile)? onDone,
  }) async {
    final result = await Navigator.push<XFile>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => UnifiedImageEditor(file: file),
      ),
    );
    if (result != null) {
      onDone?.call(result);
    }
    return result;
  }

  @override
  State<UnifiedImageEditor> createState() => _UnifiedImageEditorState();
}

class _UnifiedImageEditorState extends State<UnifiedImageEditor> {
  bool _isProcessing = false;

  Future<void> _handleEditComplete(Uint8List bytes) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final editedPath = '${tempDir.path}/edited_$timestamp.jpg';
      await File(editedPath).writeAsBytes(bytes);

      // Pop WITH the result so the awaiting caller receives the edited file.
      if (mounted) {
        Navigator.of(context).pop(XFile(editedPath));
      }
    } catch (e) {
      debugPrint('UnifiedImageEditor: error saving image: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save edit: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProImageEditor.file(
      widget.file,
      callbacks: ProImageEditorCallbacks(
        onImageEditingComplete: _handleEditComplete,
        onCloseEditor: (_) {
          // Pop with null — caller treats null as "cancelled, keep original".
          if (mounted) Navigator.of(context).pop(null);
        },
      ),
      configs: ProImageEditorConfigs(
        designMode: ImageEditorDesignMode.material,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.secondaryTeal,
            secondary: AppColors.accentAmber,
            surface: Color(0xFF04060E),
          ),
          scaffoldBackgroundColor: const Color(0xFF04060E),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF04060E),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
        ),
        i18n: const I18n(
          done: 'SAVE',
          cancel: 'BACK',
        ),
      ),
    );
  }
}
