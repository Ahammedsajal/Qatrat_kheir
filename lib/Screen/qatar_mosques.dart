import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../Provider/UserProvider.dart';
import '../Provider/SettingProvider.dart';
import '../Helper/ApiBaseHelper.dart';
import '../Helper/String.dart';
import '../Screen/SkipCashWebView.dart';
import '../settings.dart';
import '../cubits/FetchMosquesCubit.dart';
import '../Model/MosqueModel.dart';
import '../Provider/MosqueProvider.dart';
import '../Helper/Session.dart';

class QatarMosques extends StatefulWidget {
  final bool isFromCheckout;
  const QatarMosques({super.key, this.isFromCheckout = false});

  @override
  _QatarMosquesState createState() => _QatarMosquesState();
}

class _QatarMosquesState extends State<QatarMosques> {
  static const LatLng _center = LatLng(25.276987, 51.520008);
  late final MapController _mapController;
  final TextEditingController _searchController = TextEditingController();

  Position? _currentPosition;
  List<MosqueModel> _mosqueSuggestions = [];
  List<String> _areaSuggestions = [];

  late final List<DateTime> _availableDates;
  late DateTime _selectedDate;

  final List<String> qatarAreaList = [
    "Gharaffa", "Al Wakra", "Muaither", "Al Rayyan", "Doha", "Al Sadd",
    "Al Gharafa", "Al Duhail", "Umm Salal", "Al Khor", "Mesaieed",
    "Al Thumama", "Lusail", "The Pearl", "Al Hilal", "Al Aziziyah",
  ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _getCurrentLocation();
    _availableDates =
        List.generate(5, (i) => DateTime.now().add(Duration(days: i + 2)));
    _selectedDate = _availableDates.first;
  }

  Widget _buildDateSelector() {
    return SizedBox(
      height: 70,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _availableDates.length,
        itemBuilder: (context, index) {
          final date = _availableDates[index];
          final selected = _selectedDate == date;
          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: Theme.of(context).colorScheme.primary),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('EEE').format(date),
                    style: TextStyle(
                        color: selected ? Colors.white : null),
                  ),
                  Text(
                    DateFormat('dd/MM').format(date),
                    style: TextStyle(
                        color: selected ? Colors.white : null),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
    }

    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() => _currentPosition = position);
  }

  void _searchLocation(String query) async {
    setState(() {
      _mosqueSuggestions.clear();
      _areaSuggestions.clear();
    });

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final location = locations.first;
        LatLng searchedLocation = LatLng(location.latitude, location.longitude);
        _mapController.move(searchedLocation, 15.0);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${getTranslated(context, "LOCATION_NOT_FOUND")}: $e")),
      );
    }
  }

  void _updateSuggestions(String query) {
  final isArabic = Localizations.localeOf(context).languageCode == "ar";

  final mosqueList = (context.read<FetchMosquesCubit>().state is FetchMosquesSuccess)
      ? (context.read<FetchMosquesCubit>().state as FetchMosquesSuccess).mosques
      : [];

 final matchedMosques = mosqueList.where((mosque) {
  final idMatch = mosque.id.contains(query);
  final nameMatch = mosque.name.toLowerCase().contains(query.toLowerCase());
  final nameArMatch = (mosque.nameAr?.toLowerCase().contains(query.toLowerCase()) ?? false);
  return idMatch || nameMatch || nameArMatch;
}).toList().cast<MosqueModel>();

  final matchedAreas = qatarAreaList
      .where((area) => area.toLowerCase().contains(query.toLowerCase()))
      .toList();

  setState(() {
    _mosqueSuggestions = matchedMosques;
    _areaSuggestions = matchedAreas;
  });
}


  void _handleSearchSelection(String query) {
    if (_mosqueSuggestions.isNotEmpty) {
      _selectMosqueFromSuggestion(_mosqueSuggestions.first);
    } else if (_areaSuggestions.isNotEmpty) {
      _searchLocation(_areaSuggestions.first);
    } else {
      _searchLocation(query);
    }
  }

  void _selectMosqueFromSuggestion(MosqueModel mosque) {
    setState(() {
      _searchController.text = mosque.name ?? "";
      _mosqueSuggestions.clear();
      _areaSuggestions.clear();
    });

    _mapController.move(
      LatLng(mosque.latitude, mosque.longitude),
      15.0,
    );

    _showConfirmationDialog(context, mosque);
  }

  @override
  Widget build(BuildContext context) {
    final mosqueProvider = context.watch<MosqueProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(getTranslated(context, "SELECT_MOSQUE_TITLE") ?? ""),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: TextField(
                controller: _searchController,
                onChanged: _updateSuggestions,
                onSubmitted: _handleSearchSelection,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: getTranslated(context, "SEARCH_HINT"),
                  hintStyle: TextStyle(color: isDark ? const Color.fromARGB(255, 255, 252, 252) : Colors.black54),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _mosqueSuggestions.clear();
                        _areaSuggestions.clear();
                      });
                    },
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.white12 : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.transparent),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.transparent),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.teal),
                  ),
                ),
              ),
            ),
            if (_mosqueSuggestions.isNotEmpty || _areaSuggestions.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black45 : Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(4),
                  shrinkWrap: true,
                  children: [
                   ..._mosqueSuggestions.map((mosque) {
  final isArabic = Localizations.localeOf(context).languageCode == "ar";
  final displayName = isArabic
      ? (mosque.nameAr?.isNotEmpty ?? false ? mosque.nameAr! : mosque.name)
      : mosque.name;

  final displayAddress = isArabic
      ? (mosque.addressAr?.isNotEmpty ?? false ? mosque.addressAr! : getTranslated(context, "NO_ADDRESS")!)
      : (mosque.address?.isNotEmpty ?? false ? mosque.address! : getTranslated(context, "NO_ADDRESS")!);

  return ListTile(
    leading: const Icon(Icons.location_on),
    title: Text('$displayName (${mosque.id})', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
    subtitle: Text(displayAddress, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
    onTap: () => _selectMosqueFromSuggestion(mosque),
  );
}),

                    ..._areaSuggestions.map((area) => ListTile(
                          leading: const Icon(Icons.place),
                          title: Text(area),
                          onTap: () => _searchLocation(area),
                        )),
                  ],
                ),
              ),
            Expanded(
              child: BlocBuilder<FetchMosquesCubit, FetchMosquesState>(
                builder: (context, state) {
                  if (state is FetchMosquesInProgress) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is FetchMosquesFail) {
                    return Center(child: Text("${getTranslated(context, "ERROR")}: ${state.error}"));
                  } else if (state is FetchMosquesSuccess) {
                    return FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(initialCenter: _center, initialZoom: 13.0),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c'],
                        ),
                        if (_currentPosition != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                width: 40,
                                height: 40,
                                point: LatLng(
                                  _currentPosition!.latitude,
                                  _currentPosition!.longitude,
                                ),
                                child: const Icon(
                                  Icons.my_location,
                                  color: Colors.blue,
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: state.mosques.map((mosque) {
                            final isSelected = (mosqueProvider.selectedMosque?.id == mosque.id);
                            return Marker(
                              width: 40,
                              height: 40,
                              point: LatLng(mosque.latitude, mosque.longitude),
                              child: GestureDetector(
                                onTap: () => _showConfirmationDialog(context, mosque),
                                child: Icon(
                                  Icons.location_on,
                                  color: isSelected ? Colors.green : Colors.red,
                                  size: 40,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  }
                  return Center(child: Text(getTranslated(context, "NO_MOSQUES_AVAILABLE")!));
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_currentPosition != null) {
            _mapController.move(
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              15.0,
            );
          }
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }

  void _showConfirmationDialog(BuildContext context, MosqueModel mosque) {
    debugPrint('dialog builder reached');

    showDialog(
      context: context,
      builder: (ctx) {
        final isArabic = Localizations.localeOf(ctx).languageCode == "ar";

        return AlertDialog(
          title: Text(getTranslated(ctx, "CONFIRM_MOSQUE_TITLE")!),
          content: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(getTranslated(ctx, "MOSQUE_ID")!, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(mosque.id),
                const SizedBox(height: 12),
                Text(getTranslated(ctx, "MOSQUE_NAME")!, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  isArabic
                      ? (mosque.nameAr?.isNotEmpty ?? false ? mosque.nameAr! : mosque.name)
                      : mosque.name,
                ),
                const SizedBox(height: 12),
                Text(getTranslated(ctx, "ADDRESS")!, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  isArabic
                      ? (mosque.addressAr?.isNotEmpty ?? false ? mosque.addressAr! : getTranslated(ctx, "NO_ADDRESS")!)
                      : (mosque.address?.isNotEmpty ?? false ? mosque.address! : getTranslated(ctx, "NO_ADDRESS")!),
                ),
                const SizedBox(height: 12),
                Text(getTranslated(ctx, "COORDINATES")!, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text("(${mosque.latitude}, ${mosque.longitude})"),
                const SizedBox(height: 12),
                _buildDateSelector(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(getTranslated(ctx, "CANCEL")!),
          ),
          ElevatedButton(
            onPressed: () {
              ctx.read<MosqueProvider>().setSelectedMosque(mosque);

              if (widget.isFromCheckout) {
                Navigator.pop(ctx);
                Navigator.pop(ctx, mosque);
              } else {
                Navigator.pop(ctx);
                _showProductsDialog();
              }
            },
            child: Text(getTranslated(ctx, "CONFIRM")!),
          ),
        ],
        );
      },
    );
  }

  void _showProductsDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(getTranslated(context, 'MOST_NEEDED_PRODUCTS') ?? 'Products'),
          content: SizedBox(
            height: 200,
            width: double.maxFinite,
            child: ListView(
              children: const [
                ListTile(title: Text('Product 1')),
                ListTile(title: Text('Product 2')),
                ListTile(title: Text('Product 3')),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(getTranslated(context, 'CANCEL') ?? 'Cancel'),
            ),
            ElevatedButton(
              onPressed: _handleBuyNow,
              child: Text(getTranslated(context, 'BUYNOW2') ?? 'Buy Now'),
            ),
          ],
        );
      },
    );
  }

  void _handleBuyNow() {
    final userProvider = context.read<UserProvider>();
    if (userProvider.mobile.isEmpty) {
      Navigator.pop(context);
      _showEnterMobileDialog();
    } else {
      Navigator.pop(context);
      _openSkipCash();
    }
  }

  void _showEnterMobileDialog() {
    final TextEditingController mobileCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(getTranslated(context, 'ENTER_MOBILE_NUMBER') ?? 'Enter mobile number'),
          content: TextField(
            controller: mobileCtrl,
            keyboardType: TextInputType.phone,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(getTranslated(context, 'CANCEL') ?? 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final mobile = mobileCtrl.text.trim();
                if (mobile.isNotEmpty) {
                  await _updateMobile(mobile);
                  Navigator.pop(ctx);
                  _openSkipCash();
                }
              },
              child: Text(getTranslated(context, 'CONFIRM') ?? 'Confirm'),
            )
          ],
        );
      },
    );
  }

  Future<void> _updateMobile(String mobile) async {
    final userProvider = context.read<UserProvider>();
    final settingProvider = context.read<SettingProvider>();
    final api = ApiBaseHelper();
    final params = {USER_ID: userProvider.userId, MOBILE: mobile};
    final res = await api.postAPICall(getUpdateUserApi, params);
    if (res['error'] == false) {
      settingProvider.setPrefrence(MOBILE, mobile);
      userProvider.setMobile(mobile);
    }
  }

  void _openSkipCash() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SkipCashWebView(
          payUrl: '${AppSettings.baseUrl}skipcash',
          paymentId: '',
          onSuccess: (_) async {},
          onError: (_) {},
        ),
      ),
    );
  }

}
