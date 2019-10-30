import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_plugin/flutter_plugin.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  String _bankCardInfo ;
  String _idCardFrontInfo ;
  String _idCardBackInfo ;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      platformVersion = await FlutterPlugin.platformVersion;
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  Future<void> scanIdCardFront() async {
    String frontInfo;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      frontInfo = await FlutterPlugin.idCardFront;
    } on PlatformException {
      frontInfo = 'Failed to get idCardFrontInfo.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _idCardFrontInfo = frontInfo;
    });
  }

  Future<void> scanIdCardBack() async {
    String backInfo;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      backInfo = await FlutterPlugin.idCardBack;
    } on PlatformException {
      backInfo = 'Failed to get idCardInfo.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _idCardBackInfo = backInfo;
    });
  }

  Future<void> scanBankCard() async {
    String bankCardNum;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      bankCardNum = await FlutterPlugin.bankCard;
    } on PlatformException {
      bankCardNum = 'Failed to get bankCardInfo.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _bankCardInfo = bankCardNum;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Container(
          margin: EdgeInsets.only(top: 12, left: 12, right: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.only(top: 12),
                child: Text('Running on: $_platformVersion'),
              ),
              Container(
                padding: EdgeInsets.only(top: 18),
                child: InkWell(
                  child: Text('扫描银行卡: ${_bankCardInfo == null?"点击获取":_bankCardInfo}'),
                  onTap: () {
                    scanBankCard();
                  },
                ),
              ),
              Container(
                padding: EdgeInsets.only(top: 18),
                child: InkWell(
                  child: Text('扫描身份证正面: ${_idCardFrontInfo == null?"点击获取":_idCardFrontInfo}'),
                  onTap: () {
                    scanIdCardFront();
                  },
                ),
              ),
              Container(
                padding: EdgeInsets.only(top: 18),
                child: InkWell(
                  child: Text('扫描身份证反面: ${_idCardBackInfo == null?"点击获取":_idCardBackInfo}'),
                  onTap: () {
                    scanIdCardBack();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
