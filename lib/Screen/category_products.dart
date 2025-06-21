import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../Model/MosqueModel.dart';
import '../Provider/MosqueProvider.dart';
import '../cubits/FetchMosquesCubit.dart';
import '../ui/widgets/AppBarWidget.dart';
import '../Helper/Session.dart';
import '../ui/widgets/product_list_content.dart';
import '../app/routes.dart';

class CategoryProducts extends StatefulWidget {
  final String id;
  final String title;
  const CategoryProducts({super.key, required this.id, required this.title});

  @override
  State<CategoryProducts> createState() => _CategoryProductsState();
}

class _CategoryProductsState extends State<CategoryProducts> {
  MosqueModel? _selectedMosque;

  @override
  void initState() {
    super.initState();
    context.read<FetchMosquesCubit>().fetchMosques();
    _selectedMosque = context.read<MosqueProvider>().selectedMosque;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: getAppBar(widget.title, context),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: BlocBuilder<FetchMosquesCubit, FetchMosquesState>(
              builder: (context, state) {
                List<MosqueModel> mosques = [];
                String hintText =
                    getTranslated(context, 'CHOOSE_MOSQUE') ?? 'Choose from the list';
                bool isDisabled = false;

                if (state is FetchMosquesInProgress) {
                  hintText =
                      getTranslated(context, 'LOADING_MOSQUES') ?? 'Loading mosques...';
                  isDisabled = true;
                } else if (state is FetchMosquesSuccess) {
                  mosques = state.mosques;
                } else if (state is FetchMosquesFail) {
                  hintText = getTranslated(context, 'ERROR_LOADING_MOSQUES') ??
                      'Error loading mosques';
                  isDisabled = true;
                }

                return DropdownButtonFormField<MosqueModel>(
                  isExpanded: true,
                  value: _selectedMosque,
                  dropdownColor: Theme.of(context).cardColor,
                  items: mosques.map((mosque) {
                    final isArabic =
                        Localizations.localeOf(context).languageCode == 'ar';
                    final mosqueName = isArabic
                        ? (mosque.nameAr?.isNotEmpty ?? false
                            ? mosque.nameAr!
                            : mosque.name)
                        : mosque.name;
                    final mosqueDisplay = '${mosque.id} - $mosqueName';
                    return DropdownMenuItem<MosqueModel>(
                      value: mosque,
                      child: Text(
                        mosqueDisplay,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodyMedium!.color,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: isDisabled
                      ? null
                      : (MosqueModel? mosque) {
                          if (mosque != null) {
                            setState(() => _selectedMosque = mosque);
                            context.read<MosqueProvider>().setSelectedMosque(mosque);
                          }
                        },
                  decoration: InputDecoration(
                    labelText:
                        getTranslated(context, 'SELECT_MOSQUE') ?? 'Select a Mosque',
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 14,
                    ),
                    hintText: hintText,
                    filled: true,
                    fillColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.0,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2.0,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionTile(
                      icon: Icons.clear,
                      title:
                          getTranslated(context, 'CLEAR_MOSQUE') ?? 'Clear Mosque',
                      onTap: () {
                        setState(() => _selectedMosque = null);
                        context.read<MosqueProvider>().clearSelectedMosque();
                      },
                      fontSize: 12,
                      iconSize: 18,
                      verticalPadding: 6,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionTile(
                      icon: Icons.map,
                      title: getTranslated(context, 'SELECT_FROM_MAP') ??
                          'Select from Map',
                      onTap: () {
                        Navigator.pushNamed(context, Routers.qatarMosquesScreen);
                      },
                      fontSize: 12,
                      iconSize: 18,
                      verticalPadding: 6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ProductListContent(
              id: widget.id,
              tag: false,
              fromSeller: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final double fontSize;
  final double iconSize;
  final double verticalPadding;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.fontSize = 14,
    this.iconSize = 20,
    this.verticalPadding = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding:
              EdgeInsets.symmetric(vertical: verticalPadding, horizontal: 8),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary, size: iconSize),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
