class StudentGroup {
  final String id;
  final String name;
  final String description;
  final String category; // Academic, Social, Sports, Religious
  final String imageUrl;
  final int memberCount;
  final bool isPrivate;
  final String creatorId;

  StudentGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.imageUrl,
    this.memberCount = 0,
    this.isPrivate = false,
    required this.creatorId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'image_url': imageUrl,
      'member_count': memberCount,
      'is_private': isPrivate,
      'creator_id': creatorId,
    };
  }

  factory StudentGroup.fromMap(Map<String, dynamic> map) {
    return StudentGroup(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? 'General',
      imageUrl: map['image_url'] ?? '',
      memberCount: map['member_count'] ?? 0,
      isPrivate: map['is_private'] ?? false,
      creatorId: map['creator_id'] ?? '',
    );
  }
}
