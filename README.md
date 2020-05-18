## Spogit

Spogit is Spotify playlists (and folders of playlists) over Git. Yeah this is probably stupidly inefficient, but whatever. This will allow for pushing playlists to Git servers such as GitHub, making forks and PRs to other people's playlists.

The Spotify API does not expose folders in any way, shape, or form to the web API. Spotify also removed the desktop app API, and having each user make their own dev app is yucky. Spogit had to get creative in how it uses the API, by opening a chrome browser and has you log into Spotify, using the internal Web API with that token.

## Cloning a playlist
Cloning a playlist from a remote repo into your account is simple. Start the program as shown above, and `cd` into your `~/Spogit` directory. Then, simple `git clone` the repo as normal. This action will automatically update the daemon and push the data to your Spotify account.

## Pulling from Spotify
Pulling a playlist from Spotify has been implemented, just poorly. Not the pulling mechanism itself, but how it is done. A "command" must be invoked in the console of the Spogit process in the format of:
```
add-remote SomeName playlist folder whatever
```

First argument of `add-remote` is the name of the grouping, which may be surrounded in quotes to use spaces.
The second and onward arguments is a space-separated list of Spotify IDs and/or Spotify URIs ([info here](https://developer.spotify.com/documentation/web-api/#spotify-uris-and-ids)).

This operation does not modify your Spotify data at all.

## Updating Stuff
Updating your Spogit repositories happen automatically when you change something in Spotify. When a Spogit repository is checked out, changes are reflected in Spotify.
