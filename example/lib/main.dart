import 'package:flutter/material.dart';
import 'package:record_amr/record_amr.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Listener(
            child: Text('Record'),
            onPointerDown: (PointerDownEvent event) => _startRecord(),
            onPointerUp: (PointerUpEvent event) => _stopRecord(),
            onPointerCancel: (PointerCancelEvent event) => _cancelRecord(),
          ),
        ),
      ),
    );
  }
}

_startRecord() async {
  // await RecordAmr.cancelVoiceRecord();
  await RecordAmr.startVoiceRecord();
}

_stopRecord() async {
  await RecordAmr.stopVoiceRecord();
}

_cancelRecord() async {
  await RecordAmr.cancelVoiceRecord();
}
