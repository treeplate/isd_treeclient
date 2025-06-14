class Offset {
  operator /(double other) => this;
  Offset(double x, double y);
}
mixin ChangeNotifier {
  void notifyListeners() {}
}