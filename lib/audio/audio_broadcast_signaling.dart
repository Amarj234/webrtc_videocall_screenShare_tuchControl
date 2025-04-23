import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class AudioSignaling {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _userId;
  final String _roomId;
  final String _storedEmail;
  final bool _isBroadcaster;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final Map<String, RTCPeerConnection> _peerConnections = {};

  // Callbacks
  Function(MediaStream stream)? onRemoteStreamAdded;
  Function(String userId)? onUserJoined;
  Function(String userId)? onUserLeft;
  Function(dynamic error)? onError;
  Function()? onRoomReady;

  AudioSignaling( {
    required String userId,
    required String roomId,
    required String storedEmail,
    required bool isBroadcaster,
  }) : _userId = userId, _roomId = roomId, _isBroadcaster = isBroadcaster,_storedEmail=storedEmail;

  Future<void> initialize() async {
    try {
      await _setupRoom();

      if (_isBroadcaster) {
        _localStream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': false, // Audio only
        });
      }

      _setupParticipantsListener();
      onRoomReady?.call();

    } catch (e) {
      onError?.call(e);
    }
  }

  Future<void> _setupRoom() async {
    await _db.collection('audio_rooms').doc(_roomId).set({
      'createdAt': FieldValue.serverTimestamp(),
      'broadcasterId': _isBroadcaster ? _userId : null,
      'isActive': true,
    }, SetOptions(merge: true));

    await _db.collection('audio_rooms')
        .doc(_roomId)
        .collection('participants')
        .doc(_userId)
        .set({
      'userId': _userId,
      'storedEmail': _storedEmail,
      'isBroadcaster': _isBroadcaster,
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  void _setupParticipantsListener() {
    _db.collection('audio_rooms')
        .doc(_roomId)
        .collection('participants')
        .snapshots()
        .listen((snapshot) async {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added && change.doc.id != _userId) {
          onUserJoined?.call(change.doc.id);
          if (_isBroadcaster) {
            await _connectToPeer(change.doc.id);
          }
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

      if (_isBroadcaster && _localStream != null) {
        _localStream!.getAudioTracks().forEach((track) {
          pc.addTrack(track, _localStream!);
        });
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

  Future<void> toggleMute(bool muted) async {
    if (_localStream != null) {
      _localStream!.getAudioTracks().forEach((track) {
        track.enabled = !muted;
      });
    }
  }

  Future<void> disconnect() async {
    // Close all peer connections
    for (final pc in _peerConnections.values) {
      await pc.close();
    }
    _peerConnections.clear();

    // Clean up local stream
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream = null;

    // Remove user from participants
    await _db.collection('audio_rooms')
        .doc(_roomId)
        .collection('participants')
        .doc(_userId)
        .delete();

    // If broadcaster, mark room as inactive
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