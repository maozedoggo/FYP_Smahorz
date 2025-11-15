import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class WeatherService {
  int currentTemp = 0;
  int statusID = 0;
  String? weatherMain; // e.g. "Clouds", "Rain", "Clear"
  String? weatherDescription; // e.g. "overcast clouds"
  String? cityName;
  String? stateName;

  get weatherId => null;

  // Fetch city from Firestore
  Future<void> fetchData() async {
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    if (userEmail == null) return;

    final document = await FirebaseFirestore.instance
        .collection("users")
        .doc(userEmail)
        .get();

    if (document.exists) {
      stateName = document.data()?['state'];
      cityName = document.data()?['district'];
    }
  }

  // Call OpenWeather API
  Future<void> callApi() async {
    if (cityName == null) {
      throw Exception("City name is required. Call fetchCity() first.");
    }

    final url =
        "https://api.openweathermap.org/data/2.5/weather?q=$cityName,my&units=metric&appid=b9cbaf8d1d6ed70083c41adcc8a0da72";

    final uri = Uri.parse(url);
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      currentTemp = (json['main']['temp']).round();
      statusID = json['weather'][0]['id'];
      // set friendly fields
      weatherMain = (json['weather'][0]['main']?.toString());
      weatherDescription = (json['weather'][0]['description']?.toString());
    } else {
      throw Exception("Failed to load weather data: ${response.statusCode}");
    }
  }
}
