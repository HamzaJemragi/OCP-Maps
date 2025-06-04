import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ocp_maps/pages/create_trajet_page.dart';
import 'package:ocp_maps/pages/login_page.dart';
import 'package:ocp_maps/pages/trajet_details_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  // To manage the index of the selected bottom navigation item
  int _selectedIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final user = FirebaseAuth.instance.currentUser;
  String? userEmail;
  String? _sitename;
  Map<String, dynamic>? _mapname;
  Map<String, dynamic>? _mapurl;
  String? _errorMessage;
  bool _isLoading = true;
  double maplat = 0.0;
  double maplng = 0.0;
  String mapName = '';
  String trajetName = '';
  String trajetCreator = '';
  dynamic trajetDateTime = null;
  List<dynamic> trajets = [];
  List<dynamic> searchResults = [];
  String searchQuery = '';
  bool isSearching = false;
  String trajectoryName = '';
  String trajectoryCreator = '';
  dynamic trajectoryDateTime = null;
  String mapDocId = '';
  String trajectoryDocId = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _fetchSitename();
    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _signOut() async {
    FirebaseAuth.instance.signOut();
  }

  Future<void> _fetchSitename() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final userDocRef = FirebaseFirestore.instance
            .collection('utilisateurs')
            .doc(user.uid);

        final docSnapshot = await userDocRef.get();

        if (docSnapshot.exists && docSnapshot.data() != null) {
          final data = docSnapshot.data()!;
          setState(() async {
            _sitename = data['site'] as String?;
            userEmail = data['email'] as String?;
            _isLoading = false;
            if (_sitename != null && _sitename!.isNotEmpty) {
              final sitesQuerySnapshot =
                  await FirebaseFirestore.instance
                      .collection('sites')
                      .where('name', isEqualTo: _sitename)
                      .limit(1)
                      .get();

              if (sitesQuerySnapshot.docs.isNotEmpty) {
                _mapname = sitesQuerySnapshot.docs.first.data();
                final mapQuerySnapshot =
                    await FirebaseFirestore.instance
                        .collection('maps')
                        .where('name', isEqualTo: _mapname!['mapName'])
                        .limit(1)
                        .get();
                if (mapQuerySnapshot.docs.isNotEmpty) {
                  _mapurl = mapQuerySnapshot.docs.first.data();
                  maplat = _mapurl!["lat"];
                  maplng = _mapurl!["lng"];
                  mapName = _mapurl!["name"];
                  _FetchTrajectories();
                } else {
                  _mapurl = {'message': 'Map details not found for $_mapname'};
                  _showModernSnackBar('Map details not found', isError: true);
                }
              } else {
                _mapname = {'message': 'Site details not found for $_sitename'};
                _showModernSnackBar('Site details not found', isError: true);
              }
            } else {
              _sitename = 'Sitename not available for user';
              _mapname = {'message': 'No sitename to search for'};
              _showModernSnackBar('Sitename not available', isError: true);
            }
          });
        } else {
          setState(() {
            _sitename = 'Sitename not found';
            _isLoading = false;
            _showModernSnackBar('Sitename not found', isError: true);
          });
        }
      } else {
        setState(() {
          _sitename = 'User not signed in';
          _isLoading = false;
          _showModernSnackBar('User not signed in', isError: true);
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching sitename: $e';
        _isLoading = false;
      });
      _showModernSnackBar('Error fetching sitename: $e', isError: true);
    }
  }

  void _showModernSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _FetchTrajectories() async {
    try {
      QuerySnapshot mapSnapshot =
          await FirebaseFirestore.instance
              .collection('maps')
              .where('name', isEqualTo: mapName)
              .limit(1)
              .get();
      if (mapSnapshot.docs.isNotEmpty) {
        String mapDocId = mapSnapshot.docs.first.id;
        this.mapDocId = mapDocId;

        QuerySnapshot trajetsSnapshot =
            await FirebaseFirestore.instance
                .collection('maps')
                .doc(mapDocId)
                .collection('trajectories')
                .orderBy('created_at', descending: true)
                .get();
        if (trajetsSnapshot.docs.isNotEmpty) {
          setState(() {
            trajets =
                trajetsSnapshot.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  data['docId'] = doc.id;
                  return data;
                }).toList();
            if (isSearching && searchQuery.isNotEmpty) {
              _updateSearchResults();
            }
          });
        } else {
          setState(() {
            trajets = [];
            searchResults = [];
          });
        }
      }
    } catch (e) {
      print('Error fetching trajets: $e');
      _showModernSnackBar('Error fetching trajets: $e', isError: true);
    }
  }

  void _searchTrajectories(String query) {
    setState(() {
      searchQuery = query;
      isSearching = query.isNotEmpty;

      if (query.isEmpty) {
        searchResults = [];
      } else {
        _updateSearchResults();
      }
    });
  }

  void _updateSearchResults() {
    searchResults =
        trajets.where((trajet) {
          final trajetName = (trajet['name'] ?? '').toString().toLowerCase();
          return trajetName.contains(searchQuery.toLowerCase());
        }).toList();
  }

  Widget _buildModernTrajetCard(
    Map<String, dynamic> trajet, {
    bool isSearchResult = false,
  }) {
    final trajetName = trajet['name'] ?? 'Nom non disponible';
    final trajetCreator = trajet['creator'] ?? 'Créateur inconnu';
    final createdAt = trajet['created_at'];
    final trajectoryDocId = trajet['docId'] ?? '';

    String dateString = '';
    if (createdAt != null) {
      try {
        if (createdAt is Timestamp) {
          final date = createdAt.toDate();
          dateString = '${date.day}/${date.month}/${date.year}';
        }
      } catch (e) {
        dateString = '';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => TrajectoryDetailsPage(
                      trajectory: {...trajet, 'id': trajectoryDocId},
                      mapName: mapName,
                      mapDocId: mapDocId,
                      trajectoryDocId: trajectoryDocId,
                      currentUser: userEmail!,
                    ),
              ),
            );

            if (result == true) {
              _FetchTrajectories();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors:
                          isSearchResult
                              ? [Colors.purple.shade400, Colors.purple.shade600]
                              : [Colors.green.shade400, Colors.green.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (isSearchResult ? Colors.purple : Colors.green)
                            .withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.route, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isSearchResult)
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                            children: _highlightSearchTerm(
                              trajetName,
                              searchQuery,
                            ),
                          ),
                        )
                      else
                        Text(
                          trajetName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              trajetCreator,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (dateString.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dateString,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomePage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mapName.isNotEmpty) {
        _FetchTrajectories();
      }
    });

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Chargement des trajets...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (trajets.isEmpty) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.grey.shade300, Colors.grey.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(Icons.route, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text(
                'Aucun trajet disponible',
                style: TextStyle(
                  fontSize: 22,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Créez votre premier trajet !',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(20.0),
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade600, Colors.green.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.route, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Trajets disponibles',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${trajets.length} trajet${trajets.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: trajets.length,
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              itemBuilder: (context, index) {
                return _buildModernTrajetCard(trajets[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mapName.isNotEmpty) {
        _FetchTrajectories();
      }
    });

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Rechercher des trajets',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Trouvez le trajet parfait pour votre destination',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Rechercher par nom de trajet...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  prefixIcon: Container(
                    margin: const EdgeInsets.only(left: 12, right: 8),
                    child: Icon(
                      Icons.search_rounded,
                      color: Colors.grey.shade600,
                      size: 24,
                    ),
                  ),
                  suffixIcon:
                      searchQuery.isNotEmpty
                          ? Container(
                            margin: const EdgeInsets.only(right: 12),
                            child: IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: Colors.grey.shade600,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _searchTrajectories('');
                              },
                            ),
                          )
                          : null,
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                onChanged: (text) {
                  _searchTrajectories(text);
                },
              ),
            ),
            const SizedBox(height: 20),

            if (isSearching) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      searchResults.isEmpty
                          ? Icons.search_off_rounded
                          : Icons.search_rounded,
                      color: Colors.green.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        searchResults.isEmpty
                            ? 'Aucun résultat pour "$searchQuery"'
                            : '${searchResults.length} résultat${searchResults.length > 1 ? 's' : ''} trouvé${searchResults.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            Expanded(child: _buildSearchResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (!isSearching && searchQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey.shade300, Colors.grey.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(Icons.search, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              'Recherchez des trajets',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tapez le nom d\'un trajet pour commencer',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      );
    }

    if (isSearching && searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 49,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade300, Colors.orange.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(
                Icons.search_off,
                size: 35,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucun trajet trouvé',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Essayez avec un autre terme de recherche',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        return _buildModernTrajetCard(
          searchResults[index],
          isSearchResult: true,
        );
      },
    );
  }

  List<TextSpan> _highlightSearchTerm(String text, String searchTerm) {
    if (searchTerm.isEmpty) {
      return [TextSpan(text: text)];
    }

    final List<TextSpan> spans = [];
    final String lowerText = text.toLowerCase();
    final String lowerSearchTerm = searchTerm.toLowerCase();
    int start = 0;

    while (true) {
      final int index = lowerText.indexOf(lowerSearchTerm, start);
      if (index == -1) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start)));
        }
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      spans.add(
        TextSpan(
          text: text.substring(index, index + searchTerm.length),
          style: TextStyle(
            backgroundColor: Colors.purple.shade200,
            fontWeight: FontWeight.w800,
            color: Colors.purple.shade800,
          ),
        ),
      );

      start = index + searchTerm.length;
    }

    return spans.isEmpty ? [TextSpan(text: text)] : spans;
  }

  List<Widget> get _pages => <Widget>[_buildHomePage(), _buildSearchPage()];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'OCP Maps',
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
      ),
      drawer: Drawer(
        child: Column(
          children: <Widget>[
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.green.shade600, Colors.green.shade800],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        userEmail ?? 'Email non disponible',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _sitename ?? 'Site non disponible',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.logout_rounded,
                        color: Colors.red.shade600,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Déconnexion',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade600,
                      ),
                    ),
                    onTap: () {
                      _signOut();
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LoginPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.add_road_rounded,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Créer un nouveau trajet',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => CreateTrajetPage(
                                initialTarget: LatLng(maplat, maplng),
                                mapname: mapName,
                              ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
      floatingActionButton: Container(
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
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => CreateTrajetPage(
                      initialTarget: LatLng(maplat, maplng),
                      mapname: mapName,
                    ),
              ),
            );
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          label: const Text(
            'Créer un Trajet',
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
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          items: [
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      _selectedIndex == 0
                          ? Colors.green.shade100
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _selectedIndex == 0
                      ? Icons.home_rounded
                      : Icons.home_outlined,
                  size: 24,
                ),
              ),
              label: 'Accueil',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      _selectedIndex == 1
                          ? Colors.green.shade100
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _selectedIndex == 1
                      ? Icons.search_rounded
                      : Icons.search_outlined,
                  size: 24,
                ),
              ),
              label: 'Recherche',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.green.shade700,
          unselectedItemColor: Colors.grey.shade600,
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
