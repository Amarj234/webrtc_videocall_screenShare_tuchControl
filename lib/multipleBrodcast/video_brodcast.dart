import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get_storage/get_storage.dart';
import 'broadcast_signaling.dart';

class MultiUserBroadcastPage extends StatefulWidget {
  final bool isBroadcaster;
  final String roomId;

  const MultiUserBroadcastPage({
    super.key,
    required this.isBroadcaster,
    required this.roomId,
  });

  @override
  State<MultiUserBroadcastPage> createState() => _MultiUserBroadcastPageState();
}

class _MultiUserBroadcastPageState extends State<MultiUserBroadcastPage> {
  BroadcastSignaling? signaling;
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> remoteRenderers = {};
  bool isMuted = false;
  bool isSpeaking = false;
  bool isConnected = false;
  int participantCount = 0;
  final box = GetStorage();

  @override
  void initState() {
    super.initState();
    initRenderers().then((_) => initSignaling());
  }

  Future<void> initRenderers() async {
    await localRenderer.initialize();
  }

  Future<void> initSignaling() async {
    final String userId = box.read('email') ?? DateTime.now().millisecondsSinceEpoch.toString();

    signaling = BroadcastSignaling(
      userId: userId,
      onLocalStream: (stream) {
        localRenderer.srcObject = stream;
        setState(() {});
      },
      onAddRemoteStream: (id, stream) async {
        final renderer = RTCVideoRenderer();
        await renderer.initialize();
        renderer.srcObject = stream;
        setState(() {
          remoteRenderers[id] = renderer;
          participantCount = remoteRenderers.length;
        });
      },
      onRemoveRemoteStream: (id) {
      //  setState(() {
          remoteRenderers[id]?.dispose();
          remoteRenderers.remove(id);
          participantCount = remoteRenderers.length;
       // });
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      },
    );

    if (widget.isBroadcaster) {
      await signaling?.startBroadcast(widget.roomId);
    } else {
      await signaling?.joinBroadcast(widget.roomId);
    }

    setState(() => isConnected = true);
  }

  void toggleMute() {
    setState(() => isMuted = !isMuted);
    signaling?.toggleMute(isMuted);
  }

  void toggleSpeaking() {
    setState(() => isSpeaking = !isSpeaking);
    signaling?.toggleMute(isSpeaking);
  }

  Future<void> disconnect() async {
    if (widget.isBroadcaster) {
      await signaling?.endBroadcast();
    } else {
      await signaling?.leaveBroadcast();
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    localRenderer.dispose();
    for (var renderer in remoteRenderers.values) {
      renderer.dispose();
    }
    signaling?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isBroadcaster ? 'Broadcaster' : 'Viewer'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                'Participants: $participantCount',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              children: [
                // Local video preview
                Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(),
                    color: Colors.black,
                  ),
                  child: Stack(
                    children: [
                      if (localRenderer.srcObject != null)
                        RTCVideoView(
                          localRenderer,
                          mirror: true,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          color: Colors.black54,
                          child: Text(
                            'You (${isMuted ? 'Muted' : 'Speaking'})',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Remote participants
                ...remoteRenderers.entries.map((entry) => Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(),
                    color: Colors.black,
                  ),
                  child: Stack(
                    children: [
                      RTCVideoView(
                        entry.value,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          color: Colors.black54,
                          child: Text(
                            'Participant ${entry.key.substring(0, 6)}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
          if (!isConnected)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (!widget.isBroadcaster)
            FloatingActionButton(
              heroTag: "speak",
              onPressed: toggleSpeaking,
              backgroundColor: isSpeaking ? Colors.green : Colors.grey,
              child: Icon(isSpeaking ? Icons.mic : Icons.mic_off),
            ),
          const SizedBox(height: 16),
          if (widget.isBroadcaster)
            FloatingActionButton(
              heroTag: "mute",
              onPressed: toggleMute,
              backgroundColor: isMuted ? Colors.red : Colors.green,
              child: Icon(isMuted ? Icons.mic_off : Icons.mic),
            ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "end",
            onPressed: disconnect,
            backgroundColor: Colors.red,
            child: const Icon(Icons.call_end),
          ),
        ],
      ),
    );
  }
}