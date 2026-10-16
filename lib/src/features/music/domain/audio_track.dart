class AudioTrack {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final String? coverUrl;
  final String audioUrl;
  final int duration; // in seconds
  final String category;
  final int usesCount;
  final bool isVerified;
  final bool isTrending;
  final List<String> tags;

  const AudioTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.coverUrl,
    required this.audioUrl,
    this.duration = 30,
    this.category = 'Trending',
    this.usesCount = 0,
    this.isVerified = false,
    this.isTrending = false,
    this.tags = const [],
  });

  String get formattedDuration {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedUses {
    if (usesCount < 1000) return '$usesCount videos';
    if (usesCount < 1000000) {
      final k = (usesCount / 1000).toStringAsFixed(1);
      return '${k}K videos';
    }
    final m = (usesCount / 1000000).toStringAsFixed(1);
    return '${m}M videos';
  }

  factory AudioTrack.fromMap(Map<String, dynamic> map) {
    return AudioTrack(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Original Audio',
      artist: map['artist']?.toString() ?? 'Unknown Artist',
      album: map['album']?.toString(),
      coverUrl: map['coverUrl']?.toString(),
      audioUrl: map['audioUrl']?.toString() ?? '',
      duration: (map['duration'] is int)
          ? map['duration'] as int
          : int.tryParse(map['duration']?.toString() ?? '30') ?? 30,
      category: map['category']?.toString() ?? 'Trending',
      usesCount: (map['usesCount'] is int)
          ? map['usesCount'] as int
          : int.tryParse(map['usesCount']?.toString() ?? '0') ?? 0,
      isVerified: map['isVerified'] == true,
      isTrending: map['isTrending'] == true,
      tags: (map['tags'] is List)
          ? (map['tags'] as List).map((e) => e.toString()).toList()
          : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'coverUrl': coverUrl,
      'audioUrl': audioUrl,
      'duration': duration,
      'category': category,
      'usesCount': usesCount,
      'isVerified': isVerified,
      'isTrending': isTrending,
      'tags': tags,
    };
  }
}
