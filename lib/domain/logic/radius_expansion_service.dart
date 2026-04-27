import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/rescue_request.dart';

class RadiusExpansionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<double> _radiusSteps = [2.0, 5.0, 10.0, 25.0];
  final Duration _stepDuration = const Duration(minutes: 5);

  /// Starts expanding the radius for a given request.
  /// If no volunteer responds within [_stepDuration], it bumps the radius.
  /// It stops if the status is no longer 'pending' or max radius is reached.
  void startRadiusExpansion(String requestId) {
    int currentStep = 0;

    Timer.periodic(_stepDuration, (timer) async {
      try {
        final doc = await _firestore.collection('requests').doc(requestId).get();
        if (!doc.exists) {
          timer.cancel();
          return;
        }

        final statusStr = doc.data()?['status'] ?? 'pending';
        final status = RequestStatus.values.byName(statusStr);

        if (status != RequestStatus.pending) {
          // A volunteer has responded or it's cancelled
          timer.cancel();
          return;
        }

        currentStep++;
        if (currentStep >= _radiusSteps.length) {
          // Reached max radius
          timer.cancel();
          return;
        }

        final newRadius = _radiusSteps[currentStep];
        await _firestore.collection('requests').doc(requestId).update({
          'searchRadiusKm': newRadius,
        });
      } catch (e) {
        print('Error in radius expansion loop: $e');
        timer.cancel();
      }
    });
  }
}
