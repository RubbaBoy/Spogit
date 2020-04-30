import 'dart:async';

import 'package:Spogit/driver/driver_api.dart';
import 'package:Spogit/driver/playlist_manager.dart';

class ChangeWatcher {
  final DriverAPI driverAPI;

  ChangeWatcher(this.driverAPI);

  void watchChanges(Function(BaseRevision) callback) {
    // The last etag for the playlist tree request
    String previousETag;

    Timer.periodic(Duration(seconds: 2), (timer) async {
      var etag = await driverAPI.playlistManager.baseRevisionETag();
      if (etag == previousETag) {
        return;
      }

      var sendCallback = previousETag != null;

      previousETag = etag;

      if (sendCallback) {
        print('\n\nPlaylist tree has changed!');
        callback(await driverAPI.playlistManager.analyzeBaseRevision());
      }
    });
  }
}
