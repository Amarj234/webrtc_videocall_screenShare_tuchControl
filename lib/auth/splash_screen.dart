import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import '../dashboard_screen.dart';
import 'login_screen.dart' show LoginScreen;

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final box = GetStorage();

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(seconds: 2), checkLogin);
  }

  void checkLogin() {
    bool isLoggedIn = box.read('isLoggedIn') ?? false;
    if (isLoggedIn) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DashboardScreen()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: CircularProgressIndicator()), // You can customize this
    );
  }
}
