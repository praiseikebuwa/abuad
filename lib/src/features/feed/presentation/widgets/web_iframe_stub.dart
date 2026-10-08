import 'package:flutter/material.dart';

Widget buildWebIframeWidget(String embedUrl, Color themeColor) {
  return Container(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.web_asset_rounded, size: 64, color: themeColor),
        const SizedBox(height: 16),
        const Text(
          'Embedded web preview is optimized for Web browsers.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
