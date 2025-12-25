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
  double toDouble() => (msh.toDouble() * integerLimit32) + lsh;
  int toInt() => ((msh * integerLimit32) + lsh);

  int compareTo(Uint64 other) {
    int mshc = msh.compareTo(other.msh);
    if (mshc != 0) return mshc;
    return lsh.compareTo(other.lsh);
  }

  Uint64 operator *(int multiplier) {
    return Uint64.bigEndian(
        ((msh * multiplier) + ((lsh * multiplier) ~/ integerLimit32)) &
            (integerLimit32 - 1),
        (lsh * multiplier) & (integerLimit32 - 1));
  }

  Uint64 operator ~/(double divisor) {
    int newLsh = lsh ~/ divisor;
    double newMsh = msh / divisor;
    newLsh += ((newMsh % 1) * integerLimit32).floor();
    return Uint64.bigEndian(newMsh.floor(), newLsh);
  }

  double operator /(num divisor) {
    return toDouble() / divisor;
  }

  Uint64 operator %(int divisor) {
    int carry = msh % divisor;
    return Uint64.fromInt((lsh + (carry * integerLimit32)) % divisor);
  }

  Uint64 operator +(Uint64 addend) {
    int lshResult = lsh + addend.lsh;
    return Uint64.bigEndian(
        (msh + addend.msh + (lshResult ~/ integerLimit32)) &
            (integerLimit32 - 1),
        lshResult & (integerLimit32 - 1));
  }

  Uint64 operator -(Uint64 addend) {
    int newLsh = lsh - addend.lsh;
    int newMsh = msh - addend.msh;
    if (newLsh < 0) {
      newMsh--;
      newLsh += integerLimit32;
    }
    return Uint64.bigEndian(newMsh % integerLimit32, newLsh);
  }

  const Uint64.littleEndian(int lsh, int msh) : _value = (msh, lsh);
  const Uint64.bigEndian(int msh, int lsh) : _value = (msh, lsh);
  factory Uint64.fromInt(int value) {
    return Uint64.bigEndian(
        (value ~/ integerLimit32) % integerLimit32, value % integerLimit32);
  }
  factory Uint64.fromDouble(double value) {
    return Uint64.bigEndian(
      ((value / integerLimit32) % integerLimit32).floor(),
      (value % integerLimit32).floor(),
    );
  }

  factory Uint64.parse(String str) {
    Uint64 result = zero64;
    for (int digit in str.codeUnits) {
      result += Uint64.fromInt(digit - 0x30);
      result *= 10;
    }
    return result ~/ 10;
  }

  bool operator <(Uint64 other) {
    return msh < other.msh || msh == other.msh && lsh < other.lsh;
  }
}
const Uint64 zero64 = Uint64.bigEndian(0, 0);

// uses SI units
String prettyPrintDuration(Uint64 durationInMilliseconds) {
  int milliseconds = (durationInMilliseconds % 1000).toInt();
  int seconds = ((durationInMilliseconds / 1000) % 60).floor();
  int minutes = ((durationInMilliseconds / (1000 * 60)) % 60).floor();
  int hours = ((durationInMilliseconds / (1000 * 60 * 60)) % 24).floor();
  int days = (durationInMilliseconds / (1000 * 60 * 60 * 24)).floor();
  if (days > 0) return '$days days and $hours hours';
  if (hours > 0)
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  if (minutes > 0)
    return '$minutes:${seconds.toString().padLeft(2, '0')}${(milliseconds / 1000).toString().substring(1)}';
  if (seconds > 0)
    return '$seconds${(milliseconds / 1000).toString().substring(1)} seconds';
  return '$milliseconds milliseconds';
}
