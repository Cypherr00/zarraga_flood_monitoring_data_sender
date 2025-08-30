class FloodLevel {
  final String id;
  final String userId;
  final double meters;
  final DateTime createdAt;

  FloodLevel({
    required this.id,
    required this.userId,
    required this.meters,
    required this.createdAt,
  });

  factory FloodLevel.fromMap(Map<String, dynamic> map) {
    return FloodLevel(
      id: map['id'].toString(),
      userId: map['user_id'].toString(),
      meters: (map['meters'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
