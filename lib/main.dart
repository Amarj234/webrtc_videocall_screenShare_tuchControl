import 'dart:convert';

import 'package:android_intent_plus/android_intent.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:webrtc_screen_share/video_call_page.dart';

import 'background_service.dart';
import 'firebase_options.dart';


void openAccessibilitySettings() {
  final intent = AndroidIntent(
    action: 'android.settings.ACCESSIBILITY_SETTINGS',
  );
  intent.launch();
}


const platform = MethodChannel('com.example.webrtc_screen_share/screen');

Future<void> startScreenCaptureService() async {
  try {
    await platform.invokeMethod('startScreenService');
  } on PlatformException catch (e) {
    print("Failed to start service: '${e.message}'.");
  }
}




void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseApp app = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  openAccessibilitySettings();
  startScreenCaptureService();
 // initializeService();
  print("amarj234 ${app.options.appId}");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(

        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: VideoCallPage(),
    );
  }
}

