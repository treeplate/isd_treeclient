import 'dart:convert';
import 'dart:typed_data';

class BinaryReader {
  int _index = 0;
  final ByteData _data;
  final List<int> _rawData;
  final Endian endian;
  final Map<int, String> stringTable = {};

  bool get done => _index >= _rawData.length;

  int readUint32() {
    if (_index > _rawData.length - 4)
      throw StateError(
          'called readUint32 without enough bytes to read a uint32');
    _index += 4;
    return _data.getUint32(_index - 4, endian);
  }

  int readUint64() {
    if (_index > _rawData.length - 8)
      throw StateError(
          'called readUint64 without enough bytes to read a uint64');
    _index += 8;
    return _data.getUint64(_index - 8, endian);
  }

  double readFloat64() {
    if (_index > _rawData.length - 4)
      throw StateError(
          'called readFloat64 without enough bytes to read a float64');
    _index += 8;
    return _data.getFloat64(_index - 8, endian);
  }

  String readString() {
    int code = readUint32();
    String? result = stringTable[code];
    if (result != null) {
      return result;
    }
    int length = readUint32();
    if (_index > _rawData.length - length)
      throw StateError(
          'called readString without enough bytes to read a string of that length ($length)');
    List<int> rawString = _rawData.sublist(_index, _index + length);
    _index += length;
    result = utf8.decode(rawString);
    stringTable[code] = result;
    return result;
  }

  BinaryReader(this._rawData, this.endian)
      : _data = Uint8List.fromList(_rawData).buffer.asByteData();
}
