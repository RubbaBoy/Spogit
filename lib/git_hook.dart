import 'dart:async';
import 'dart:io';
import 'package:Spogit/utility.dart';

Future<void> main(List<String> args) async {
    var hook = GitHook();
    await hook.listen();
    hook.postCheckout.stream.listen((data) {
      print('Post checkout variables:');
      print('Previous hash = ${data.prevRef}');
      print('New hash = ${data.newRef}');
      print('Is from branch checkout = ${data.branchCheckout}');
      print('Working directory = ${data.workingDirectory.path}');
  });
}

class GitHook {

  final postCheckout = StreamController<PostCheckoutData>.broadcast();

  Future<void> listen() async {
    var server = await HttpServer.bind(InternetAddress.loopbackIPv4, 9082);
    print('Listening on localhost:${server.port}');

    server.listen((request) async {
      var segments = request.requestedUri.pathSegments;
      var query = request.requestedUri.queryParameters;

      if (segments.safeFirst == 'post-checkout') {
        postCheckout.add(PostCheckoutData(query['prev'], query['new'], query['from-branch'] == '1', query['pwd'].directory));
      } else {
        print('Unknown path "/${segments.join('/')}"');
      }

      await request.response.close();
    });
  }
}

class PostCheckoutData {
  final String prevRef;
  final String newRef;
  final bool branchCheckout;
  final Directory workingDirectory;

  PostCheckoutData(this.prevRef, this.newRef, this.branchCheckout, this.workingDirectory);
}
