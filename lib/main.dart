import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'dart:async';

void main() {
  runApp(WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => WeatherProvider(),
      child: MaterialApp(
        title: 'Weather App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: WeatherScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

// City Model for Autocomplete
class CityModel {
  final String name;
  final String country;
  final String state;
  final double lat;
  final double lon;

  CityModel({
    required this.name,
    required this.country,
    required this.state,
    required this.lat,
    required this.lon,
  });

  factory CityModel.fromJson(Map<String, dynamic> json) {
    return CityModel(
      name: json['name'] ?? '',
      country: json['country'] ?? '',
      state: json['state'] ?? '',
      lat: (json['lat'] ?? 0).toDouble(),
      lon: (json['lon'] ?? 0).toDouble(),
    );
  }

  String get displayName {
    String display = name;
    if (state.isNotEmpty) {
      display += ', $state';
    }
    display += ', $country';
    return display;
  }
}

// Weather Model
class WeatherModel {
  final String cityName;
  final String country;
  final double temperature;
  final double feelsLike;
  final double minTemp;
  final double maxTemp;
  final String description;
  final String weatherMain;
  final int humidity;
  final int pressure;
  final double windSpeed;
  final int visibility;

  WeatherModel({
    required this.cityName,
    required this.country,
    required this.temperature,
    required this.feelsLike,
    required this.minTemp,
    required this.maxTemp,
    required this.description,
    required this.weatherMain,
    required this.humidity,
    required this.pressure,
    required this.windSpeed,
    required this.visibility,
  });

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    return WeatherModel(
      cityName: json['name'] ?? 'Unknown',
      country: json['sys']?['country'] ?? '',
      temperature: (json['main']?['temp'] ?? 0).toDouble(),
      feelsLike: (json['main']?['feels_like'] ?? 0).toDouble(),
      minTemp: (json['main']?['temp_min'] ?? 0).toDouble(),
      maxTemp: (json['main']?['temp_max'] ?? 0).toDouble(),
      description: json['weather']?[0]?['description'] ?? 'Unknown',
      weatherMain: json['weather']?[0]?['main'] ?? 'Clear',
      humidity: json['main']?['humidity'] ?? 0,
      pressure: json['main']?['pressure'] ?? 0,
      windSpeed: (json['wind']?['speed'] ?? 0).toDouble(),
      visibility: json['visibility'] ?? 0,
    );
  }
}

// Weather Provider for State Management
class WeatherProvider extends ChangeNotifier {
  WeatherModel? _weather;
  bool _isLoading = false;
  String? _errorMessage;
  List<CityModel> _citySuggestions = [];
  bool _isLoadingSuggestions = false;

  final String _apiKey = "53177d368db2f243352b93fc1eee6102";
  final String _weatherBaseUrl = "https://api.openweathermap.org/data/2.5/weather";
  final String _geocodingBaseUrl = "https://api.openweathermap.org/geo/1.0/direct";

  // Getters
  WeatherModel? get weather => _weather;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<CityModel> get citySuggestions => _citySuggestions;
  bool get isLoadingSuggestions => _isLoadingSuggestions;

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Set error message
  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Fetch city suggestions from API
  Future<void> fetchCitySuggestions(String query) async {
    if (query.trim().isEmpty) {
      _citySuggestions = [];
      notifyListeners();
      return;
    }

    if (query.length < 2) return; // Don't search for very short queries

    _isLoadingSuggestions = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$_geocodingBaseUrl?q=$query&limit=5&appid=$_apiKey'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        _citySuggestions = jsonData.map((city) => CityModel.fromJson(city)).toList();
      } else {
        _citySuggestions = [];
      }
    } catch (e) {
      _citySuggestions = [];
    } finally {
      _isLoadingSuggestions = false;
      notifyListeners();
    }
  }

  // Clear suggestions
  void clearSuggestions() {
    _citySuggestions = [];
    notifyListeners();
  }

  // Fetch weather by city model (from suggestions)
  Future<void> fetchWeatherByCity(String cityName) async {
    if (cityName.trim().isEmpty) {
      _setError('Please enter a city name');
      return;
    }

    _setLoading(true);
    _setError(null);
    clearSuggestions();

    try {
      final response = await http.get(
        Uri.parse('$_weatherBaseUrl?q=$cityName&appid=$_apiKey&units=metric'),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        _weather = WeatherModel.fromJson(jsonData);
        _setError(null);
      } else if (response.statusCode == 404) {
        _setError('City not found. Please check the spelling.');
      } else {
        _setError('Failed to load weather data. Please try again.');
      }
    } catch (e) {
      _setError('Network error. Please check your internet connection.');
    } finally {
      _setLoading(false);
    }
  }

  // Fetch weather by coordinates (from city suggestion or GPS)
  Future<void> fetchWeatherByCoordinates(double lat, double lon) async {
    _setLoading(true);
    _setError(null);
    clearSuggestions();

    try {
      final response = await http.get(
        Uri.parse('$_weatherBaseUrl?lat=$lat&lon=$lon&appid=$_apiKey&units=metric'),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        _weather = WeatherModel.fromJson(jsonData);
        _setError(null);
      } else {
        _setError('Failed to load weather data. Please try again.');
      }
    } catch (e) {
      _setError('Network error. Please check your internet connection.');
    } finally {
      _setLoading(false);
    }
  }

  // Fetch weather by GPS location
  Future<void> fetchWeatherByLocation() async {
    _setLoading(true);
    _setError(null);
    clearSuggestions();

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable them.');
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions denied. Please allow location access.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions permanently denied. Please enable them in settings.');
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      // Fetch weather data using coordinates
      await fetchWeatherByCoordinates(position.latitude, position.longitude);
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
    }
  }

  // Initialize with current location
  Future<void> initializeWithLocation() async {
    await fetchWeatherByLocation();
  }
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  _WeatherScreenState createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final TextEditingController _cityController = TextEditingController();
  Timer? _debounceTimer;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    // Initialize with current location when app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WeatherProvider>().initializeWithLocation();
    });
  }

  // Debounced search for city suggestions
  void _onSearchChanged(String query) {
    setState(() {
      _showSuggestions = query.isNotEmpty;
    });

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    _debounceTimer = Timer(Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        context.read<WeatherProvider>().fetchCitySuggestions(query);
      }
    });
  }

  // Handle city selection from suggestions
  void _selectCity(CityModel city) {
    _cityController.text = city.name;
    setState(() {
      _showSuggestions = false;
    });
    context.read<WeatherProvider>().fetchWeatherByCoordinates(city.lat, city.lon);
  }

  // Get weather icon based on weather condition
  IconData _getWeatherIcon(String weatherMain) {
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
    return Consumer<WeatherProvider>(
      builder: (context, weatherProvider, child) {
        List<Color> gradientColors = _getBackgroundGradient(
            weatherProvider.weather?.weatherMain);

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
                    // Search Section with Autocomplete
                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            // Search TextField with Autocomplete
                            TextField(
                              controller: _cityController,
                              decoration: InputDecoration(
                                hintText: 'Enter city name',
                                prefixIcon: Icon(Icons.search),
                                suffixIcon: _cityController.text.isNotEmpty
                                    ? IconButton(
                                  icon: Icon(Icons.clear),
                                  onPressed: () {
                                    _cityController.clear();
                                    setState(() {
                                      _showSuggestions = false;
                                    });
                                    weatherProvider.clearSuggestions();
                                  },
                                )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                              ),
                              onChanged: _onSearchChanged,
                              onSubmitted: (value) {
                                setState(() {
                                  _showSuggestions = false;
                                });
                                weatherProvider.fetchWeatherByCity(value);
                              },
                            ),

                            // City Suggestions Dropdown
                            if (_showSuggestions && weatherProvider.citySuggestions.isNotEmpty)
                              Container(
                                margin: EdgeInsets.only(top: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade300),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                constraints: BoxConstraints(maxHeight: 200),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: weatherProvider.citySuggestions.length,
                                  itemBuilder: (context, index) {
                                    final city = weatherProvider.citySuggestions[index];
                                    return ListTile(
                                      leading: Icon(
                                        Icons.location_on,
                                        color: Colors.blue,
                                        size: 20,
                                      ),
                                      title: Text(
                                        city.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${city.state.isNotEmpty ? '${city.state}, ' : ''}${city.country}',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      onTap: () => _selectCity(city),
                                      dense: true,
                                    );
                                  },
                                ),
                              ),

                            // Loading indicator for suggestions
                            if (_showSuggestions && weatherProvider.isLoadingSuggestions)
                              Container(
                                margin: EdgeInsets.only(top: 8),
                                padding: EdgeInsets.all(16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Searching cities...'),
                                  ],
                                ),
                              ),

                            SizedBox(height: 16),

                            // Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: weatherProvider.isLoading
                                        ? null
                                        : () {
                                      setState(() {
                                        _showSuggestions = false;
                                      });
                                      weatherProvider.fetchWeatherByCity(_cityController.text);
                                    },
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
                                  onPressed: weatherProvider.isLoading
                                      ? null
                                      : () {
                                    setState(() {
                                      _showSuggestions = false;
                                    });
                                    weatherProvider.fetchWeatherByLocation();
                                  },
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
                      child: weatherProvider.isLoading
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
                          : weatherProvider.errorMessage != null
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
                                  weatherProvider.errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 16),
                                ),
                                SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () => weatherProvider.clearError(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text('Try Again'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                          : weatherProvider.weather != null
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
                                  weatherProvider.weather!.cityName,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                Text(
                                  weatherProvider.weather!.country,
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
                                      _getWeatherIcon(weatherProvider.weather!.weatherMain),
                                      size: 80,
                                      color: Colors.orange,
                                    ),
                                    SizedBox(width: 20),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${weatherProvider.weather!.temperature.round()}°C',
                                          style: TextStyle(
                                            fontSize: 48,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                        Text(
                                          'Feels like ${weatherProvider.weather!.feelsLike.round()}°C',
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
                                  weatherProvider.weather!.description.toUpperCase(),
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
                                            '${weatherProvider.weather!.minTemp.round()}°C',
                                          ),
                                          _buildWeatherDetail(
                                            Icons.thermostat,
                                            'Max Temp',
                                            '${weatherProvider.weather!.maxTemp.round()}°C',
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
                                            '${weatherProvider.weather!.humidity}%',
                                          ),
                                          _buildWeatherDetail(
                                            Icons.speed,
                                            'Pressure',
                                            '${weatherProvider.weather!.pressure} hPa',
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
                                            '${weatherProvider.weather!.windSpeed} m/s',
                                          ),
                                          _buildWeatherDetail(
                                            Icons.visibility,
                                            'Visibility',
                                            '${(weatherProvider.weather!.visibility / 1000).toStringAsFixed(1)} km',
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
      },
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
    _debounceTimer?.cancel();
    super.dispose();
  }
}