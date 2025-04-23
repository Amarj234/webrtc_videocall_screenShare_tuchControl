import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:webrtc_screen_share/multipleBrodcast/video_brodcast.dart';


class BroadcastListPage extends StatefulWidget {
  const BroadcastListPage({super.key});

  @override
  _BroadcastListPageState createState() => _BroadcastListPageState();
}

class _BroadcastListPageState extends State<BroadcastListPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _roomIdController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Broadcasts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateRoomDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _roomIdController,
              decoration: InputDecoration(
                labelText: 'Join by Room ID',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => _joinRoom(context),
                ),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'Active Broadcasts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db.collection('broadcast_rooms')
                  .where('broadcasterId', isNotEqualTo: null)
                  .snapshots(),
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
                    return _buildBroadcastItem(room, context);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "fghdfg",
        onPressed: () => _showCreateRoomDialog(context),
        child: const Icon(Icons.broadcast_on_personal),
        tooltip: 'Start New Broadcast',
      ),
    );
  }

  Widget _buildBroadcastItem(DocumentSnapshot room, BuildContext context) {
    final roomData = room.data() as Map<String, dynamic>;
    final broadcasterId = roomData['broadcasterId'] ?? 'Unknown';
    final createdAt = roomData['createdAt']?.toDate() ?? DateTime.now();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.live_tv, color: Colors.red),
        title: Text('Broadcast by ${broadcasterId.substring(0, 6)}...'),
        subtitle: Text('Started ${_formatTime(createdAt)}'),
        trailing: const Icon(Icons.arrow_forward),
        onTap: () => _joinBroadcast(context, room.id),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  void _joinBroadcast(BuildContext context, String roomId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiUserBroadcastPage(
          isBroadcaster: false,
          roomId: roomId,
        ),
      ),
    );
  }

  void _joinRoom(BuildContext context) {
    if (_roomIdController.text.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiUserBroadcastPage(
          isBroadcaster: false,
          roomId: _roomIdController.text,
        ),
      ),
    );
  }

  Future<void> _showCreateRoomDialog(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start New Broadcast'),
        content: const Text('Do you want to start a new live broadcast?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final roomId = DateTime.now().millisecondsSinceEpoch.toString();
              Navigator.pop(context, roomId);
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (result != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MultiUserBroadcastPage(
            isBroadcaster: true,
            roomId: result,
          ),
        ),
      );
    }
  }
}