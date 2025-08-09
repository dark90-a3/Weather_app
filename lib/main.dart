import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: WeatherScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  _WeatherScreenState createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final TextEditingController _cityController = TextEditingController();
  Map<String, dynamic>? weatherData;
  bool isLoading = false;
  String? errorMessage;

  // OpenWeatherMap API key - Replace with your actual API key
  final String apiKey = "53177d368db2f243352b93fc1eee6102";
  final String baseUrl = "https://api.openweathermap.org/data/2.5/weather";

  @override
  void initState() {
    super.initState();
    _getCurrentLocationWeather();
  }

  // Get weather using device location (GPS)
  Future<void> _getCurrentLocationWeather() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

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

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      await _fetchWeatherByCoordinates(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  // Fetch weather data by coordinates
  Future<void> _fetchWeatherByCoordinates(double lat, double lon) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?lat=$lat&lon=$lon&appid=$apiKey&units=metric'),
      );

      if (response.statusCode == 200) {
        setState(() {
          weatherData = json.decode(response.body);
          isLoading = false;
          errorMessage = null;
        });
      } else {
        throw Exception('Failed to load weather data');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching weather data: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  // Fetch weather data by city name
  Future<void> _fetchWeatherByCity(String cityName) async {
    if (cityName.trim().isEmpty) {
      setState(() {
        errorMessage = 'Please enter a city name';
      });
      return;
    }

    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final response = await http.get(
        Uri.parse('$baseUrl?q=$cityName&appid=$apiKey&units=metric'),
      );

      if (response.statusCode == 200) {
        setState(() {
          weatherData = json.decode(response.body);
          isLoading = false;
          errorMessage = null;
        });
      } else if (response.statusCode == 404) {
        setState(() {
          errorMessage = 'City not found. Please check the spelling.';
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load weather data');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching weather data: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  // Get weather icon based on weather condition
  IconData _getWeatherIcon(String? weatherMain) {
    if (weatherMain == null) return Icons.wb_sunny;

    switch (weatherMain.toLowerCase()) {
      case 'clear':
        return Icons.wb_sunny;
      case 'clouds':
        return Icons.wb_cloudy;
      case 'rain':
        return Icons.umbrella;
      case 'drizzle':
        return Icons.grain;
      case 'thunderstorm':
        return Icons.flash_on;
      case 'snow':
        return Icons.ac_unit;
      case 'mist':
      case 'fog':
      case 'haze':
        return Icons.blur_on;
      default:
        return Icons.wb_sunny;
    }
  }

  // Get background gradient based on weather
  List<Color> _getBackgroundGradient(String? weatherMain) {
    if (weatherMain == null) {
      return [Colors.blue.shade400, Colors.blue.shade600];
    }

    switch (weatherMain.toLowerCase()) {
      case 'clear':
        return [Colors.orange.shade300, Colors.blue.shade400];
      case 'clouds':
        return [Colors.grey.shade400, Colors.grey.shade600];
      case 'rain':
      case 'drizzle':
        return [Colors.indigo.shade400, Colors.blue.shade700];
      case 'thunderstorm':
        return [Colors.purple.shade400, Colors.indigo.shade700];
      case 'snow':
        return [Colors.lightBlue.shade200, Colors.blue.shade400];
      default:
        return [Colors.blue.shade400, Colors.blue.shade600];
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Color> gradientColors = _getBackgroundGradient(
        weatherData?['weather']?[0]?['main']);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Search Section
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _cityController,
                          decoration: InputDecoration(
                            hintText: 'Enter city name',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                          ),
                          onSubmitted: (value) => _fetchWeatherByCity(value),
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _fetchWeatherByCity(_cityController.text),
                                icon: Icon(Icons.search),
                                label: Text('Search Weather'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _getCurrentLocationWeather,
                              icon: Icon(Icons.my_location),
                              label: Text('GPS'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 20),

                // Weather Display Section
                Expanded(
                  child: isLoading
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Loading weather data...',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                      : errorMessage != null
                      ? Center(
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Error',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                      : weatherData != null
                      ? SingleChildScrollView(
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            // City Name
                            Text(
                              weatherData!['name'] ?? 'Unknown',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            Text(
                              weatherData!['sys']?['country'] ?? '',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),

                            SizedBox(height: 20),

                            // Weather Icon and Temperature
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _getWeatherIcon(weatherData!['weather']?[0]?['main']),
                                  size: 80,
                                  color: Colors.orange,
                                ),
                                SizedBox(width: 20),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${weatherData!['main']?['temp']?.round() ?? 0}°C',
                                      style: TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    Text(
                                      'Feels like ${weatherData!['main']?['feels_like']?.round() ?? 0}°C',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            SizedBox(height: 16),

                            // Weather Description
                            Text(
                              weatherData!['weather']?[0]?['description']?.toString().toUpperCase() ?? 'UNKNOWN',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                                letterSpacing: 1.2,
                              ),
                            ),

                            SizedBox(height: 30),

                            // Weather Details Grid
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildWeatherDetail(
                                        Icons.thermostat,
                                        'Min Temp',
                                        '${weatherData!['main']?['temp_min']?.round() ?? 0}°C',
                                      ),
                                      _buildWeatherDetail(
                                        Icons.thermostat,
                                        'Max Temp',
                                        '${weatherData!['main']?['temp_max']?.round() ?? 0}°C',
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildWeatherDetail(
                                        Icons.water_drop,
                                        'Humidity',
                                        '${weatherData!['main']?['humidity'] ?? 0}%',
                                      ),
                                      _buildWeatherDetail(
                                        Icons.speed,
                                        'Pressure',
                                        '${weatherData!['main']?['pressure'] ?? 0} hPa',
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildWeatherDetail(
                                        Icons.air,
                                        'Wind Speed',
                                        '${weatherData!['wind']?['speed'] ?? 0} m/s',
                                      ),
                                      _buildWeatherDetail(
                                        Icons.visibility,
                                        'Visibility',
                                        '${((weatherData!['visibility'] ?? 0) / 1000).toStringAsFixed(1)} km',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                      : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.wb_sunny,
                          size: 80,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Welcome to Weather App',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Search for a city or use GPS to get weather info',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherDetail(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(
          icon,
          size: 24,
          color: Colors.blue,
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }
}