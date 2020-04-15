import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:webdriver/sync_io.dart';

WebDriver driver;

Future<void> main(List<String> args) async {
  final runner = WebDriverRunner();
  await runner.start();

  print('Started driver!');

  driver = runner.driver;

  print(driver.id);
  print(driver.uri);

//  print((await driver.findElement(By.tagName('body'))).toStringDeep());
//
//  print('Listening to shit');
//  await listenShit();
//  print('All good');

//  var d = driver.executeAsync('setTimeout(() => args[0](), 3000);', args);
//  print(d);
//  print(d.runtimeType);

//  sleep(Duration(seconds: 5));
//  driver.execute(script, args)

//  var res = driver.execute(r'''
//  XMLHttpRequest.prototype.wrappedSetRequestHeader = XMLHttpRequest.prototype.setRequestHeader;
//  XMLHttpRequest.prototype.setRequestHeader = function (header, value) {
//    this.wrappedSetRequestHeader(header, value);
//    // if (value === 'rootlist') {
//    // socket.send(value.toString());
//    let socket = new WebSocket(`ws://192.168.1.24:6979`);
////        let socket = new WebSocket(`ws://192.168.1.24:6979/${value}`);
//        XMLHttpRequest.prototype.setRequestHeader = this.wrappedSetRequestHeader;
////        setTimeout(socket.close, 100);
//    // }
//};
////setInterval(() => { socket.send('bruh'); }, 1000);
//  ''', []);

//  print(driver.pageSource);

//  await driver.get('chrome://settings/');

  initJs();

  print('Expanding in 5 seconds...');

  sleep(Duration(seconds: 5));

//  sleep(Duration(seconds: 1));


  print('Expanded!');

  var allStuff = bruhAll();

  print(allStuff.map((e) => e.toString()).join('\n'));

//  watchFile(File(r'C:\Users\RubbaBoy\AppData\Roaming\Spotify\debug.log'))
//      .listen(print);

//  sleep(Duration(seconds: 30));
  await slp(300000000).then((_) => runner.stop());

//  Timer.periodic(Duration(seconds: 10), (_) => print('Update'));
}

Stream<String> watchFile(File file) {
  final stream = StreamController<String>.broadcast();

  var last = 0;
  Timer.periodic(Duration(seconds: 3), (_) async {
    var newBytes = file.lengthSync() - last;

    if (newBytes == 0) {
      return;
    }

    await LineSplitter()
        .bind(utf8.decoder
            .bind(file.openRead(last, last += newBytes).take(newBytes)))
        .forEach((data) => stream.add(data));
  });

  return stream.stream;
}

void initJs() => driver.execute('''
(function() {
    let val = {
        getFolded: function () {
            return [...document.querySelectorAll('li:not(.RootlistItemFolder--is-expanded) a[data-sidebar-list-item-uri^="spotify:app:playlist-folder"]')];
        },
        getButtonFromListItem: (listItem) => {
            return listItem.parentNode.parentNode.querySelector('button');
        },
        getIdentifier: (listItem) => {
            return listItem.href;
        },
        fromIdentifier: (identifier) => {
            return document.querySelector('a[data-sidebar-list-item-uri="' + identifier + '"]')
        },
        toggleAll: (folded) => {
            folded.forEach(e => getButtonFromListItem(fromIdentifier(e)).click());
        },
        getAllDisplayed: () => {
            return [...document.querySelectorAll('a[data-sidebar-list-item-uri^="spotify:app:playlist"]')]
                .map((e) => {
                    let style = e.parentNode.parentNode.parentNode.parentNode.parentNode.getAttribute('style');
                    return [e.getAttribute('data-sidebar-list-item-uri'), style.substring(14, style.length - 1)];
                });
        },
        getFullTree: () => {
            let foldedInitially = getFolded().map(getIdentifier);

            toggleAll(foldedInitially);

            let allStuff = getAllDisplayed();

            toggleAll(foldedInitially);

            return allStuff;
        }
    };
    for (let method in val) {
        window[method] = val[method];
    }
})();
''', []);

List<SpotifyEntity> bruhAll() {
  var result = driver.execute('return getFullTree();', []);

  var bruh2 = result
      .map((line) => [
            line[0]
                .substring('spotify:app:'.length, line[0].length)
                .split(':')
                .toList(),
            int.parse(line[1])
          ])
      .toList();

  final root = SpotifyFolder();
  var current = root;
  var currDepth = 0;

  for (var value in bruh2) {
    var data = value[0];

    while (value[1] < currDepth) {
      currDepth--;
      current = current.parent;
    }

    if (data[0] == 'playlist-folder') {
      current.children.add(current = SpotifyFolder(data[1], '', current));
      currDepth++;
    } else {
      current.children.add(SpotifyPlaylist(data[1]));
    }
  }

  return root.children;
}

Map<dynamic, dynamic> getLocalStorage() =>
    driver.execute('return window.localStorage;', []);

void setLocalStorage(String key, String value) => driver.execute(
    'window.localStorage.setItem(arguments[0], arguments[1])', [key, value]);

Future<void> slp(int mills) async {
  final completer = Completer();
  Timer(Duration(milliseconds: mills), () => completer.complete());
  return completer.future;
}

Future<void> listenShit([int port = 6979]) async {
  var server = await HttpServer.bind('192.168.1.24', port);
  server.listen((req) async {
    print('req uri = ${req.uri.path}');
    if (req.uri.path == '/') {
      // Upgrade a HttpRequest to a WebSocket connection.
      var socket = await WebSocketTransformer.upgrade(req);
      socket.listen((m) => print('[DATA] $m'));
    }
    ;
  });
}

class WebDriverRunner {
  Process _process;

  WebDriver _driver;

  WebDriver get driver => _driver;

  Future<void> start(
      [File chromedriver,
      File spotify,
      int chromeDriverPort = 4569,
      int remoteDebuggingPort = 6978]) async {
    chromedriver ??= File(r'E:\BRUHHHHH\chromedriver-79.exe');
    spotify ??= File(r'C:\Users\RubbaBoy\AppData\Roaming\Spotify\Spotify.exe');

//    _process = await Process.start(chromedriver.path, [
//      '--port=$chromeDriverPort',
//      '--url-base=wd/hub',
//      '--enable-logging',
//      '--verbose'
//    ]);
//
//    await for (var out
//        in const LineSplitter().bind(utf8.decoder.bind(_process.stdout))) {
//      if (out.contains('Starting ChromeDriver')) {
//        break;
//      }
//    }

//    print('Starting');

    _driver = await createDriver(
        uri: Uri.parse('http://localhost:${chromeDriverPort}/wd/hub/'),
        desired: {
          'browserName': 'chrome',
          'goog:chromeOptions': {
            'binary': spotify.path,
            'args': [
              '--disable-background-networking',
              '--disable-client-side-phishing-detection',
              '--disable-default-apps',
              '--disable-hang-monitor',
              '--disable-popup-blocking',
              '--disable-prompt-on-repost',
              '--disable-sync',
              '--enable-automation',
              '--enable-blink-features=ShadowDOMV0',
              '--enable-logging',
//              r'--load-extension="C:\Users\RubbaBoy\AppData\Local\Temp\scoped_dir27708_2007804984\internal"',
              '--log-level=0',
              '--no-first-run',
              '--password-store=basic',
              '--test-type=webdriver',
              '--use-mock-keychain',
//              r'--user-data-dir="C:\Users\RubbaBoy\AppData\Local\Temp\scoped_dir27708_1019023969"',
              '--verbose',
              '--product-version=Spotify/1.1.30.658',
              '--lang=en',
              r'--log-file="C:\Users\RubbaBoy\AppData\Roaming\Spotify\debug.json"',
              r'--log-net-log="C:\Users\RubbaBoy\AppData\Roaming\Spotify\net.json"',
              '--net-log-level=0',
              '--log-severity=all',
              '--remote-debugging-port=$remoteDebuggingPort',
              '--disable-features=MimeHandlerViewInCrossProcessFrame',
              '--disable-spell-checking',
              '--disable-d3d11',
              '--disable-pinch',
              '--auto-open-devtools-for-tabs',
              '--disable-site-isolation-trials data:,'
            ],
          },
        });

    print('done');
  }

  void stop() {
    _driver.quit(closeSession: true);
    _process?.kill();
  }
}

class SpotifyPlaylist extends SpotifyEntity {
  SpotifyPlaylist(String id) : super(id);

  @override
  String print(int indentation) => '${'  ' * indentation} $id';
}

class SpotifyFolder extends SpotifyEntity {
  final List<SpotifyEntity> children = [];
  final String name;
  final SpotifyFolder parent;

  SpotifyFolder([String id, this.name, this.parent]) : super(id);

  @override
  String print(int indentation) => """${'  ' * indentation} $name ($id)
${children.map((entity) => entity.print(indentation + 2)).join('\n')}""";

  @override
  String toString() => print(0);
}

abstract class SpotifyEntity {
  final String id;

  SpotifyEntity(this.id);

  String print(int indentation);
}

List<int> stripList(Uint8List list) {
  var pastComma = false;
  var pastFirst = false;
  return <int>[...list.toList()]..removeWhere((i) {
      if (pastFirst) {
        return true;
      }

      if (i == 10 || i == 13) {
        pastFirst = true;
      }

      var res = !pastComma || i < 32 || i > 126;
      pastComma = pastComma || i == 44; // ,
      return res;
    });
}
