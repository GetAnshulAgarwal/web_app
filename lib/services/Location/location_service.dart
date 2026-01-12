import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  static Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  static Future<List<Placemark>> reverseGeocode(
      double latitude,
      double longitude,
      ) async {
    return await placemarkFromCoordinates(latitude, longitude);
  }

  static Future<List<Location>> geocodeFromPincode(String pincode) async {
    return await locationFromAddress(pincode);
  }

  // Calculate distance between two points
  static double calculateDistance(
      double lat1, double lon1, double lat2, double lon2
      ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  // Get formatted address from coordinates
  static Future<String> getFormattedAddress(
      double latitude, double longitude
      ) async {
    try {
      List<Placemark> placemarks = await reverseGeocode(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return '${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}';
      }
    } catch (e) {
      print('Error getting address: $e');
    }
    return 'Unknown Location';
  }
}