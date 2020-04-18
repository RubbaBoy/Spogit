import 'dart:async';
import 'dart:convert';

import 'package:Spogit/driver/js_communication.dart';
import 'package:Spogit/driver_utility.dart';
import 'package:webdriver/sync_io.dart';

class RequestManager {
  final WebDriver _driver;
  final JSCommunication _communication;

  PersonalData personalData;
  String authToken;

  RequestManager(this._driver, this._communication);

  Future<void> initAuth() async {
    var _authCompleter = Completer<String>();

    StreamSubscription sub;
    sub = _communication.stream.listen((message) async {
      if (message.type == 'auth') {
        if (message.value.startsWith('Bearer ')) {
          authToken = message.value.substring(7);

          print('Got token, getting /me data');
          var meResponse = await makeRequest(DriverRequest(
              method: 'GET', uri: Uri.parse('https://api.spotify.com/v1/me')));
          personalData = PersonalData.fromJson(meResponse.body);
          print('Hello ${personalData.displayName}!');

          _authCompleter.complete();

          await sub?.cancel();
        }
      }
    });

    _driver.execute('''
        const authSocket = new WebSocket(`ws://localhost:6979`);
        constantMock = window.fetch;
        window.fetch = function() {
            if (arguments.length === 2) {
                if (arguments[0].startsWith('https://api.spotify.com/')) {
                    let headers = arguments[1].headers || {};
                    let auth = headers.authorization;
                    if (auth != null) {
                        authSocket.send(JSON.stringify({'type': 'auth', 'value': auth}));
                    }
                }
            }
            return constantMock.apply(this, arguments)
        }
    ''', []);

    (await getElement(_driver, By.cssSelector('a[href="/collection"]'))).click();

    return _authCompleter.future;
  }

  Future<DriverResponse> makeRequest(DriverRequest request) async {
    var response =
        await _driver.executeAsync(request.toJS(authToken), []);
    return DriverResponse(response['status'], Map.castFrom(response['body']));
  }
}

class DriverResponse {
  final int status;
  final Map<String, dynamic> body;

  DriverResponse(this.status, this.body);

  @override
  String toString() {
    return 'DriverResponse{status: $status, body: $body}';
  }
}

class DriverRequest {
  final bool authed;
  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final Map<String, dynamic> body;

  DriverRequest({
    this.authed = true,
    this.method = 'POST',
    this.uri,
    this.body,
    Map<String, String> headers = const {},
  }) : headers = {
          ...headers,
          ...{
            'accept': 'application/json',
            'content-type': 'application/json;charset=UTF-8',
            'accept-language': 'en',
            'app-platform': 'WebPlayer',
            'spotify-app-version': '1587143698',
          }
        };

  String toJS(String authToken) {
    var xhrHeaders = {
      ...headers,
      if (authed) ...{'Authorization': 'Bearer $authToken'},
    };

    return '''
    let args = arguments;
    let xhr = new XMLHttpRequest();
    xhr.withCredentials = $authed;
    
    xhr.addEventListener("readystatechange", function() {
      if(this.readyState === 4) {
        args[0]({'body': JSON.parse(this.responseText), 'status': this.status});
      }
    });
    
    xhr.open("$method", "$uri");
    ${xhrHeaders.keys.map((k) => 'xhr.setRequestHeader("$k", "${xhrHeaders[k]}");').join('\n')}
    
    xhr.send(${body != null ? "'${jsonEncode(body)}'" : "null"});
  ''';
  }
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
        spotifyUrl = Uri.parse(json['external_urls']['spotify']),
        followers = json['followers']['total'],
        id = json['id'],
        uri = json['uri'];
}
