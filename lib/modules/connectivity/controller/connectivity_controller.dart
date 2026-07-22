// lib/modules/connectivity/controller/connectivity_controller.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityController extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  bool _isConnected = true;
  bool _isChecking = false;

  ConnectivityController() {
    _initConnectivity();
    _subscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
      onError: (e) {
        debugPrint("Connectivity Stream Error: $e");
      },
    );
  }

  bool get isConnected => _isConnected;
  bool get isChecking => _isChecking;

  Future<void> _initConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateConnectionStatus(results);
    } catch (e) {
      debugPrint("Connectivity Init Error: $e");
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    // In connectivity_plus v6.x, check if we have any active connection.
    // If the list is empty or only contains ConnectivityResult.none, we are offline.
    final hasConnection = results.isNotEmpty && !results.contains(ConnectivityResult.none);
    if (_isConnected != hasConnection) {
      _isConnected = hasConnection;
      notifyListeners();
    }
  }

  Future<bool> forceCheck() async {
    if (_isChecking) return _isConnected;
    _isChecking = true;
    notifyListeners();

    // Give a short delay to simulate network call / make it feel responsive
    await Future.delayed(const Duration(milliseconds: 600));

    try {
      final results = await _connectivity.checkConnectivity();
      _updateConnectionStatus(results);
    } catch (e) {
      debugPrint("Connectivity ForceCheck Error: $e");
    } finally {
      _isChecking = false;
      notifyListeners();
    }
    return _isConnected;
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
