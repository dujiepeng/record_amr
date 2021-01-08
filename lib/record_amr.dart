import 'dart:async';

import 'package:flutter/services.dart';

/// `volume` 0 ~ 1;
typedef VolumeCallBack = Function(double volume);
typedef StopRecordCallBack = void Function(String path, int duration);

class RecordAmr {
  static const MethodChannel _channel = const MethodChannel('record_amr');

  static RecordAmr _wavToAmr;

  // ignore: unused_field
  VolumeCallBack _callBack;

  static RecordAmr get _private => _wavToAmr = _wavToAmr ?? RecordAmr._();

  RecordAmr._() {
    _channel.setMethodCallHandler((call) {
      if (call.method == 'volume') {
        double volume = call.arguments.toDouble();
        if (_private._callBack != null) {
          _private._callBack(volume);
        }
      }
      return null;
    });
  }

  bool recoreding = false;
  VolumeCallBack callback;

  /// start record
  /// [path] record file path.
  /// [callBack] volume callback: 0 ~ 1.
  static Future<bool> startVoiceRecord([VolumeCallBack volumeCallBack]) async {
    if (_private.recoreding) {
      return false;
    }
    if (volumeCallBack != null) {
      _private._callBack = volumeCallBack;
    }

    _private.recoreding =
        await _channel.invokeMethod('startVoiceRecord') as bool;

    return _private.recoreding;
  }

  /// stop record
  static Future<bool> stopVoiceRecord(StopRecordCallBack callBack) async {
    Map result = await _channel.invokeMethod('stopVoiceRecord');
    _private._callBack = null;
    _private.recoreding = false;
    String error = result['error'];
    String path = result['path'];
    int duration = result['duration'] as int;
    callBack(path, duration);
    return error == null ? true : false;
  }

  /// cancel record
  static Future<Null> cancelVoiceRecord() async {
    await _channel.invokeMethod('cancelVoiceRecord');
    _private._callBack = null;
    _private.recoreding = false;
  }
}
