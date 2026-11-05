import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:abuad/src/features/feed/presentation/widgets/post_text_utils.dart';
import 'package:abuad/src/shared/widgets/formatted_comment_content.dart';
import 'package:abuad/src/shared/widgets/abuad_markdown.dart';

void main() {
  group('PostTextUtils Tests', () {
    test('Short post is not marked as long', () {
      const shortText = 'Hey everyone, check this out!';
      expect(PostTextUtils.isContentLong(shortText), isFalse);
    });

    test('Post exceeding line limit is marked as long', () {
      final multiline = List.generate(8, (i) => 'Line $i').join('\n');
      expect(PostTextUtils.isContentLong(multiline, maxLines: 5), isTrue);
    });

    test('Post exceeding character limit is marked as long and truncated cleanly', () {
      final longText = 'A' * 400;
      expect(PostTextUtils.isContentLong(longText, maxChars: 300), isTrue);

      final truncated = PostTextUtils.truncatePostContent(longText, maxChars: 280, maxLines: 4);
      expect(truncated.endsWith('...'), isTrue);
      expect(truncated.length, lessThanOrEqualTo(285));
    });

    test('Extra long post detection for detail screen dropdown', () {
      final story = 'Word ' * 200; // ~1000 chars
      expect(PostTextUtils.isContentExtraLong(story, maxChars: 850), isTrue);

      const normalDetailPost = 'This is a moderate length post for details screen.';
      expect(PostTextUtils.isContentExtraLong(normalDetailPost, maxChars: 850), isFalse);
    });
  });

  group('FormattedCommentContent Widget Tests', () {
    testWidgets('Renders plain comment text without errors', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: FormattedCommentContent(
                content: 'Hello campus world!',
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AbuadMarkdownContent), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Hello campus world!'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Extracts text and sticker cleanly when both are present', (tester) async {
      const combined = 'Fakkkkk\n\n![sticker](https://cdn.abuadapp.com.ng/stickers/barca.png)';

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: FormattedCommentContent(
                content: combined,
              ),
            ),
          ),
        ),
      );

      // Verifies the text is rendered separately
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Fakkkkk'),
        ),
        findsOneWidget,
      );
      // ClipRRect wraps the sticker image
      expect(find.byType(ClipRRect), findsOneWidget);
    });
  });
}
