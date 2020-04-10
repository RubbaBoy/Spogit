## Spogit

Spogit is Spotify playlists (and folders of playlists) over Git. Yeah this is probably stupidly inefficient, but whatever. This will allow for pushing playlists to Git servers such as GitHub, making forks and PRs to other people's playlists.





The current workflow (Don't pay attention to this, for my own knowledge, this will be refactored later)

- User initializes a spotify playlist in `~/Spogit`
- The daemon process sees this and adds a Git hook

The spotify hooking workflow:

- The program first links to your spotify account
- Upon changing (optionally creating) of a playlist, the `~/Spogit/*` repo is updated