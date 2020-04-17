import 'dart:async';
import 'dart:convert';

import 'package:webdriver/sync_io.dart';

class RequestManager {
  final WebDriver _driver;
  Completer<String> _authTokenCompleter;
  String _authToken;

  String get authToken => _authToken;

  set authToken(String value) {
    print('authToken = $value');
    _authToken = value;

    if (!(_authTokenCompleter?.isCompleted ?? true)) {
      _authTokenCompleter.complete(value);
    }
  }

  RequestManager(this._driver);

  Future<String> waitForAuth() async {
    if (_authToken != null) {
      return _authToken;
    }
    _authTokenCompleter = Completer<String>();
    return _authTokenCompleter.future;
  }

  Future<DriverResponse> makeRequest(DriverRequest request) async {
    var response = await _driver.executeAsync(request.toJS(await waitForAuth()), []);
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
            'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/81.0.4044.113 Safari/537.36',
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
