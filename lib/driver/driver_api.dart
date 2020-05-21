import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Spogit/driver/driver_request.dart';
import 'package:Spogit/driver/js_communication.dart';
import 'package:Spogit/driver/playlist_manager.dart';
import 'package:Spogit/driver_utility.dart';
import 'package:Spogit/utility.dart';
import 'package:logging/logging.dart';
import 'package:webdriver/sync_io.dart';

class DriverAPI {
  final log = Logger('DriverAPI');

  final File cookiesFile;
  final File chromeDriverFile;
  WebDriver driver;

  JSCommunication communication;
  RequestManager requestManager;
  PlaylistManager playlistManager;

  DriverAPI(this.cookiesFile, this.chromeDriverFile);

  Future<void> startDriver() async {
    final runner = WebDriverRunner();
    await runner.start(chromeDriverFile);

    driver = runner.driver;

    communication = await JSCommunication.startCommunication();

    requestManager = RequestManager(driver, communication);

    await getCredentials();

    await requestManager.initAuth();

    playlistManager = await PlaylistManager.createPlaylistManager(
        driver, requestManager, communication);
  }

  Future<void> getCredentials() async {
    if (await cookiesFile.exists()) {
      driver.get('https://open.spotify.com/');
      var json = jsonDecode(cookiesFile.readAsStringSync());
      json.forEach((cookie) => driver.cookies.add(Cookie.fromJson(cookie)));

      driver.get('https://open.spotify.com/');
      return;
    }

    driver.get(
        'https://accounts.spotify.com/en/login?continue=https:%2F%2Fopen.spotify.com%2F');

    await getElement(driver, By.cssSelector('.Root__main-view'),
        duration: 20000);

    log.info('Logged in');

    jsonEncode(driver.cookies.all.map((cookie) => cookie.toJson()).toList()) >>
        cookiesFile;
  }

  Map<dynamic, dynamic> getLocalStorage() =>
      driver.execute('return window.localStorage;', []);

  void setLocalStorage(String key, String value) => driver.execute(
      'window.localStorage.setItem(arguments[0], arguments[1])', [key, value]);
}

class WebDriverRunner {
  final log = Logger('WebDriverRunner');

  Process _process;

  WebDriver _driver;

  WebDriver get driver => _driver;

  Future<void> start(File chromedriver,
      [int chromeDriverPort = 4569]) async {
    if (await isOpen(chromeDriverPort)) {
      log.info('Starting chromedriver...');

      _process = await Process.start(chromedriver.path, [
        '--port=$chromeDriverPort',
        '--url-base=wd/hub',
      ]);

      await for (var out
      in const LineSplitter().bind(utf8.decoder.bind(_process.stdout))) {
        if (out.contains('Starting ChromeDriver')) {
          break;
        }
      }

      log.info('Started chromedriver with PID $chromeDriverPort');
    } else {
      log.info('Looks like chromedriver is already running');
    }

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
//              '--headless',

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

    log.info('Started driver');
  }

  void stop() {
    _driver.quit(closeSession: true);
    _process?.kill();
  }

  Future<bool> isOpen(int port) =>
      ServerSocket.bind('127.0.0.1', port).then((socket) {
        socket.close();
        return true;
      }).catchError((_) => false);
}
