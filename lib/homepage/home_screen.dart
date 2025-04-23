import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_storage/get_storage.dart';
import 'package:webrtc_screen_share/video/join_call.dart';

import '../video/video_call.dart';

class HomeScreen extends StatefulWidget {

  HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CollectionReference users = FirebaseFirestore.instance.collection('users');

  final box = GetStorage();


  bool isCalling = false;
  Stream<String?> listenToFirstRoomId(String email) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(email)
        .collection('rooms')
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id; // Get the ID of the first room
      }
      return null; // No rooms found
    });
  }

  @override
  void initState() {
    final currentEmail = box.read('email');
    // TODO: implement initState
    super.initState();

    listenToFirstRoomId(currentEmail).listen((exists) {
      if (exists!=null) {
if(isCalling==true) return;

isCalling=true;
        showDialog(
          context: context,
          barrierDismissible: false, // Prevent dismissing by tapping outside
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Incoming Call', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.call, size: 50, color: Colors.green),
                  SizedBox(height: 10),
                  Text('is calling...', style: TextStyle(fontSize: 16)),
                ],
              ),
              actions: <Widget>[
                TextButton.icon(
                  onPressed: (){
                    Navigator.of(context).pop();
                    // Handle reject action
                  },
                  icon: Icon(Icons.call_end, color: Colors.red),
                  label: Text('Reject'),
                ),
                ElevatedButton.icon(
                  onPressed: ()async{
                    Navigator.of(context).pop();
                    // Handle accept action
                 await   Navigator.push(context, MaterialPageRoute(builder: (context)=>JoinCall(callId:exists ,email: currentEmail,)));
                    isCalling=false;
                  },
                  icon: Icon(Icons.call, color: Colors.white),
                  label: Text('Accept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ],
            );
          },
        );
        // Handle the case when the room exists
        print("Room exists for $currentEmail");
      } else {
        if(isCalling){
          isCalling=false;
          Navigator.of(context).pop();
        }
        // Handle the case when the room does not exist
        print("Room does not exist for $currentEmail");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentEmail = box.read('email');

    return Scaffold(
      appBar: AppBar(title: Text("User List")),
      body: StreamBuilder<QuerySnapshot>(
        stream: users.snapshots(),
        builder: (context1, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator());

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
            return Center(child: Text("No users found"));

          final filteredDocs = snapshot.data!.docs.where((doc) {


            final data = doc.data() as Map<String, dynamic>;

            return data['email'] != currentEmail;
          }).toList();



          return ListView.builder(
            itemCount: filteredDocs.length,
            itemBuilder: (context1, index) {
              final data = filteredDocs[index].data() as Map<String, dynamic>;
              return ListTile(
                leading: CircleAvatar(child: Text(data['name'][0])),
                title: Text(data['name']),
                subtitle: Text(data['email']),
                trailing: IconButton(
                  icon: Icon(Icons.call),
                  onPressed: () {

                    Navigator.push(context, MaterialPageRoute(builder: (context)=>VideoCall(email:data['email'] ,)));
                    // Handle message action
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
