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
  Permission.sensors; Permission.camera;
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp( home: MyHomePage() );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

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

  List<double> filteredAcceleration = [];
  List<double> filteredGyroscope = [];

  List<double> filteredVelocity = [];

  double accelerationMinMax = 0;
  double accelerationMin = 0;
  double accelerationMax = 0;


  double nonZeroGyroscopeDataPercentage = 0;
  bool isDeviceMoving = false;
  bool isRealSpeedChange = false;

  late Oscilloscope filteredAccelerationGraph;
  late Oscilloscope filteredGyroscopeGraph;
  late Oscilloscope filteredVelocityGraph;

  void listenGyroscope() async {
    sensor.gyroscopeEvents.listen( (GyroscopeEvent event) {
      double combinedXYZ = event.z * event.z + event.y * event.y + event.x * event.x;
      final gyroscopeFilter = SimpleKalman(errorMeasure: 512, errorEstimate: 120, q: 0.5);
      double gyroscopeData = gyroscopeFilter.filtered(combinedXYZ);
      gyroscopeData = gyroscopeData < 0.0005 ? 0 : gyroscopeData;
      filteredGyroscope.add(gyroscopeData);
      if (filteredGyroscope.length > 300) filteredGyroscope.removeAt(0);

      List<double> sublistOfFilteredGyroscope =
          filteredGyroscope.length > 100 ?
          filteredGyroscope.sublist(filteredGyroscope.length-100,
          filteredGyroscope.length-1) : filteredGyroscope;
      int nonZeroCount = 0;
      for (double element in sublistOfFilteredGyroscope) {
        if (element != 0 ) nonZeroCount++;
      }
      nonZeroGyroscopeDataPercentage = nonZeroCount / 100; //threshold > 0.05 (5%)
      nonZeroCount = 0;
      setState(() {
        isDeviceMoving = nonZeroGyroscopeDataPercentage > 0.30 ? true : false;
        filteredGyroscopeGraph = Oscilloscope(
            dataSet: filteredGyroscope, showYAxis: true, yAxisMin: -1.0);
      });
    });
  }

  void listenAcceleration() async {
    sensor.userAccelerometerEvents.listen( (UserAccelerometerEvent event) {
      final accelerationFilter = SimpleKalman(errorMeasure: 512, errorEstimate: 120, q: 0.9);
      double accelerationData = accelerationFilter.filtered(event.x);
      accelerationData = accelerationData.abs() < 0.02 ? 0 : accelerationData;
      filteredAcceleration.add(accelerationData);
      if (filteredAcceleration.length > 300) filteredAcceleration.removeAt(0);

      accelerationMax = filteredAcceleration.reduce(max);
      accelerationMin = filteredAcceleration.reduce(min);
      
      if (isDeviceMoving == true) {

        // if (filteredAcceleration[filteredAcceleration.length-1] <
        //     filteredAcceleration[filteredAcceleration.length-2])
        //   print(filteredAcceleration[filteredAcceleration.length-1]);

        double comparedResults = accelerationMax > accelerationMin.abs() ?
        accelerationMax : accelerationMin;

        accelerationMinMax = accelerationMinMax.abs() > comparedResults.abs() ?
            accelerationMinMax : comparedResults;

        if (accelerationMinMax.abs() - comparedResults.abs() < 0.2) {
          accelerationMinMax = comparedResults;
        }

        filteredVelocity.add(accelerationMinMax);
      } else { filteredVelocity.add(0); accelerationMinMax = 0;}
      if (filteredVelocity.length > 300) filteredVelocity.removeAt(0);

      setState(() {
        filteredAccelerationGraph = Oscilloscope(
            dataSet: filteredAcceleration, showYAxis: true, yAxisMin: -1.0);
        filteredVelocityGraph = Oscilloscope(
            dataSet: filteredVelocity, showYAxis: true, yAxisMin: -1.0);
      });
    });
  }

  @override
  void initState() {
    super.initState();

    initializeCameraController();
    listenGyroscope();
    listenAcceleration();

    filteredVelocity.add(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height / 2,
              width: MediaQuery.of(context).size.width,
              child: CameraPreview(cameraController)
            ),
            Text("Acceleration Graph"),
            Expanded(flex: 2, child: filteredAccelerationGraph),
            Text("Velocity graph"),
            Expanded(flex: 2, child: filteredVelocityGraph),
            Text("Gyroscope percentage: $nonZeroGyroscopeDataPercentage"),
            Text("Is the device moving: $isDeviceMoving")
          ],
        )
      )
    );
  }
}