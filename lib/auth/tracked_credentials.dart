import 'package:Spogit/auth/auth_store.dart';
import 'package:oauth2/oauth2.dart';

import 'package:http/http.dart' as http;

class TrackedCredentials extends Credentials {

  final Function(Credentials) onRefresh;

  TrackedCredentials(String accessToken, String refreshToken, int expiresIn,
      tokenEndpoint, List<String> scopes, [this.onRefresh])
      : super(accessToken,
            refreshToken: refreshToken,
            expiration: DateTime.now().add(Duration(seconds: expiresIn)),
            tokenEndpoint: tokenEndpoint,
            scopes: scopes);

  @override
  Future<Credentials> refresh(
      {String identifier,
        String secret,
        Iterable<String> newScopes,
        bool basicAuth = true,
        http.Client httpClient}) async {
    var cred = await super.refresh(identifier: identifier, secret: secret, newScopes: newScopes, basicAuth: basicAuth, httpClient: httpClient);
    onRefresh?.call(cred);
    return cred;
  }
}

// This is not above as it is needed for all Credentials
extension CredSaver on Credentials {
  void saveCredentials(AuthStore authStore) =>
      authStore.saveData(AuthData.fromCredential(this));
}
