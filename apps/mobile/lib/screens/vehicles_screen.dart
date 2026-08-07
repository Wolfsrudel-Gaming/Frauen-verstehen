import 'package:flutter/material.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import 'vehicle_detail_screen.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  List<Map<String, dynamic>> _vehicles = [];
  bool _loading = true;
  String? _error;

  final _makeCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  String _category = 'car';
  String _protocol = 'obd2';

  final _categories = ['car', 'motorcycle', 'bicycle', 'ebike', 'oldtimer', 'truck', 'van', 'other'];
  final _protocols = ['obd2', 'gps_only', 'none'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final v = await DataService.getVehicles();
      setState(() { _vehicles = v; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _addVehicle() async {
    if (_makeCtrl.text.trim().isEmpty || _modelCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marke und Modell sind Pflichtfelder')),
      );
      return;
    }
    try {
      await DataService.createVehicle(
        make: _makeCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        year: _yearCtrl.text.isNotEmpty ? int.tryParse(_yearCtrl.text) : null,
        licensePlate: _plateCtrl.text.trim(),
        category: _category,
        protocolSupport: _protocol,
      );
      _makeCtrl.clear();
      _modelCtrl.clear();
      _yearCtrl.clear();
      _plateCtrl.clear();
      await _load();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fahrzeug hinzufügen'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _makeCtrl, decoration: const InputDecoration(labelText: 'Marke *'), textInputAction: TextInputAction.next),
              TextField(controller: _modelCtrl, decoration: const InputDecoration(labelText: 'Modell *'), textInputAction: TextInputAction.next),
              TextField(controller: _yearCtrl, decoration: const InputDecoration(labelText: 'Baujahr'), keyboardType: TextInputType.number, textInputAction: TextInputAction.next),
              TextField(controller: _plateCtrl, decoration: const InputDecoration(labelText: 'Kennzeichen'), textInputAction: TextInputAction.next),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Fahrzeugart'),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _protocol,
                decoration: const InputDecoration(labelText: 'OBD-Unterstützung'),
                items: _protocols.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (v) => setState(() => _protocol = v!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: _addVehicle, child: const Text('Hinzufügen')),
        ],
      ),
    );
  }

  Color _protocolColor(String p) {
    if (p == 'obd2') return Colors.blue;
    if (p == 'gps_only') return Colors.green;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fahrzeuge'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _vehicles.isEmpty
                  ? const EmptyState(
                      icon: Icons.directions_car_outlined,
                      title: 'Noch keine Fahrzeuge',
                      message: 'Lege unten rechts dein erstes Fahrzeug an — Auto, Motorrad, '
                          'Oldtimer oder Fahrrad.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _vehicles.length,
                      itemBuilder: (ctx, i) {
                        final v = _vehicles[i];
                        final isActive = v['isActive'] as bool? ?? true;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: Icon(
                              _iconFor(v['category'] as String? ?? 'car'),
                              color: isActive ? null : Colors.grey,
                            ),
                            title: Text(
                              '${v['make']} ${v['model']}${v['year'] != null ? ' (${v['year']})' : ''}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isActive ? null : Colors.grey,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _protocolColor(v['protocolSupport'] as String? ?? 'none'),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    v['protocolSupport'] as String? ?? '?',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (v['licensePlate'] != null) ...[
                                  const SizedBox(width: 8),
                                  Text(v['licensePlate'] as String, style: const TextStyle(fontSize: 13)),
                                ],
                                if (!isActive) ...[
                                  const SizedBox(width: 8),
                                  const Text('stillgelegt', style: TextStyle(color: AppTheme.bad, fontSize: 12)),
                                ],
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => VehicleDetailScreen(vehicle: v),
                            )).then((_) => _load()),
                          ),
                        );
                      },
                    ),
    );
  }

  IconData _iconFor(String category) {
    switch (category) {
      case 'motorcycle': return Icons.two_wheeler;
      case 'bicycle': return Icons.directions_bike;
      case 'ebike': return Icons.electric_bike;
      case 'truck': return Icons.local_shipping;
      case 'van': return Icons.airport_shuttle;
      default: return Icons.directions_car;
    }
  }
}
