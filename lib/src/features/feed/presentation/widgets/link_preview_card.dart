import 'package:any_link_preview/any_link_preview.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/url_validator.dart';

class LinkPreviewCard extends StatelessWidget {
  final String? url;
  final EdgeInsetsGeometry margin;

  const LinkPreviewCard({
    super.key,
    required this.url,
    this.margin = const EdgeInsets.only(top: 8),
  });

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = UrlValidator.normalizeUrl(url);
    if (normalizedUrl == null) return const SizedBox.shrink();

    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              await launchUrl(
                Uri.parse(normalizedUrl),
                mode: LaunchMode.externalApplication,
              );
            },
            child: AnyLinkPreview(
              link: normalizedUrl,
              displayDirection: UIDirection.uiDirectionVertical,
              showMultimedia: true,
              bodyMaxLines: 3,
              bodyTextOverflow: TextOverflow.ellipsis,
              removeElevation: true,
              borderRadius: 14,
              placeholderWidget: Container(
                height: 100,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                alignment: Alignment.centerLeft,
                child: Text(
                  normalizedUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
