import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:simple_kalman/simple_kalman.dart';
import 'package:oscilloscope/oscilloscope.dart';
import 'package:camera/camera.dart';

late final cameras;
late CameraController cameraController;

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
  } on CameraException catch (e) {debugPrint('Error in fetching');}
  Permission.sensors;
  Permission.camera;
  cameras = await availableCameras();
  runApp(const MyApp());


}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
            primarySwatch: Colors.blue
        ),
        home: MyHomePage()
    );
  }
}

class MyHomePage extends StatefulWidget {

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  _MyHomePageState();
  Sensors sensor = Sensors();

  void initializeCameraController() {
    final camera = cameras.first;
    cameraController = CameraController(camera, ResolutionPreset.max);
    cameraController.initialize();
  }

  double x1 = 0;
  double x2 = 0;
  List<SensorData> sensorData = [];

  List<double> data = [];
  List<double> data2 = [];
  List<double> data3 = [];
  List<double> v = [];
  List<double> d = [];
  List<double> buffer = [];

  late Oscilloscope scopeOne;
  late Oscilloscope scopeTwo;
  late Oscilloscope scopeThree;

  double accelerationMax = 0;
  double localMinMax = 0;

  @override
  void initState() {
    super.initState();
    listenSensor();
    getSensor();
    initializeCameraController();
    v.add(0);
    d.add(0);
  }

  void getSensor() async {
    sensor.gyroscopeEvents.listen(
            (GyroscopeEvent event) {
          final kalman = SimpleKalman(errorMeasure: 512, errorEstimate: 120, q: 0.5);
          x2 = kalman.filtered(event.z * event.z + event.y * event.y + event.x * event.x);
          if (x2 < 0.0005) {
            x2 = 0;
          }
          data3.add(x2);
          if (data3.length > 300) {
            data3.removeAt(0);
            int count = 0;
            for (double i in data3.sublist(200, 300)) {
              if (i != 0) {
                count++;
              }
            }
            if (count / 100 < 0.05) {
              v = [];
              v.add(0);
            }
          }

          setState(() {
            scopeThree = Oscilloscope(
              dataSet: data3, showYAxis: true, yAxisMin: -1.0,
            );
          });
        }
    );
  }

  void listenSensor() async {
    sensor.userAccelerometerEvents.listen(
            (UserAccelerometerEvent event) {
          final kalman = SimpleKalman(errorMeasure: 512, errorEstimate: 100, q: 0.9);
          x1 = kalman.filtered(event.x);
          if (x1.abs() <= 0.02) x1 = 0;
          data.add(x1);
          buffer.add(x1);
          int count = 0;
          localMinMax = data.sublist(200,300).reduce(max) >
              data.sublist(200,300).reduce(min).abs() ?
          data.sublist(200,300).reduce(max) :
          data.sublist(200,300).reduce(min);
          if (buffer.length > 5) {
            for (int i = buffer.length-5; i < buffer.length-1; i++) {
              if (buffer[i] != 0) {
                count ++;
              }
              // if (count == 5) {
              //   v.add(localMinMax);
              // } else {
              //   v.add();
              // }
            }
          }

          if(data.length > 300) {
            data.removeAt(0);
            data2.removeAt(0);
            buffer.removeAt(0);
            v.add(0);
          }
          print(DateTime.now());


          data2.add(event.x);
          setState(() {
            scopeOne = Oscilloscope(dataSet: data, showYAxis: true, yAxisMin: -1.0);
            scopeTwo = Oscilloscope(dataSet: data2,showYAxis: true, yAxisMin: -1.0);
          });
        }
    );
  }

  @override
  Widget build(BuildContext context) {

    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
        body: Column(
            children: [
              SizedBox(
                  height: height / 2,
                  width: width,
                  child: CameraPreview(cameraController)
              ),
              const Text("with filter"),
              Expanded(flex: 2, child: scopeOne),
              const Text("Gyroscope"),
              Expanded(flex: 2, child: scopeThree)
            ]
        )
    );
  }
}

class SensorData {
  SensorData(this.time, this.data);

  final DateTime time;
  final double data;
}

