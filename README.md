![Release](https://github.com/RubbaBoy/Spogit/workflows/Release/badge.svg)

## Spogit

Spogit is Spotify playlists (and folders of playlists) over Git. Yeah this is probably stupidly inefficient, but whatever. This will allow for pushing playlists to Git servers such as GitHub, making forks and PRs to other people's playlists.

The Spotify API does not expose folders in any way, shape, or form to the web API. Spotify also removed the desktop app API, and having each user make their own dev app is yucky. Spogit had to get creative in how it uses the API, by opening a chrome browser and has you log into Spotify, using the internal Web API with that token.

## Installing

Installing Spogit is very straightforward, the only requirements is that you have Google Chrome installed. To install:

- Download the correct version of [ChromeDriver](https://chromedriver.chromium.org/) for your system
- Download your OS's release of [Spogit](https://github.com/RubbaBoy/Spogit/releases)
- Run the Spogit executable through your terminal, and login to Spotify

If the program stops for whatever reason, running the executable is the only thing you need to do to get it started again.

If you're illiterate and/or want to see Spogit running on a clean machine, check out the YouTube Demo:

[![Thumbnail](assets/Thumbnail.png)](https://www.youtube.com/watch?v=eIRy5j_zlPA)

## Commands

Commands are executed in the currently running Spogit process. The help is available by typing `help` and pressing enter, giving a result like:

```
=== Command help ===

status
    Lists the linked repos and playlists

list
    Lists your Spotify accounts' playlist and folder names and IDs.

add-remote "My Demo" spotify:playlist:41fMgMIEZJLJjJ9xbzYar6 27345c6f477d000
    Adds a list of playlist or folder IDs to the local Spogit root with the given name.
    
add-local "My Demo"
	Adds a local directory in the Spogit root to your Spotify account and begin tracking. Useful if git hooks are not working.

===
```

The commands are outlined below

### Status

The command `status` accepts no arguments are simply displays the status of your linked playlists. The top line of each linked group is the path of the data (e.g. `Spogit/Name`) and below are the playlist/folder names and their parsed IDs.

An example:

```
Spogit/AlternateRock:
 Alt ∕ Rock #64896a09c264a0f1
   Alt #41fMgMIEZJLJjJ9xbzYar6
   Alternative #6Xj0tPxwbI0GEUCFMduycy
   Ghost #2le4cCM38wjlQUuLODY6OC
   Non-English #1k63hUp3qMM8Cner9wrTDK
   not rap #59bqg4vhhXAxV3GImhCFra
   Rock #668IKn6D7BT0FyQj7N7Xsr
   The New Alt #37i9dQZF1DX82GYcclJ3Ug
```



### List

The `list` command accepts no arguments and lists all the Spotify playlists and folders, along with their respective parsed IDs. An example of this is:

```
Listing of all current Spotify tree data.
Key:
P - Playlist. ID starts with spotify:playlist
S - Group start. ID starts with spotify:start-group
E - Group end. ID starts with spotify:end-group

[S] General #20c77c3ea882ff4b
   [P] Speakers #4T8gh2JVgZoiGFutx04ErJ
   [P] Bass #6tiHNh6HjiuBFFW6YK1nqY
   [P] Stuff #1eEtiJrfTlaHZlkWseVU0c
 [E] General #20c77c3ea882ff4b
 [S] Alt/Rock #64896a09c264a0f1
   [P] Ghost #2le4cCM38wjlQUuLODY6OC
   [P] Non-English #1k63hUp3qMM8Cner9wrTDK
   [P] Alt #41fMgMIEZJLJjJ9xbzYar6
   [P] Rock #668IKn6D7BT0FyQj7N7Xsr
   [P] Alternative #6Xj0tPxwbI0GEUCFMduycy
   [P] The New Alt #37i9dQZF1DX82GYcclJ3Ug
   [P] not rap #59bqg4vhhXAxV3GImhCFra
 [E] Alt/Rock #64896a09c264a0f1
```



### Adding A Remote

The `add-remote` command clones your remote playlists/folders from Spotify to your local drive, allowing for them to be placed into a git repository. This command accepts an argument of the grouping name, and then a space-separated list of [Spotify ID](https://developer.spotify.com/documentation/web-api/#spotify-uris-and-ids)s. As it may be troublesome to get playlist IDs and even harder to get folder IDs, the `list` command above is very useful.

An example command adding the IDs `spotify:playlist:41fMgMIEZJLJjJ9xbzYar6` and `27345c6f477d000` (A parsed and unparsed ID example, either will work) with the grouping name `My Demo`:

```
add-remote "My Demo" spotify:playlist:41fMgMIEZJLJjJ9xbzYar6 27345c6f477d000
```

After doing this, any modification to the playlists over Spotify will modify the local copy as well, as long as the program is running.

### Adding A Local Repo

If your Git hooks are not functioning properly and a repo is not auto-added when it is clones, or it is created/clones when Spogit is not running, `add-local` may be used. It accepts a single argument of the directory name in the Spogit root to add to your account from and start tracking.

An example command adding the `~/Spogit/Music` cloned playlist to your Spotify account:

```
add-local "Music"
```



## Cloning From A Git Repository

Cloning a playlist from a remote repo into your account is simple. After the program is running, `cd` into your `~/Spogit` directory. Then, simple `git clone` the repo as normal. This action will automatically notify Spogit and push the data to your Spotify account.

