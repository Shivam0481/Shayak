import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class DirectionsService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';

  Future<DirectionsInfo?> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) return null;

    final url =
        '$_baseUrl?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if ((data['routes'] as List).isEmpty) return null;

        final route = data['routes'][0];
        final leg = route['legs'][0];

        final distance = leg['distance']['text'] as String;
        final duration = leg['duration']['text'] as String;
        final points = _decodePolyline(route['overview_polyline']['points']);

        return DirectionsInfo(
          distance: distance,
          duration: duration,
          polylinePoints: points,
        );
      }
    } catch (e) {
      print('Error fetching directions: $e');
    }
    return null;
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }
}

class DirectionsInfo {
  final String distance;
  final String duration;
  final List<LatLng> polylinePoints;

  DirectionsInfo({
    required this.distance,
    required this.duration,
    required this.polylinePoints,
  });
}
