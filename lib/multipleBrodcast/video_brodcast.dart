import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'miltiple_signaling.dart';


class MultiUserBroadcastPage extends StatefulWidget {
  final bool isBroadcaster;
  final String roomId;

  const MultiUserBroadcastPage({
    super.key,
    required this.isBroadcaster,
    required this.roomId,
  });

  @override
  _MultiUserBroadcastPageState createState() => _MultiUserBroadcastPageState();
}

class _MultiUserBroadcastPageState extends State<MultiUserBroadcastPage> {
  late MultiUserSignaling signaling;
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> remoteRenderers = {};
  bool isMuted = false;
  bool isSharingScreen = false;
  String userId = DateTime.now().millisecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _initSignaling();
  }

  Future<void> _initRenderers() async {
    await localRenderer.initialize();
  }

  void _initSignaling() {
    signaling = MultiUserSignaling(
      userId: userId,
      roomId: widget.roomId,
      isBroadcaster: widget.isBroadcaster,
    );

    signaling.onRemoteStreamAdded = (stream) {
      final renderer = RTCVideoRenderer();
      renderer.initialize().then((_) {
        renderer.srcObject = stream;
        final streamId = stream.id;
        setState(() {
          remoteRenderers[streamId] = renderer;
        });
      });
    };

    signaling.onUserJoined = (userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User $userId joined')),
      );
    };

    signaling.onUserLeft = (userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User $userId left')),
      );
    };

    signaling.onError = (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    };

    signaling.onRoomCreated = () {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room ready for participants')),
      );
    };

    signaling.initialize();
  }

  @override
  void dispose() {
    localRenderer.dispose();
    for (final renderer in remoteRenderers.values) {
      renderer.dispose();
    }
    signaling.disconnect();
    super.dispose();
  }

  void toggleMute() {
    setState(() {
      isMuted = !isMuted;
    });
    // Implement mute functionality in signaling
  }

  void toggleScreenShare() async {
    setState(() {
      isSharingScreen = !isSharingScreen;
    });
    // Implement screen share functionality in signaling
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isBroadcaster ? 'Broadcaster' : 'Viewer'),
      ),
      body: Stack(
        children: [
          // Remote streams
          for (final entry in remoteRenderers.entries)
            Positioned.fill(
              child: RTCVideoView(entry.value),
            ),

          // Local preview
          if (widget.isBroadcaster)
            Positioned(
              bottom: 20,
              right: 20,
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: RTCVideoView(localRenderer, mirror: true),
              ),
            ),
        ],
      ),
      floatingActionButton: widget.isBroadcaster
          ? Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton(
            heroTag: "1tg",
            onPressed: toggleMute,
            backgroundColor: isMuted ? Colors.red : Colors.green,
            child: Icon(isMuted ? Icons.mic_off : Icons.mic),
          ),
          const SizedBox(width: 20),
          FloatingActionButton(
            heroTag: "11tg",
            onPressed: toggleScreenShare,
            backgroundColor: isSharingScreen ? Colors.blue : Colors.grey,
            child: Icon(Icons.screen_share),
          ),
          const SizedBox(width: 20),
          FloatingActionButton(
            heroTag: "1tg3",
            onPressed: () {
              Navigator.pop(context);
            },
            backgroundColor: Colors.red,
            child: const Icon(Icons.call_end),
          ),
        ],
      )
          : FloatingActionButton(
        onPressed: () {
          Navigator.pop(context);
        },
        backgroundColor: Colors.red,
        child: const Icon(Icons.call_end),
      ),
    );
  }
}