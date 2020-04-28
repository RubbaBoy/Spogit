import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Spogit/driver/js_communication.dart';
import 'package:Spogit/driver_utility.dart';
import 'package:Spogit/utility.dart';
import 'package:http/http.dart' as http;
import 'package:webdriver/sync_io.dart';

class RequestManager {
  final WebDriver _driver;
  final JSCommunication _communication;

  PersonalData personalData;
  String authToken;

  RequestManager(this._driver, this._communication);

  Future<void> initAuth() async {
    var authCompleter = Completer<String>();

    StreamSubscription sub;
    sub = _communication.stream.listen((message) async {
      var headers = access(message.value['1'], 'headers');

      var authorization = access(headers, 'authorization');
      if (authorization == null) {
        return;
      }

      await sub?.cancel();

      authToken = authorization.substring(7);

      var meResponse = await DriverRequest(method: RequestMethod.Get, uri: Uri.parse('https://api.spotify.com/v1/me'), token: authToken)
      .send();

      print(meResponse.json);

      personalData = PersonalData.fromJson(meResponse.json);

      authCompleter.complete();
    });

    _driver.execute('''
const authSocket = new WebSocket(`ws://localhost:6979`);
constantMock = window.fetch;
window.fetch = function() {
        if (arguments[0].includes('spotify.com')) {
            authSocket.send(JSON.stringify({'type': 'http', 'value': arguments}));
        }
    return constantMock.apply(this, arguments)
}
    ''', []);

    (await getElement(_driver, By.cssSelector('a[href="/collection"]')))
        .click();

    return authCompleter.future;
  }
}

class DriverRequest {
  final RequestMethod method;
  final Uri uri;
  final Map<String, String> headers;
  final Map<String, dynamic> body;

  DriverRequest({
    String token,
    RequestMethod method,
    Uri uri,
    this.body,
    Map<String, String> headers = const {},
  })  : method = method ?? RequestMethod.Post,
        uri = uri.replace(queryParameters: {
          ...{'time': '$now'},
          // This is simply to stop Chrome from caching requests
          ...uri.queryParameters
        }),
        headers = {
          ...headers,
          ...{
            if (token != null) ...{'authorization': 'Bearer $token'},
            'accept': 'application/json',
            'content-type': 'application/json;charset=UTF-8',
            'accept-language': 'en',
            'app-platform': 'WebPlayer',
            'spotify-app-version': '1587143698',
          }
        };

  Future<http.Response> send() =>
      method.send(uri.toString(), body: body, headers: headers);
}

class RequestMethod {
  static final RequestMethod Get =
      RequestMethod._((url, headers, body) => http.get(url, headers: headers));

  static final RequestMethod Post = RequestMethod._(
      (url, headers, body) => http.post(url, headers: headers, body: jsonEncode(body)));

  static final RequestMethod Head =
      RequestMethod._((url, headers, body) => http.head(url, headers: headers));

  static final RequestMethod Delete =
      RequestMethod._((url, headers, body) => http.delete(url, headers: headers));

  final Future<http.Response> Function(
      String url, Map<String, String> headers, dynamic body) request;

  const RequestMethod._(this.request);

  Future<http.Response> send(String url,
          {Map<String, String> headers, dynamic body}) async =>
      await request(url, headers, body);
}

class PersonalData {
  final String birthdate;
  final String country;
  final String displayName;
  final String email;
  final Uri spotifyUrl;
  final int followers;
  final String id;
  final String uri;

  PersonalData.fromJson(Map<String, dynamic> json)
      : birthdate = json['birthdate'],
        country = json['country'],
        displayName = json['display_name'],
        email = json['email'],
        spotifyUrl = (access(json['external_urls'], 'spotify') as String)?.uri,
        followers = access(json['followers'], 'total') as int,
        id = json['id'],
        uri = json['uri'];
}
