import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import '../../../core/theme/app_colors.dart';

/// A unified screen for editing images across the ABUAD app.
/// This screen wraps [ProImageEditor] with consistent branding and configuration.
class UnifiedImageEditor extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ProImageEditor.file(
      file,
      callbacks: ProImageEditorCallbacks(
        onImageEditingComplete: (Uint8List bytes) async {
          // Save edited image to a temporary file
          final tempDir = await getTemporaryDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final editedPath = '${tempDir.path}/edited_$timestamp.jpg';
          final editedFile = File(editedPath);
          await editedFile.writeAsBytes(bytes);
          
          onImageEditingComplete(XFile(editedPath));
          
          if (context.mounted) Navigator.pop(context);
        },
        onCloseEditor: (editorMode) {
          if (context.mounted) Navigator.pop(context);
        },
      ),
      configs: ProImageEditorConfigs(
        designMode: ImageEditorDesignMode.material,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.secondaryTeal,
            brightness: Brightness.dark,
            surface: AppColors.surfaceDark,
          ),
          scaffoldBackgroundColor: AppColors.surfaceDark,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.surfaceDark,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
        ),
      ),
    );
  }
}
