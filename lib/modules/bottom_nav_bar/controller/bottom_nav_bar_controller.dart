// lib/modules/bottom_nav_bar/controller/bottom_nav_bar_controller.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BottomNavBarController extends ChangeNotifier {
  int _selectedIndex = 0;

  int get selectedIndex => _selectedIndex;

  void setSelectedIndex(int index) {
    if (_selectedIndex != index) {
      _selectedIndex = index;
      notifyListeners();
      _updateWebUrl(index);
    }
  }

  void _updateWebUrl(int index) {
    String path = '/dashboard';
    switch (index) {
      case 0:
        path = '/dashboard';
        break;
      case 1:
        path = '/leave';
        break;
      case 2:
        path = '/tour';
        break;
      case 3:
        path = '/profile';
        break;
      case 4:
        path = '/directory';
        break;
      case 5:
        path = '/payslips';
        break;
      case 6:
        path = '/holidays';
        break;
      case 7:
        path = '/approvals';
        break;
    }
    SystemNavigator.routeInformationUpdated(location: path);
  }

  void reset() {
    _selectedIndex = 0;
    notifyListeners();
  }
}
