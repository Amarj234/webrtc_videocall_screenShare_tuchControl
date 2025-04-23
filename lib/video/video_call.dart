import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:webrtc_screen_share/video/signaling.dart';

class VideoCall extends StatefulWidget {
  final String email;
  const VideoCall({super.key, required this.email});

  @override
  _VideoCallState createState() => _VideoCallState();
}

class _VideoCallState extends State<VideoCall> {
  Signaling? signaling;
  RTCVideoRenderer localRenderer = RTCVideoRenderer();
  RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  bool inCalling = false;
  String? roomId;
  bool isSharingScreen = false;


  @override
  void initState() {
    super.initState();

   _connect();
  }

  void _connect() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();

    signaling = Signaling();

    signaling?.onLocalStream = ((stream) {
      localRenderer.srcObject = stream;
      setState(() {});
    });

    signaling?.onAddRemoteStream = ((stream) {
      remoteRenderer.srcObject = stream;
      setState(() {});
    });

    signaling?.onRemoveRemoteStream = (() {
      remoteRenderer.srcObject = null;
      Navigator.pop(context);
    });

    signaling?.onDisconnect = (() {

    });
Future.delayed(Duration(seconds: 1),() async {
      await signaling?.createRoom(widget.email);
    });

  }

  @override
  void deactivate() {
    localRenderer.dispose();
    remoteRenderer.dispose();
    super.deactivate();
  }

  void toggleStream() async {
    if (isSharingScreen) {
      await signaling?.switchToCamera();
    } else {
      await Future.delayed(Duration(milliseconds: 500));
      await signaling?.switchToScreenShare();
    }
    setState(() {
      isSharingScreen = !isSharingScreen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('WebRTC Screen Share + Touch Control')),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton:  Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FloatingActionButton(
            heroTag: 'fab1',
            onPressed: () async {

              await signaling?.hungUp(widget.email);
          //  Navigator.pop(c);
            },
            backgroundColor: Colors.red,
            child: Icon(Icons.call_end),
          ),
          FloatingActionButton(
            heroTag: 'fab2',
            onPressed: signaling?.muteMic,
            child: Icon(Icons.mic_off),
          ),
          FloatingActionButton(
            heroTag: 'fab3',
            onPressed: toggleStream,
            child: Icon(Icons.screen_share),
          ),
        ],
      )
         ,
      body:  Stack(
        children: [
          RTCVideoView(remoteRenderer),
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              width: 120,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(8),
              ),
              child: RTCVideoView(localRenderer, mirror: true),
            ),
          ),
        ],
      )

    );
  }
}
