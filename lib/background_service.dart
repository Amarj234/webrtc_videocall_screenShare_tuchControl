import 'dart:async';
import 'dart:core';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';


final service = FlutterBackgroundService();
Future<void> initializeService() async {


  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      foregroundServiceNotificationId: 888,
      initialNotificationTitle: "Service Running",
      initialNotificationContent: "Your background service is active",
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,

      onBackground: onIosBackground,
    ),
  );

  service.startService();
  // service.invoke("stopService"); if you want to stop service call this fun

}

stopBackground (){
  service.invoke("stopService");


}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}
@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: "Service Running",
      content: "Background work happening",
    );
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  service.on('onTaskRemoved').listen((event) {
    print('App removed from recent tasks!');
    service.invoke('restartService'); // custom logic
  });

  // Example: Periodic Task
  Timer.periodic(const Duration(seconds: 5), (timer) async {
    if (service is AndroidServiceInstance && !(await service.isForegroundService())) {
      return;
    }
print("app is running in background");
    // Perform your background task here
    // For example, you can fetch data from an API or perform some calculations
    // You can also use the service.sendData() method to send data back to the main isolate
  });




}


