import 'dart:async';
import 'dart:io';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
File? pickedImage;
class Home_page extends StatefulWidget {
  const Home_page({super.key});


  @override
  State<Home_page> createState() => _Home_pageState();
}

class _Home_pageState extends State<Home_page> {

  bool spin = true;
  GoogleMapController? _googleMapController;
  final FirebaseFirestore cloud = FirebaseFirestore.instance;
  LatLng userlocatiion = const LatLng(360, 360);
  String locationName = "Current location";

  Future<void> checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    // Check location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }
    setState(() {
      currentLocation();
    });
  }

  Future<void> currentLocation() async{
    try{
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy:LocationAccuracy.low);
      setState(() {
        userlocatiion =  LatLng(position.latitude, position.longitude);
        spin = false;
        locationName = "Current location";
      });
    }
    catch(e){
      throw Exception("Something went wrong");
    }
  }

  Future<bool> pickImageFromCamera() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if(pickedFile != null) {
      setState(() {
        pickedImage = File(pickedFile.path);
      });
      return true;
    }
    return false;
  }

  Future<void> uploadImage(LatLng location) async {
    setState(() {
      spin = true;
    });
    if(userlocatiion == const LatLng(360, 360)) {
      return;
    }
    final storageRef = FirebaseStorage.instance.ref();

    String folderName = "${double.parse(location.latitude.toDouble().toStringAsFixed(3))}_${double.parse(location.longitude.toDouble().toStringAsFixed(3))}";
    final imageRef = storageRef.child('$folderName/${DateTime.now().microsecondsSinceEpoch}.png');
    try{
      await imageRef.putFile(pickedImage!);
      final downloadURL = await imageRef.getDownloadURL();
      cloud.collection('images').doc(folderName).collection('imagesList').add({
        'imageLink': downloadURL,
      });
      toast("Image uploaded successfully");
      setState(() {
        spin = false;
      });
    }
    catch(e){
      toast('Uplaod failed $e');
      setState(() {
        spin = false;
      });
    }
  }

  Stream<QuerySnapshot> getImages(LatLng location){
    String folderName = "${double.parse(location.latitude.toDouble().toStringAsFixed(3))}_${double.parse(location.longitude.toDouble().toStringAsFixed(3))}";
    return cloud.collection('images').doc(folderName).collection('imagesList').snapshots();
  }
  
  void _onMapLongPress(LatLng latLng) {
    setState(() {
      userlocatiion = latLng;
      locationName = "Selected location";
    });
    //print('Latitude: ${latLng.latitude}, Longitude: ${latLng.longitude}');
  }

  void toast(String text){
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose(){
    _googleMapController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    setState(() {
      checkLocationPermission();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: userlocatiion == const LatLng(360, 360) ? const SizedBox(
        height: double.infinity,
        width: double.infinity,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      )  : ModalProgressHUD(
        inAsyncCall: spin,
        color: Colors.black,
        opacity: .5,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: userlocatiion,
            zoom: 13,
          ),
          onLongPress: _onMapLongPress,
          markers: {
            Marker(
              markerId: const MarkerId('location1'),
              infoWindow: InfoWindow(title: locationName),
              icon: BitmapDescriptor.defaultMarker,
              position: userlocatiion,
              onTap: (){
                bottomSheet(context, userlocatiion);
              }
            ),
          },
          onMapCreated: (GoogleMapController controller){
            _googleMapController = controller;
          },
        ),
      ),
        floatingActionButton: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(
              width: 30,
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              //crossAxisAlignment: CrossAxisAlignment.,
              children: [
                FloatingActionButton(
                    onPressed: (){
                      currentLocation();
                    },
                  backgroundColor: Colors.white,
                  splashColor: Colors.green,
                child: const Icon(
                  Icons.my_location_outlined,
                  color: Colors.blue,
                ),),
                const SizedBox(
                  height: 10,
                ),
                FloatingActionButton(onPressed: () async {
                  if(await pickImageFromCamera() == true){
                    uploadImage(userlocatiion);
                  }
                },
                  backgroundColor: Colors.pink,
                  splashColor: Colors.lightBlue,
                  child: const Icon(
                    Icons.camera,
                    size: 40,
                  ),
                ),
                const SizedBox(
                  height: 20,
                )
              ],
            ),
          ],
        ),
      //floatingActionButtonLocation: FloatingActionButtonLocation.,
    );

  }

  Future<dynamic> bottomSheet(BuildContext context, LatLng location) {
    return showModalBottomSheet(
                  context: context,
                  builder: (BuildContext context){
                    return StreamBuilder(
                      stream: getImages(location),
                      builder: (context, snapshot) {
                        if(!snapshot.hasData) {
                          return const Center(
                            child: Text(
                              'No images found',
                            ),
                          );
                        }
                        var images = snapshot.data!.docs;
                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: images.length,
                            itemBuilder: (context, index){
                              var image = images[index];
                              return Row(
                                children: [
                                  index == 0 ? const SizedBox(
                                    width: 20,
                                  ): const SizedBox(),
                                  SizedBox(
                                    height: MediaQuery.of(context).size.height*.4,
                                    width: MediaQuery.of(context).size.width*.7,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Image.network(image['imageLink'],
                                      fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 10,
                                  )
                                ],
                              );
                            }
                        );
                      }
                    );
                  }
              );
  }
}
