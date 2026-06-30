// lib/modules/tour/controller/tour_controller.dart

import 'package:flutter/material.dart';
import '../../../model/tour_model.dart';

enum TourStatus { initial, loading, loaded, error }

class TourController extends ChangeNotifier {
  TourStatus _status = TourStatus.initial;
  List<TourModel> _tours = [];
  String? _errorMessage;

  TourStatus get status => _status;
  List<TourModel> get tours => _tours;
  String? get errorMessage => _errorMessage;

  Future<void> fetchTours(String employeeId) async {
    _status = TourStatus.loading;
    notifyListeners();

    try {
      await Future.delayed(const Duration(milliseconds: 600));

      _tours = [
        TourModel(
          id: '1',
          employeeId: employeeId,
          tourType: 'Official Tour',
          destination: 'hyderabad',
          startDate: DateTime(2026, 5, 7),
          endDate: DateTime(2026, 5, 10),
          travelPurpose: 'To attend ST Commission Officials',
          transportMode: 'Train',
          status: 'Approved',
          appliedOn: DateTime(2026, 5, 4),
        ),
        TourModel(
          id: '2',
          employeeId: employeeId,
          tourType: 'Official Tour',
          destination: 'New Delhi',
          startDate: DateTime(2026, 5, 11),
          endDate: DateTime(2026, 5, 11),
          travelPurpose: 'To attend Sitting of ST Commission',
          transportMode: 'Flight',
          status: 'Approved',
          appliedOn: DateTime(2026, 5, 8),
        ),
        TourModel(
          id: '3',
          employeeId: employeeId,
          tourType: 'Official Tour',
          destination: 'hyderabad',
          startDate: DateTime(2026, 4, 1),
          endDate: DateTime(2026, 4, 4),
          travelPurpose: 'As a Venue Officer for online test conducted by IBPS',
          transportMode: 'Train',
          status: 'Approved',
          appliedOn: DateTime(2026, 3, 28),
        ),
        TourModel(
          id: '4',
          employeeId: employeeId,
          tourType: 'Official Tour',
          destination: 'hyderabad',
          startDate: DateTime(2026, 1, 27),
          endDate: DateTime(2026, 1, 29),
          travelPurpose: 'To attend ST Commission Officials',
          transportMode: 'Train',
          status: 'Approved',
          appliedOn: DateTime(2026, 1, 24),
        ),
        TourModel(
          id: '5',
          employeeId: employeeId,
          tourType: 'Official Tour',
          destination: 'New Delhi',
          startDate: DateTime(2026, 1, 20),
          endDate: DateTime(2026, 1, 21),
          travelPurpose: 'To attend Sitting of ST Commission',
          transportMode: 'Flight',
          status: 'Approved',
          appliedOn: DateTime(2026, 1, 17),
        ),
        TourModel(
          id: '6',
          employeeId: employeeId,
          tourType: 'Official Tour',
          destination: 'New Delhi, Hyderabad',
          startDate: DateTime(2025, 12, 17),
          endDate: DateTime(2025, 12, 21),
          travelPurpose: 'Baoard Meeting & Statutory Exam',
          transportMode: 'Flight',
          status: 'Approved',
          appliedOn: DateTime(2025, 12, 14),
        ),
        TourModel(
          id: '7',
          employeeId: employeeId,
          tourType: 'Official Tour',
          destination: 'Pachmarhi MP',
          startDate: DateTime(2025, 11, 2),
          endDate: DateTime(2025, 11, 3),
          travelPurpose: 'SC ST Parliamentry committee Meeting.',
          transportMode: 'Bus',
          status: 'Approved',
          appliedOn: DateTime(2025, 10, 30),
        ),
      ];

      _status = TourStatus.loaded;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to fetch tour data.';
      _status = TourStatus.error;
      notifyListeners();
    }
  }

  Future<bool> applyTour(TourModel tour) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      final index = _tours.indexWhere((t) => t.id == tour.id);
      if (index != -1) {
        _tours[index] = tour;
      } else {
        _tours.insert(0, tour);
      }
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteTour(String tourId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      _tours.removeWhere((t) => t.id == tourId);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> approveTour(String tourId, String remarks) async {
    try {
      await Future.delayed(const Duration(seconds: 1));
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> rejectTour(String tourId, String remarks) async {
    try {
      await Future.delayed(const Duration(seconds: 1));
      return true;
    } catch (e) {
      return false;
    }
  }
}
