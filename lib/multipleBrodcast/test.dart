// import 'package:flutter/material.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart';
// import 'package:get_storage/get_storage.dart';
//
// import 'broadcast_signaling.dart';
//
// class MultiUserBroadcastPage extends StatefulWidget {
//   final bool isBroadcaster;
//   final String roomId;
//
//   const MultiUserBroadcastPage({
//     super.key,
//     required this.isBroadcaster,
//     required this.roomId,
//   });
//
//   @override
//   State<MultiUserBroadcastPage> createState() => _MultiUserBroadcastPageState();
// }
//
// class _MultiUserBroadcastPageState extends State<MultiUserBroadcastPage> {
//   BroadcastSignaling? signaling;
//   final RTCVideoRenderer localRenderer = RTCVideoRenderer();
//   final Map<String, RTCVideoRenderer> remoteRenderers = {};
//   bool isMuted = false;
//   bool isSharingScreen = false;
//   final box = GetStorage();
//
//
//   @override
//   void initState() {
//     super.initState();
//     initRenderers().then((_) => initSignaling());
//   }
//
//   Future<void> initRenderers() async {
//     await localRenderer.initialize();
//   }
//
//   Future<void> initSignaling() async {
//     final String userId =     box.read('email');
//     // signaling = BroadcastSignaling(
//     //   onLocalStream: (stream) {
//     //     localRenderer.srcObject = stream;
//     //     setState(() {});
//     //   },
//     //   onAddRemoteStream: (id, stream) async {
//     //     final renderer = RTCVideoRenderer();
//     //     await renderer.initialize();
//     //     renderer.srcObject = stream;
//     //     setState(() {
//     //       remoteRenderers[id] = renderer;
//     //     });
//     //   },
//     //   onRemoveRemoteStream: (id) {
//     //     setState(() {
//     //       remoteRenderers[id]?.dispose();
//     //       remoteRenderers.remove(id);
//     //     });
//     //   },
//     // );
//
//     signaling = BroadcastSignaling();
//
//     signaling?.onLocalStream = ((stream) {
//       localRenderer.srcObject = stream;
//       setState(() {});
//     });
//     signaling?.onAddRemoteStream = ((id, stream) {
//       remoteRenderers[id]?.srcObject = stream;
//       setState(() {});
//     });
//
//     signaling?.onRemoveRemoteStream = ((id) {
//       remoteRenderers[id]?.srcObject = null;
//       Navigator.pop(context);
//     });
//
//
//     if (widget.isBroadcaster) {
//       await signaling?.startBroadcast(userId);
//     } else {
//       await signaling?.joinBroadcast(widget.roomId, userId);
//     }
//   }
//
//   @override
//   void dispose() {
//     localRenderer.dispose();
//     for (var renderer in remoteRenderers.values) {
//       renderer.dispose();
//     }
//     // if (widget.isBroadcaster) {
//     //   signaling.endBroadcast();
//     // }
//     super.dispose();
//   }
//
//   void toggleMute() {
//     setState(() {
//       isMuted = !isMuted;
//     });
//     // signaling.toggleMute(isMuted);
//   }
//
//   void toggleScreenShare() async {
//     setState(() {
//       isSharingScreen = !isSharingScreen;
//     });
//     // Add screen sharing logic if needed
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text(widget.isBroadcaster ? 'Broadcaster' : 'Viewer')),
//       body: Column(
//         children: [
//           Expanded(
//             child: GridView.count(
//               crossAxisCount: 2,
//               children: [
//                 ...remoteRenderers.entries.map((entry) => Container(
//                   margin: const EdgeInsets.all(8),
//                   decoration: BoxDecoration(border: Border.all()),
//                   child: RTCVideoView(entry.value, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
//                 )),
//                 // Show local view as well
//                 if (localRenderer.srcObject != null)
//                   Container(
//                     margin: const EdgeInsets.all(8),
//                     decoration: BoxDecoration(border: Border.all(), color: Colors.black),
//                     child: RTCVideoView(localRenderer, mirror: true),
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//       floatingActionButton: Row(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           if (widget.isBroadcaster)
//             FloatingActionButton(
//               heroTag: "mute",
//               onPressed: toggleMute,
//               backgroundColor: isMuted ? Colors.red : Colors.green,
//               child: Icon(isMuted ? Icons.mic_off : Icons.mic),
//             ),
//           const SizedBox(width: 20),
//           if (widget.isBroadcaster)
//             FloatingActionButton(
//               heroTag: "screen",
//               onPressed: toggleScreenShare,
//               backgroundColor: isSharingScreen ? Colors.blue : Colors.grey,
//               child: const Icon(Icons.screen_share),
//             ),
//           const SizedBox(width: 20),
//           FloatingActionButton(
//             heroTag: "end",
//             onPressed: () => Navigator.pop(context),
//             backgroundColor: Colors.red,
//             child: const Icon(Icons.call_end),
//           ),
//         ],
//       ),
//     );
//   }
// }
