import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/app_mode.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'vehicles_screen.dart';
import 'trips_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _me;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const TripsScreen(),
    const VehiclesScreen(),
  ];

  @override
  void initState() {
    super.initState();
    if (!AppMode.isOffline) _loadMe();
  }

  Future<void> _loadMe() async {
    try {
      final me = await ApiService.getMe();
      setState(() { _me = me; });
    } catch (_) {
      // If me fails, session is invalid — go back to login
      if (mounted) {
        await ApiService.clearToken();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  Future<void> _signOut() async {
    await AppMode.setOffline(false);
    await ApiService.clearToken();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  String get _activeOrgName {
    final orgs = _me?['orgs'] as List<dynamic>? ?? [];
    final activeOrgId = _me?['activeOrgId'] as String?;
    final org = orgs.firstWhere(
      (o) => (o as Map<String, dynamic>)['orgId'] == activeOrgId,
      orElse: () => <String, dynamic>{},
    );
    return (org as Map<String, dynamic>)['orgName'] as String? ?? '—';
  }

  @override
  Widget build(BuildContext context) {
    final username = (_me?['user'] as Map<String, dynamic>?)?['username'] as String? ?? '…';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Driver Analytics', style: TextStyle(fontSize: 16)),
            if (AppMode.isOffline)
              const Text(
                'Offline-Modus · Daten lokal',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              )
            else if (_me != null)
              Text(
                '$_activeOrgName · $username',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Sign out', onPressed: _signOut),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Übersicht'),
          NavigationDestination(icon: Icon(Icons.route), label: 'Fahrten'),
          NavigationDestination(icon: Icon(Icons.directions_car), label: 'Fahrzeuge'),
        ],
      ),
    );
  }
}
