import 'package:Spogit/cache/album/album_resource.dart';
import 'package:Spogit/cache/cache_manager.dart';
import 'package:Spogit/cache/cache_types.dart';
import 'package:Spogit/driver/playlist_manager.dart';
import 'package:Spogit/json/album_full.dart';

class AlbumResourceManager {

  final PlaylistManager playlistManager;
  final CacheManager cacheManager;

  AlbumResourceManager(this.playlistManager, this.cacheManager);

  /// Gets or retrieves the album JSON for the associated track ID.
  Future<AlbumFull> getAlbum(String track) async {
    track = track.parseId;

    var albums = cacheManager.getAllOfType(CacheType.ALBUM);
    var foundAlbum = albums.firstWhere((album) => album.data.tracks.items.any((trackObj) => trackObj.id == track), orElse: () => null);
    if (foundAlbum != null) {
      return Future.value(foundAlbum.data);
    }

    var gottenTrack = await playlistManager.getTrack(track);
    if (gottenTrack == null) {
      throw 'Gotten track for ID "$track" is null!';
    }

    var album = gottenTrack.album;

    // The full album must be gotten for access for the tracks
    var fullAlbum = await playlistManager.getAlbum(album.id);

    cacheManager[album.id] = AlbumResource(album.id, fullAlbum);

    return fullAlbum;
  }
}
