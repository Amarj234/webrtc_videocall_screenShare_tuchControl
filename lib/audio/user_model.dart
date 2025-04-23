import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String userId;
  final String name;
  final bool isBroadcaster;
  final DateTime joinedAt;

  UserProfile({
    required this.userId,
    required this.name,
    required this.isBroadcaster,
    required this.joinedAt,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      userId: doc.id,
      name: data['name'] ?? 'Anonymous',
      isBroadcaster: data['isBroadcaster'] ?? false,
      joinedAt: data['joinedAt']?.toDate() ?? DateTime.now(),
    );
  }
}