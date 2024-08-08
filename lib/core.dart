const int integerLimit32 = 0x100000000;

extension type Uint64((int, int) _value) {
  String get displayName {
    if (msh == 0) return lsh.toString();
    if (msh == -1) return '-${lsh.toString()}';
    return '0x${msh.toRadixString(16)}${lsh.toRadixString(16).padLeft(8, '0')}';
  }

  String get hexString {
    if (msh == 0) return '0x${lsh.toRadixString(16)}';
    if (msh == -1) return '-0x${lsh.toRadixString(16)}';
    return '0x${msh.toRadixString(16)}${lsh.toRadixString(16).padLeft(8, '0')}';
  }

  bool get isZero => _value.$1 == 0 && _value.$2 == 0;
  int get lsh => _value.$2;
  int get msh => _value.$1;
  double get asDouble => ((msh << 32) + lsh).toDouble();
  int get asInt => ((msh << 32) + lsh);

  Uint64 operator *(int multiplier) {
    return Uint64.bigEndian(
        ((msh * multiplier) + ((lsh * multiplier) >> 32)) &
            (integerLimit32 - 1),
        lsh & (integerLimit32 - 1));
  }

  double operator /(double divisor) {
    return asDouble / divisor;
  }

  Uint64 operator %(int divisor) {
    if ((divisor >> 32) == 0) {
      return Uint64.bigEndian(0, lsh % divisor);
    }
    return Uint64.bigEndian(msh % (divisor >> 32), lsh % divisor);
  }

  Uint64.littleEndian(int lsh, int msh) : _value = (msh, lsh);
  Uint64.bigEndian(int msh, int lsh) : _value = (msh, lsh);
  factory Uint64.fromInt(int value) => Uint64.bigEndian(value >> 32, value & (integerLimit32 - 1));
}
