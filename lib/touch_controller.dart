import 'package:flutter/services.dart';

class TouchController {
  static const MethodChannel _channel =
  MethodChannel('com.example.remote_control/touch');

  static Future<void> sendTouch(double x, double y) async {
    try {
      await _channel.invokeMethod('sendTouch', {'x': x, 'y': y});
    } on PlatformException catch (e) {
      print("Failed to send touch: '${e.message}'.");
    }
  }
}
