import 'dart:math';
import '../entities/rescue_request.dart';

class PriorityCalculator {
  // Weights can be adjusted based on needs
  static const double urgencyWeight = 0.5;
  static const double distanceWeight = 0.3;
  static const double scarcityWeight = 0.2;

  static double calculateScore({
    required double urgency, // 1-10
    required double distanceInKm,
    required double resourceScarcity, // 0-1 (1 being most scarce)
  }) {
    // Normalize distance (assuming max relevant distance is 50km for normalization)
    double normalizedDistance = 1 - (min(distanceInKm, 50.0) / 50.0);

    // Normalize urgency (1-10 -> 0-1)
    double normalizedUrgency = (urgency - 1) / 9.0;

    return (normalizedUrgency * urgencyWeight) +
           (normalizedDistance * distanceWeight) +
           (resourceScarcity * scarcityWeight);
  }

  static double getDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) *
            (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }
}
