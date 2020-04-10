import 'dart:convert';
import 'dart:io';

import 'package:Spogit/auth_retriever.dart';
import 'package:oauth2/oauth2.dart';

class AuthStore {
  final File path;

  AuthStore([this.path]);

  AuthData readData() => path.existsSync()
      ? AuthData.fromJson(jsonDecode(path.readAsStringSync()))
      : null;

  void saveData(AuthData authData) =>
      path.writeAsString(jsonEncode(authData.toJson()));
}

class AuthData {
  final String accessToken;
  final String refreshToken;
  final int expireTime;
  final List<String> scopes;

  AuthData(this.accessToken, this.refreshToken, this.expireTime, this.scopes);

  Credentials toCredentials() => Credentials(accessToken,
      refreshToken: refreshToken,
      expiration: DateTime.fromMillisecondsSinceEpoch(expireTime, isUtc: true),
      tokenEndpoint: tokenUrl,
      scopes: scopes);

  AuthData.fromJson(Map<String, dynamic> json)
      : accessToken = json['auth_token'],
        refreshToken = json['refresh_token'],
        expireTime = json['expires_in'],
        scopes = List<String>.from(json['scopes']);

  AuthData.fromCredential(Credentials cred)
      : accessToken = cred.accessToken,
        refreshToken = cred.refreshToken,
        expireTime = cred.expiration.millisecondsSinceEpoch,
        scopes = cred.scopes;

  Map<String, dynamic> toJson() => {
        'auth_token': accessToken,
        'refresh_token': refreshToken,
        'expires_in': expireTime,
        'scopes': scopes,
      };
}
