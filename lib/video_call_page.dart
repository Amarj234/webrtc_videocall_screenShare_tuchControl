import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:webrtc_screen_share/touch_controller.dart';
import '/signaling.dart';

class VideoCallPage extends StatefulWidget {
  const VideoCallPage({super.key});

  @override
  _VideoCallPageState createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  Signaling? signaling;
  RTCVideoRenderer localRenderer = RTCVideoRenderer();
  RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  bool inCalling = false;
  String? roomId;
  bool isSharingScreen = false;
  late TextEditingController _joinRoomTextEditingController;

  @override
  void initState() {
    super.initState();
    _joinRoomTextEditingController = TextEditingController();
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
    });

    signaling?.onDisconnect = (() {
      setState(() {
        inCalling = false;
        roomId = null;
      });
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

  void sendTouchEvent(Offset localPosition) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Simulated remote screen resolution
    final remoteScreenWidth = 1080;
    final remoteScreenHeight = 2400;

    final x = localPosition.dx * remoteScreenWidth / screenWidth;
    final y = localPosition.dy * remoteScreenHeight / screenHeight;

    TouchController.sendTouch(x, y);
    showTapIndicator(context, localPosition);
  }

  void showTapIndicator(BuildContext context, Offset position) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: position.dx - 15,
        top: position.dy - 15,
        child: IgnorePointer(
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.withOpacity(0.5),
            ),
          ),
        ),
      ),
    );
    overlay.insert(overlayEntry);
    Future.delayed(Duration(milliseconds: 300), () => overlayEntry.remove());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('WebRTC Screen Share + Touch Control')),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: inCalling
          ? Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FloatingActionButton(
            onPressed: () async {
              await signaling?.hungUp();
              setState(() {
                inCalling = false;
                roomId = null;
              });
            },
            backgroundColor: Colors.red,
            child: Icon(Icons.call_end),
          ),
          FloatingActionButton(
            onPressed: signaling?.muteMic,
            child: Icon(Icons.mic_off),
          ),
          FloatingActionButton(
            onPressed: toggleStream,
            child: Icon(Icons.screen_share),
          ),
        ],
      )
          : null,
      body: inCalling
          ? Stack(
        children: [
          GestureDetector(
            onTapDown: (details) {
              sendTouchEvent(details.globalPosition);
            },
            child: RTCVideoView(remoteRenderer),
          ),
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              width: 120,
              height: 90,
              child: RTCVideoView(localRenderer, mirror: true),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      )
          : Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: Icon(Icons.group_add),
              label: Text('CREATE ROOM'),
              onPressed: () async {
                final _roomId = await signaling?.createRoom();
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Room Created'),
                    content: Row(
                      children: [
                        Text(_roomId ?? ''),
                        IconButton(
                          icon: Icon(Icons.copy),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: _roomId ?? ''),
                            );
                            Navigator.pop(context);
                          },
                        )
                      ],
                    ),
                  ),
                );
                setState(() {
                  roomId = _roomId;
                  inCalling = true;
                });
              },
            ),
            SizedBox(width: 10),
            ElevatedButton.icon(
              icon: Icon(Icons.login),
              label: Text('JOIN ROOM'),
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text('Join Room'),
                    content: TextField(
                      controller: _joinRoomTextEditingController,
                      decoration: InputDecoration(hintText: 'Room ID'),
                    ),
                    actions: [
                      TextButton(
                        child: Text('Cancel'),
                        onPressed: () => Navigator.pop(context),
                      ),
                      ElevatedButton(
                        child: Text('Join'),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                );

                if (_joinRoomTextEditingController.text.isNotEmpty) {
                  await signaling?.joinRoomById(
                    _joinRoomTextEditingController.text,
                  );
                  setState(() {
                    roomId = _joinRoomTextEditingController.text;
                    inCalling = true;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
