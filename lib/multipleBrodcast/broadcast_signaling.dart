import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class BroadcastSignaling {
  final String userId;
  final Function(MediaStream stream)? onLocalStream;
  final Function(String id, MediaStream stream)? onAddRemoteStream;
  final Function(String id)? onRemoveRemoteStream;
  final Function(dynamic error)? onError;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Map<String, RTCPeerConnection> _peerConnections = {};
  MediaStream? _localStream;
  String? _roomId;
  bool _isBroadcaster = false;

  BroadcastSignaling({
    required this.userId,
    this.onLocalStream,
    this.onAddRemoteStream,
    this.onRemoveRemoteStream,
    this.onError,
  });
  Future<RTCPeerConnection> _createPeerConnection() async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    };

    final constraints = {
      'mandatory': {},
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ],
    };

    final pc = await createPeerConnection(config, constraints);

    pc.onIceConnectionState = (state) {
      print('ICE connection state changed: $state');
    };

    return pc;
  }


  Future<void> startBroadcast(String roomId) async {
    _roomId = roomId;
    _isBroadcaster = true;
    _localStream = await _getUserMedia();
    onLocalStream?.call(_localStream!);

    await _setupRoom(true);
    _setupParticipantsListener();
    _listenForAnswers();
  }

  Future<void> joinBroadcast(String roomId) async {
    _roomId = roomId;
    _isBroadcaster = false;
    _localStream = await _getUserMedia();
    onLocalStream?.call(_localStream!);

    await _setupRoom(false);
    _setupParticipantsListener();
    _listenForOffers();
  }

  Future<MediaStream> _getUserMedia() async {
    return await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': true,
    });
  }

  Future<void> _setupRoom(bool isBroadcaster) async {
    await _db.collection('broadcast_rooms').doc(_roomId).set({
      'createdAt': FieldValue.serverTimestamp(),
      'broadcasterId': isBroadcaster ? userId : null,
      'isActive': true,
    }, SetOptions(merge: true));

    await _db.collection('broadcast_rooms')
        .doc(_roomId)
        .collection('participants')
        .doc(userId)
        .set({
      'userId': userId,
      'isBroadcaster': isBroadcaster,
      'joinedAt': FieldValue.serverTimestamp(),
      'isSpeaking': false,
    });
  }

  void _setupParticipantsListener() {
    _db.collection('broadcast_rooms')
        .doc(_roomId)
        .collection('participants')
        .snapshots()
        .listen((snapshot) async {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added && change.doc.id != userId) {
          await _connectToPeer(change.doc.id);
        } else if (change.type == DocumentChangeType.removed) {
           _removePeerConnection(change.doc.id);
          onRemoveRemoteStream?.call(change.doc.id);
        }
      }
    });
  }

  Future<void> _connectToPeer(String peerId) async {
    try {
      final pc = await _createPeerConnection();
      _peerConnections[peerId] = pc;

      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) {
          pc.addTrack(track, _localStream!);
        });
      }

      _setupIceCandidateExchange(peerId, pc);

      if (_isBroadcaster) {
        final offer = await pc.createOffer();
        await pc.setLocalDescription(offer);

        await _db.collection('broadcast_rooms')
            .doc(_roomId)
            .collection('offers')
            .doc('${userId}_to_$peerId')
            .set({
          'from': userId,
          'to': peerId,
          'sdp': offer.sdp,
          'type': offer.type,
        });
      }
    } catch (e) {
      onError?.call(e);
    }
  }

  void _listenForOffers() {
    _db.collection('broadcast_rooms')
        .doc(_roomId)
        .collection('offers')
        .where('to', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) async {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final peerId = data['from'];

        final pc = _peerConnections[peerId] ?? await _createPeerConnection();
        _peerConnections[peerId] = pc;

        if (_localStream != null) {
          _localStream!.getTracks().forEach((track) {
            pc.addTrack(track, _localStream!);
          });
        }

        final offer = RTCSessionDescription(data['sdp'], data['type']);
        await pc.setRemoteDescription(offer);

        final answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);

        await _db.collection('broadcast_rooms')
            .doc(_roomId)
            .collection('answers')
            .doc('${userId}_to_$peerId')
            .set({
          'from': userId,
          'to': peerId,
          'sdp': answer.sdp,
          'type': answer.type,
        });

        _setupIceCandidateExchange(peerId, pc);
      }
    });
  }

  void _listenForAnswers() {
    _db.collection('broadcast_rooms')
        .doc(_roomId)
        .collection('answers')
        .where('to', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) async {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final peerId = data['from'];
        final pc = _peerConnections[peerId];
        if (pc != null ) {
          final answer = RTCSessionDescription(data['sdp'], data['type']);
          await pc.setRemoteDescription(answer);
        }
      }
    });
  }

  void _setupIceCandidateExchange(String peerId, RTCPeerConnection pc) {
    _db.collection('broadcast_rooms')
        .doc(_roomId)
        .collection('candidates')
        .where('from', isEqualTo: peerId)
        .where('to', isEqualTo: userId)
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

    pc.onIceCandidate = (candidate) async {
      if (candidate != null) {
        await _db.collection('broadcast_rooms')
            .doc(_roomId)
            .collection('candidates')
            .add({
          'from': userId,
          'to': peerId,
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      }
    };

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        onAddRemoteStream?.call(peerId, event.streams[0]);
      }
    };
  }


  void _removePeerConnection(String peerId) {
    final pc = _peerConnections[peerId];
    if (pc != null) {
      pc.close();
      _peerConnections.remove(peerId);
      _db.collection('broadcast_rooms')
          .doc(_roomId)
          .collection('participants')
          .doc(peerId)
          .delete();
    }
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
    await _db.collection('broadcast_rooms')
        .doc(_roomId)
        .collection('participants')
        .doc(userId)
        .update({
      'isSpeaking': isSpeaking,
      'lastActive': FieldValue.serverTimestamp(),
    });
  }

  Future<void> endBroadcast() async {
    await _cleanupRoom();
    await _disconnect();
  }

  Future<void> leaveBroadcast() async {
    await _removeParticipant();
    await _disconnect();
  }

  Future<void> _cleanupRoom() async {
    await _db.collection('broadcast_rooms').doc(_roomId).update({
      'isActive': false,
    });
    await _removeParticipant();
  }

  Future<void> _removeParticipant() async {
    await _db.collection('broadcast_rooms')
        .doc(_roomId)
        .collection('participants')
        .doc(userId)
        .delete();
  }

  Future<void> _disconnect() async {
    for (final pc in _peerConnections.values) {
      await pc.close();
    }
    _peerConnections.clear();
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream = null;
  }

  void dispose() {
    _disconnect();
  }
}
