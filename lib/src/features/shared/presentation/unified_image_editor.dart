import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import '../../../core/theme/app_colors.dart';

/// A unified screen for editing images across the ABUAD app.
/// This screen wraps [ProImageEditor] with consistent branding and configuration.
class UnifiedImageEditor extends StatefulWidget {
  final File file;
  final Function(XFile editedFile) onImageEditingComplete;

  const UnifiedImageEditor({
    super.key,
    required this.file,
    required this.onImageEditingComplete,
  });

  /// Static helper to simplify navigation and launching the editor.
  static Future<void> open(
    BuildContext context, {
    required File file,
    required Function(XFile editedFile) onDone,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnifiedImageEditor(
          file: file,
          onImageEditingComplete: onDone,
        ),
      ),
    );
  }

  @override
  State<UnifiedImageEditor> createState() => _UnifiedImageEditorState();
}

class _UnifiedImageEditorState extends State<UnifiedImageEditor> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return ProImageEditor.file(
      widget.file,
      callbacks: ProImageEditorCallbacks(
        onImageEditingComplete: (Uint8List bytes) async {
          if (_isProcessing) return;
          
          setState(() {
            _isProcessing = true;
          });

          try {
            // Save edited image to a temporary file
            final tempDir = await getTemporaryDirectory();
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final editedPath = '${tempDir.path}/edited_$timestamp.jpg';
            final editedFile = File(editedPath);
            await editedFile.writeAsBytes(bytes);
            
            widget.onImageEditingComplete(XFile(editedPath));
            
            if (mounted) {
              Navigator.pop(context);
            }
          } catch (e) {
            debugPrint('Error saving edited image: $e');
            if (mounted) {
              setState(() {
                _isProcessing = false;
              });
            }
          }
        },
        onCloseEditor: (editorMode) {
          if (mounted) Navigator.pop(context);
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
