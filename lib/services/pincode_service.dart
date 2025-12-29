import 'package:dio/dio.dart';

class PincodeService {
  final Dio _dio = Dio();

  Future<Map<String, String>?> getCityStateFromPincode(String pincode) async {
    if (pincode.length != 6) return null;

    try {
      final response = await _dio.get(
        'https://api.postalpincode.in/pincode/$pincode',
      );

      if (response.statusCode == 200 &&
          response.data is List &&
          response.data.isNotEmpty) {
        final data = response.data[0];
        if (data['Status'] == 'Success' &&
            data['PostOffice'] != null &&
            data['PostOffice'].isNotEmpty) {
          final postOffice = data['PostOffice'][0];
          return {
            'city': postOffice['District'] ?? '',
            'state': postOffice['State'] ?? '',
          };
        }
      }
    } catch (e) {
      print('Error fetching pincode data: $e');
    }
    return null;
  }
}
