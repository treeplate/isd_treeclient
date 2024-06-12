# isd_treeclient
This app is a client for [ISD](https://interstellar-dynasties.space).
## Cookie Storage
This app saves its state between runs. When using dart:html, it uses local storage, but when using dart:io, it has to save it to a file. This file is called "cookies.save", and uses its own format, described here.

### Map<String, String> => .save file
Each entry in the map is separated by a null byte, a newline, and another null byte. The entries themselves are encoded as key, null, colon, null, value.
### .save file => Map<String, String>
Split the raw file data on null-newline-null, making a list of raw entries, and then split each entry on null-colon-null, making a list [key, value]. Now you have a List<List<String>>, and can map each List<String> to a MapEntry<String, String>, and then use Map.fromEntries to complete the decoding.