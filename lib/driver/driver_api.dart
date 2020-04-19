import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Spogit/driver/driver_request.dart';
import 'package:Spogit/driver/js_communication.dart';
import 'package:Spogit/driver/playlist_manager.dart';
import 'package:Spogit/driver_utility.dart';
import 'package:webdriver/sync_io.dart';

void main(List<String> args) {
  DriverAPI().main(args);
}

const String PLAYLIST_111 = 'spotify:playlist:2RFxTyHARNM8KDpZyamcsx';

//const String FOLDER_GENERAL = 'spotify:start-group:20c77c3ea882ff4b:General';
//const String FOLDER_FOLD1 = 'spotify:start-group:231be240b5401a01:fold';
//const String FOLDER_FOLD2 = 'spotify:start-group:c5dd575d299c043a:fold';

const SOME_FOLDER = '39b5c7b76cb5000';
const INNER_PLAYLIST = '0RWiVsbFgo4sMYT4XK6fAM';
const FIRST = 'b623551dee2c000';

class DriverAPI {
  WebDriver driver;
  File cookiesFile = File('cookies.json');

  Future<void> main(List<String> args) async {
    final runner = WebDriverRunner();
    await runner.start();

    print('Started driver!');

    driver = runner.driver;

    final communication = await JSCommunication.startCommunication();

    final requestManager = RequestManager(driver, communication);

    await getCredentials();

    await requestManager.initAuth();

    final playlistManager = await PlaylistManager.createPlaylistManager(driver, requestManager, communication);

    print('Initialized everything!');

//    var res = await playlistManager.movePlaylist(PLAYLIST_111, toGroup: FOLDER_GENERAL, offset: 1);

//    var res = await playlistManager.createFolder('Alrighty', toGroup: FOLDER_FOLD1, offset: 1);


//    var folder = await playlistManager.createFolder('Anothe router', absolutePosition: 0);
//    var folderId = folder['id'];
//    print('Made folder $folderId');
//
//    var playlist = await playlistManager.createPlaylist('Another inner');
//    var playlistId = playlist['id'];
//    print('Created playlist with ID of $playlistId');


    const secondChild = '4bd03915143b8000';
    const anotherRouter = '954932e2829000';
    var moved = await playlistManager.movePlaylist(secondChild, toGroup: anotherRouter);

//    var base = await playlistManager.analyzeBaseRevision();
//    print('Base =');
//    print(base.elements.join('\n'));

    print(moved);

    print('Moved playlist');
  }

  Future<void> getCredentials() async {
    if (cookiesFile.existsSync()) {
      driver.get('https://open.spotify.com/');
      var json = jsonDecode(cookiesFile.readAsStringSync());
      json.forEach((cookie) => driver.cookies.add(Cookie.fromJson(cookie)));

      driver.get('https://open.spotify.com/');
      return;
    }

    driver.get(
        'https://accounts.spotify.com/en/login?continue=https:%2F%2Fopen.spotify.com%2F');

    await getElement(driver, By.cssSelector('.Root__main-view'), duration: 20000);

    print('Logged in!');

    cookiesFile.writeAsStringSync(jsonEncode(
        driver.cookies.all.map((cookie) => cookie.toJson()).toList()));
  }

  void moveObject(String moving, String to) {
    driver.execute('''
    
    ''', [moving, to]);
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

  Map<dynamic, dynamic> getLocalStorage() =>
      driver.execute('return window.localStorage;', []);

  void setLocalStorage(String key, String value) => driver.execute(
      'window.localStorage.setItem(arguments[0], arguments[1])', [key, value]);
}

class JsonMessage {
  final String type;
  final String value;

  JsonMessage.fromJSON(Map<String, dynamic> json) :
      type = json['type'],
        value = json['value'];
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
//    spotify ??= File(r'C:\Users\RubbaBoy\AppData\Roaming\Spotify\Spotify.exe');

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
//          'loggingPrefs': {
//            'browser': 'ALL'
//          },
          'goog:loggingPrefs': {'browser': 'ALL'},
          'goog:chromeOptions': {
            'args': [
              '--disable-web-security',
              '--allow-running-insecure-content',
//              '--disable-background-networking',
//              '--disable-client-side-phishing-detection',
//              '--disable-default-apps',
//              '--disable-hang-monitor',
//              '--disable-popup-blocking',
//              '--disable-prompt-on-repost',
//              '--disable-sync',
              '--enable-automation',
//              '--enable-blink-features=ShadowDOMV0',
              '--enable-logging',
//              r'--load-extension="C:\Users\RubbaBoy\AppData\Local\Temp\scoped_dir27708_2007804984\internal"',
              '--log-level=0',
//              '--no-first-run',
//              '--password-store=basic',
              '--test-type=webdriver',
//              '--use-mock-keychain',
//              r'--user-data-dir="C:\Users\RubbaBoy\AppData\Local\Temp\scoped_dir27708_1019023969"',
//              '--verbose',
//              '--product-version=Spotify/1.1.30.658',
//              '--lang=en',
//              r'--log-file="C:\Users\RubbaBoy\AppData\Roaming\Spotify\debug.json"',
//              r'--log-net-log="C:\Users\RubbaBoy\AppData\Roaming\Spotify\net.json"',
              '--net-log-level=0',
              '--log-severity=all',
//              '--remote-debugging-port=$remoteDebuggingPort',
//              '--disable-features=MimeHandlerViewInCrossProcessFrame',
//              '--disable-spell-checking',
//              '--disable-d3d11',
//              '--disable-pinch',
              '--auto-open-devtools-for-tabs',
//              '--disable-site-isolation-trials data:,'
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
