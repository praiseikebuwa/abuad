class StudentGroup {
  final String id;
  final String name;
  final String description;
  final String category; // Academic, Social, Sports, Religious
  final String imageUrl;
  final int memberCount;
  final bool isPrivate;

  StudentGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.imageUrl,
    this.memberCount = 0,
    this.isPrivate = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'imageUrl': imageUrl,
      'memberCount': memberCount,
      'isPrivate': isPrivate,
    };
  }

  factory StudentGroup.fromMap(String id, Map<String, dynamic> map) {
    return StudentGroup(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? 'General',
      imageUrl: map['imageUrl'] ?? '',
      memberCount: map['memberCount'] ?? 0,
      isPrivate: map['isPrivate'] ?? false,
    );
  }
}
