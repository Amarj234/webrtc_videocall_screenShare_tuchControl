import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class AudioSignaling {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _userId;
  final String _roomId;
  final bool _isBroadcaster;

  MediaStream? _localStream;
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, MediaStream> _remoteStreams = {};

  Function(String userId, MediaStream stream)? onRemoteStreamAdded;
  Function(String userId)? onUserJoined;
  Function(String userId)? onUserLeft;
  Function(dynamic error)? onError;
  Function()? onRoomReady;

  AudioSignaling({
    required String userId,
    required String roomId,
    required bool isBroadcaster,
  })  : _userId = userId,
        _roomId = roomId,
        _isBroadcaster = isBroadcaster;

  Future<void> initialize() async {
    try {
      await _setupRoom();
      await _initLocalStream();
      _setupParticipantsListener();
      onRoomReady?.call();
    } catch (e) {
      onError?.call(e);
    }
  }

  Future<void> _initLocalStream() async {
    final constraints = {
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
  }

  Future<void> _setupRoom() async {
    await _db.collection('audio_rooms').doc(_roomId).set({
      'createdAt': FieldValue.serverTimestamp(),
      'broadcasterId': _isBroadcaster ? _userId : null,
      'isActive': true,
    }, SetOptions(merge: true));

    await _db
        .collection('audio_rooms')
        .doc(_roomId)
        .collection('participants')
        .doc(_userId)
        .set({
      'userId': _userId,
      'isBroadcaster': _isBroadcaster,
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  void _setupParticipantsListener() {
    _db
        .collection('audio_rooms')
        .doc(_roomId)
        .collection('participants')
        .snapshots()
        .listen((snapshot) async {
      for (final change in snapshot.docChanges) {
        final peerId = change.doc.id;
        if (peerId == _userId) continue;

        if (change.type == DocumentChangeType.added) {
          onUserJoined?.call(peerId);
          await _connectToPeer(peerId);
        } else if (change.type == DocumentChangeType.removed) {
          onUserLeft?.call(peerId);
          _removePeerConnection(peerId);
        }
      }
    });
  }

  Future<void> _connectToPeer(String peerId) async {
    try {
      final pc = await _createPeerConnection();
      _peerConnections[peerId] = pc;

      if (_localStream != null) {
        for (var track in _localStream!.getAudioTracks()) {
          pc.addTrack(track, _localStream!);
        }
      }

      _setupIceCandidateExchange(peerId, pc);

      if (_isBroadcaster) {
        final offer = await pc.createOffer();
        await pc.setLocalDescription(offer);

        await _db
            .collection('audio_rooms')
            .doc(_roomId)
            .collection('offers')
            .doc('$_userId-$peerId')
            .set({
          'from': _userId,
          'to': peerId,
          'sdp': offer.sdp,
          'type': offer.type,
        });
      } else {
        _listenForOffers(pc, peerId);
      }

      _listenForAnswers(pc, peerId);
    } catch (e) {
      onError?.call(e);
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
        await _db
            .collection('audio_rooms')
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
      if (event.track.kind == 'audio' && event.streams.isNotEmpty) {
        final stream = event.streams[0];
        _remoteStreams[stream.id] = stream;
        onRemoteStreamAdded?.call(stream.id, stream);
      }
    };

    return pc;
  }

  void _listenForOffers(RTCPeerConnection pc, String peerId) {
    _db
        .collection('audio_rooms')
        .doc(_roomId)
        .collection('offers')
        .where('to', isEqualTo: _userId)
        .snapshots()
        .listen((snapshot) async {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['from'] != peerId) continue;

        final polite = _userId.compareTo(peerId) > 0; // You are polite if your ID is higher
        final offer = RTCSessionDescription(data['sdp'], data['type']);

        bool makingOffer = pc.signalingState == RTCSignalingState.RTCSignalingStateHaveLocalOffer;

        try {
          if (makingOffer && !polite) {
            print("⚠️ Offer collision with $peerId. Ignoring because we're impolite.");
            return;
          }

          await pc.setRemoteDescription(offer);

          final answer = await pc.createAnswer();
          await pc.setLocalDescription(answer);

          await _db
              .collection('audio_rooms')
              .doc(_roomId)
              .collection('answers')
              .doc('$_userId-$peerId')
              .set({
            'from': _userId,
            'to': peerId,
            'sdp': answer.sdp,
            'type': answer.type,
          });

          print("✅ Sent answer to $peerId");

        } catch (e) {
          print("❌ Failed to process offer from $peerId: $e");
          onError?.call(e);
        }
      }
    });
  }

  void _listenForAnswers(RTCPeerConnection pc, String peerId) {
    _db
        .collection('audio_rooms')
        .doc(_roomId)
        .collection('answers')
        .where('to', isEqualTo: _userId)
        .snapshots()
        .listen((snapshot) async {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['from'] != peerId) continue;

        final answer = RTCSessionDescription(data['sdp'], data['type']);
        await pc.setRemoteDescription(answer);
      }
    });
  }

  bool _isPolite(String peerId) => _userId.compareTo(peerId) > 0;

  void _setupIceCandidateExchange(String peerId, RTCPeerConnection pc) {
    _db
        .collection('audio_rooms')
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
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !muted;
    });
  }

  Future<void> disconnect() async {
    for (var pc in _peerConnections.values) {
      await pc.close();
    }
    _peerConnections.clear();

    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream = null;

    await _db
        .collection('audio_rooms')
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

  void _removePeerConnection(String peerId) {
    _peerConnections[peerId]?.close();
    _peerConnections.remove(peerId);
    _remoteStreams.remove(peerId);
  }

  static Stream<QuerySnapshot> getActiveRooms() {
    return FirebaseFirestore.instance
        .collection('audio_rooms')
        .where('isActive', isEqualTo: true)
        .snapshots();
  }
}
