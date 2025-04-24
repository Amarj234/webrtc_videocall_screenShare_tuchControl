import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';

import 'audio_broadcast_signaling.dart';
import 'audio_brodcast.dart';

class AudioRoomListPage extends StatelessWidget {
  final box = GetStorage();

   AudioRoomListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Broadcasts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _createNewRoom(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: AudioSignaling.getActiveRooms(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No active broadcasts'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final room = snapshot.data!.docs[index];
              return _buildRoomItem(room, context);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNewRoom(context),
        child: const Icon(Icons.live_tv),
        tooltip: 'Start New Broadcast',
      ),
    );
  }

  Widget _buildRoomItem(DocumentSnapshot room, BuildContext context) {
    final roomData = room.data() as Map<String, dynamic>;
    final broadcasterEmail = roomData['broadcasterEmail'] ?? 'Unknown';
    final createdAt = roomData['createdAt']?.toDate() ?? DateTime.now();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.radio, color: Colors.blue),
        title: Text('Broadcast by ${broadcasterEmail.split('@').first}'),
        subtitle: Text('Started ${_formatTime(createdAt)}'),
        trailing: const Icon(Icons.headphones),
        onTap: () => _joinRoom(context, room.id),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _joinRoom(BuildContext context, String roomId) {
    final storedEmail = box.read('email');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AudioBroadcastPage(
          isBroadcaster: false,
          roomId: roomId,
          storedEmail: storedEmail,
        ),
      ),
    );
  }

  void _createNewRoom(BuildContext context) {
    final storedEmail = box.read('email');
    final roomId = DateTime.now().millisecondsSinceEpoch.toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AudioBroadcastPage(
          storedEmail: storedEmail,
          isBroadcaster: true,
          roomId: roomId,
        ),
      ),
    );
  }
}