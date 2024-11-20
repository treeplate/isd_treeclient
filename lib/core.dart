const int integerLimit32 = 0x100000000;

extension type Uint64((int, int) _value) {
  String get displayName {
    if (msh == 0) return lsh.toString();
    if (msh == -1) return '-${lsh.toString()}';
    return '0x${msh.toRadixString(16)}${lsh.toRadixString(16).padLeft(8, '0')}';
  }

  String get hexString {
    return '${msh.toRadixString(16).padLeft(8, '0')}${lsh.toRadixString(16).padLeft(8, '0')}';
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

  Uint64 operator +(Uint64 addend) {
    int lshResult = lsh + addend.lsh;
    return Uint64.bigEndian((msh + addend.msh + (lshResult >> 32)) & (integerLimit32 - 1), lshResult & (integerLimit32 - 1));
  }

  Uint64 operator -(Uint64 addend) {
    int newLsh = lsh - addend.lsh;
    int newMsh = msh - addend.msh;
    if (newLsh < 0) {
      newMsh--;
      newLsh += 1 << 32;
    }
    if (newMsh < 0) {
      return Uint64.bigEndian(integerLimit32, integerLimit32) - Uint64.bigEndian(newMsh, 0) + Uint64.bigEndian(0, newLsh) + Uint64.bigEndian(0, 1);
    }
    return Uint64.bigEndian(newMsh, newLsh);
  }

  const Uint64.littleEndian(int lsh, int msh) : _value = (msh, lsh);
  const Uint64.bigEndian(int msh, int lsh) : _value = (msh, lsh);
  factory Uint64.fromInt(int value) => Uint64.bigEndian(value >> 32, value & (integerLimit32 - 1));
}

String prettyPrintDuration(Uint64 duration) {
  int milliseconds = (duration % 1000).asInt;
  int seconds = ((duration / 1000) % 60).floor();
  int minutes = ((duration / (1000 * 60)) % 60).floor();
  int hours = ((duration / (1000 * 60 * 60)) % 24).floor();
  int days = (duration / (1000 * 60 * 60 * 24)).floor();
  if (days > 0) return '$days days and $hours hours';
  if (hours > 0) return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  if (minutes > 0) return '$minutes:${seconds.toString().padLeft(2, '0')}${(milliseconds / 1000).toString().substring(1)}';
  if (seconds > 0) return '$seconds${(milliseconds / 1000).toString().substring(1)} seconds';
  return '$milliseconds milliseconds';
}