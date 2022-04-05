import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart';
import 'package:location/location.dart';


class LiveTracking extends StatefulWidget {
  const LiveTracking({Key? key}) : super(key: key);

  @override
  _LiveTrackingState createState() => _LiveTrackingState();
}

class _LiveTrackingState extends State<LiveTracking> {

  GoogleMapController? _controller;
  StreamSubscription? locationSubscription;
  Location locationTracker = Location();
  Marker? marker;
  Circle? circle;


  // Static Initial Camera Position Given To Map Manually
  static final CameraPosition initialCameraPosition = CameraPosition(
    target: LatLng(33.6844, 73.0479),
    zoom: 14,
  );

  // Get The Image of Car and Convert It Into ByteData and Convert it Unsigned Integer List
  Future<Uint8List> getMarker() async{
    ByteData byteData = await DefaultAssetBundle.of(context).load('assets/images/car_icon.png');
    return byteData.buffer.asUint8List();
  }

  // Update Marker And Circle To Show ON Map
  void updataMarkerAndCircle(LocationData newLocalData, Uint8List imageData){
    LatLng latlng = LatLng(newLocalData.latitude!, newLocalData.longitude!);
    this.setState(() {
      marker = Marker(
          markerId: MarkerId("Home"),
          position: latlng,
          rotation: newLocalData.heading!,
          draggable: false,
          zIndex: 2,
          flat: true,
          anchor: Offset(0.5, 0.5),
          icon: BitmapDescriptor.fromBytes(imageData));
      circle = Circle(
          circleId: CircleId("Car"),
          radius: newLocalData.accuracy!,
          zIndex: 1,
          strokeColor: Colors.deepOrangeAccent,
          center: latlng,
          fillColor: Colors.deepOrange);
    });
  }



  // Get Current Location
  void getCurrentLocation() async{
    try{
      Uint8List imageData = await getMarker();
      var location = await locationTracker.getLocation();
      updataMarkerAndCircle(location, imageData);
      if(locationSubscription != null){
        locationSubscription?.cancel();
      }

      locationSubscription = locationTracker.onLocationChanged.listen((newLocalData) {
        if(_controller != null){
          _controller?.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  bearing: 192.8334901395799,
                  target: LatLng(newLocalData.latitude!, newLocalData.longitude!),
                  tilt: 0,
                  zoom: 18.0,
                ),
              ));
          updataMarkerAndCircle(newLocalData, imageData);
          uploadData(newLocalData);

        }
      });
    }on PlatformException catch(e){
      if(e.code == "Permission Denied"){
        debugPrint("Permission Denied");
      }
    }
  }

  // Send Location Latitude And Longitude On The Server Api
  uploadData(LocationData myLocalData) async{
    try{
      var latitude =  myLocalData.latitude.toString();
      var longitude = myLocalData.longitude.toString();

      // Get TimeStamp Through These Lines
      // Get TimeStamp
      DateTime _now = DateTime.now();
      var timestamp = '${_now.hour}:${_now.minute}:${_now.second}';


      var response = await post(Uri.parse('http://codebase.pk:8800/api/location/'),
          body: {
            "latitude" : latitude,
            "longitude" : longitude,
            "timestamp" : timestamp
          });
      if(response.statusCode == 200){
        var data = jsonDecode(response.body.toString());
        print(data);
        Fluttertoast.showToast(msg: "Uploaded Lat and Long Successfully");
      }else {
        print("Not Uploaded Location");
        Fluttertoast.showToast(msg: "Not Uploaded Successfully");
      }
    }catch(e){
      print(e.toString());
    }
  }


  @override
  void initState() {
    getCurrentLocation();
    super.initState();
  }

  @override
  void dispose() {
    if(locationSubscription != null){
      locationSubscription!.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.deepOrangeAccent,
        title: Text("Live Location Tracking"),
      ),
      body: GoogleMap(
        initialCameraPosition: initialCameraPosition,
        mapType: MapType.normal,
        markers: Set.of((marker != null) ? [marker!] : [] ),
        circles: Set.of((circle != null) ? [circle!] : [] ),
        onMapCreated: (GoogleMapController controller){
          _controller = controller;
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepOrangeAccent,
        child: Icon(Icons.location_searching_rounded, color: Colors.white,),
        onPressed: (){
          getCurrentLocation();
        },
      ),
    );
  }
}