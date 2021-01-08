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
  double _volume = 0;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: _volume * 100,
                height: 30,
                color: Colors.blue[300],
              ),
              Expanded(
                child: GestureDetector(
                  onTapDown: (TapDownDetails details) => _startRecord(),
                  onTapUp: (TapUpDetails details) => _stopRecord(),
                  onTapCancel: () => _cancelRecord(),
                  child: Text(
                    'Record',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _startRecord() async {
    bool success = await RecordAmr.startVoiceRecord((volume) {
      print('volume ---- $volume');
      setState(() {
        _volume = volume;
      });
    });
    print('开始录制 ---- $success');
  }

  _stopRecord() async {
    bool success = await RecordAmr.stopVoiceRecord((path, duration) {
      print('path --- $path, duration ---- $duration');
    });
    setState(() {
      _volume = 0;
    });
    print('结束录制 ---- $success');
  }

  _cancelRecord() async {
    await RecordAmr.cancelVoiceRecord();
    print('取消录制');
  }
}
