import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme.dart';

class MapViewerScreen extends StatelessWidget {
  final double lat;
  final double lng;
  final String title;
  final String subtitle;

  const MapViewerScreen({
    super.key,
    required this.lat,
    required this.lng,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: TwibeeAppBar(
        title: title,
        subtitle: subtitle.isNotEmpty ? subtitle : null,
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(lat, lng),
          zoom: 16,
        ),
        markers: {
          Marker(
            markerId: const MarkerId('location'),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(title: title, snippet: subtitle),
          )
        },
        myLocationButtonEnabled: true,
        myLocationEnabled: true,
      ),
    );
  }
}

