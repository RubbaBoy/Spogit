import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Spogit/driver/driver_api.dart';

class JSCommunication {
  final int port;
  final _broadcast = StreamController<JsonMessage>.broadcast();
  HttpServer _httpServer;

  Stream<JsonMessage> get stream => _broadcast.stream;

  JSCommunication._(this.port);

  static Future<JSCommunication> startCommunication([int port = 6979]) async {
    final communication = JSCommunication._(port);
    await communication.startListener();
    return communication;
  }

  Future<void> startListener() async {
    if (_httpServer != null) {
      throw 'HttpServer already initialized';
    }

    _httpServer = await HttpServer.bind('localhost', port);
    _httpServer.listen((req) async {
      if (req.uri.path == '/') {
        var socket = await WebSocketTransformer.upgrade(req);
        socket.listen((data) => _broadcast.add(JsonMessage.fromJSON(jsonDecode(data))));
      }
    });
  }
}
