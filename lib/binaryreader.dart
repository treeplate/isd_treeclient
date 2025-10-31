import 'dart:convert';
import 'dart:typed_data';
import 'core.dart';

class BinaryReader {
  int _index = 0;
  final ByteData _data;
  final Uint8List _rawData;
  final Endian endian;
  final Map<int, String> stringTable;

  bool get done => _index >= _rawData.length;

  int readUint8() {
    if (_index > _rawData.length - 1)
      throw StateError(
          'called readUint8 without enough bytes to read a uint32');
    _index += 1;
    return _data.getUint8(_index - 1);
  }

  int readUint32() {
    if (_index > _rawData.length - 4)
      throw StateError(
          'called readUint32 without enough bytes to read a uint32');
    _index += 4;
    return _data.getUint32(_index - 4, endian);
  }

  int readInt32() {
    if (_index > _rawData.length - 4)
      throw StateError(
          'called readInt32 without enough bytes to read a Int32');
    _index += 4;
    return _data.getInt32(_index - 4, endian);
  }

  Uint64 readUint64() {
    return endian == Endian.big ? Uint64.bigEndian(readUint32(), readUint32()) : Uint64.littleEndian(readUint32(), readUint32());
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

  BinaryReader(ByteBuffer buffer, this.stringTable, this.endian)
      : _rawData = buffer.asUint8List(),
        _data = buffer.asByteData();
}
