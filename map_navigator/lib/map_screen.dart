import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  LatLng? _currentPosition;
  LatLng? _startPosition;
  LatLng? _endPosition;

  String _travelMode = 'driving';
  String _distance = '';
  String _duration = '';

  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(10.7769, 106.7009),
    zoom: 14,
  );

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vui lòng bật GPS')));
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _startPosition = _currentPosition;
        _addMarker(_currentPosition!, "Vị trí hiện tại", true);
        _moveCamera(_currentPosition!);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lấy vị trí: $e')));
    }
  }

  void _addMarker(LatLng position, String title, bool isStart) {
    setState(() {
      _markers.add(Marker(
        markerId: MarkerId(title),
        position: position,
        infoWindow: InfoWindow(title: title),
        icon: isStart
            ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue)
            : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    });
  }

  Future<void> _moveCamera(LatLng position) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(position, 15));
  }

  Future<void> _findRoute() async {
    if (_startPosition == null || _endPosition == null) return;

    String apiKey = "AIzaSyBt21aPcaZy4oaHSsAWkkClyh3gAqVCSZE";

    String url = "https://maps.googleapis.com/maps/api/directions/json?"
        "origin=${_startPosition!.latitude},${_startPosition!.longitude}"
        "&destination=${_endPosition!.latitude},${_endPosition!.longitude}"
        "&mode=$_travelMode"
        "&key=$apiKey";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['routes'] != null && data['routes'].isNotEmpty) {
        final leg = data['routes'][0]['legs'][0];
        String encoded = data['routes'][0]['overview_polyline']['points'];

        setState(() {
          _polylines.clear();
          _polylines.add(Polyline(
            polylineId: const PolylineId('route'),
            points: _decodePolyline(encoded),
            color: Colors.blue,
            width: 6,
          ));
          _distance = leg['distance']['text'];
          _duration = leg['duration']['text'];
        });
      }
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int shift = 0, result = 0, b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google Maps - Debug')),
      body: GoogleMap(
        initialCameraPosition: _initialCamera,
        markers: _markers,
        polylines: _polylines,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: true,
        onMapCreated: (controller) => _controller.complete(controller),
        onTap: (LatLng pos) {
          setState(() {
            _endPosition = pos;
            _markers.removeWhere((m) => m.markerId.value == "Đích đến");
            _addMarker(pos, "Đích đến", false);
          });
          _findRoute();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _findRoute,
        child: const Icon(Icons.route),
      ),
    );
  }
}