import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class AudioSignaling {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _userId;
  final String _roomId;
  final bool _isBroadcaster;
  final String? _storedEmail;

  MediaStream? _localStream;
  final Map<String, RTCPeerConnection> _peerConnections = {};

  // Callbacks
  Function(MediaStream stream)? onRemoteStreamAdded;
  Function(String userId)? onUserJoined;
  Function(String userId)? onUserLeft;
  Function(dynamic error)? onError;
  Function()? onRoomReady;

  AudioSignaling({
    required String userId,
    required String roomId,
    required bool isBroadcaster,
    String? storedEmail,
  })
      : _userId = userId,
        _roomId = roomId,
        _isBroadcaster = isBroadcaster,
        _storedEmail = storedEmail;

  Future<void> initialize() async {
    try {
      await _setupRoom();
      await _initLocalStream();
      _setupParticipantsListener();
      onRoomReady?.call();
    } catch (e) {
      onError?.call("Initialization error: $e");
    }
  }

  Future<void> _initLocalStream() async {
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false, // Audio-only for the broadcaster
      });
      print("Local stream initialized: ${_localStream?.id}");
    } catch (e) {
      onError?.call("Error accessing media devices: $e");
    }
  }

  Future<void> _setupRoom() async {
    try {
      await _db.collection('audio_rooms').doc(_roomId).set({
        'createdAt': FieldValue.serverTimestamp(),
        'broadcasterId': _isBroadcaster ? _userId : null,
        'broadcasterEmail': _isBroadcaster ? _storedEmail : null,
        'isActive': true,
      }, SetOptions(merge: true));

      await _db.collection('audio_rooms')
          .doc(_roomId)
          .collection('participants')
          .doc(_userId)
          .set({
        'userId': _userId,
        'name': _storedEmail ?? 'Anonymous',
        'email': _storedEmail,
        'isBroadcaster': _isBroadcaster,
        'isSpeaking': false,
        'joinedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      onError?.call("Error setting up room: $e");
    }
  }

  void _setupParticipantsListener() {
    _db.collection('audio_rooms')
        .doc(_roomId)
        .collection('participants')
        .snapshots()
        .listen((snapshot) async {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added &&
            change.doc.id != _userId) {
          onUserJoined?.call(change.doc.id);
          await _connectToPeer(change.doc.id);
        } else if (change.type == DocumentChangeType.removed) {
          onUserLeft?.call(change.doc.id);
          _removePeerConnection(change.doc.id);
        }
      }
    });
  }

  Future<void> _connectToPeer(String peerId) async {
    try {
      final pc = await _createPeerConnection();
      _peerConnections[peerId] = pc;

      if (_localStream != null) {
        _localStream!.getAudioTracks().forEach((track) {
          pc.addTrack(track, _localStream!);
        });
        print("Added local audio tracks to peer connection");
      }

      _setupIceCandidateExchange(peerId, pc);

      if (_isBroadcaster) {
        final offer = await pc.createOffer();
        await pc.setLocalDescription(offer);

        await _db.collection('audio_rooms')
            .doc(_roomId)
            .collection('offers')
            .doc(_userId)
            .set({
          'from': _userId,
          'to': peerId,
          'sdp': offer.sdp,
          'type': offer.type,
        });
      } else {
        _listenForOffers(pc);
      }
    } catch (e) {
      onError?.call("Error connecting to peer: $e");
    }
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    final pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    });

    pc.onIceCandidate = (candidate) async {
      if (candidate != null) {
        await _db.collection('audio_rooms')
            .doc(_roomId)
            .collection('candidates')
            .add({
          'from': _userId,
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      }
    };

    pc.onTrack = (RTCTrackEvent event) {
      if (event.track.kind == 'audio') {
        print("Remote audio track received: ${event.streams[0].id}");
        onRemoteStreamAdded?.call(event.streams[0]);
      }
    };

    pc.onIceConnectionState = (state) {
      if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        _removePeerConnectionByPC(pc);
      }
    };

    return pc;
  }

  void _listenForOffers(RTCPeerConnection pc) {
    _db.collection('audio_rooms')
        .doc(_roomId)
        .collection('offers')
        .where('to', isEqualTo: _userId)
        .snapshots()
        .listen((snapshot) async {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final offer = RTCSessionDescription(
          data['sdp'],
          data['type'],
        );

        await pc.setRemoteDescription(offer);
        final answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);

        await _db.collection('audio_rooms')
            .doc(_roomId)
            .collection('answers')
            .add({
          'from': _userId,
          'to': data['from'],
          'sdp': answer.sdp,
          'type': answer.type,
        });
      }
    });
  }

  void _setupIceCandidateExchange(String peerId, RTCPeerConnection pc) {
    _db.collection('audio_rooms')
        .doc(_roomId)
        .collection('candidates')
        .where('from', isEqualTo: peerId)
        .snapshots()
        .listen((snapshot) async {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final candidate = RTCIceCandidate(
          data['candidate'],
          data['sdpMid'],
          data['sdpMLineIndex'],
        );
        await pc.addCandidate(candidate);
      }
    });
  }

  Future<void> toggleMute(bool muted) async {
    if (_localStream != null) {
      _localStream!.getAudioTracks().forEach((track) {
        track.enabled = !muted;
      });
      await _updateSpeakingStatus(!muted);
    }
  }

  Future<void> _updateSpeakingStatus(bool isSpeaking) async {
    await _db.collection('audio_rooms')
        .doc(_roomId)
        .collection('participants')
        .doc(_userId)
        .update({
      'isSpeaking': isSpeaking,
      'lastActive': FieldValue.serverTimestamp(),
    });
  }

  int getListenerCount() {
    return _peerConnections.length;
  }

  List<String> getListenerIds() {
    return _peerConnections.keys.toList();
  }

  void _removePeerConnection(String peerId) {
    final pc = _peerConnections[peerId];
    if (pc != null) {
      pc.close();
      _peerConnections.remove(peerId);
    }
  }

  void _removePeerConnectionByPC(RTCPeerConnection pc) {
    pc.close();
    _peerConnections.removeWhere((key, value) => value == pc);
  }

  Future<void> disconnect() async {
    for (final pc in _peerConnections.values) {
      await pc.close();
    }
    _peerConnections.clear();

    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream = null;

    await _db.collection('audio_rooms')
        .doc(_roomId)
        .collection('participants')
        .doc(_userId)
        .delete();

    if (_isBroadcaster) {
      await _db.collection('audio_rooms').doc(_roomId).update({
        'isActive': false,
      });
    }
  }

  static Stream<QuerySnapshot> getActiveRooms() {
    return FirebaseFirestore.instance
        .collection('audio_rooms')
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

}