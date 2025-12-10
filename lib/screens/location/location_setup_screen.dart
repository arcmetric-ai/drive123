import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/location_preference.dart';

class LocationSetupScreen extends StatefulWidget {
  const LocationSetupScreen({
    super.key,
    this.savedLocations = const [],
    this.initialSelectionKey,
    this.initialManualAddress,
  });

  final List<PreferredLocation> savedLocations;
  final String? initialSelectionKey;
  final String? initialManualAddress;

  @override
  State<LocationSetupScreen> createState() => _LocationSetupScreenState();
}

class _LocationSetupScreenState extends State<LocationSetupScreen> {
  final _manualAddressController = TextEditingController();
  PreferredLocation? _selectedSavedLocation;
  String? _selectedSavedLocationKey;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSelectionKey != null) {
      final match = _findLocation(widget.initialSelectionKey!);
      if (match != null) {
        _selectedSavedLocation = match;
        _selectedSavedLocationKey = match.storageKey;
      }
    }
    if (_selectedSavedLocation == null && widget.initialManualAddress != null) {
      _manualAddressController.text = widget.initialManualAddress!;
    }
  }

  @override
  void dispose() {
    _manualAddressController.dispose();
    super.dispose();
  }

  PreferredLocation? _findLocation(String key) {
    for (final location in widget.savedLocations) {
      if (location.storageKey == key) {
        return location;
      }
    }
    return null;
  }

  Future<void> _handleSave() async {
    final manualLocation = _manualAddressController.text.trim();
    final hasManual = manualLocation.isNotEmpty;
    if (!hasManual && _selectedSavedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a saved location or enter one manually.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;

    final result = hasManual
        ? LocationSelectionResult.manual(manualLocation)
        : LocationSelectionResult.saved(_selectedSavedLocation!);

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Your Location'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Where will you take lessons?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ocean,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Search for your address or enter it manually so we can find instructors nearby.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              if (widget.savedLocations.isNotEmpty) ...[
                const Text(
                  'Saved pickup locations',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ocean,
                  ),
                ),
                const SizedBox(height: 12),
                ...widget.savedLocations.map((location) {
                  return RadioListTile<String>(
                    value: location.storageKey,
                    groupValue: _selectedSavedLocationKey,
                    activeColor: AppColors.ocean,
                    contentPadding: EdgeInsets.zero,
                    title: Text(location.displayText),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedSavedLocationKey = value;
                        _selectedSavedLocation = _findLocation(value);
                        _manualAddressController.clear();
                      });
                    },
                  );
                }),
                const SizedBox(height: 20),
                Divider(color: Colors.grey[200]),
                const SizedBox(height: 20),
              ],
              const Text(
                'Enter a one-time pickup location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ocean,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _manualAddressController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: '123 Main Street, Toronto, ON',
                  prefixIcon: const Icon(Icons.edit_location_alt),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.ocean,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ocean,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Save Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

