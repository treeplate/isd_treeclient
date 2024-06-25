# isd_treeclient
This app is a client for [ISD](https://interstellar-dynasties.space).
## Server-Client Protocol
See [the official protocol](https://software.hixie.ch/fun/isd/test-2024/servers/src/README.md), as well as the official [system](https://software.hixie.ch/fun/isd/test-2024/servers/src/systems-server/README.md), [dynasty](https://software.hixie.ch/fun/isd/test-2024/servers/src/dynasties-server/README.md), and [login](https://software.hixie.ch/fun/isd/test-2024/servers/src/login-server/README.md) sub-protocols.
## Cookie Storage
This app saves its state between runs. When using package:web, it uses local storage, but when using dart:io, it has to save it to a file. This file is called "cookies.save", and uses its own format, described here.

### Map<String, String> => .save file
Each entry in the map is separated by a newline followed by a null byte. The entries themselves are encoded as key, colon, null, value.
### .save file => Map<String, String>
Split the raw file data on newline-null, making a list of raw entries, and then split each entry on colon-null, making a list [key, value]. Now you have a List<List<String>>, and can map each List<String> to a MapEntry<String, String>, and then use Map.fromEntries to complete the decoding.