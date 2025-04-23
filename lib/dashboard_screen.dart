import 'package:flutter/material.dart';

import 'audio/audio_brodcast.dart';
import 'homepage/home_screen.dart';
import 'multipleBrodcast/video_brodcast.dart';

class DashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Three tabs
      child: Scaffold(
        appBar: AppBar(
          title: Text("Broadcast Hub"),

        ),
        body: TabBarView(
          children: [
            HomeScreen(),          // You already have this
            VideoBroadcastScreen(),
            AudioBroadcastScreen(),
          ],
        ),
        bottomNavigationBar:TabBar(
          tabs: [
            Tab(text: 'Home', icon: Icon(Icons.home)),
            Tab(text: 'Video', icon: Icon(Icons.videocam)),
            Tab(text: 'Audio', icon: Icon(Icons.mic)),
          ],
        ) ,
      ),
    );
  }
}
