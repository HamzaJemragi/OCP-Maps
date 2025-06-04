import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class CreateTrajetPage extends StatefulWidget {
  final LatLng initialTarget;
  final double initialZoom;
  final String mapname;

  const CreateTrajetPage({
    super.key,
    this.initialTarget = const LatLng(32.2248187, -9.2498231),
    this.initialZoom = 16.0,
    this.mapname = '',
  });

  @override
  State<CreateTrajetPage> createState() => _CreateTrajetPageState();
}

class _CreateTrajetPageState extends State<CreateTrajetPage> {
  final Completer<GoogleMapController> _mapControllerCompleter =
      Completer<GoogleMapController>();
  GoogleMapController? _mapController;
  TextEditingController _nameController = TextEditingController();
  bool _isNameValid = false;

  // Two selected locations and markers
  LatLng? _selectedLocation1;
  LatLng? _selectedLocation2;
  Marker? _selectedMarker1;
  Marker? _selectedMarker2;
  Set<Polyline> _polylines = {};
  List<LatLng> _routePoints = [];
  double _routeDistance = 0.0;
  String _routeDuration = '';
  bool _isLoadingRoute = false;
  String _routeError = '';

  // Track which point is being selected (1 or 2)
  int _currentPointSelection = 1;

  // Current user email
  String? _currentUserEmail;

  // OSRM API endpoint - Free public demo server
  static const String _osrmBaseUrl =
      'https://router.project-osrm.org/route/v1/driving';

  @override
  void initState() {
    super.initState();
    _getCurrentUserEmail();

    // Listen to text changes to update button state
    _nameController.addListener(() {
      bool isValid = _nameController.text.trim().isNotEmpty;
      if (_isNameValid != isValid) {
        setState(() {
          _isNameValid = isValid;
        });
      }
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentUserEmail() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Get user document from users collection
        DocumentSnapshot userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .get();

        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          setState(() {
            _currentUserEmail = userData['email'] ?? currentUser.email;
          });
        } else {
          // Fallback to Firebase Auth email if user document doesn't exist
          setState(() {
            _currentUserEmail = currentUser.email;
          });
        }
      }
    } catch (e) {
      print('Error getting current user email: $e');
      // Fallback to Firebase Auth email
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        setState(() {
          _currentUserEmail = currentUser.email;
        });
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapControllerCompleter.complete(controller);
    _mapController = controller;
  }

  void _onMapTap(LatLng location) {
    setState(() {
      if (_currentPointSelection == 1) {
        _selectedLocation1 = location;
        _selectedMarker1 = Marker(
          markerId: const MarkerId('selectedPointMarker1'),
          position: location,
          infoWindow: InfoWindow(
            title: 'Starting Point',
            snippet:
                'Lat: ${location.latitude.toStringAsFixed(5)}, Lng: ${location.longitude.toStringAsFixed(5)}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        );
        // Auto switch to point 2 selection after selecting point 1
        _currentPointSelection = 2;
      } else {
        _selectedLocation2 = location;
        _selectedMarker2 = Marker(
          markerId: const MarkerId('selectedPointMarker2'),
          position: location,
          infoWindow: InfoWindow(
            title: 'Destination',
            snippet:
                'Lat: ${location.latitude.toStringAsFixed(5)}, Lng: ${location.longitude.toStringAsFixed(5)}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        );
      }

      // Clear any previous error
      _routeError = '';

      // Get route if both points are selected
      _getOSRMRoute();
    });
    _mapController?.animateCamera(CameraUpdate.newLatLng(location));
  }

  Future<void> _getOSRMRoute() async {
    if (_selectedLocation1 == null || _selectedLocation2 == null) {
      setState(() {
        _polylines = {};
        _routePoints = [];
        _routeDistance = 0.0;
        _routeDuration = '';
        _isLoadingRoute = false;
        _routeError = '';
      });
      return;
    }

    setState(() {
      _isLoadingRoute = true;
      _routeError = '';
    });

    try {
      // Build the OSRM API URL
      // Format: longitude,latitude;longitude,latitude
      String coordinates =
          '${_selectedLocation1!.longitude},${_selectedLocation1!.latitude};'
          '${_selectedLocation2!.longitude},${_selectedLocation2!.latitude}';

      String url =
          '$_osrmBaseUrl/$coordinates?'
          'overview=full&'
          'geometries=geojson&'
          'steps=true&'
          'annotations=true';

      print('Requesting OSRM route from: $url');

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent':
                  'FlutterApp/1.0', // Good practice to identify your app
            },
          )
          .timeout(const Duration(seconds: 10));

      print('OSRM Response status: ${response.statusCode}');
      print('OSRM Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];

          // Get distance and duration from OSRM
          double distanceInMeters = route['distance'].toDouble();
          double durationInSeconds = route['duration'].toDouble();

          // Convert duration to human readable format
          String durationText = _formatDuration(durationInSeconds);

          // Get route geometry (coordinates)
          List<dynamic> coordinates = route['geometry']['coordinates'];
          List<LatLng> routePoints =
              coordinates
                  .map(
                    (coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()),
                  )
                  .toList();

          setState(() {
            _routeDistance = distanceInMeters;
            _routeDuration = durationText;
            _routePoints = routePoints;
            _polylines = {
              Polyline(
                polylineId: const PolylineId('osrm_route'),
                points: _routePoints,
                color: Colors.blue,
                width: 6,
                patterns: [],
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
                jointType: JointType.round,
              ),
            };
            _isLoadingRoute = false;
          });

          // Adjust camera to show the entire route
          _fitCameraToRoute();
        } else {
          // Handle OSRM API errors
          String errorMessage = 'Unable to find route';
          if (data['code'] == 'NoRoute') {
            errorMessage = 'No route found between the selected points';
          } else if (data['code'] == 'NoSegment') {
            errorMessage =
                'One of the coordinates cannot be snapped to street network';
          } else if (data['code'] == 'InvalidInput') {
            errorMessage = 'Invalid coordinates provided';
          }

          print(
            'OSRM API error: ${data['code']} - ${data['message'] ?? errorMessage}',
          );

          setState(() {
            _routeError = errorMessage;
            _isLoadingRoute = false;
          });

          // Fallback to straight line
          _createStraightLineRoute();
        }
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      print('Error getting OSRM route: $e');
      setState(() {
        _routeError = 'Error: ${e.toString()}';
        _isLoadingRoute = false;
      });

      // Fallback to straight line if OSRM fails
      _createStraightLineRoute();
    }
  }

  String _formatDuration(double durationInSeconds) {
    int totalMinutes = (durationInSeconds / 60).round();

    if (totalMinutes < 60) {
      return '$totalMinutes min';
    } else {
      int hours = totalMinutes ~/ 60;
      int minutes = totalMinutes % 60;
      if (minutes == 0) {
        return '$hours h';
      } else {
        return '$hours h $minutes min';
      }
    }
  }

  void _fitCameraToRoute() {
    if (_routePoints.isEmpty || _mapController == null) return;

    // Calculate bounds that include all route points
    double minLat = _routePoints.first.latitude;
    double maxLat = _routePoints.first.latitude;
    double minLng = _routePoints.first.longitude;
    double maxLng = _routePoints.first.longitude;

    for (LatLng point in _routePoints) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    // Add some padding
    double padding = 0.01;
    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );

    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
  }

  void _createStraightLineRoute() {
    if (_selectedLocation1 != null && _selectedLocation2 != null) {
      double distance = _calculateHaversineDistance(
        _selectedLocation1!,
        _selectedLocation2!,
      );

      setState(() {
        _routeDistance = distance;
        _routeDuration = 'Estimated';
        _routePoints = [_selectedLocation1!, _selectedLocation2!];
        _polylines = {
          Polyline(
            polylineId: const PolylineId('straight_line'),
            points: [_selectedLocation1!, _selectedLocation2!],
            color: Colors.orange,
            width: 4,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        };
      });
    }
  }

  double _calculateHaversineDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Earth radius in meters
    double lat1Rad = point1.latitude * pi / 180;
    double lat2Rad = point2.latitude * pi / 180;
    double deltaLatRad = (point2.latitude - point1.latitude) * pi / 180;
    double deltaLngRad = (point2.longitude - point1.longitude) * pi / 180;

    double a =
        sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLngRad / 2) *
            sin(deltaLngRad / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c; // Distance in meters
  }

  void _clearRoute() {
    setState(() {
      _selectedLocation1 = null;
      _selectedLocation2 = null;
      _selectedMarker1 = null;
      _selectedMarker2 = null;
      _polylines = {};
      _routePoints = [];
      _routeDistance = 0.0;
      _routeDuration = '';
      _currentPointSelection = 1;
      _routeError = '';
      _isLoadingRoute = false;
    });
  }

  void _confirmSelection() {
    if (_selectedLocation1 != null && _selectedLocation2 != null) {
      double distance =
          _routeDistance > 0
              ? _routeDistance
              : _calculateHaversineDistance(
                _selectedLocation1!,
                _selectedLocation2!,
              );

      // Helper method for detail rows - define first before use
      Widget buildDetailRow(IconData icon, String label, String value) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        builder:
            (context) => SingleChildScrollView(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                    left: 24,
                    right: 24,
                    top: 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Modern drag handle
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Header with icon and title
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.route_outlined,
                              color: Colors.green.shade600,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'Create New Trajectory',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Modern text field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Trajectory Name',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              hintText: 'Enter a name for this route',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.grey[200]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.grey[200]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.green.shade400,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Modern route details card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.grey[600],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Route Details',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2D3748),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Location details with better formatting
                            buildDetailRow(
                              Icons.my_location,
                              'From',
                              '${_selectedLocation1!.latitude.toStringAsFixed(5)}, ${_selectedLocation1!.longitude.toStringAsFixed(5)}',
                            ),
                            const SizedBox(height: 12),
                            buildDetailRow(
                              Icons.location_on,
                              'To',
                              '${_selectedLocation2!.latitude.toStringAsFixed(5)}, ${_selectedLocation2!.longitude.toStringAsFixed(5)}',
                            ),
                            const SizedBox(height: 12),
                            buildDetailRow(
                              Icons.straighten,
                              'Distance',
                              '${(distance / 1000).toStringAsFixed(2)} km',
                            ),

                            if (_routeDuration.isNotEmpty &&
                                _routeDuration != 'N/A') ...[
                              const SizedBox(height: 12),
                              buildDetailRow(
                                Icons.access_time,
                                'Duration',
                                _routeDuration,
                              ),
                            ],

                            if (_routeError.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.orange.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.orange.shade600,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _routeError,
                                        style: TextStyle(
                                          color: Colors.orange.shade700,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      if (_currentUserEmail != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 16,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Creator: $_currentUserEmail',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 32),

                      // Modern action buttons
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: Colors.grey[300]!),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4A5568),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed:
                                  _nameController.text.trim().isEmpty
                                      ? null
                                      : () async {
                                        try {
                                          QuerySnapshot parentQuerySnapshot =
                                              await FirebaseFirestore.instance
                                                  .collection('maps')
                                                  .where(
                                                    'name',
                                                    isEqualTo: widget.mapname,
                                                  )
                                                  .limit(1)
                                                  .get();

                                          if (parentQuerySnapshot
                                              .docs
                                              .isNotEmpty) {
                                            DocumentSnapshot
                                            parentDocumentSnapshot =
                                                parentQuerySnapshot.docs.first;

                                            Map<String, dynamic>
                                            trajectoryData = {
                                              'name':
                                                  _nameController.text.trim(),
                                              'point1_lat':
                                                  _selectedLocation1!.latitude,
                                              'point1_lng':
                                                  _selectedLocation1!.longitude,
                                              'point2_lat':
                                                  _selectedLocation2!.latitude,
                                              'point2_lng':
                                                  _selectedLocation2!.longitude,
                                              'distance_meters': distance,
                                              'creator':
                                                  _currentUserEmail ??
                                                  'unknown',
                                              'created_at':
                                                  FieldValue.serverTimestamp(),
                                              'route_type':
                                                  _routeError.isEmpty
                                                      ? 'osrm'
                                                      : 'straight_line',
                                            };

                                            // Add route points if available
                                            if (_routePoints.isNotEmpty) {
                                              trajectoryData['route_points'] =
                                                  _routePoints
                                                      .map(
                                                        (point) => {
                                                          'lat': point.latitude,
                                                          'lng':
                                                              point.longitude,
                                                        },
                                                      )
                                                      .toList();
                                            }

                                            // Add duration if available
                                            if (_routeDuration.isNotEmpty &&
                                                _routeDuration != 'N/A') {
                                              trajectoryData['duration'] =
                                                  _routeDuration;
                                            }

                                            await parentDocumentSnapshot
                                                .reference
                                                .collection('trajectories')
                                                .add(trajectoryData);

                                            Navigator.pop(
                                              context,
                                            ); // Close bottom sheet
                                            Navigator.pop(
                                              context,
                                              'Trajectory saved successfully',
                                            );
                                          } else {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Error: Parent map not found.',
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          print('Error saving trajectory: $e');
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Error saving trajectory: $e',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                disabledBackgroundColor: Colors.grey[300],
                              ),
                              child: const Text(
                                'Save Trajectory',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Trajectory',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade600, Colors.green.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_selectedLocation1 != null || _selectedLocation2 != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearRoute,
              tooltip: 'Clear Route',
            ),
        ],
      ),
      body: Column(
        children: [
          // Toggle buttons for manual point selection
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _currentPointSelection = 1;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _currentPointSelection == 1
                              ? Colors.green
                              : Colors.grey[300],
                      foregroundColor:
                          _currentPointSelection == 1
                              ? Colors.white
                              : Colors.black,
                    ),
                    icon: Icon(
                      _selectedLocation1 != null
                          ? Icons.check_circle
                          : Icons.location_on,
                      size: 18,
                    ),
                    label: const Text('Start Point'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _currentPointSelection = 2;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _currentPointSelection == 2
                              ? Colors.red
                              : Colors.grey[300],
                      foregroundColor:
                          _currentPointSelection == 2
                              ? Colors.white
                              : Colors.black,
                    ),
                    icon: Icon(
                      _selectedLocation2 != null
                          ? Icons.check_circle
                          : Icons.flag,
                      size: 18,
                    ),
                    label: const Text('End Point'),
                  ),
                ),
              ],
            ),
          ),

          // Map
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: widget.initialTarget,
                    zoom: widget.initialZoom,
                  ),
                  onTap: _onMapTap,
                  markers: {
                    if (_selectedMarker1 != null) _selectedMarker1!,
                    if (_selectedMarker2 != null) _selectedMarker2!,
                  },
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  mapToolbarEnabled: false,
                  zoomControlsEnabled: true,
                  mapType: MapType.normal,
                ),

                // Instruction card
                if (_selectedLocation1 == null || _selectedLocation2 == null)
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Icon(
                              _selectedLocation1 == null
                                  ? Icons.location_on
                                  : Icons.flag,
                              color:
                                  _selectedLocation1 == null
                                      ? Colors.green
                                      : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedLocation1 == null
                                    ? 'Tap on the map to select your starting point'
                                    : 'Now tap to select your destination',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Loading indicator
                if (_isLoadingRoute)
                  const Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('Finding best route...'),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Route information card
                if (_selectedLocation1 != null &&
                    _selectedLocation2 != null &&
                    !_isLoadingRoute)
                  Positioned(
                    bottom: 20,
                    left: 10,
                    right: 10,
                    child: Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _routeError.isEmpty
                                      ? Icons.directions
                                      : Icons.warning,
                                  color:
                                      _routeError.isEmpty
                                          ? Colors.green
                                          : Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Distance: ${(_routeDistance / 1000).toStringAsFixed(2)} km',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (_routeDuration.isNotEmpty &&
                                          _routeDuration != 'N/A')
                                        Text(
                                          'Duration: $_routeDuration',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      if (_routeError.isNotEmpty)
                                        Text(
                                          _routeError,
                                          style: const TextStyle(
                                            color: Colors.orange,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton:
          (_selectedLocation1 != null &&
                  _selectedLocation2 != null &&
                  !_isLoadingRoute)
              ? Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade500, Colors.green.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: FloatingActionButton.extended(
                  onPressed: _confirmSelection,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  label: const Text(
                    'sauvegarder le Trajet',
                    style: TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  icon: const Icon(
                    Icons.add_road_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              )
              : null,
    );
  }
}
