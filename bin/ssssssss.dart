import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final file = File('progress.txt');

  var last = 0;
  Timer.periodic(Duration(seconds: 3), (_) async {
    var newBytes = file.lengthSync() - last;

    if (newBytes == 0) {
      return;
    }

    await for (var out in const LineSplitter().bind(utf8.decoder
        .bind(file.openRead(last, last += newBytes).take(newBytes)))) {
      print('[LINE] $out');
    }
  });
}
