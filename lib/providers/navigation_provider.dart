import 'package:flutter/material.dart';

class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  void setIndex(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  void switchToHome() => setIndex(0);
  void switchToSearch() => setIndex(1);
  void switchToLibrary() => setIndex(2);
  void switchToSettings() => setIndex(3);
}
