import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'audio_broadcast_signaling.dart';

class AudioBroadcastPage extends StatefulWidget {
  final bool isBroadcaster;
  final String roomId;
  final String? storedEmail;

  const AudioBroadcastPage({
    super.key,
    required this.isBroadcaster,
    required this.roomId,
    this.storedEmail,
  });

  @override
  _AudioBroadcastPageState createState() => _AudioBroadcastPageState();
}

class _AudioBroadcastPageState extends State<AudioBroadcastPage> {
  late AudioSignaling signaling;
  final String _userId = DateTime.now().millisecondsSinceEpoch.toString();
  bool _isMuted = false;
  bool _isSpeaking = false;
  bool _isConnected = false;
  int _listenerCount = 0;
  List<Map<String, dynamic>> _participants = [];

  @override
  void initState() {
    super.initState();
    _initSignaling();
    _loadParticipants();
  }

  void _initSignaling() {
    signaling = AudioSignaling(
      userId: _userId,
      roomId: widget.roomId,
      isBroadcaster: widget.isBroadcaster,
      storedEmail: widget.storedEmail,
    );

    // Listener setup for audio
    if (!widget.isBroadcaster) {
      signaling.onRemoteStreamAdded = (MediaStream stream) {

        print ('Remote stream added: ${stream.ownerTag}');
        // ⚠️ Audio will play automatically when assigned as srcObject
        for (var track in stream.getAudioTracks()) {
          track.enabled = true;
        }
        // Just setting stream is enough; no video renderer needed
        setState(() => _isConnected = true);
      };
    }

    signaling.onUserJoined = (userId) {
      if (widget.isBroadcaster) {
        setState(() => _listenerCount = signaling.getListenerCount());
      }
    };

    signaling.onUserLeft = (userId) {
      if (widget.isBroadcaster) {
       _listenerCount = signaling.getListenerCount();
      }
    };



    signaling.onError = (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    };

    signaling.onRoomReady = () {
      setState(() => _isConnected = true);
    };

    signaling.initialize();
  }

  void _loadParticipants() {
    FirebaseFirestore.instance
        .collection('audio_rooms')
        .doc(widget.roomId)
        .collection('participants')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _participants = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'userId': doc.id,
              'name': data['name'] ?? 'Anonymous',
              'isBroadcaster': data['isBroadcaster'] ?? false,
              'isSpeaking': data['isSpeaking'] ?? false,
            };
          }).toList();
        });
      }
    });
  }

  void _toggleMute() async {
    await signaling.toggleMute(!_isMuted);
    setState(() => _isMuted = !_isMuted);
  }

  void _toggleSpeaking() async {
    if (!_isSpeaking) {
      await signaling.toggleMute(false);
    } else {
      await signaling.toggleMute(true);
    }
    setState(() => _isSpeaking = !_isSpeaking);
  }

  Future<void> _disconnect() async {
    await signaling.disconnect();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  String _getActiveSpeakers() {
    final speakers = _participants.where((p) => p['isSpeaking'] == true).toList();
    if (speakers.isEmpty) return 'No active speakers';
    return speakers.map((p) => p['name']).join(', ');
  }

  @override
  void dispose() {
    signaling.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isBroadcaster ? 'Your Broadcast' : 'Listening'),
        actions: [
          if (widget.isBroadcaster)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Listeners: $_listenerCount',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    _isMuted ? 'Muted' : 'Live',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isMuted ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.isBroadcaster ? Icons.mic : Icons.headphones,
              size: 100,
              color: _isConnected ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 20),
            Text(
              widget.isBroadcaster ? 'You are broadcasting' : 'Connected to broadcast',
              style: const TextStyle(fontSize: 20),
            ),
            if (!_isConnected) ...[
              const SizedBox(height: 20),
              const CircularProgressIndicator(),
            ],
            const SizedBox(height: 20),
            Text(
              _getActiveSpeakers(),
              style: const TextStyle(
                fontSize: 16,
                color: Colors.blue,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (!widget.isBroadcaster)
            FloatingActionButton(
              heroTag: "speak",
              onPressed: _toggleSpeaking,
              backgroundColor: _isSpeaking ? Colors.green : Colors.grey,
              child: Icon(_isSpeaking ? Icons.mic : Icons.mic_off),
            ),
          if (widget.isBroadcaster)
            FloatingActionButton(
              heroTag: "mute",
              onPressed: _toggleMute,
              backgroundColor: _isMuted ? Colors.red : Colors.green,
              child: Icon(_isMuted ? Icons.mic_off : Icons.mic),
            ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "disconnect",
            onPressed: _disconnect,
            backgroundColor: Colors.red,
            child: const Icon(Icons.call_end),
          ),
        ],
      ),
    );
  }
}
