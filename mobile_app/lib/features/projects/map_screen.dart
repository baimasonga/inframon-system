import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Projects & Issues')),
      body: FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(34.0522, -118.2437),
          initialZoom: 13.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.inframon',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: const LatLng(34.0522, -118.2437),
                width: 80,
                height: 80,
                child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
              ),
              Marker(
                point: const LatLng(34.0400, -118.2500),
                width: 80,
                height: 80,
                child: const Icon(Icons.location_on, color: Colors.grey, size: 40),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
