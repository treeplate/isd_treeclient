import 'dart:convert';
import 'dart:typed_data';

class BinaryReader {
  int _index = 0;
  final ByteData _data;
  final List<int> _rawData;

  bool get done => _index >= _rawData.length;

  int readUint32() {
    if (_index > _rawData.length - 4)
      throw StateError(
          'called readUint32 without enough bytes to read a uint32');
    _index += 4;
    return _data.getUint32(_index - 4, Endian.little);
  }
  int readUint64() {
    if (_index > _rawData.length - 8)
      throw StateError(
          'called readUint64 without enough bytes to read a uint64');
    _index += 8;
    return _data.getUint64(_index - 8, Endian.little);
  }

  double readFloat64() {
    if (_index > _rawData.length - 4)
      throw StateError(
          'called readFloat64 without enough bytes to read a float64');
    _index += 8;
    return _data.getFloat64(_index - 8, Endian.little);
  }

  String readString() {
    int length = readUint32();
    if (_index > _rawData.length - length)
      throw StateError(
          'called readString without enough bytes to read a string of that length');
    List<int> rawString = _rawData.sublist(_index, _index + length);
    _index += length;
    return utf8.decode(rawString);
  }

  BinaryReader(this._rawData)
      : _data = Uint8List.fromList(_rawData).buffer.asByteData();
}
