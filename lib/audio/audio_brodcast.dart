import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get_storage/get_storage.dart';
import 'audio_signaling.dart';

class AudioBroadcastPage extends StatefulWidget {
  final bool isBroadcaster;
  final String roomId;

  const AudioBroadcastPage({
    super.key,
    required this.isBroadcaster,
    required this.roomId,
  });

  @override
  _AudioBroadcastPageState createState() => _AudioBroadcastPageState();
}

class _AudioBroadcastPageState extends State<AudioBroadcastPage> {
  late AudioSignaling signaling;
   String _userId = DateTime.now().millisecondsSinceEpoch.toString();
  bool _isMuted = false;
  bool _isConnected = false;
  int _listenerCount = 0;
  final Map<String, MediaStream> _remoteStreams = {};
  final box = GetStorage();

  @override
  void initState() {
    super.initState();
    _initSignaling();
  }

  void _initSignaling() {
    final storedEmail = box.read('email');
    _userId= storedEmail;
    signaling = AudioSignaling(
      userId: _userId,
      roomId: widget.roomId,
      isBroadcaster: widget.isBroadcaster,
    );

    signaling.onRemoteStreamAdded = (userId, stream) {
      setState(() {
        _remoteStreams[userId] = stream;
        _isConnected = true;
      });
    };

    signaling.onUserJoined = (userId) {
      if (widget.isBroadcaster) {
        _listenerCount++;
      }
    };

    signaling.onUserLeft = (userId) {
      if (widget.isBroadcaster) {


        _listenerCount--;
      }
       _remoteStreams.remove(userId);
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

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    signaling.toggleMute(_isMuted);
  }

  Future<void> _disconnect() async {
    await signaling.disconnect();
    if (mounted) {
      Navigator.pop(context);
    }
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
              child: Center(
                child: Text(
                  'Listeners: $_listenerCount',
                  style: const TextStyle(fontSize: 16),
                ),
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
            if (_remoteStreams.isNotEmpty)
              Text(
                'Active speakers: ${_remoteStreams.length}',
                style: const TextStyle(fontSize: 16, color: Colors.blue),
              ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
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