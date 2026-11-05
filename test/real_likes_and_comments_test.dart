import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:abuad/src/features/feed/domain/post.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Optimistic Like Delta Logic Tests', () {
    test('Initial unliked post: user taps like => countDiff is +1', () {
      const bool apiLiked = false;
      const bool userLikedInState = true;
      final countDiff = userLikedInState ? (apiLiked ? 0 : 1) : (apiLiked ? -1 : 0);
      expect(countDiff, equals(1));
    });

    test('After API syncs (apiLiked is true), optimistic state still true => countDiff is 0 (prevents double counting)', () {
      const bool apiLiked = true;
      const bool userLikedInState = true;
      final countDiff = userLikedInState ? (apiLiked ? 0 : 1) : (apiLiked ? -1 : 0);
      expect(countDiff, equals(0));
    });

    test('Initial liked post: user taps unlike => countDiff is -1', () {
      const bool apiLiked = true;
      const bool userLikedInState = false;
      final countDiff = userLikedInState ? (apiLiked ? 0 : 1) : (apiLiked ? -1 : 0);
      expect(countDiff, equals(-1));
    });

    test('After API syncs (apiLiked is false), optimistic state still false => countDiff is 0', () {
      const bool apiLiked = false;
      const bool userLikedInState = false;
      final countDiff = userLikedInState ? (apiLiked ? 0 : 1) : (apiLiked ? -1 : 0);
      expect(countDiff, equals(0));
    });
  });

  group('Post Model Like & Comment Count Immutability Tests', () {
    test('Post.copyWith correctly updates likesCount and commentsCount', () {
      final post = Post(
        id: 'test-p1',
        authorId: 'u1',
        authorName: 'Daniel',
        authorHandle: '@daniel',
        content: 'Campus news update',
        timestamp: DateTime.now(),
        likesCount: 5,
        commentsCount: 2,
        isLiked: false,
      );

      final likedPost = post.copyWith(
        likesCount: post.likesCount + 1,
        isLiked: true,
      );
      expect(likedPost.likesCount, equals(6));
      expect(likedPost.isLiked, isTrue);

      final commentedPost = likedPost.copyWith(
        commentsCount: likedPost.commentsCount + 1,
      );
      expect(commentedPost.commentsCount, equals(3));
    });
  });
}
