import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  Permission.sensors;
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

  bool pressing = false;
  dynamic data;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("sensor testing")),
      body: Center(
        child: (pressing == false) ? const Text("Press to start") : Text(data.toString())
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: (){},
        child: GestureDetector(
            onLongPressStart: (LongPressStartDetails longPressStartDetails) {
              pressing = true;
              sensor.accelerometerEvents.listen(
                (AccelerometerEvent event) {  setState(() { data = event.x; }); }
              );
            },
            onLongPressEnd: (LongPressEndDetails longPressEndDetails) {
              pressing = false;
              data = "Press to start";
            }
        ),
      ),
    );
  }
}
