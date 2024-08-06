extension type Uint64((int, int) _value) {
  String get displayName {
    if(_value.$1 == 0) return _value.$2.toString();
    if(_value.$1 == -1) return '-${_value.$2.toString()}';
    return '0x${_value.$1.toRadixString(16)}${_value.$2.toRadixString(16).padLeft(8, '0')}';
  }

  String get hexString {
    if(_value.$1 == 0) return '0x${_value.$2.toRadixString(16)}';
    if(_value.$1 == -1) return '-0x${_value.$2.toRadixString(16)}';
    return '0x${_value.$1.toRadixString(16)}${_value.$2.toRadixString(16).padLeft(8, '0')}';
  }

  bool get isZero => _value.$1 == 0 && _value.$2 == 0;
}