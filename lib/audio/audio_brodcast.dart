import 'package:flutter/material.dart';

import 'audio_broadcast_signaling.dart';


class AudioBroadcastPage extends StatefulWidget {
  final bool isBroadcaster;
  final String roomId;
  final String storedEmail;

  const AudioBroadcastPage({
    super.key,
    required this.isBroadcaster,
    required this.roomId,
    required this.storedEmail,
  });

  @override
  _AudioBroadcastPageState createState() => _AudioBroadcastPageState();
}

class _AudioBroadcastPageState extends State<AudioBroadcastPage> {
  late AudioSignaling signaling;
  final String _userId = DateTime.now().millisecondsSinceEpoch.toString();
  bool _isMuted = false;
  bool _isConnected = false;
  int _listenerCount = 0;

  @override
  void initState() {
    super.initState();
    _initSignaling();
  }

  void _initSignaling() {
    signaling = AudioSignaling(
      userId: _userId,
      roomId: widget.roomId,
      storedEmail: widget.storedEmail,
      isBroadcaster: widget.isBroadcaster,
    );

    signaling.onRemoteStreamAdded = (stream) {
      // For listeners, this is the broadcaster's audio stream
      setState(() => _isConnected = true);
    };

    signaling.onUserJoined = (userId) {
      if (widget.isBroadcaster) {
        setState(() => _listenerCount++);
      }
    };

    signaling.onUserLeft = (userId) {
      if (widget.isBroadcaster) {
        setState(() => _listenerCount--);
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
              widget.isBroadcaster
                  ? 'You are broadcasting'
                  : 'Connected to broadcast',
              style: const TextStyle(fontSize: 20),
            ),
            if (!_isConnected) ...[
              const SizedBox(height: 20),
              const CircularProgressIndicator(),
            ],
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