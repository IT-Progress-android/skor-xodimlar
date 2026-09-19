import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skore_hodimlar/core/localization/app_localizations.dart';
import 'package:skore_hodimlar/features/lookup/domain/entities/tashkilot_entity.dart';
import 'package:skore_hodimlar/features/lookup/presentation/bloc/lookup_bloc.dart';

class AddStaffPage extends StatefulWidget {
  const AddStaffPage({super.key});

  @override
  State<AddStaffPage> createState() => _AddStaffPageState();
}

class _AddStaffPageState extends State<AddStaffPage> {
  int _currentStep = 0;
  List<TashkilotEntity> _tashkilotlar = [];
  List<TashkilotEntity> _filtered = [];
  final _searchCtrl = TextEditingController();

  TashkilotEntity? _selectedTashkilot;

  String? _selectedBolim;
  String? _selectedLavozim;
  String? _selectedSmena;

  final _ismCtrl = TextEditingController();
  final _familiyaCtrl = TextEditingController();
  final _telefonCtrl = TextEditingController(text: '+998');
  String _jins = 'Male';

  File? _image;
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    context.read<LookupBloc>().add(LoadTashkilotlar());
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.toLowerCase();
      setState(() {
        _filtered = _tashkilotlar
            .where((t) => t.title.toLowerCase().contains(q))
            .toList();
      });
    });

    // Auto-detect gender from surname or name input
    _familiyaCtrl.addListener(_detectGenderFromInput);
    _ismCtrl.addListener(_detectGenderFromInput);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _familiyaCtrl.removeListener(_detectGenderFromInput);
    _ismCtrl.removeListener(_detectGenderFromInput);
    _ismCtrl.dispose();
    _familiyaCtrl.dispose();
    _telefonCtrl.dispose();
    super.dispose();
  }

  /// Automatically detects gender based on Uzbek/Russian surname/patronymic endings
  void _detectGenderFromInput() {
    final fam = _familiyaCtrl.text.trim().toLowerCase();
    final ism = _ismCtrl.text.trim().toLowerCase();
    final textToCheck = fam.isNotEmpty ? fam : ism;
    if (textToCheck.isEmpty) return;

    final words = textToCheck.split(RegExp(r'\s+'));
    for (final word in words.reversed) {
      // 1. Ayol (Female): -ova, -yeva, -eva, -vna, -qizi
      if (word.endsWith('ova') ||
          word.endsWith('yeva') ||
          word.endsWith('eva') ||
          word.endsWith('vna') ||
          word.endsWith('qizi') ||
          word.endsWith("qiz'i")) {
        if (_jins != 'Female') {
          setState(() => _jins = 'Female');
        }
        return;
      }
      // 2. Erkak (Male): -ov, -yev, -ev, -vich, -o'g'li
      else if (word.endsWith('ov') ||
          word.endsWith('yev') ||
          word.endsWith('ev') ||
          word.endsWith('vich') ||
          word.endsWith("o'g'li") ||
          word.endsWith("og'li") ||
          word.endsWith('ogli') ||
          word.endsWith('ugli')) {
        if (_jins != 'Male') {
          setState(() => _jins = 'Male');
        }
        return;
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await picker.pickImage(source: source, imageQuality: 70);
    if (picked != null) {
      setState(() => _image = File(picked.path));
    }
  }

  void _submit() {
    if (_selectedTashkilot == null ||
        _selectedBolim == null ||
        _selectedLavozim == null ||
        _selectedSmena == null ||
        _ismCtrl.text.trim().isEmpty ||
        _familiyaCtrl.text.trim().isEmpty ||
        _telefonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('add_staff_fill_all_fields'))),
      );
      return;
    }

    // Submitting staff payload compatible with all backend keys (gender, jins)
    final body = {
      'maktab_id': _selectedTashkilot!.id,
      'bolim': _selectedBolim,
      'lavozim': _selectedLavozim,
      'smena': _selectedSmena,
      'first_name': _ismCtrl.text.trim(),
      'last_name': _familiyaCtrl.text.trim(),
      'phone': _telefonCtrl.text.trim(),
      'gender': _jins, // 'Male' / 'Female'
      'jins': _jins == 'Male' ? 'erkak' : 'ayol', // 'erkak' / 'ayol'
    };
    context.read<LookupBloc>().add(StoreStaff(body));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('add_staff_title')),
        backgroundColor: const Color(0xFF0D6E6E),
        foregroundColor: Colors.white,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: BlocConsumer<LookupBloc, LookupState>(
        listener: (context, state) {
          if (state is TashkilotlarLoaded) {
            setState(() {
              _tashkilotlar = state.list;
              _filtered = _tashkilotlar;
            });
          }
          if (state is StaffStored) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => AlertDialog(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Text(
                  context.tr('success'),
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                content: Text(
                  context.tr('add_staff_success_desc', {
                    'name': state.fullName,
                  }),
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: const Color(0xFF334155),
                    height: 1.4,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      context.pop(); // close dialog
                      context.pop(); // close page
                    },
                    child: Text(
                      context.tr('ok'),
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF0D6E6E),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          if (state is LookupError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(primary: Color(0xFF0D6E6E)),
            ),
            child: Stepper(
              type: StepperType.vertical,
              currentStep: _currentStep,
              onStepContinue: () {
                if (_currentStep == 0) {
                  if (_selectedTashkilot == null) return;
                  context.read<LookupBloc>().add(
                    LoadMetadata(schoolName: _selectedTashkilot!.title),
                  );
                  setState(() => _currentStep++);
                } else if (_currentStep == 1) {
                  if (_selectedBolim == null ||
                      _selectedLavozim == null ||
                      _selectedSmena == null) {
                    return;
                  }
                  setState(() => _currentStep++);
                } else if (_currentStep == 2) {
                  if (_ismCtrl.text.trim().isEmpty ||
                      _familiyaCtrl.text.trim().isEmpty ||
                      _telefonCtrl.text.trim().isEmpty) {
                    return;
                  }
                  setState(() => _currentStep++);
                } else if (_currentStep == 3) {
                  _submit();
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) setState(() => _currentStep--);
              },
              steps: [
                Step(
                  title: Text(context.tr('select_org_title')),
                  isActive: _currentStep >= 0,
                  content: Column(
                    children: [
                      TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          labelText: context.tr('add_staff_search'),
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final t = _filtered[index];
                            final isSel = _selectedTashkilot?.id == t.id;
                            return ListTile(
                              title: Text(t.title),
                              selected: isSel,
                              selectedColor: const Color(0xFF0D6E6E),
                              onTap: () =>
                                  setState(() => _selectedTashkilot = t),
                              trailing: isSel
                                  ? const Icon(
                                      Icons.check,
                                      color: Color(0xFF0D6E6E),
                                    )
                                  : null,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Step(
                  title: Text(context.tr('add_staff_step2_title')),
                  isActive: _currentStep >= 1,
                  content: (state is MetadataLoaded)
                      ? Column(
                          children: [
                            DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: context.tr('department'),
                              ),
                              initialValue: _selectedBolim,
                              items: state.entity.bolimlar
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedBolim = v),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: context.tr('position'),
                              ),
                              initialValue: _selectedLavozim,
                              items: state.entity.lavozimlar
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedLavozim = v),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: context.tr('shift'),
                              ),
                              initialValue: _selectedSmena,
                              items: state.entity.smenalar
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedSmena = v),
                            ),
                          ],
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
                Step(
                  title: Text(context.tr('add_staff_step3_title')),
                  isActive: _currentStep >= 2,
                  content: Column(
                    children: [
                      TextField(
                        controller: _familiyaCtrl,
                        decoration: InputDecoration(
                          labelText: context.tr('add_staff_surname_label'),
                          hintText: context.tr('add_staff_surname_hint'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ismCtrl,
                        decoration: InputDecoration(
                          labelText: context.tr('add_staff_name_label'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _telefonCtrl,
                        decoration: InputDecoration(
                          labelText: context.tr('add_staff_phone_label'),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Text(
                            context.tr('add_staff_gender_label'),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 10),
                          ChoiceChip(
                            avatar: const Icon(Icons.man_rounded, size: 18),
                            label: Text(context.tr('add_staff_male')),
                            selected: _jins == 'Male',
                            selectedColor: const Color(0xFF0D6E6E),
                            labelStyle: TextStyle(
                              color: _jins == 'Male'
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (v) => setState(() => _jins = 'Male'),
                          ),
                          const SizedBox(width: 10),
                          ChoiceChip(
                            avatar: const Icon(Icons.woman_rounded, size: 18),
                            label: Text(context.tr('add_staff_female')),
                            selected: _jins == 'Female',
                            selectedColor: const Color(0xFF0D6E6E),
                            labelStyle: TextStyle(
                              color: _jins == 'Female'
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (v) => setState(() => _jins = 'Female'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Step(
                  title: Text(context.tr('add_staff_step4_title')),
                  isActive: _currentStep >= 3,
                  content: Column(
                    children: [
                      if (_image != null)
                        Image.file(
                          _image!,
                          height: 150,
                          width: 150,
                          fit: BoxFit.cover,
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.camera_alt),
                            onPressed: () => _pickImage(ImageSource.camera),
                          ),
                          IconButton(
                            icon: const Icon(Icons.photo),
                            onPressed: () => _pickImage(ImageSource.gallery),
                          ),
                        ],
                      ),
                      if (state is LookupLoading)
                        const CircularProgressIndicator(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
