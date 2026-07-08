import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../theme.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  bool _isLoading = true;
  Position? _currentPosition;
  LatLng? _selectedLocation;
  String? _currentAddress;
  GoogleMapController? _mapController;
  List<dynamic> _nearbyPlaces = [];
  bool _isFetchingPlaces = false;

  IconData _getIconForType(List<dynamic>? types) {
    if (types == null || types.isEmpty) return Icons.place;
    final type = types.first.toString().toLowerCase();
    if (type.contains('restaurant') || type.contains('food') || type.contains('cafe')) return Icons.restaurant;
    if (type.contains('hospital') || type.contains('health')) return Icons.local_hospital;
    if (type.contains('atm') || type.contains('bank')) return Icons.local_atm;
    if (type.contains('gas_station') || type.contains('fuel')) return Icons.local_gas_station;
    if (type.contains('school') || type.contains('university')) return Icons.school;
    if (type.contains('store') || type.contains('shop') || type.contains('mall')) return Icons.store;
    if (type.contains('gym') || type.contains('health')) return Icons.fitness_center;
    return Icons.place;
  }

  final String _googleMapsApiKey = "AIzaSyAW9l676qV0YaiOCAxWFLOIoV5UIMEcUQw";

  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(28.6139, 77.2090),
    zoom: 15.0,
  );

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _isLoading = false);
      return;
    } 

    _currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
    if (_currentPosition != null) {
      _selectedLocation = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      if (_mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(_selectedLocation!, 16));
      }
      _fetchNearbyAndAddress(_selectedLocation!);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchNearbyAndAddress(LatLng location) async {
    if (!mounted) return;
    setState(() {
      _isFetchingPlaces = true;
    });

    final lat = location.latitude;
    final lng = location.longitude;
    final url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&radius=10000&key=$_googleMapsApiKey';

    bool googleSuccess = false;

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
          googleSuccess = true;
          if (mounted) {
            setState(() {
              _nearbyPlaces = data['results'].take(25).toList();
              // Try to get address from the first place
              _currentAddress = _nearbyPlaces.first['vicinity'];
              _isFetchingPlaces = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching Google places: $e");
    }

    // Fallback to OpenStreetMap (Nominatim & Overpass) if Google API is restricted
    if (!googleSuccess) {
      try {
        // 1. Get Address from Nominatim
        final osmUrl = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1';
        final osmResponse = await http.get(Uri.parse(osmUrl), headers: {'User-Agent': 'TwibeeChatApp/1.0'}).timeout(const Duration(seconds: 8));
        if (osmResponse.statusCode == 200) {
          final data = json.decode(osmResponse.body);
          if (mounted) {
            setState(() {
              _currentAddress = data['display_name'];
            });
          }
        }

        // 2. Get Nearby Places from Overpass - broader query for any named place
        final overpassQuery = '[out:json][timeout:10];(node(around:5000,$lat,$lng)[name];way(around:5000,$lat,$lng)[name][building!~"yes"];);out center 30;';
        final overpassUrl = 'https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(overpassQuery)}';
        final overpassResponse = await http.get(Uri.parse(overpassUrl)).timeout(const Duration(seconds: 12));
        if (overpassResponse.statusCode == 200) {
          final data = json.decode(overpassResponse.body);
          final elements = data['elements'] as List<dynamic>? ?? [];

          final mappedPlaces = elements
              .where((e) => e['tags'] != null && e['tags']['name'] != null)
              .map((e) {
            final tags = e['tags'];
            final elat = e['lat'] ?? e['center']?['lat'];
            final elng = e['lon'] ?? e['center']?['lon'];
            final amenityType = tags['amenity'] ?? tags['shop'] ?? tags['tourism'] ?? tags['leisure'] ?? 'place';
            return {
              'name': tags['name'],
              'vicinity': tags['addr:street'] ?? tags['addr:suburb'] ?? amenityType,
              'types': [amenityType],
              'geometry': {
                'location': {'lat': elat, 'lng': elng}
              }
            };
          }).toList();

          if (mounted) {
            setState(() {
              _nearbyPlaces = mappedPlaces.take(25).toList();
              _isFetchingPlaces = false;
            });
          }
        } else {
          if (mounted) setState(() => _isFetchingPlaces = false);
        }
      } catch (e) {
        debugPrint("Error fetching OSM fallback: $e");
        if (mounted) setState(() => _isFetchingPlaces = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: const TwibeeAppBar(title: 'Send location'),
      body: Column(
        children: [
          // Interactive Map Area
          Container(
            height: MediaQuery.of(context).size.height * 0.45,
            width: double.infinity,
            decoration: const BoxDecoration(color: AppColors.lightGrey),
            child: Stack(
              alignment: Alignment.center,
              children: [
                GoogleMap(
                  initialCameraPosition: _currentPosition != null
                      ? CameraPosition(target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude), zoom: 16)
                      : _initialCamera,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                  onMapCreated: (controller) => _mapController = controller,
                  onCameraMove: (position) {
                    _selectedLocation = position.target;
                  },
                  onCameraIdle: () {
                    if (_selectedLocation != null) {
                      _fetchNearbyAndAddress(_selectedLocation!);
                    }
                  },
                ),
                if (_isLoading)
                  const CircularProgressIndicator(color: AppColors.orange)
                else ...[
                  // Center Marker Pin
                  const Padding(
                    padding: EdgeInsets.only(bottom: 35), // Offset for pin tip
                    child: Icon(Icons.location_on, size: 50, color: AppColors.orange),
                  ),
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton(
                      backgroundColor: AppColors.white,
                      mini: true,
                      elevation: 4,
                      onPressed: () {
                        if (_currentPosition != null && _mapController != null) {
                          final latLng = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
                          _mapController!.animateCamera(CameraUpdate.newLatLng(latLng));
                          _selectedLocation = latLng;
                          _fetchNearbyAndAddress(latLng);
                        }
                      },
                      child: const Icon(Icons.my_location, color: AppColors.orange),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Actions Area
          Expanded(
            child: Container(
              color: AppColors.white,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.green,
                      radius: 22,
                      child: Icon(Icons.cell_tower, color: AppColors.white, size: 24),
                    ),
                    title: const Text('Share My Live Location for...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.dark)),
                    subtitle: const Text('Updated in real time as you move', style: TextStyle(color: AppColors.grey, fontSize: 13)),
                    onTap: () {
                      if (_currentPosition != null) {
                        Navigator.pop(context, 'live_location:${_currentPosition!.latitude},${_currentPosition!.longitude}');
                      } else {
                        Navigator.pop(context, 'live_location');
                      }
                    },
                  ),
                  const Divider(height: 1, indent: 70),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.blue,
                      radius: 22,
                      child: Icon(Icons.person_pin_circle, color: AppColors.white, size: 24),
                    ),
                    title: const Text('Send My Current Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.dark)),
                    subtitle: _isFetchingPlaces 
                      ? const Text('Fetching address...', style: TextStyle(color: AppColors.grey))
                      : Text(
                          _currentAddress ?? (_selectedLocation != null 
                              ? 'Lat: ${_selectedLocation!.latitude.toStringAsFixed(4)}, Lng: ${_selectedLocation!.longitude.toStringAsFixed(4)}'
                              : 'Accurate to 15 meters'),
                          style: const TextStyle(color: AppColors.grey),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    onTap: () {
                      if (_selectedLocation != null) {
                        String finalLoc = _currentAddress ?? 'Selected Location';
                        finalLoc += '\nhttps://maps.google.com/?q=${_selectedLocation!.latitude},${_selectedLocation!.longitude}';
                        Navigator.pop(context, finalLoc);
                      } else {
                        Navigator.pop(context, 'current_location');
                      }
                    },
                  ),
                  const Divider(height: 1, indent: 70),
                  if (_nearbyPlaces.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text('OR CHOOSE A PLACE', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.grey, fontSize: 13, letterSpacing: 0.5)),
                    ),
                  ..._nearbyPlaces.map((place) {
                    final types = place['types'] as List<dynamic>?;
                    final iconData = _getIconForType(types);
                    final name = place['name'] ?? 'Unknown Place';
                    final vicinity = place['vicinity'] ?? '';
                    final lat = place['geometry']?['location']?['lat'];
                    final lng = place['geometry']?['location']?['lng'];
                    
                    return ListTile(
                      leading: CircleAvatar(backgroundColor: AppColors.orange, radius: 22, child: Icon(iconData, color: Colors.white, size: 22)),
                      title: Text(name, style: const TextStyle(color: AppColors.dark, fontWeight: FontWeight.bold, fontSize: 15)),
                      subtitle: Text(vicinity, style: const TextStyle(color: AppColors.grey, fontSize: 13)),
                      onTap: () {
                        String finalLoc = 'place:$name\n$vicinity';
                        if (lat != null && lng != null) {
                          finalLoc += '\nhttps://maps.google.com/?q=$lat,$lng';
                        }
                        Navigator.pop(context, finalLoc);
                      },
                    );
                  }),
                  if (_nearbyPlaces.isEmpty && !_isLoading && !_isFetchingPlaces)
                    const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          'Move the map to discover places,\nor send the selected point directly.', 
                          style: TextStyle(color: AppColors.grey),
                          textAlign: TextAlign.center,
                        )
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

