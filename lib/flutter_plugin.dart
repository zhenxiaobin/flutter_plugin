import 'dart:async';
import 'package:flutter/services.dart';
export 'bankcard_entity.dart';
export 'idcard_back_entity.dart';
export 'idcard_front_entity.dart';

class FlutterPlugin {
  static const MethodChannel _channel =
      const MethodChannel('flutter_plugin');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static Future<String> get idCardFront async {
    String frontInfo = await _channel.invokeMethod('getIdCardFront');
    return frontInfo;
  }

  static Future<String> get idCardBack async {
    final String backInfo = await _channel.invokeMethod('getIdCardBack');
    return backInfo;
  }

  static Future<String> get bankCard async {
    final String version = await _channel.invokeMethod('getBankCard');
    return version;
  }





}
