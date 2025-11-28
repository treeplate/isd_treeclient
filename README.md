# isd_treeclient
This app is a client for [ISD](https://interstellar-dynasties.space).
## How to Play
- For the first 30 seconds, you can watch the spaceship (which you start focused on, so it'll be where the white dot is) crash into the planet in "system view", or you can press "stop following" and zoom around with scroll wheel, pan with mouse, and click on a planet or something on the right menu to focus on it. You can also look up where you are in "galaxy view" by copying the star ID (S______) into the textbox and pressing "Lookup", or just look at the full galaxy (warning: full galaxy is laggy).
- At the top right, you'll see four buttons. In order from left to right:
    - debugging tool, do not use
    - inbox (where you see messages)
    - profile (change username, password, log out, or use the serverside icons with "use network icons")
    - brightness (change between light/dark mode - dark mode is recommended)
- Ignore "debug system view" (it's a debugging tool not intended for end users)
- After the spaceship crashes, you can go to "planet view" and see the planet.
- You can click on the crater and the spaceship. When you click on the spaceship, you can click on the button next to "Researching:" to pick a research. Note that the current tech tree may have you waiting for like 20 minutes for some things. Do not press the "disable" or "dismantle" button on the spaceship, or "dismantle" on the crater under the spaceship, as that basically softlocks the game.
- You can drag a building from the right side of the screen onto the grid to place it, and then click it again to interact with it. 
- You can zoom and pan around the planet.
- You can build on top of cities, though cities in general right now are kinda pointless. You cannot build half-in a city and half-not in a city.
## Server-Client Protocol
See [the official protocol](https://software.hixie.ch/fun/isd/test-2024/servers/src/README.md), as well as the official [system](https://software.hixie.ch/fun/isd/test-2024/servers/src/systems-server/README.md), [dynasty](https://software.hixie.ch/fun/isd/test-2024/servers/src/dynasties-server/README.md), and [login](https://software.hixie.ch/fun/isd/test-2024/servers/src/login-server/README.md) sub-protocols.
## Cookie Storage
This app saves its state between runs. When using package:web, it uses local storage, but when using dart:io, it has to save it to a file. This file is called "cookies.save", and uses its own format, described here.

### Map<String, String> => .save file
Each entry in the map is separated by a newline followed by a null byte. The entries themselves are encoded as key, colon, null, value.
### .save file => Map<String, String>
Split the raw file data on newline-null, making a list of raw entries, and then split each entry on colon-null, making a list [key, value]. Now you have a List<List\<String>>, and can map each List\<String> to a MapEntry<String, String>, and then use Map.fromEntries to complete the decoding.
## Tools
https://github.com/treeplate/isd_starnames is a tool for finding stars with specific names.
