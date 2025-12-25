import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationPickerScreen({super.key, this.initialLocation});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _pickedLocation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pickedLocation = widget.initialLocation;
    if (_pickedLocation == null) {
      _determinePosition();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled.')),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location permissions are permanently denied, we cannot request permissions.',
          ),
        ),
      );
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _pickedLocation = LatLng(position.latitude, position.longitude);
      _isLoading = false;
    });

    _mapController?.animateCamera(CameraUpdate.newLatLng(_pickedLocation!));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Delivery Location'),
        actions: [
          if (_pickedLocation != null)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () {
                Navigator.pop(context, _pickedLocation);
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _pickedLocation ?? const LatLng(0, 0),
                    zoom: 15,
                  ),
                  onMapCreated: (controller) => _mapController = controller,
                  onCameraMove: (position) {
                    _pickedLocation = position.target;
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
                const Center(
                  child: Icon(Icons.location_on, size: 40, color: Colors.red),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, _pickedLocation);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Confirm Location'),
                  ),
                ),
              ],
            ),
    );
  }
}
