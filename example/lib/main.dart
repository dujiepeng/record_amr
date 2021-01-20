import 'package:flutter/material.dart';
import 'package:record_amr/record_amr.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  double _volume = 0;
  String _path;

  @override
  void initState() {
    _requestPermiss();
    super.initState();
  }

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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.play_arrow),
                    onPressed: () => _play(),
                  ),
                  IconButton(
                    icon: Icon(Icons.stop),
                    onPressed: () => _stop(),
                  ),
                ],
              )
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
    print('start record ---- $success');
  }

  _stopRecord() async {
    bool success = await RecordAmr.stopVoiceRecord((path, duration) {
      _path = path;
      print('path --- $path, duration ---- $duration');
    });
    setState(() {
      _volume = 0;
    });
    print('stop record ---- $success');
  }

  _cancelRecord() async {
    await RecordAmr.cancelVoiceRecord();
    setState(() {
      _volume = 0;
    });
    print('取消录制');
  }

  _play() async {
    await RecordAmr.play(_path, (path) {
      print('play end');
    });
  }

  _stop() async {
    await RecordAmr.stop();
  }

  _requestPermiss() async {
    await Permission.microphone.request();
  }
}
