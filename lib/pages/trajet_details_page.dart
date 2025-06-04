import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class TrajectoryDetailsPage extends StatefulWidget {
  final Map<String, dynamic> trajectory;
  final String mapName;
  final String mapDocId;
  final dynamic trajectoryDocId;
  final String currentUser;

  const TrajectoryDetailsPage({
    Key? key,
    required this.trajectory,
    required this.mapName,
    required this.mapDocId,
    required this.trajectoryDocId,
    required this.currentUser,
  }) : super(key: key);

  @override
  _TrajectoryDetailsPageState createState() => _TrajectoryDetailsPageState();
}

class _TrajectoryDetailsPageState extends State<TrajectoryDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isEditing = false;
  bool _isLoading = false;
  bool _isDeleting = false;
  // late String currentUserId;
  late bool isCreator;

  // Trajectory data
  late String trajectoryName;
  late String trajectoryCreatorId;
  // late String trajectoryDescription;
  late DateTime createdAt;
  late List<dynamic> waypoints;
  late String trajectoryId;
  String _currentUserEmail = '';

  @override
  void initState() {
    super.initState();
    _getCurrentUserEmail();
    _initializeData();
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
            _currentUserEmail = currentUser.email!;
          });
        }
      }
    } catch (e) {
      print('Error getting current user email: $e');
      // Fallback to Firebase Auth email
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        setState(() {
          _currentUserEmail = currentUser.email!;
        });
      }
    }
  }

  void _initializeData() {
    // Initialize trajectory data
    trajectoryName = widget.trajectory['name'] ?? 'Nom non disponible';
    trajectoryCreatorId = widget.trajectory['creator'] ?? '';
    waypoints = widget.trajectory['route_points'] ?? [];
    trajectoryId = widget.trajectory['id'] ?? '';

    // Check if current user is the creator
    isCreator = trajectoryCreatorId == widget.currentUser;

    // Handle created_at timestamp
    final createdAtData = widget.trajectory['created_at'];
    if (createdAtData is Timestamp) {
      createdAt = createdAtData.toDate();
    } else {
      createdAt = DateTime.now();
    }

    // Initialize form controllers
    _nameController.text = trajectoryName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _generateGoogleMapsUrl() {
    if (waypoints.isEmpty) return '';

    String baseUrl = 'https://www.google.com/maps/dir/';

    // Add all waypoints as destinations
    List<String> coordinates = [];
    for (var waypoint in waypoints) {
      final lat = waypoint['lat']?.toString() ?? '';
      final lng = waypoint['lng']?.toString() ?? '';
      if (lat.isNotEmpty && lng.isNotEmpty) {
        coordinates.add('$lat,$lng');
      }
    }

    if (coordinates.isEmpty) return '';

    // Join coordinates with '/'
    String waypointsString = coordinates.join('/');

    return '$baseUrl$waypointsString';
  }

  void _showQRCodeBottomSheet() {
    final googleMapsUrl = _generateGoogleMapsUrl();

    if (googleMapsUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible de générer le QR code: aucun point de passage valide',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(Icons.qr_code, size: 48, color: Colors.green),
                    const SizedBox(height: 12),
                    Text(
                      'QR Code de la trajectoire',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      trajectoryName,
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // QR Code
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: googleMapsUrl,
                      version: QrVersions.auto,
                      size: 250.0,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
              ),

              // Instructions
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info,
                                color: Colors.green.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Instructions',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Scannez ce QR code avec votre téléphone pour ouvrir la trajectoire directement dans Google Maps avec tous les points de passage.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final Uri url = Uri.parse(googleMapsUrl);
                              if (await canLaunchUrl(url)) {
                                await launchUrl(
                                  url,
                                  mode: LaunchMode.externalApplication,
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Impossible d\'ouvrir Google Maps',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.map),
                            label: const Text('Ouvrir dans Maps'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                            label: const Text('Fermer'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateTrajectory() async {
    // Double-check permissions before updating
    if (!isCreator) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vous n\'avez pas le droit de modifier cette trajectoire',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('maps')
          .doc(widget.mapDocId)
          .collection('trajectories')
          .doc(widget.trajectoryDocId)
          .update({
            'name': _nameController.text.trim(),
            'updated_at': FieldValue.serverTimestamp(),
          });

      setState(() {
        trajectoryName = _nameController.text.trim();
        _isEditing = false;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trajectoire mise à jour avec succès'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la mise à jour: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteTrajectory() async {
    // Double-check permissions before deleting
    if (!isCreator) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vous n\'avez pas le droit de supprimer cette trajectoire',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: Text(
            'Êtes-vous sûr de vouloir supprimer la trajectoire "$trajectoryName" ?\n\nCette action est irréversible.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('maps')
          .doc(widget.mapDocId)
          .collection('trajectories')
          .doc(trajectoryId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trajectoire supprimée avec succès'),
          backgroundColor: Colors.blue,
        ),
      );

      // Go back to previous screen
      Navigator.of(context).pop(true); // Return true to indicate deletion
    } catch (e) {
      setState(() {
        _isDeleting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la suppression: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _nameController.text = trajectoryName;
    });
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    Color? iconColor,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor ?? Colors.green, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nom de la trajectoire',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Entrez le nom de la trajectoire',
                      hintStyle: TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white70,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le nom est requis';
                      }
                      if (value.trim().length < 3) {
                        return 'Le nom doit contenir au moins 3 caractères';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Modifier la trajectoire' : 'Détails de la trajectoire',
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
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          // Only show edit and delete options if user is the creator
          if (isCreator && !_isEditing && !_isDeleting) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              tooltip: 'Modifier',
            ),
            PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'generate_qr',
                      child: Row(
                        children: [
                          Icon(Icons.qr_code, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Générer QR Code'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            'Supprimer',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
              onSelected: (value) {
                if (value == 'generate_qr') {
                  _showQRCodeBottomSheet();
                } else if (value == 'delete') {
                  _deleteTrajectory();
                }
              },
            ),
          ],

          // For non-creators, show only QR generation in popup menu
          if (!isCreator && !_isEditing && !_isDeleting && waypoints.isNotEmpty)
            PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'generate_qr',
                      child: Row(
                        children: [
                          Icon(Icons.qr_code, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Générer QR Code'),
                        ],
                      ),
                    ),
                  ],
              onSelected: (value) {
                if (value == 'generate_qr') {
                  _showQRCodeBottomSheet();
                }
              },
            ),

          if (_isEditing && isCreator) ...[
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _cancelEdit,
              tooltip: 'Annuler',
            ),
          ],
        ],
      ),
      body:
          _isDeleting
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Suppression en cours...'),
                  ],
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with trajectory icon
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade400,
                            Colors.green.shade600,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.route, size: 48, color: Colors.white),
                          const SizedBox(height: 12),
                          Text(
                            _isEditing ? 'Mode édition' : trajectoryName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (!_isEditing) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isCreator
                                        ? Colors.blue.shade600
                                        : Colors.orange.shade600,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isCreator
                                    ? 'Vous êtes le créateur'
                                    : 'Lecture seule',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Show permission notice for non-creators
                    if (!isCreator && !_isEditing) ...[
                      Card(
                        color: Colors.orange.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Icon(Icons.info, color: Colors.orange.shade700),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Vous pouvez consulter cette trajectoire mais vous ne pouvez pas la modifier car vous n\'en êtes pas le créateur.',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_isEditing && isCreator) ...[
                      _buildEditForm(),
                    ] else ...[
                      // Trajectory Information
                      _buildInfoCard(
                        icon: Icons.label,
                        title: 'Nom de la trajectoire',
                        content: trajectoryName,
                      ),

                      _buildInfoCard(
                        icon: Icons.person,
                        title: 'Créateur',
                        content: trajectoryCreatorId,
                        iconColor: Colors.blue,
                      ),

                      _buildInfoCard(
                        icon: Icons.calendar_today,
                        title: 'Date de création',
                        content:
                            '${createdAt.day}/${createdAt.month}/${createdAt.year} à ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
                        iconColor: Colors.purple,
                      ),

                      _buildInfoCard(
                        icon: Icons.location_on,
                        title: 'Points de passage',
                        content: '${waypoints.length} point(s)',
                        iconColor: Colors.red,
                      ),

                      _buildInfoCard(
                        icon: Icons.map,
                        title: 'Carte',
                        content: widget.mapName,
                        iconColor: Colors.teal,
                      ),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
      floatingActionButton:
          (_isEditing && isCreator)
              ? Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FloatingActionButton(
                    heroTag: "cancel",
                    onPressed: _cancelEdit,
                    backgroundColor: Colors.grey,
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  FloatingActionButton(
                    heroTag: "save",
                    onPressed: _isLoading ? null : _updateTrajectory,
                    backgroundColor: Colors.blue,
                    child:
                        _isLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : const Icon(Icons.save, color: Colors.white),
                  ),
                ],
              )
              : null,
    );
  }
}
