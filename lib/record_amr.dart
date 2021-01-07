import 'dart:async';

import 'package:flutter/services.dart';

/// `volume` 0 ~ 1;
typedef VolumeCallBack = Function(double volume);

class RecordAmr {
  static const MethodChannel _channel = const MethodChannel('record_amr');

  static RecordAmr _wavToAmr;

  // ignore: unused_field
  VolumeCallBack _callBack;

  static RecordAmr get _private => _wavToAmr = _wavToAmr ?? RecordAmr._();

  RecordAmr._() {
    _channel.setMethodCallHandler((call) {
      return null;
    });
  }

  bool recoreding = false;
  VolumeCallBack callback;

  /// start record
  /// [path] record file path.
  /// [callBack] volume callback: 0 ~ 1.
  static Future<bool> startVoiceRecord({
    VolumeCallBack volumeCallBack,
  }) async {
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
  /// return amr file path.
  static Future<String> stopVoiceRecord() async {
    String path = await _channel.invokeMethod('stopVoiceRecord') as String;
    _private._callBack = null;
    _private.recoreding = false;

    return path;
  }

  /// cancel record
  static Future<Null> cancelVoiceRecord() async {
    await _channel.invokeMethod('cancelVoiceRecord');
    _private._callBack = null;
    _private.recoreding = false;
  }
}
