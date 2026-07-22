import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import 'address_picker.dart';
import 'hc_common.dart';

// ── API providers ──
final _caregiversProvider = FutureProvider.autoDispose((ref) async {
  final list = await hcFetchAll(
    ref,
    '/homecare/caregivers/',
    params: {'page_size': 200},
  );
  return list
      .map((c) => c as Map)
      .map(
        (c) => {
          'id': c['id'],
          'full_name':
              c['user']?['full_name'] ??
              c['user']?['email'] ??
              'Caregiver #${c['id']}',
          'role': (c['specialties'] as List?)?.join(', ') ?? 'Caregiver',
        },
      )
      .toList();
});

final _doctorsProvider = FutureProvider.autoDispose((ref) async {
  final list = await hcFetchAll(
    ref,
    '/doctors/directory/',
    params: {'page_size': 200},
  );
  return list
      .map((d) => d as Map)
      .map(
        (d) => {
          'user': d['user'],
          'name': d['name'] ?? d['email'] ?? 'Doctor #${d['id']}',
          'email': d['email'] ?? '',
          'phone': d['phone'] ?? '',
          'specialization': d['specialization'] ?? '',
          'qualification': d['qualification'] ?? '',
          'years_of_experience': d['years_of_experience'],
          'hospital_name': d['hospital_name'] ?? '',
          'is_verified': d['is_verified'] ?? false,
        },
      )
      .toList();
});

// ── Constants ──
final _idTypes = <List<dynamic>>[
  ['national_id', 'National ID', Icons.card_membership_rounded],
  ['alien_id', 'Alien ID', Icons.badge_rounded],
  ['passport', 'Passport', Icons.badge_rounded],
  ['driving_license', 'Driving licence', Icons.card_travel_rounded],
  ['birth_cert', 'Birth certificate', Icons.verified_rounded],
  ['military_id', 'Military ID', Icons.shield_rounded],
  ['other', 'Other', Icons.credit_card_rounded],
];

const _idNumberLabels = {
  'national_id': 'ID number',
  'alien_id': 'Alien ID number',
  'passport': 'Passport number',
  'driving_license': 'Driving licence number',
  'birth_cert': 'Birth certificate number',
  'military_id': 'Military ID number',
  'other': 'Identification number',
};

final _riskLevels = <List<dynamic>>[
  ['low', 'Low', Icons.shield_rounded, hcGreen],
  ['medium', 'Medium', Icons.shield_outlined, hcAmber],
  ['high', 'High', Icons.warning_rounded, hcRed],
  ['critical', 'Critical', Icons.gpp_bad_rounded, Colors.deepOrange],
];

const _nationalities = [
  ('KE', 'Kenya', '🇰🇪'),
  ('UG', 'Uganda', '🇺🇬'),
  ('TZ', 'Tanzania', '🇹🇿'),
  ('RW', 'Rwanda', '🇷🇼'),
  ('BI', 'Burundi', '🇧🇮'),
  ('SS', 'South Sudan', '🇸🇸'),
  ('ET', 'Ethiopia', '🇪🇹'),
  ('SO', 'Somalia', '🇸🇴'),
  ('CD', 'DR Congo', '🇨🇩'),
  ('NG', 'Nigeria', '🇳🇬'),
  ('GH', 'Ghana', '🇬🇭'),
  ('ZA', 'South Africa', '🇿🇦'),
  ('GB', 'United Kingdom', '🇬🇧'),
  ('US', 'United States', '🇺🇸'),
  ('CA', 'Canada', '🇨🇦'),
  ('IN', 'India', '🇮🇳'),
  ('OTHER', 'Other', '🌐'),
];

const _relationships = [
  'Spouse',
  'Parent',
  'Child',
  'Sibling',
  'Guardian',
  'Friend',
  'Other',
];

const _specializations = [
  'General Practitioner',
  'Family Medicine',
  'Internal Medicine',
  'Paediatrics',
  'Obstetrics & Gynaecology',
  'Surgery',
  'Orthopaedics',
  'Cardiology',
  'Neurology',
  'Psychiatry',
  'Dermatology',
  'Oncology',
  'Endocrinology',
  'Gastroenterology',
  'Nephrology',
  'Pulmonology',
  'Rheumatology',
  'Urology',
  'ENT',
  'Ophthalmology',
  'Anaesthesiology',
  'Radiology',
  'Pathology',
  'Emergency Medicine',
  'Geriatrics',
  'Palliative Care',
  'Other',
];

const _comorbidityOptions = [
  'Hypertension',
  'Type 2 diabetes',
  'Type 1 diabetes',
  'Asthma',
  'COPD',
  'Chronic kidney disease',
  'Heart failure',
  'Coronary artery disease',
  'Atrial fibrillation',
  'Previous stroke',
  'Hyperlipidaemia',
  'Hypothyroidism',
  'Hyperthyroidism',
  'Osteoarthritis',
  'Rheumatoid arthritis',
  'Osteoporosis',
  'Depression',
  'Anxiety',
  'Dementia',
  'Epilepsy',
  "Parkinson's disease",
  'HIV',
  'Hepatitis B',
  'Hepatitis C',
  'Tuberculosis',
  'Cancer',
  'Obesity',
  'Sickle cell disease',
  'Peptic ulcer disease',
  'GERD',
  'Anaemia',
];

const _presentingComplaintOptions = [
  'Wound care',
  'Post-surgical recovery',
  'Pain management',
  'Medication management',
  'Mobility assistance',
  'Physiotherapy',
  'Pressure ulcer care',
  'Palliative care',
  'Chronic disease monitoring',
  'Post-stroke rehabilitation',
  'Fever',
  'Cough',
  'Shortness of breath',
  'Chest pain',
  'Fatigue',
  'Dizziness',
  'Falls',
  'Confusion',
  'Poor appetite',
  'Weight loss',
  'Swelling / oedema',
  'Catheter care',
  'Feeding tube care',
  'Elderly care',
  'Maternal / newborn care',
];

const _pastConditionOptions = [
  'Appendectomy',
  'Cholecystectomy',
  'Caesarean section',
  'Hysterectomy',
  'Hernia repair',
  'Fracture',
  'Joint replacement',
  'Cataract surgery',
  'Myocardial infarction',
  'Stroke',
  'Pneumonia',
  'Malaria',
  'Typhoid',
  'Tuberculosis',
  'Hepatitis',
  'COVID-19',
  'Deep vein thrombosis',
  'Pulmonary embolism',
  'Blood transfusion',
  'Previous hospitalisation',
  'Previous ICU admission',
  'Kidney stones',
  'Seizure',
];

const _socialFamilyOptions = [
  'Non-smoker',
  'Current smoker',
  'Ex-smoker',
  'Occasional alcohol use',
  'Regular alcohol use',
  'No alcohol use',
  'Lives alone',
  'Lives with family',
  'Has a caregiver at home',
  'Family history of diabetes',
  'Family history of hypertension',
  'Family history of heart disease',
  'Family history of cancer',
  'Family history of stroke',
  'Family history of kidney disease',
  'Family history of mental illness',
  'Sedentary lifestyle',
  'Physically active',
  'Retired',
  'Unemployed',
  'Employed',
];

const _pastMedicationOptions = [
  'Metformin',
  'Insulin',
  'Amlodipine',
  'Lisinopril',
  'Losartan',
  'Hydrochlorothiazide',
  'Atorvastatin',
  'Simvastatin',
  'Aspirin',
  'Clopidogrel',
  'Warfarin',
  'Salbutamol',
  'Prednisolone',
  'Levothyroxine',
  'Omeprazole',
  'Furosemide',
  'Bisoprolol',
  'Carvedilol',
  'Digoxin',
  'Paracetamol',
  'Ibuprofen',
  'Morphine',
  'Tramadol',
  'Amoxicillin',
  'Ceftriaxone',
  'Antiretrovirals (ARVs)',
  'Anti-TB therapy',
];

// ── Steps ──
class _Step {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _Step({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

const _steps = [
  _Step(
    title: 'Personal',
    subtitle: 'Account & demographics',
    icon: Icons.person_rounded,
    color: hcTeal,
  ),
  _Step(
    title: 'Clinical',
    subtitle: 'Diagnosis & allergies',
    icon: Icons.local_hospital_rounded,
    color: hcBlue,
  ),
  _Step(
    title: 'Medical history',
    subtitle: 'Comorbidities & background',
    icon: Icons.history_rounded,
    color: Color(0xFF0891B2),
  ),
  _Step(
    title: 'Doctor',
    subtitle: 'Responsible physician',
    icon: Icons.badge_rounded,
    color: Color(0xFF1D4ED8),
  ),
  _Step(
    title: 'Care team',
    subtitle: 'Caregivers & nurses',
    icon: Icons.groups_rounded,
    color: Color(0xFF7C3AED),
  ),
  _Step(
    title: 'Next of kin',
    subtitle: 'Emergency contacts',
    icon: Icons.contact_phone_rounded,
    color: hcRed,
  ),
];

// ═════════════════════════════════════════════════════════════════
//  SCREEN
// ═════════════════════════════════════════════════════════════════

class HomecarePatientEnrollScreen extends ConsumerStatefulWidget {
  const HomecarePatientEnrollScreen({super.key});

  @override
  ConsumerState<HomecarePatientEnrollScreen> createState() =>
      _HomecarePatientEnrollScreenState();
}

class _HomecarePatientEnrollScreenState
    extends ConsumerState<HomecarePatientEnrollScreen> {
  // Controllers
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _idNumberCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _diagnosisCtrl = TextEditingController();
  final _otherNotesCtrl = TextEditingController();
  final _manualDoctorNameCtrl = TextEditingController();
  final _manualDoctorPhoneCtrl = TextEditingController();
  final _manualDoctorEmailCtrl = TextEditingController();
  final _manualDoctorHospitalCtrl = TextEditingController();
  final _manualDoctorNotesCtrl = TextEditingController();

  int _step = 0;
  String _gender = '';
  String _idType = 'national_id';
  String _nationality = 'KE';
  String _riskLevel = 'low';
  String _doctorMode = 'directory';
  String _manualDoctorSpecialization = '';
  double? _addressLat;
  double? _addressLng;

  // Search existing
  List<Map> _searchResults = [];
  bool _searching = false;
  Map? _alreadyEnrolledExisting;
  Map? _linkedAccount;

  // Diagnosis / allergies
  List _diagnosisItems = [];
  List _allergyItems = [];
  List<String> _allergiesList = [];
  bool _loadingDiagnoses = false;
  bool _loadingAllergies = false;

  // Medical history
  List<String> _comorbidities = [];
  List<String> _presentingComplaint = [];
  List<String> _pastConditions = [];
  List<String> _socialFamily = [];
  List<String> _pastMedication = [];

  // Doctor / care team
  int? _assignedDoctorUser;
  int? _assignedCaregiverId;
  List<int> _additionalCaregivers = [];
  List<Map> _caregivers = [];
  List<Map> _doctors = [];

  // Emergency contacts
  final List<_EmergencyContact> _contacts = [];
  bool _saving = false;
  String? _topError;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _contacts.add(_EmergencyContact(isPrimary: true));
    _loadCatalogs();
  }

  @override
  void dispose() {
    for (final c in [
      _firstNameCtrl,
      _lastNameCtrl,
      _emailCtrl,
      _phoneCtrl,
      _passwordCtrl,
      _dobCtrl,
      _idNumberCtrl,
      _addressCtrl,
      _diagnosisCtrl,
      _otherNotesCtrl,
      _manualDoctorNameCtrl,
      _manualDoctorPhoneCtrl,
      _manualDoctorEmailCtrl,
      _manualDoctorHospitalCtrl,
      _manualDoctorNotesCtrl,
    ]) {
      c.dispose();
    }
    for (final c in _contacts) {
      c.dispose();
    }
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCatalogs() async {
    try {
      final dio = ref.read(dioProvider);
      final dr = await dio.get('/homecare/diagnoses/search/');
      if (mounted)
        setState(() {
          _diagnosisItems =
              ((dr.data is List ? dr.data : dr.data?['results']) as List?)
                  ?.cast<Map>() ??
              [];
        });
      final ar = await dio.get('/homecare/allergies/search/');
      if (mounted)
        setState(() {
          _allergyItems =
              ((ar.data is List ? ar.data : ar.data?['results']) as List?)
                  ?.cast<Map>() ??
              [];
        });
    } catch (_) {}
    try {
      final cg = await ref.read(_caregiversProvider.future);
      if (mounted) setState(() => _caregivers = cg.cast<Map>());
    } catch (_) {}
    try {
      final docs = await ref.read(_doctorsProvider.future);
      if (mounted) setState(() => _doctors = docs.cast<Map>());
    } catch (_) {}
  }

  // ── Search existing patients ──
  Future<void> _searchExisting(String q) async {
    if (q.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(
        '/homecare/patients/search-existing/',
        queryParameters: {'q': q.trim()},
      );
      final data = res.data;
      final rows = (data is List ? data : data?['results']) as List? ?? [];
      setState(() => _searchResults = rows.cast<Map>());
    } catch (e) {
      debugPrint('Search error: $e');
      setState(() => _searchResults = []);
    } finally {
      setState(() => _searching = false);
    }
  }

  void _onSelectExisting(Map? sel) {
    setState(() {
      if (sel == null) {
        _alreadyEnrolledExisting = null;
        _linkedAccount = null;
        _searchResults = [];
        return;
      }
      if (sel['type'] == 'homecare') {
        _alreadyEnrolledExisting = sel;
        _linkedAccount = null;
        return;
      }
      _alreadyEnrolledExisting = null;
      _linkedAccount = sel;
      _firstNameCtrl.text = sel['first_name'] ?? '';
      _lastNameCtrl.text = sel['last_name'] ?? '';
      _emailCtrl.text = sel['email'] ?? '';
      _phoneCtrl.text = sel['phone'] ?? '';
      if (sel['date_of_birth'] != null)
        _dobCtrl.text = sel['date_of_birth'].toString().substring(0, 10);
      if (sel['gender'] != null) _gender = sel['gender'];
      if (sel['national_id'] != null) {
        _idType = 'national_id';
        _idNumberCtrl.text = sel['national_id'].toString();
      }
      if (sel['address'] != null) _addressCtrl.text = sel['address'];
    });
  }

  void _clearLinked() => setState(() {
    _linkedAccount = null;
    _searchResults = [];
  });

  // ── Diagnosis/allergy search ──
  Future<void> _searchDiagnoses(String q) async {
    setState(() => _loadingDiagnoses = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(
        '/homecare/diagnoses/search/',
        queryParameters: {'q': q},
      );
      _diagnosisItems =
          ((res.data is List ? res.data : res.data?['results']) as List?)
              ?.cast<Map>() ??
          [];
    } catch (_) {}
    setState(() => _loadingDiagnoses = false);
  }

  Future<void> _searchAllergies(String q) async {
    setState(() => _loadingAllergies = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(
        '/homecare/allergies/search/',
        queryParameters: {'q': q},
      );
      _allergyItems =
          ((res.data is List ? res.data : res.data?['results']) as List?)
              ?.cast<Map>() ??
          [];
    } catch (_) {}
    setState(() => _loadingAllergies = false);
  }

  bool _validateStep(int i) {
    setState(() => _topError = null);
    if (i == 0) {
      if (_alreadyEnrolledExisting != null) {
        setState(() => _topError = 'This patient is already enrolled here.');
        return false;
      }
      if (_firstNameCtrl.text.trim().isEmpty) {
        setState(() => _topError = 'First name is required.');
        return false;
      }
      if (_lastNameCtrl.text.trim().isEmpty) {
        setState(() => _topError = 'Last name is required.');
        return false;
      }
      if (_emailCtrl.text.trim().isEmpty) {
        setState(() => _topError = 'Email is required.');
        return false;
      }
      if (_idNumberCtrl.text.trim().isEmpty) {
        setState(() => _topError = 'Identification number is required.');
        return false;
      }
    } else if (i == 1) {
      if (_diagnosisCtrl.text.trim().isEmpty) {
        setState(() => _topError = 'Primary diagnosis is required.');
        return false;
      }
    }
    return true;
  }

  void _goTo(int i) {
    if (i > _step && !_validateStep(_step)) return;
    setState(() => _step = i);
    _scrollCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _next() {
    if (!_validateStep(_step)) return;
    setState(() => _step = (_step + 1).clamp(0, _steps.length - 1));
    _scrollCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _addContact() => setState(
    () => _contacts.add(_EmergencyContact(isPrimary: _contacts.isEmpty)),
  );
  void _removeContact(int i) => setState(() => _contacts.removeAt(i));
  void _markPrimary(int i) {
    setState(() {
      for (var j = 0; j < _contacts.length; j++)
        _contacts[j].isPrimary = j == i;
    });
  }

  String _buildMedicalHistory() {
    final parts = <String>[];
    void push(String label, List<String> vals) {
      final v = vals.where((x) => x.trim().isNotEmpty).join(', ');
      if (v.isNotEmpty) parts.add('$label:\n$v');
    }

    push('Comorbidities', _comorbidities);
    push('Presenting complaint', _presentingComplaint);
    push('Past conditions', _pastConditions);
    push('Social / family history', _socialFamily);
    push('Past medication', _pastMedication);
    if (_otherNotesCtrl.text.trim().isNotEmpty)
      parts.add('Other:\n${_otherNotesCtrl.text.trim()}');
    return parts.join('\n\n');
  }

  bool _validateAll() {
    setState(() => _topError = null);
    if (_alreadyEnrolledExisting != null) {
      _step = 0;
      setState(() => _topError = 'This patient is already enrolled here.');
      return false;
    }
    if (_firstNameCtrl.text.trim().isEmpty) {
      _step = 0;
      setState(() => _topError = 'First name is required.');
      return false;
    }
    if (_lastNameCtrl.text.trim().isEmpty) {
      _step = 0;
      setState(() => _topError = 'Last name is required.');
      return false;
    }
    if (_emailCtrl.text.trim().isEmpty) {
      _step = 0;
      setState(() => _topError = 'Email is required.');
      return false;
    }
    if (_idNumberCtrl.text.trim().isEmpty) {
      _step = 0;
      setState(() => _topError = 'Identification number is required.');
      return false;
    }
    if (_diagnosisCtrl.text.trim().isEmpty) {
      _step = 1;
      setState(() => _topError = 'Primary diagnosis is required.');
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_validateAll()) return;
    setState(() {
      _saving = true;
      _topError = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final contacts = _contacts
          .where(
            (c) =>
                c.nameCtrl.text.trim().isNotEmpty &&
                c.phoneCtrl.text.trim().isNotEmpty,
          )
          .map(
            (c) => {
              'name': c.nameCtrl.text.trim(),
              'relationship': c.relationshipCtrl.text.trim(),
              'phone': c.phoneCtrl.text.trim(),
              'email': c.emailCtrl.text.trim(),
              'address': c.addressCtrl.text.trim(),
              'address_lat': c.addressLat,
              'address_lng': c.addressLng,
              'is_primary': c.isPrimary,
            },
          )
          .toList();

      final payload = <String, dynamic>{
        'user_email': _emailCtrl.text.trim(),
        'first_name': _firstNameCtrl.text.trim(),
        'last_name': _lastNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'date_of_birth': _dobCtrl.text.trim().isEmpty
            ? null
            : _dobCtrl.text.trim(),
        'gender': _gender.isEmpty ? null : _gender,
        'address': _addressCtrl.text.trim(),
        'address_lat': _addressLat,
        'address_lng': _addressLng,
        'id_type': _idType,
        'id_number': _idNumberCtrl.text.trim(),
        'nationality': _nationality,
        'primary_diagnosis': _diagnosisCtrl.text.trim(),
        'medical_history': _buildMedicalHistory(),
        'allergies': _allergiesList.join(', '),
        'risk_level': _riskLevel,
        'emergency_contacts': contacts,
      };
      if (_passwordCtrl.text.trim().isNotEmpty)
        payload['password'] = _passwordCtrl.text.trim();
      if (_doctorMode == 'directory' && _assignedDoctorUser != null) {
        payload['assigned_doctor_user_id'] = _assignedDoctorUser;
      } else if (_doctorMode == 'manual' &&
          _manualDoctorNameCtrl.text.trim().isNotEmpty) {
        payload['assigned_doctor_info'] = {
          'name': _manualDoctorNameCtrl.text.trim(),
          'specialization': _manualDoctorSpecialization,
          'phone': _manualDoctorPhoneCtrl.text.trim(),
          'email': _manualDoctorEmailCtrl.text.trim(),
          'hospital': _manualDoctorHospitalCtrl.text.trim(),
          'notes': _manualDoctorNotesCtrl.text.trim(),
        };
      }
      if (_assignedCaregiverId != null)
        payload['assigned_caregiver'] = _assignedCaregiverId;
      if (_additionalCaregivers.isNotEmpty)
        payload['additional_caregivers'] = _additionalCaregivers;

      final res = await dio.post('/homecare/patients/enroll/', data: payload);
      final data = res.data as Map;

      if (data['temporary_password'] != null) {
        if (mounted)
          _showCredentialsDialog(
            email: data['login_email'] ?? _emailCtrl.text.trim(),
            password: data['temporary_password'].toString(),
            patientId: data['id'],
            adId: data['adheremed_patient_id'] ?? '',
          );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Patient enrolled successfully')),
          );
          context.go('/homecare/patients/${data['id']}');
        }
      }
    } catch (e) {
      String msg = 'Enrolment failed.';
      try {
        final errData = (e as dynamic).response?.data;
        if (errData is Map) {
          msg =
              errData['detail']?.toString() ??
              errData.entries
                  .map(
                    (en) =>
                        '${en.key}: ${en.value is List ? (en.value as List).join(', ') : en.value}',
                  )
                  .join('\n');
        } else if (errData is String) {
          msg = errData;
        }
      } catch (_) {}
      if (mounted) setState(() => _topError = msg);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showCredentialsDialog({
    required String email,
    required String password,
    int? patientId,
    String adId = '',
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hcTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.key_rounded, color: hcTeal),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Patient login created',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share these details so the patient can sign in to their dashboard.',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              if (adId.isNotEmpty)
                _CredField(label: 'AdhereMed Patient ID', value: adId),
              _CredField(label: 'Email', value: email),
              _CredField(label: 'Temporary password', value: password),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: hcBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_rounded, size: 16, color: hcBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'The patient should change this password after their first login.',
                        style: TextStyle(fontSize: 11.5, color: hcBlue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () => ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Login details copied')),
              ),
              icon: const Icon(Icons.content_copy_rounded, size: 18),
              label: const Text('Copy'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                if (patientId != null) {
                  context.go('/homecare/patients/$patientId');
                } else {
                  context.go('/homecare/patients');
                }
              },
              style: FilledButton.styleFrom(backgroundColor: hcTeal),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Open profile'),
            ),
          ],
        );
      },
    );
  }

  int get _completion {
    var pts = 0;
    if (_firstNameCtrl.text.trim().isNotEmpty &&
        _lastNameCtrl.text.trim().isNotEmpty)
      pts++;
    if (_emailCtrl.text.trim().isNotEmpty) pts++;
    if (_diagnosisCtrl.text.trim().isNotEmpty) pts++;
    if (_assignedCaregiverId != null) pts++;
    if (_contacts.any(
      (c) =>
          c.nameCtrl.text.trim().isNotEmpty &&
          c.phoneCtrl.text.trim().isNotEmpty,
    ))
      pts++;
    if (_dobCtrl.text.trim().isNotEmpty || _addressCtrl.text.trim().isNotEmpty)
      pts++;
    return ((pts / 6) * 100).round();
  }

  Map? get _selectedDoctorObj {
    if (_assignedDoctorUser == null) return null;
    try {
      return _doctors.firstWhere((d) => d['user'] == _assignedDoctorUser);
    } catch (_) {
      return null;
    }
  }

  List<Map> get _additionalChoices =>
      _caregivers.where((c) => c['id'] != _assignedCaregiverId).toList();
  List<Map> get _selectedCaregiverDetails {
    final ids = [
      if (_assignedCaregiverId != null) _assignedCaregiverId,
      ..._additionalCaregivers,
    ];
    return _caregivers.where((c) => ids.contains(c['id'])).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark
        ? Border.all(color: Colors.white.withValues(alpha: 0.08))
        : Border.all(color: const Color(0xFF0F172A).withValues(alpha: 0.06));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enrol a patient'),
        actions: [
          TextButton(
            onPressed: () => context.go('/homecare/patients'),
            child: const Text('Cancel'),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            _buildHero(),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (MediaQuery.of(context).size.width > 600)
                  _buildSideStepper(cs, cardBg, cardBorder),
                Expanded(
                  child: _buildFormCard(context, cs, cardBg, cardBorder),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D9488), Color(0xFF0EA5A4), Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            ),
            child: const Icon(
              Icons.person_add_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HOMECARE · NEW PATIENT',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Enrol a patient',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Set up the patient profile, clinical context, care team and emergency contacts.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideStepper(ColorScheme cs, Color cardBg, Border cardBorder) {
    return SizedBox(
      width: 200,
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          border: cardBorder,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PROGRESS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _steps.length; i++) ...[
              _StepIndicator(
                index: i,
                current: _step,
                step: _steps[i],
                onTap: () => _goTo(i),
              ),
              if (i < _steps.length - 1) const SizedBox(height: 2),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(),
            ),
            Text(
              'COMPLETION',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _completion / 100,
                minHeight: 6,
                color: hcTeal,
              ),
            ),
            Text(
              '$_completion%',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard(
    BuildContext context,
    ColorScheme cs,
    Color cardBg,
    Border cardBorder,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        border: cardBorder,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(context),
          const SizedBox(height: 20),
          _buildStepBody(context),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          if (_topError != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hcRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _topError!,
                style: const TextStyle(color: hcRed, fontSize: 13),
              ),
            ),
          Row(
            children: [
              TextButton.icon(
                onPressed: _step == 0 ? null : () => setState(() => _step--),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Previous'),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.go('/homecare/patients'),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              if (_step < _steps.length - 1)
                FilledButton.icon(
                  onPressed: _next,
                  style: FilledButton.styleFrom(backgroundColor: hcTeal),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Next'),
                ),
            ],
          ),
          if (_step == _steps.length - 1) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(backgroundColor: hcTeal),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text('Enrol patient'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepHeader(BuildContext context) {
    final s = _steps[_step];
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: s.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(s.icon, color: s.color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STEP ${_step + 1} OF ${_steps.length}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: s.color,
                ),
              ),
              Text(
                s.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              Text(
                s.subtitle,
                style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepBody(BuildContext context) {
    switch (_step) {
      case 0:
        return _buildPersonalInfoStep(context);
      case 1:
        return _buildClinicalStep(context);
      case 2:
        return _buildMedicalHistoryStep(context);
      case 3:
        return _buildDoctorStep(context);
      case 4:
        return _buildCareTeamStep(context);
      case 5:
        return _buildEmergencyContactsStep(context);
      default:
        return const SizedBox.shrink();
    }
  }

  // ═══════════════════ STEP 0: Personal info ═══════════════════
  Widget _buildPersonalInfoStep(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                hcTeal.withValues(alpha: 0.06),
                hcBlue.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: hcTeal.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.search_rounded, color: hcTeal, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Find an existing patient',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _PatientSearchField(
                results: _searchResults,
                loading: _searching,
                onSearch: _searchExisting,
                onSelect: _onSelectExisting,
                onClear: _clearLinked,
              ),
              if (_alreadyEnrolledExisting != null)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: hcAmber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: hcAmber,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_alreadyEnrolledExisting!['full_name'] ?? 'This patient'} is already enrolled.',
                          style: const TextStyle(fontSize: 12, color: hcAmber),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_linkedAccount != null)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: hcTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link_rounded, color: hcTeal, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Linked to ${_linkedAccount!['email']} — details prefilled.',
                          style: const TextStyle(fontSize: 12, color: hcTeal),
                        ),
                      ),
                      TextButton(
                        onPressed: _clearLinked,
                        child: const Text(
                          'Unlink',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_alreadyEnrolledExisting == null && _linkedAccount == null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    "Can't find them? Fill in the details below.",
                    style: TextStyle(
                      fontSize: 11.5,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Each field on its own row to avoid overflow ──
        TextField(
          controller: _firstNameCtrl,
          decoration: const InputDecoration(
            labelText: 'First name *',
            prefixIcon: Icon(Icons.person_rounded),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _lastNameCtrl,
          decoration: const InputDecoration(labelText: 'Last name *'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          readOnly: _linkedAccount != null,
          decoration: InputDecoration(
            labelText: 'Email *',
            prefixIcon: const Icon(Icons.email_rounded),
            helperText: _linkedAccount != null
                ? 'Locked - linked to an existing account'
                : null,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone',
            prefixIcon: Icon(Icons.phone_rounded),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _dobCtrl,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Date of birth',
            prefixIcon: Icon(Icons.calendar_today_rounded),
          ),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
              initialDate: DateTime.now().subtract(
                const Duration(days: 365 * 30),
              ),
            );
            if (d != null) {
              _dobCtrl.text =
                  '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
              setState(() {});
            }
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _gender.isEmpty ? null : _gender,
          decoration: const InputDecoration(
            labelText: 'Gender',
            prefixIcon: Icon(Icons.wc_rounded),
          ),
          items: const [
            DropdownMenuItem(value: 'Male', child: Text('Male')),
            DropdownMenuItem(value: 'Female', child: Text('Female')),
            DropdownMenuItem(value: 'Other', child: Text('Other')),
            DropdownMenuItem(
              value: 'Prefer not to say',
              child: Text('Prefer not to say'),
            ),
          ],
          onChanged: (v) => setState(() => _gender = v ?? ''),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passwordCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Initial password',
            prefixIcon: Icon(Icons.lock_rounded),
            helperText: 'Patient can change it later',
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _idType,
          decoration: const InputDecoration(
            labelText: 'Identification type *',
            prefixIcon: Icon(Icons.card_membership_rounded),
          ),
          items: _idTypes
              .map(
                (t) => DropdownMenuItem(
                  value: t[0] as String,
                  child: Row(
                    children: [
                      Icon(t[2] as IconData, size: 16),
                      const SizedBox(width: 8),
                      Text(t[1] as String),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _idType = v ?? 'national_id'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _idNumberCtrl,
          decoration: InputDecoration(
            labelText:
                '${_idNumberLabels[_idType] ?? 'Identification number'} *',
            prefixIcon: const Icon(Icons.tag_rounded),
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _nationality,
          decoration: const InputDecoration(
            labelText: 'Nationality',
            prefixIcon: Icon(Icons.flag_rounded),
          ),
          items: _nationalities
              .map(
                (n) => DropdownMenuItem(
                  value: n.$1,
                  child: Row(
                    children: [
                      Text(n.$3, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(n.$2),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _nationality = v ?? 'KE'),
        ),
        const SizedBox(height: 10),
        HcAddressPicker(
          initialAddress: _addressCtrl.text,
          onPicked: (result) {
            _addressCtrl.text = result.address;
            _addressLat = result.lat;
            _addressLng = result.lng;
            setState(() {});
          },
        ),
      ],
    );
  }

  // ═══════════════════ STEP 1: Clinical ═══════════════════
  Widget _buildClinicalStep(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Primary diagnosis — dropdown combobox from catalog + manual entry
        _DiagnosisComboBox(
          controller: _diagnosisCtrl,
          items: _diagnosisItems,
          loading: _loadingDiagnoses,
          onSearch: _searchDiagnoses,
        ),
        const SizedBox(height: 10),
        Text(
          'Risk level',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _riskLevels
              .map(
                (r) => ChoiceChip(
                  selected: _riskLevel == r[0],
                  avatar: Icon(
                    r[2] as IconData,
                    size: 16,
                    color: r[3] as Color,
                  ),
                  label: Text(r[1] as String),
                  selectedColor: (r[3] as Color).withValues(alpha: 0.15),
                  onSelected: (_) =>
                      setState(() => _riskLevel = r[0] as String),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        // Allergies — dropdown multi-select combobox with closable chips
        _AllergyComboBox(
          items: _allergyItems,
          loading: _loadingAllergies,
          selected: _allergiesList,
          onAdd: (val) {
            if (val.isNotEmpty && !_allergiesList.contains(val)) {
              setState(() => _allergiesList.add(val));
            }
          },
          onRemove: (val) {
            setState(() => _allergiesList.remove(val));
          },
          onSearch: _searchAllergies,
        ),
      ],
    );
  }

  // ═══════════════════ STEP 2: Medical history ═══════════════════
  Widget _buildMedicalHistoryStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MultiComboChips(
          label: 'Comorbidities',
          options: _comorbidityOptions,
          selected: _comorbidities,
          icon: Icons.list_alt_rounded,
          color: const Color(0xFF0891B2),
          onChanged: (v) => setState(() => _comorbidities = v),
        ),
        const SizedBox(height: 14),
        _MultiComboChips(
          label: 'Presenting complaint',
          options: _presentingComplaintOptions,
          selected: _presentingComplaint,
          icon: Icons.chat_rounded,
          color: const Color(0xFF0891B2),
          onChanged: (v) => setState(() => _presentingComplaint = v),
        ),
        const SizedBox(height: 14),
        _MultiComboChips(
          label: 'Past conditions',
          options: _pastConditionOptions,
          selected: _pastConditions,
          icon: Icons.history_rounded,
          color: const Color(0xFF0891B2),
          onChanged: (v) => setState(() => _pastConditions = v),
        ),
        const SizedBox(height: 14),
        _MultiComboChips(
          label: 'Social / family history',
          options: _socialFamilyOptions,
          selected: _socialFamily,
          icon: Icons.people_rounded,
          color: const Color(0xFF0891B2),
          onChanged: (v) => setState(() => _socialFamily = v),
        ),
        const SizedBox(height: 14),
        _MultiComboChips(
          label: 'Past medication',
          options: _pastMedicationOptions,
          selected: _pastMedication,
          icon: Icons.medication_rounded,
          color: hcTeal,
          onChanged: (v) => setState(() => _pastMedication = v),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _otherNotesCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Any other notes',
            prefixIcon: Icon(Icons.note_rounded),
            helperText: 'Additional clinical notes',
          ),
        ),
      ],
    );
  }

  // ═══════════════════ STEP 3: Doctor ═══════════════════
  Widget _buildDoctorStep(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'directory',
              label: Text('Directory'),
              icon: Icon(Icons.search_rounded, size: 18),
            ),
            ButtonSegment(
              value: 'manual',
              label: Text('Manual'),
              icon: Icon(Icons.edit_rounded, size: 18),
            ),
          ],
          selected: {_doctorMode},
          onSelectionChanged: (v) => setState(() => _doctorMode = v.first),
        ),
        const SizedBox(height: 16),
        if (_doctorMode == 'directory') ..._buildDoctorDirectory(cs),
        if (_doctorMode == 'manual') ..._buildDoctorManual(),
      ],
    );
  }

  List<Widget> _buildDoctorDirectory(ColorScheme cs) {
    return [
      TextField(
        decoration: const InputDecoration(
          labelText: 'Responsible doctor',
          prefixIcon: Icon(Icons.badge_rounded),
          helperText: 'Searchable list of verified doctors',
        ),
        onChanged: (v) {
          if (v.length > 1) {
            final q = v.toLowerCase();
            final match = _doctors
                .where(
                  (d) =>
                      (d['name']?.toString() ?? '').toLowerCase().contains(q),
                )
                .toList();
            if (match.isNotEmpty) {
              setState(() {
                _assignedDoctorUser = match.first['user'];
              });
            }
          }
        },
      ),
      if (_selectedDoctorObj != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hcTeal.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: hcTeal.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.badge_rounded,
                  color: Color(0xFF1D4ED8),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_selectedDoctorObj!['name']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (_selectedDoctorObj!['is_verified'] == true)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: hcGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Verified',
                              style: TextStyle(fontSize: 9, color: hcGreen),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '${_selectedDoctorObj!['specialization'] ?? 'General practitioner'}${_selectedDoctorObj!['qualification'] != null ? ' · ${_selectedDoctorObj!['qualification']}' : ''}',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    Text(
                      '${_selectedDoctorObj!['email']}${_selectedDoctorObj!['phone'] != null ? ' · ${_selectedDoctorObj!['phone']}' : ''}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      if (_selectedDoctorObj == null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            "Can't find the doctor? Switch to Manual above.",
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ),
    ];
  }

  List<Widget> _buildDoctorManual() {
    return [
      TextField(
        controller: _manualDoctorNameCtrl,
        decoration: const InputDecoration(
          labelText: 'Doctor full name *',
          prefixIcon: Icon(Icons.badge_rounded),
        ),
      ),
      const SizedBox(height: 10),
      _buildSpecializationField(),
      const SizedBox(height: 10),
      TextField(
        controller: _manualDoctorPhoneCtrl,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
          labelText: 'Phone',
          prefixIcon: Icon(Icons.phone_rounded),
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _manualDoctorEmailCtrl,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: 'Email',
          prefixIcon: Icon(Icons.email_rounded),
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _manualDoctorHospitalCtrl,
        decoration: const InputDecoration(
          labelText: 'Hospital / clinic',
          prefixIcon: Icon(Icons.local_hospital_rounded),
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _manualDoctorNotesCtrl,
        maxLines: 2,
        decoration: const InputDecoration(
          labelText: 'Additional notes',
          prefixIcon: Icon(Icons.note_rounded),
        ),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: hcAmber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 16, color: hcAmber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "This doctor is recorded for reference only and won't have a system login.",
                style: TextStyle(fontSize: 12, color: hcAmber),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildSpecializationField() {
    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return _specializations;
        return _specializations.where(
          (s) => s.toLowerCase().contains(textEditingValue.text.toLowerCase()),
        );
      },
      onSelected: (v) => setState(() => _manualDoctorSpecialization = v),
      fieldViewBuilder: (context, ctrl, focusNode, onSubmitted) {
        ctrl.text = _manualDoctorSpecialization;
        return TextField(
          controller: ctrl,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Specialization',
            prefixIcon: Icon(Icons.medical_information_rounded),
          ),
          onChanged: (v) => setState(() => _manualDoctorSpecialization = v),
          onSubmitted: (_) => onSubmitted(),
        );
      },
    );
  }

  // ═══════════════════ STEP 4: Care team ═══════════════════
  Widget _buildCareTeamStep(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Primary caregiver / nurse',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        _CaregiverDropdown(
          caregivers: _caregivers,
          selectedId: _assignedCaregiverId,
          onChanged: (id) => setState(() => _assignedCaregiverId = id),
        ),
        const SizedBox(height: 14),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Additional caregivers / nurses',
            prefixIcon: Icon(Icons.group_add_rounded),
            helperText: "They'll all see this patient on their roster.",
          ),
          onChanged: (v) {
            if (v.length > 1) {
              final q = v.toLowerCase();
              final match = _additionalChoices
                  .where(
                    (c) => (c['full_name']?.toString() ?? '')
                        .toLowerCase()
                        .contains(q),
                  )
                  .toList();
              if (match.isNotEmpty &&
                  !_additionalCaregivers.contains(match.first['id'])) {
                setState(() => _additionalCaregivers.add(match.first['id']));
              }
            }
          },
        ),
        if (_additionalCaregivers.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _additionalCaregivers
                .map(
                  (id) => Chip(
                    avatar: const Icon(
                      Icons.person_rounded,
                      size: 14,
                      color: hcPurple,
                    ),
                    label: Text(
                      _caregivers
                              .where((c) => c['id'] == id)
                              .firstOrNull?['full_name']
                              ?.toString() ??
                          '',
                      style: const TextStyle(fontSize: 12),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    backgroundColor: hcPurple.withValues(alpha: 0.08),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                    onDeleted: () =>
                        setState(() => _additionalCaregivers.remove(id)),
                  ),
                )
                .toList(),
          ),
        ],
        if (_selectedCaregiverDetails.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'Assigned care team',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          for (final c in _selectedCaregiverDetails)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hcTeal.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: hcTeal.withValues(alpha: 0.18)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: hcTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.medical_services_rounded,
                      size: 20,
                      color: hcTeal,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c['full_name']?.toString() ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          c['role']?.toString() ?? '',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  // ═══════════════════ STEP 5: Emergency contacts ═══════════════════
  Widget _buildEmergencyContactsStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _contacts.length; i++) ...[
          _ContactCard(
            contact: _contacts[i],
            index: i,
            onRemove: _contacts.length > 1 ? () => _removeContact(i) : null,
            onMarkPrimary: () => _markPrimary(i),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          onPressed: _addContact,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add another contact'),
          style: OutlinedButton.styleFrom(
            foregroundColor: hcTeal,
            side: const BorderSide(color: hcTeal),
          ),
        ),
        if (_contacts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Icon(
                  Icons.info_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "It's recommended to add at least one emergency contact.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════
//  SUB-WIDGETS
// ═════════════════════════════════════════════════════════════════

class _EmergencyContact {
  final nameCtrl = TextEditingController();
  final relationshipCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  double? addressLat;
  double? addressLng;
  bool isPrimary;
  _EmergencyContact({this.isPrimary = false});
  void dispose() {
    nameCtrl.dispose();
    relationshipCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    addressCtrl.dispose();
  }
}

class _StepIndicator extends StatelessWidget {
  final int index;
  final int current;
  final _Step step;
  final VoidCallback onTap;
  const _StepIndicator({
    required this.index,
    required this.current,
    required this.step,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    final isDone = index < current;
    final bg = isDone
        ? hcGreen
        : isActive
        ? hcTeal
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);
    final fg = (isDone || isActive) ? Colors.white : Colors.grey;
    final titleColor = isActive || isDone
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: isDone
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    )
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: titleColor,
                    ),
                  ),
                  Text(
                    step.subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
}

/// Simple inline search field with results listed below (no overlay).
class _PatientSearchField extends StatefulWidget {
  final List<Map> results;
  final bool loading;
  final ValueChanged<String> onSearch;
  final ValueChanged<Map?> onSelect;
  final VoidCallback onClear;
  const _PatientSearchField({
    required this.results,
    required this.loading,
    required this.onSearch,
    required this.onSelect,
    required this.onClear,
  });

  @override
  State<_PatientSearchField> createState() => _PatientSearchFieldState();
}

class _PatientSearchFieldState extends State<_PatientSearchField> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _ctrl,
          decoration: InputDecoration(
            hintText: 'Search by ID, name, phone or email…',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: widget.loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _ctrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _ctrl.clear();
                      widget.onSelect(null);
                      widget.onSearch('');
                    },
                  )
                : null,
          ),
          onChanged: widget.onSearch,
        ),
        // Show results inline if there are any and the field has content
        if (widget.results.isNotEmpty && _ctrl.text.trim().length >= 2)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: widget.results.length,
              itemBuilder: (_, i) {
                final r = widget.results[i];
                final fullName =
                    r['full_name'] ??
                    '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim() ??
                    r['email'];
                final isHc = r['type'] == 'homecare';
                return ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isHc
                          ? hcTeal.withValues(alpha: 0.1)
                          : Colors.blueGrey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isHc ? Icons.favorite_rounded : Icons.person_rounded,
                      size: 16,
                      color: isHc ? hcTeal : Colors.blueGrey,
                    ),
                  ),
                  title: Text(
                    '$fullName',
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    '${r['medical_record_number'] ?? r['patient_id'] ?? r['adheremed_patient_id'] ?? ''}${r['email'] != null ? ' · ${r['email']}' : ''}${r['phone'] != null ? ' · ${r['phone']}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isHc
                          ? hcTeal.withValues(alpha: 0.1)
                          : hcBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isHc ? 'Enrolled' : 'Has login',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isHc ? hcTeal : hcBlue,
                      ),
                    ),
                  ),
                  onTap: () {
                    widget.onSelect(r);
                    _ctrl.text = fullName.toString();
                    setState(() {});
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

class _MultiComboChips extends StatefulWidget {
  final String label;
  final List<String> options;
  final List<String> selected;
  final IconData icon;
  final Color color;
  final ValueChanged<List<String>> onChanged;
  const _MultiComboChips({
    required this.label,
    required this.options,
    required this.selected,
    required this.icon,
    required this.color,
    required this.onChanged,
  });

  @override
  State<_MultiComboChips> createState() => _MultiComboChipsState();
}

class _MultiComboChipsState extends State<_MultiComboChips> {
  final LayerLink _layerLink = LayerLink();
  final _ctrl = TextEditingController();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  void _openOverlay() {
    if (_isOpen) return;
    _isOpen = true;
    _overlayEntry = _createOverlay();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closeOverlay() {
    if (!_isOpen) return;
    _isOpen = false;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlay() {
    final renderBox = context.findRenderObject() as RenderBox;
    final width = renderBox.size.width;
    return OverlayEntry(
      builder: (context) => _MultiComboDropdown(
        layerLink: _layerLink,
        width: width,
        options: widget.options,
        selected: widget.selected,
        color: widget.color,
        onSelected: (val) {
          if (!widget.selected.contains(val)) {
            widget.onChanged([...widget.selected, val]);
          }
          _ctrl.clear();
          setState(() {});
        },
        onClose: _closeOverlay,
      ),
    );
  }

  @override
  void dispose() {
    _closeOverlay();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label
          Row(
            children: [
              Icon(widget.icon, size: 14, color: widget.color),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Selected chips
          if (widget.selected.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.selected
                  .map(
                    (s) => Chip(
                      avatar: Icon(widget.icon, size: 14, color: widget.color),
                      label: Text(s, style: const TextStyle(fontSize: 11.5)),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      backgroundColor: widget.color.withValues(alpha: 0.08),
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                      onDeleted: () {
                        widget.onChanged(
                          widget.selected.where((x) => x != s).toList(),
                        );
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 4),
          ],
          // Input field — tap to open dropdown
          GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
              _openOverlay();
            },
            child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                hintText: 'Select from list or type & press enter…',
                isDense: true,
                prefixIcon: Icon(widget.icon, size: 18, color: widget.color),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_ctrl.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle_rounded,
                          color: hcTeal,
                          size: 20,
                        ),
                        onPressed: () {
                          final v = _ctrl.text.trim();
                          if (v.isNotEmpty && !widget.selected.contains(v)) {
                            widget.onChanged([...widget.selected, v]);
                          }
                          _ctrl.clear();
                          _closeOverlay();
                          setState(() {});
                        },
                      )
                    else
                      const SizedBox.shrink(),
                    IconButton(
                      icon: Icon(
                        _isOpen
                            ? Icons.arrow_drop_up_rounded
                            : Icons.arrow_drop_down_rounded,
                      ),
                      onPressed: () {
                        if (_isOpen) {
                          _closeOverlay();
                        } else {
                          _openOverlay();
                        }
                        setState(() {});
                      },
                    ),
                  ],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: widget.color, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onChanged: (v) {
                if (!_isOpen) _openOverlay();
                setState(() {});
              },
              onSubmitted: (v) {
                final val = v.trim();
                if (val.isNotEmpty && !widget.selected.contains(val)) {
                  widget.onChanged([...widget.selected, val]);
                }
                _ctrl.clear();
                _closeOverlay();
                setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Dropdown overlay body for _MultiComboChips — shows all available options.
class _MultiComboDropdown extends StatelessWidget {
  final LayerLink layerLink;
  final double width;
  final List<String> options;
  final List<String> selected;
  final Color color;
  final ValueChanged<String> onSelected;
  final VoidCallback onClose;

  const _MultiComboDropdown({
    required this.layerLink,
    required this.width,
    required this.options,
    required this.selected,
    required this.color,
    required this.onSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final available = options.where((o) => !selected.contains(o)).toList();
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onClose,
          child: Container(color: Colors.black26),
        ),
        CompositedTransformFollower(
          link: layerLink,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 6),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(14),
            color: cs.surface,
            child: Container(
              width: width,
              constraints: const BoxConstraints(maxHeight: 240),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: available.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 28,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'All options selected',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: available.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: cs.outlineVariant),
                      itemBuilder: (_, i) {
                        final name = available[i];
                        final already = selected.contains(name);
                        return ListTile(
                          dense: true,
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              size: 16,
                              color: color,
                            ),
                          ),
                          title: Text(
                            name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: already ? cs.onSurfaceVariant : null,
                            ),
                          ),
                          trailing: already
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: cs.onSurfaceVariant,
                                )
                              : null,
                          onTap: already ? null : () => onSelected(name),
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Single-select dropdown combobox for picking the primary caregiver / nurse.
/// Uses an overlay with the full list — similar to the nuxtfrontend v-autocomplete.
class _CaregiverDropdown extends StatefulWidget {
  final List<Map> caregivers;
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  const _CaregiverDropdown({
    required this.caregivers,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  State<_CaregiverDropdown> createState() => _CaregiverDropdownState();
}

class _CaregiverDropdownState extends State<_CaregiverDropdown> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  Map? get _selected {
    if (widget.selectedId == null) return null;
    try {
      return widget.caregivers.firstWhere((c) => c['id'] == widget.selectedId);
    } catch (_) {
      return null;
    }
  }

  void _openOverlay() {
    if (_isOpen || widget.caregivers.isEmpty) return;
    _isOpen = true;
    final renderBox = context.findRenderObject() as RenderBox;
    final width = renderBox.size.width;
    _overlayEntry = OverlayEntry(
      builder: (context) => _CaregiverDropdownOverlay(
        layerLink: _layerLink,
        width: width,
        caregivers: widget.caregivers,
        selectedId: widget.selectedId,
        onSelected: (id) {
          widget.onChanged(id);
          _closeOverlay();
          setState(() {});
        },
        onClose: _closeOverlay,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closeOverlay() {
    if (!_isOpen) return;
    _isOpen = false;
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _closeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sel = _selected;
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          _openOverlay();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant),
            color: cs.surface,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: hcTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.star_rounded, size: 18, color: hcTeal),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: sel == null
                    ? Text('Select a caregiver / nurse…',
                        style: TextStyle(
                            fontSize: 14, color: cs.onSurfaceVariant))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            sel['full_name']?.toString() ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          Text(
                            sel['role']?.toString() ?? '',
                            style: TextStyle(
                                fontSize: 11.5, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
              ),
              if (sel != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Clear selection',
                  onPressed: () {
                    widget.onChanged(null);
                    setState(() {});
                  },
                ),
              Icon(
                _isOpen
                    ? Icons.arrow_drop_up_rounded
                    : Icons.arrow_drop_down_rounded,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Overlay body for the caregiver dropdown.
class _CaregiverDropdownOverlay extends StatelessWidget {
  final LayerLink layerLink;
  final double width;
  final List<Map> caregivers;
  final int? selectedId;
  final ValueChanged<int?> onSelected;
  final VoidCallback onClose;

  const _CaregiverDropdownOverlay({
    required this.layerLink,
    required this.width,
    required this.caregivers,
    required this.selectedId,
    required this.onSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onClose,
          child: Container(color: Colors.black26),
        ),
        CompositedTransformFollower(
          link: layerLink,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 6),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(14),
            color: cs.surface,
            child: Container(
              width: width,
              constraints: const BoxConstraints(maxHeight: 280),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: caregivers.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 28, color: cs.onSurfaceVariant),
                            const SizedBox(height: 8),
                            Text('No caregivers available',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: caregivers.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: cs.outlineVariant),
                      itemBuilder: (_, i) {
                        final c = caregivers[i];
                        final isSelected = c['id'] == selectedId;
                        return ListTile(
                          dense: true,
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: hcTeal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.medical_services_rounded,
                                size: 16, color: hcTeal),
                          ),
                          title: Text(
                            c['full_name']?.toString() ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? hcTeal
                                  : cs.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            c['role']?.toString() ?? '',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded,
                                  size: 18, color: hcTeal)
                              : null,
                          onTap: () => onSelected(c['id']),
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ContactCard extends StatefulWidget {
  final _EmergencyContact contact;
  final int index;
  final VoidCallback? onRemove;
  final VoidCallback onMarkPrimary;
  const _ContactCard({
    required this.contact,
    required this.index,
    this.onRemove,
    required this.onMarkPrimary,
  });

  @override
  State<_ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends State<_ContactCard> {
  @override
  Widget build(BuildContext context) {
    final c = widget.contact;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hcRed.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hcRed.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: hcRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.contact_phone_rounded,
                  color: hcRed,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Contact ${widget.index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (widget.onRemove != null)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: hcRed,
                  ),
                  onPressed: widget.onRemove,
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: c.nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Full name *',
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: c.relationshipCtrl,
            decoration: const InputDecoration(
              labelText: 'Relationship',
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: c.phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone *',
              prefixIcon: Icon(Icons.phone_rounded, size: 16),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: c.emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_rounded, size: 16),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: c.addressCtrl,
            decoration: const InputDecoration(
              labelText: 'Address (optional)',
              prefixIcon: Icon(Icons.home_rounded, size: 16),
              isDense: true,
            ),
          ),
          if (c.addressLat != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Row(
                children: [
                  Icon(Icons.gps_fixed_rounded, size: 12, color: hcTeal),
                  const SizedBox(width: 4),
                  Text(
                    '${c.addressLat!.toStringAsFixed(5)}, ${c.addressLng!.toStringAsFixed(5)}',
                    style: const TextStyle(fontSize: 11, color: hcTeal),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Checkbox(
                value: c.isPrimary,
                activeColor: hcTeal,
                onChanged: (_) => widget.onMarkPrimary(),
              ),
              const Text('Primary contact', style: TextStyle(fontSize: 12.5)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CredField extends StatelessWidget {
  final String label;
  final String value;
  const _CredField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Diagnosis dropdown combobox — tappable field that opens an overlay overlay
/// overlay with catalog suggestions. Mimics the v-combobox pattern from the
/// nuxtfrontend: pick from the catalog or type your own.
class _DiagnosisComboBox extends StatefulWidget {
  final TextEditingController controller;
  final List items;
  final bool loading;
  final ValueChanged<String> onSearch;

  const _DiagnosisComboBox({
    required this.controller,
    required this.items,
    required this.loading,
    required this.onSearch,
  });

  @override
  State<_DiagnosisComboBox> createState() => _DiagnosisComboBoxState();
}

class _DiagnosisComboBoxState extends State<_DiagnosisComboBox> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  void _openOverlay() {
    if (_isOpen) return;
    _isOpen = true;
    _overlayEntry = _createOverlay();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closeOverlay() {
    if (!_isOpen) return;
    _isOpen = false;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlay() {
    final renderBox = context.findRenderObject() as RenderBox;
    final width = renderBox.size.width;
    return OverlayEntry(
      builder: (context) => _DiagnosisDropdown(
        layerLink: _layerLink,
        width: width,
        items: widget.items,
        loading: widget.loading,
        onSelected: (name) {
          widget.controller.text = name;
          widget.controller.selection = TextSelection.fromPosition(
            TextPosition(offset: name.length),
          );
          _closeOverlay();
          setState(() {});
        },
        onClose: _closeOverlay,
      ),
    );
  }

  @override
  void dispose() {
    _closeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          _openOverlay();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: widget.controller,
              decoration: InputDecoration(
                labelText: 'Primary diagnosis *',
                hintText: 'Pick from catalog or type your own',
                prefixIcon: const Icon(Icons.assignment_rounded),
                suffixIcon: widget.loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.controller.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                widget.controller.clear();
                                _closeOverlay();
                                setState(() {});
                              },
                            )
                          else
                            const SizedBox.shrink(),
                          IconButton(
                            icon: Icon(
                              _isOpen
                                  ? Icons.arrow_drop_up_rounded
                                  : Icons.arrow_drop_down_rounded,
                            ),
                            onPressed: () {
                              if (_isOpen) {
                                _closeOverlay();
                              } else {
                                _openOverlay();
                              }
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                helperText: 'Tap to search the diagnosis catalog',
                helperMaxLines: 2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: hcTeal, width: 1.5),
                ),
              ),
              onChanged: (v) {
                if (v.trim().length >= 2) widget.onSearch(v);
                if (!_isOpen) _openOverlay();
                setState(() {});
              },
              onSubmitted: (_) => _closeOverlay(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width dropdown overlay body for the diagnosis combo.
class _DiagnosisDropdown extends StatelessWidget {
  final LayerLink layerLink;
  final double width;
  final List items;
  final bool loading;
  final ValueChanged<String> onSelected;
  final VoidCallback onClose;

  const _DiagnosisDropdown({
    required this.layerLink,
    required this.width,
    required this.items,
    required this.loading,
    required this.onSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onClose,
          child: Container(color: Colors.black26),
        ),
        CompositedTransformFollower(
          link: layerLink,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 6),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(14),
            color: cs.surface,
            child: Container(
              width: width,
              constraints: const BoxConstraints(maxHeight: 260),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 28,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No matching diagnoses in catalog',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Type your own and press enter.',
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: cs.outlineVariant),
                      itemBuilder: (_, i) {
                        final d = items[i] as Map;
                        final name = d['name']?.toString() ?? '';
                        final icd = d['icd_code']?.toString();
                        final cat = d['category']?.toString();
                        return ListTile(
                          dense: true,
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: hcTeal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.local_hospital_rounded,
                              size: 16,
                              color: hcTeal,
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: (icd != null || cat != null)
                              ? Row(
                                  children: [
                                    if (icd != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1,
                                        ),
                                        margin: const EdgeInsets.only(right: 6),
                                        decoration: BoxDecoration(
                                          color: hcBlue.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          icd,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: hcBlue,
                                          ),
                                        ),
                                      ),
                                    if (cat != null)
                                      Text(
                                        cat,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                  ],
                                )
                              : null,
                          onTap: () => onSelected(name),
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Allergy dropdown multi-select combobox with closable chips.
/// Mimics the nuxtfrontend v-combobox with multiple, chips, closable-chips.
class _AllergyComboBox extends StatefulWidget {
  final List items;
  final bool loading;
  final List<String> selected;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onSearch;

  const _AllergyComboBox({
    required this.items,
    required this.loading,
    required this.selected,
    required this.onAdd,
    required this.onRemove,
    required this.onSearch,
  });

  @override
  State<_AllergyComboBox> createState() => _AllergyComboBoxState();
}

class _AllergyComboBoxState extends State<_AllergyComboBox> {
  final LayerLink _layerLink = LayerLink();
  final _ctrl = TextEditingController();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  void _openOverlay() {
    if (_isOpen) return;
    _isOpen = true;
    _overlayEntry = _createOverlay();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closeOverlay() {
    if (!_isOpen) return;
    _isOpen = false;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlay() {
    final renderBox = context.findRenderObject() as RenderBox;
    final width = renderBox.size.width;
    return OverlayEntry(
      builder: (context) => _AllergyDropdown(
        layerLink: _layerLink,
        width: width,
        items: widget.items,
        selected: widget.selected,
        loading: widget.loading,
        onSelected: (name) {
          widget.onAdd(name);
          _ctrl.clear();
          setState(() {});
        },
        onClose: _closeOverlay,
      ),
    );
  }

  @override
  void dispose() {
    _closeOverlay();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 14, color: hcRed),
              const SizedBox(width: 6),
              Text(
                'Allergies',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Selected allergy chips
          if (widget.selected.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.selected
                  .map(
                    (a) => Chip(
                      avatar: const Icon(
                        Icons.warning_rounded,
                        size: 14,
                        color: hcRed,
                      ),
                      label: Text(a, style: const TextStyle(fontSize: 12)),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      backgroundColor: hcRed.withValues(alpha: 0.08),
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                      onDeleted: () {
                        widget.onRemove(a);
                        setState(() {});
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],
          // Input field
          GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
              _openOverlay();
            },
            child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                labelText: 'Pick from catalog or type & press enter',
                prefixIcon: const Icon(Icons.warning_amber_rounded),
                suffixIcon: widget.loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_ctrl.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle_rounded,
                                color: hcTeal,
                                size: 20,
                              ),
                              onPressed: () {
                                final v = _ctrl.text.trim();
                                if (v.isNotEmpty) {
                                  widget.onAdd(v);
                                  _ctrl.clear();
                                  _closeOverlay();
                                  setState(() {});
                                }
                              },
                            )
                          else
                            const SizedBox.shrink(),
                          IconButton(
                            icon: Icon(
                              _isOpen
                                  ? Icons.arrow_drop_up_rounded
                                  : Icons.arrow_drop_down_rounded,
                            ),
                            onPressed: () {
                              if (_isOpen) {
                                _closeOverlay();
                              } else {
                                _openOverlay();
                              }
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: hcRed, width: 1.5),
                ),
              ),
              onChanged: (v) {
                if (v.trim().length >= 2) widget.onSearch(v);
                if (!_isOpen) _openOverlay();
                setState(() {});
              },
              onSubmitted: (v) {
                final val = v.trim();
                if (val.isNotEmpty) {
                  widget.onAdd(val);
                  _ctrl.clear();
                  _closeOverlay();
                  setState(() {});
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width dropdown overlay body for the allergy multi-select.
class _AllergyDropdown extends StatelessWidget {
  final LayerLink layerLink;
  final double width;
  final List items;
  final List<String> selected;
  final bool loading;
  final ValueChanged<String> onSelected;
  final VoidCallback onClose;

  const _AllergyDropdown({
    required this.layerLink,
    required this.width,
    required this.items,
    required this.selected,
    required this.loading,
    required this.onSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final available = items
        .where((it) => !selected.contains((it as Map)['name']))
        .toList();
    final hasNoData = available.isEmpty && !loading;
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onClose,
          child: Container(color: Colors.black26),
        ),
        CompositedTransformFollower(
          link: layerLink,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 6),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(14),
            color: cs.surface,
            child: Container(
              width: width,
              constraints: const BoxConstraints(maxHeight: 240),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : hasNoData
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 28,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No matching allergies',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Type your own and press enter.',
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: available.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: cs.outlineVariant),
                      itemBuilder: (_, i) {
                        final a = available[i] as Map;
                        final name = a['name']?.toString() ?? '';
                        return ListTile(
                          dense: true,
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: hcRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.warning_rounded,
                              size: 16,
                              color: hcRed,
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: a['category'] != null
                              ? Text(
                                  a['category'].toString(),
                                  style: const TextStyle(fontSize: 11),
                                )
                              : null,
                          onTap: () => onSelected(name),
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
