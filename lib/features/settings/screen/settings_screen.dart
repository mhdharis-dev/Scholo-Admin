import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:alert_info/alert_info.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:scholo_admin/core/cloudinaryServies/cloudinary_service.dart';
import 'package:scholo_admin/core/constant/image_constant.dart';
import 'package:scholo_admin/core/widgets/phone_field.dart';
import 'package:scholo_admin/auth/controller/login_controller.dart';
import 'package:scholo_admin/models/school_model.dart';
import 'package:scholo_admin/core/config/session_manager.dart';

class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _schoolNameController = TextEditingController();
  final TextEditingController _principalNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _officialEmailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // Support Form Controllers
  final TextEditingController _supportNameCtrl = TextEditingController();
  final TextEditingController _supportEmailCtrl = TextEditingController();
  final TextEditingController _supportMsgCtrl = TextEditingController();

  File? _logoFile;
  String? _logoUrl;
  bool _isUploading = false;
  bool _isSaving = false;
  bool _showPassword = false;
  bool _isProfileEditing = false;

  SchoolModel? _lastInitializedSchool;
  String _selectedLanguage = 'en';
  String? _selectedGender;

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
  }

  @override
  void dispose() {
    _schoolNameController.dispose();
    _principalNameController.dispose();
    _phoneController.dispose();
    _officialEmailController.dispose();
    _addressController.dispose();
    _supportNameCtrl.dispose();
    _supportEmailCtrl.dispose();
    _supportMsgCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('settings_language') ?? 'en';
    });
  }

  Future<void> _saveLanguagePreference(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('settings_language', lang);
    setState(() {
      _selectedLanguage = lang;
    });
    if (mounted) {
      AlertInfo.show(
        context: context,
        text: lang == 'ar' ? 'تم تغيير اللغة إلى العربية' : 'Language updated to English',
        typeInfo: TypeInfo.success,
        backgroundColor: const Color(0xFF27AE60),
        iconColor: Colors.white,
        textColor: Colors.white,
        position: MessagePosition.top,
      );
    }
  }

  void _initializeFields(SchoolModel school) {
    _schoolNameController.text = school.schoolName;
    _principalNameController.text = school.principalName;
    _phoneController.text = school.phoneNumber;
    _officialEmailController.text = school.officialEmail;
    _addressController.text = school.schoolAddress;
    _logoUrl = school.imageUrl;
    _selectedGender = school.gender.isEmpty ? 'Male' : school.gender;
    _lastInitializedSchool = school;
  }

  Future<void> _pickLogo() async {
    if (!_isProfileEditing) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _logoFile = File(result.files.single.path!);
      });
    }
  }

  Future<String?> _uploadLogo() async {
    if (_logoFile == null) return _logoUrl;
    setState(() => _isUploading = true);
    try {
      final response = await CloudinaryService.studentProfile.uploadFile(
        CloudinaryFile.fromFile(_logoFile!.path, folder: 'school_logos'),
      );
      return response.secureUrl;
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
      if (mounted) {
        AlertInfo.show(
          context: context,
          text: '${_t('save_error')}: $e',
          typeInfo: TypeInfo.error,
          backgroundColor: Colors.redAccent,
          iconColor: Colors.white,
          textColor: Colors.white,
          position: MessagePosition.top,
        );
      }
      return null;
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _saveSettings(SchoolModel currentSchool) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final phone = _phoneController.text.trim();
    final phoneError = getPhoneValidationErrorMessage(phone);
    if (phoneError.isNotEmpty) {
      AlertInfo.show(
        context: context,
        text: _selectedLanguage == 'ar' ? 'رقم الهاتف غير صالح' : phoneError,
        typeInfo: TypeInfo.error,
        backgroundColor: Colors.redAccent,
        iconColor: Colors.white,
        textColor: Colors.white,
        position: MessagePosition.top,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final uploadedUrl = await _uploadLogo();
      if (uploadedUrl == null && _logoFile != null) {
        setState(() => _isSaving = false);
        return;
      }

      final updatedSchool = currentSchool.copyWith(
        schoolName: _schoolNameController.text.trim(),
        principalName: _principalNameController.text.trim(),
        gender: _selectedGender ?? '',
        phoneNumber: phone,
        officialEmail: _officialEmailController.text.trim(),
        schoolAddress: _addressController.text.trim(),
        imageUrl: uploadedUrl ?? '',
      );

      await ref.read(updateSchoolProvider)(updatedSchool);

      if (mounted) {
        AlertInfo.show(
          context: context,
          text: _t('save_success'),
          typeInfo: TypeInfo.success,
          backgroundColor: const Color(0xFF27AE60),
          iconColor: Colors.white,
          textColor: Colors.white,
          position: MessagePosition.top,
        );
        setState(() {
          _logoFile = null;
          _logoUrl = updatedSchool.imageUrl;
          _isProfileEditing = false;
          _lastInitializedSchool = null;
        });
      }
    } catch (e) {
      if (mounted) {
        AlertInfo.show(
          context: context,
          text: '${_t('save_error')}: $e',
          typeInfo: TypeInfo.error,
          backgroundColor: Colors.redAccent,
          iconColor: Colors.white,
          textColor: Colors.white,
          position: MessagePosition.top,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final isAr = _selectedLanguage == 'ar';
        return Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(_t('logout_title')),
            content: Text(_t('logout_message')),
            actions: [
              TextButton(
                child: Text(_t('cancel')),
                onPressed: () => Navigator.of(context).pop(),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff1293d4)),
                child: Text(_t('logout_btn'), style: const TextStyle(color: Colors.white)),
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  SessionManager.schoolId = null;
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    context.go('/login');
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _t(String key) {
    final isAr = _selectedLanguage == 'ar';
    final translations = {
      'settings_title': {'en': 'School Settings', 'ar': 'إعدادات المدرسة'},
      'settings_subtitle': {
        'en': 'Manage school registries, configure localization preferences, inspect legal agreements, or file support tickets.',
        'ar': 'إدارة سجلات المدرسة، وتكوين تفضيلات اللغة، وفحص الاتفاقيات القانونية، أو تقديم تذاكر الدعم.'
      },
      'tab_profile': {'en': 'School Profile', 'ar': 'ملف المدرسة'},
      'tab_language': {'en': 'System Language', 'ar': 'لغة النظام'},
      'tab_help': {'en': 'Help & Support', 'ar': 'المساعدة والدعم'},
      'tab_terms': {'en': 'Terms of Service', 'ar': 'شروط الخدمة'},
      'tab_privacy': {'en': 'Privacy Policy', 'ar': 'سياسة الخصوصية'},
      'tab_about': {'en': 'About Scholo', 'ar': 'حول سكولو'},
      'tab_logout': {'en': 'Log Out', 'ar': 'تسجيل الخروج'},
      'school_identity': {'en': 'School Identity', 'ar': 'هوية المدرسة'},
      'profile_info': {'en': 'Profile Information', 'ar': 'معلومات الملف الشخصي'},
      'school_name': {'en': 'School Name', 'ar': 'اسم المدرسة'},
      'principal_name': {'en': 'Principal Name', 'ar': 'اسم المدير'},
      'gender': {'en': 'Gender', 'ar': 'الجنس'},
      'male': {'en': 'Male', 'ar': 'ذكر'},
      'female': {'en': 'Female', 'ar': 'أنثى'},
      'official_email': {'en': 'Official Email Address', 'ar': 'البريد الإلكتروني الرسمي'},
      'phone_number': {'en': 'Phone Number', 'ar': 'رقم الهاتف'},
      'school_address': {'en': 'School Address', 'ar': 'عنوان المدرسة'},
      'security_credentials': {'en': 'Security & Credentials', 'ar': 'الأمان وبيانات الاعتماد'},
      'admin_email': {'en': 'Admin Email', 'ar': 'بريد المسؤول'},
      'admin_password': {'en': 'Admin Password', 'ar': 'كلمة مرور المسؤول'},
      'edit_profile': {'en': 'Edit Profile', 'ar': 'تعديل الملف الشخصي'},
      'save_changes': {'en': 'Save Changes', 'ar': 'حفظ التغييرات'},
      'cancel': {'en': 'Cancel', 'ar': 'إلغاء'},
      'save_success': {'en': 'School settings saved successfully', 'ar': 'تم حفظ إعدادات المدرسة بنجاح'},
      'save_error': {'en': 'Failed to save settings', 'ar': 'فشل في حفظ الإعدادات'},
      'select_language': {'en': 'Choose System Language', 'ar': 'اختر لغة النظام'},
      'english': {'en': 'English (Default)', 'ar': 'الإنجليزية (الافتراضية)'},
      'arabic': {'en': 'Arabic', 'ar': 'العربية'},
      'logout_title': {'en': 'Confirm Logout', 'ar': 'تأكيد تسجيل الخروج'},
      'logout_message': {'en': 'Are you sure you want to log out?', 'ar': 'هل أنت متأكد أنك تريد تسجيل الخروج؟'},
      'logout_btn': {'en': 'Logout', 'ar': 'تسجيل خروج'},
      'support_form_title': {'en': 'Submit a Support Ticket', 'ar': 'إرسال تذكرة دعم'},
      'support_name': {'en': 'Your Name', 'ar': 'اسمك'},
      'support_message': {'en': 'Message / Issue description', 'ar': 'الرسالة / وصف المشكلة'},
      'support_submit': {'en': 'Submit Ticket', 'ar': 'إرسال التذكرة'},
      'support_success': {'en': 'Support ticket submitted successfully', 'ar': 'تم تقديم تذكرة الدعم بنجاح'},
      'support_contacts': {'en': 'Direct Contact Info', 'ar': 'معلومات الاتصال المباشر'},
      'support_email': {'en': 'Email Support', 'ar': 'الدعم عبر البريد الإلكتروني'},
      'support_phone': {'en': 'Phone Support', 'ar': 'الدعم الهاتفي'},
      'faqs': {'en': 'Frequently Asked Questions', 'ar': 'الأسئلة الشائعة'},
      'faq_1_q': {'en': 'How do I add a new teacher?', 'ar': 'كيف يمكنني إضافة معلم جديد؟'},
      'faq_1_a': {
        'en': 'Go to the Teacher section in the sidebar, click the add button, enter details and submit.',
        'ar': 'اذهب إلى قسم المعلمين في الشريط الجانبي، وانقر على زر الإضافة، وأدخل التفاصيل ثم أرسل.'
      },
      'faq_2_q': {'en': 'How do I update school logo?', 'ar': 'كيف يمكنني تحديث شعار المدرسة؟'},
      'faq_2_a': {
        'en': 'Click the camera icon on the logo avatar in Edit mode, choose an image and click Save.',
        'ar': 'انقر على أيقونة الكاميرا على الصورة الرمزية للشعار في وضع التحرير، واختر صورة ثم انقر على حفظ.'
      },
      'app_version': {'en': 'App Version', 'ar': 'إصدار التطبيق'},
      'developer': {'en': 'Developer Info', 'ar': 'معلومات المطور'},
      'system_status': {'en': 'System Status', 'ar': 'حالة النظام'},
      'status_online': {'en': 'All Systems Operational', 'ar': 'جميع الأنظمة تعمل بشكل طبيعي'},
      'view_mode_desc': {'en': 'School profile details are in read-only mode. Click Edit to make changes.', 'ar': 'تفاصيل ملف المدرسة في وضع القراءة فقط. انقر فوق تحرير لإجراء تغييرات.'},
    };
    return translations[key]?[isAr ? 'ar' : 'en'] ?? key;
  }

  // --- COMPONENT BUILDERS ---

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: child,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? prefixIcon,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Colors.grey.shade500, size: 20) : null,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xff1293d4), width: 1.5),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, {bool isPassword = false, VoidCallback? onTogglePassword}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  isPassword && !_showPassword ? '•••••••••' : value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              if (isPassword)
                IconButton(
                  icon: Icon(
                    _showPassword ? Icons.visibility : Icons.visibility_off,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: onTogglePassword,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: Colors.grey.shade100, height: 1),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // --- CENTER DIALOG MODALS ---

  Widget _buildDialogHeader({required String title, required BuildContext context}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
          constraints: const BoxConstraints(),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  void _showLanguageDialog() {
    final isAr = _selectedLanguage == 'ar';
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Directionality(
              textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
              child: Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Container(
                  width: 450,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDialogHeader(title: _t('select_language'), context: context),
                      const SizedBox(height: 24),
                      RadioListTile<String>(
                        title: Text(_t('english')),
                        value: 'en',
                        groupValue: _selectedLanguage,
                        activeColor: const Color(0xff1293d4),
                        onChanged: (val) {
                          if (val != null) {
                            _saveLanguagePreference(val);
                            Navigator.pop(context);
                          }
                        },
                      ),
                      const Divider(height: 1),
                      RadioListTile<String>(
                        title: Text(_t('arabic')),
                        value: 'ar',
                        groupValue: _selectedLanguage,
                        activeColor: const Color(0xff1293d4),
                        onChanged: (val) {
                          if (val != null) {
                            _saveLanguagePreference(val);
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showHelpDialog() {
    final isAr = _selectedLanguage == 'ar';
    showDialog(
      context: context,
      builder: (context) {
        final supportFormKeyLocal = GlobalKey<FormState>();
        bool isSubmittingLocal = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Directionality(
              textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
              child: Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Container(
                  width: 680,
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildDialogHeader(title: _t('tab_help'), context: context),
                      const SizedBox(height: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Ticket query
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Form(
                                  key: supportFormKeyLocal,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _t('support_form_title'),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 16),
                                      _buildTextField(
                                        controller: _supportNameCtrl,
                                        label: _t('support_name'),
                                        prefixIcon: Icons.person,
                                        validator: (val) => val == null || val.trim().isEmpty ? "Required" : null,
                                      ),
                                      _buildTextField(
                                        controller: _supportEmailCtrl,
                                        label: _t('official_email'),
                                        prefixIcon: Icons.email,
                                        validator: (val) => val == null || val.trim().isEmpty ? "Required" : null,
                                      ),
                                      TextFormField(
                                        controller: _supportMsgCtrl,
                                        maxLines: 3,
                                        validator: (val) => val == null || val.trim().isEmpty ? "Required" : null,
                                        decoration: InputDecoration(
                                          labelText: _t('support_message'),
                                          alignLabelWithHint: true,
                                          filled: true,
                                          fillColor: Colors.white,
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(color: Colors.grey.shade200),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: Color(0xff1293d4), width: 1.5),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xff1293d4),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            onPressed: isSubmittingLocal
                                                ? null
                                                : () {
                                                    if (!supportFormKeyLocal.currentState!.validate()) return;
                                                    setModalState(() => isSubmittingLocal = true);
                                                    Future.delayed(const Duration(milliseconds: 1000), () {
                                                      if (context.mounted) {
                                                        AlertInfo.show(
                                                          context: context,
                                                          text: _t('support_success'),
                                                          typeInfo: TypeInfo.success,
                                                          backgroundColor: const Color(0xFF27AE60),
                                                          iconColor: Colors.white,
                                                          textColor: Colors.white,
                                                          position: MessagePosition.top,
                                                        );
                                                        _supportNameCtrl.clear();
                                                        _supportEmailCtrl.clear();
                                                        _supportMsgCtrl.clear();
                                                        Navigator.pop(context);
                                                      }
                                                    });
                                                  },
                                            child: isSubmittingLocal
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                                                  )
                                                : Text(_t('support_submit')),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              // Contacts
                              Text(
                                _t('support_contacts'),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 10),
                              ListTile(
                                leading: const Icon(Icons.email, color: Color(0xff1293d4)),
                                title: Text(_t('support_email'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                subtitle: const Text("support@scholo.com"),
                              ),
                              ListTile(
                                leading: const Icon(Icons.phone, color: Color(0xff1293d4)),
                                title: Text(_t('support_phone'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                subtitle: const Text("+1 (800) 555-0199"),
                              ),
                              const Divider(),
                              const SizedBox(height: 16),
                              Text(
                                _t('faqs'),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 10),
                              ExpansionTile(
                                title: Text(_t('faq_1_q'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Text(_t('faq_1_a'), style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                  ),
                                ],
                              ),
                              ExpansionTile(
                                title: Text(_t('faq_2_q'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Text(_t('faq_2_a'), style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTermsDialog() {
    final isAr = _selectedLanguage == 'ar';
    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              width: 720,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDialogHeader(title: _t('tab_terms'), context: context),
                  const SizedBox(height: 16),
                  Container(
                    height: 400,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        _getTermsText(),
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPrivacyDialog() {
    final isAr = _selectedLanguage == 'ar';
    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              width: 720,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDialogHeader(title: _t('tab_privacy'), context: context),
                  const SizedBox(height: 16),
                  Container(
                    height: 400,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        _getPrivacyText(),
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAboutDialog() {
    final isAr = _selectedLanguage == 'ar';
    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              width: 480,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogHeader(title: _t('tab_about'), context: context),
                  const SizedBox(height: 24),
                  Container(
                    width: 70,
                    height: 70,
                    decoration: const BoxDecoration(
                      color: Color(0xff1293d4),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.school_outlined, size: 36, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Scholo Management System",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  _buildReadOnlyField(_t('app_version'), "1.0.2 (Build 4120)"),
                  _buildReadOnlyField(_t('developer'), "Scholo Software Inc."),
                  _buildReadOnlyField(_t('system_status'), _t('status_online')),
                  const SizedBox(height: 16),
                  Text(
                    "© 2026 Scholo Inc. All rights reserved.",
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- QUICK MENUS CARD ---

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = const Color(0xff1293d4),
    Color? titleColor,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: titleColor ?? const Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schoolAsync = ref.watch(schoolStreamProvider);
    final isAr = _selectedLanguage == 'ar';

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: schoolAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xff1293d4)),
            ),
          ),
          error: (err, stack) => Center(
            child: Text(
              'Error loading settings: $err',
              style: const TextStyle(color: Colors.red),
            ),
          ),
          data: (school) {
            if (school == null) {
              return const Center(child: Text("No school details found."));
            }

            if (_lastInitializedSchool == null || _lastInitializedSchool!.schoolId != school.schoolId) {
              _initializeFields(school);
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page Header
                  Text(
                    _t('settings_title'),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t('settings_subtitle'),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Profile Form
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                            // 1. Unified Hero Header Card
                            _buildCard(
                              child: Row(
                                children: [
                                  Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: _logoFile != null
                                            ? Image.file(_logoFile!, fit: BoxFit.cover)
                                            : (_logoUrl != null && _logoUrl!.isNotEmpty
                                                ? Image.network(
                                                    _logoUrl!,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) => Image.asset(
                                                      ImageConstant.temporaryTeacherImage,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  )
                                                : Image.asset(ImageConstant.temporaryTeacherImage, fit: BoxFit.cover)),
                                      ),
                                      if (_isProfileEditing)
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: GestureDetector(
                                            onTap: _pickLogo,
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xff1293d4),
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white, width: 2),
                                              ),
                                              child: const Icon(
                                                Icons.camera_alt,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (_isProfileEditing) ...[
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: _buildTextField(
                                                  controller: _schoolNameController,
                                                  label: _t('school_name'),
                                                  validator: (val) => val == null || val.trim().isEmpty ? "Required" : null,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                flex: 3,
                                                child: _buildTextField(
                                                  controller: _principalNameController,
                                                  label: _t('principal_name'),
                                                  validator: (val) => val == null || val.trim().isEmpty ? "Required" : null,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                flex: 2,
                                                child: DropdownButtonFormField<String>(
                                                  value: _selectedGender,
                                                  decoration: InputDecoration(
                                                    labelText: _t('gender'),
                                                    labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                                    filled: true,
                                                    fillColor: const Color(0xFFF8FAFC),
                                                    enabledBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(12),
                                                      borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
                                                    ),
                                                    focusedBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(12),
                                                      borderSide: const BorderSide(color: Color(0xff1293d4), width: 1.5),
                                                    ),
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                                  ),
                                                  items: [
                                                    DropdownMenuItem(
                                                      value: 'Male',
                                                      child: Text(_t('male')),
                                                    ),
                                                    DropdownMenuItem(
                                                      value: 'Female',
                                                      child: Text(_t('female')),
                                                    ),
                                                  ],
                                                  onChanged: (val) {
                                                    setState(() {
                                                      _selectedGender = val;
                                                    });
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ] else ...[
                                          Text(
                                            school.schoolName,
                                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Text(
                                                "${_t('principal_name')}: ${school.principalName}",
                                                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                              ),
                                              if (school.gender.isNotEmpty) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xff1293d4).withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    school.gender == 'Female' ? _t('female') : _t('male'),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Color(0xff1293d4),
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 8,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              school.schoolCode,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey.shade400,
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                            _buildBadge(school.status, school.status.toLowerCase() == 'active' ? Colors.green : Colors.red),
                                            _buildBadge(school.environment, school.environment.toLowerCase() == 'prod' ? Colors.orange : Colors.blue),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  // Profile Edit State Actions
                                  if (!_isProfileEditing)
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xff1293d4),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                      ),
                                      icon: const Icon(Icons.edit, size: 18),
                                      label: Text(_t('edit_profile')),
                                      onPressed: () {
                                        setState(() {
                                          _isProfileEditing = true;
                                        });
                                      },
                                    )
                                  else
                                    Row(
                                      children: [
                                        OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _logoFile = null;
                                              _isProfileEditing = false;
                                              _initializeFields(school);
                                            });
                                          },
                                          child: Text(_t('cancel')),
                                        ),
                                        const SizedBox(width: 10),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xff1293d4),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          onPressed: (_isSaving || _isUploading) ? null : () => _saveSettings(school),
                                          child: (_isSaving || _isUploading)
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                                                )
                                              : Text(_t('save_changes')),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // 2. Details & Credentials Grid
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left details card
                                Expanded(
                                  child: _buildCard(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildSectionTitle(_t('profile_info')),
                                        if (_isProfileEditing) ...[
                                          _buildTextField(
                                            controller: _officialEmailController,
                                            label: _t('official_email'),
                                            prefixIcon: Icons.email,
                                            validator: (val) {
                                              if (val == null || val.trim().isEmpty) return "Required";
                                              if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) return "Invalid Email";
                                              return null;
                                            },
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 16.0),
                                            child: CountryPhoneField(
                                              controller: _phoneController,
                                              labelText: _t('phone_number'),
                                            ),
                                          ),
                                          _buildTextField(
                                            controller: _addressController,
                                            label: _t('school_address'),
                                            prefixIcon: Icons.location_on,
                                            validator: (val) => val == null || val.trim().isEmpty ? "Required" : null,
                                          ),
                                        ] else ...[
                                          _buildReadOnlyField(_t('official_email'), school.officialEmail),
                                          _buildReadOnlyField(_t('phone_number'), school.phoneNumber),
                                          _buildReadOnlyField(_t('school_address'), school.schoolAddress),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 24),
                                // Right credentials card
                                Expanded(
                                  child: _buildCard(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildSectionTitle(_t('security_credentials')),
                                        _buildReadOnlyField(_t('admin_email'), school.email),
                                        _buildReadOnlyField(
                                          _t('admin_password'),
                                          school.password,
                                          isPassword: true,
                                          onTogglePassword: () => setState(() => _showPassword = !_showPassword),
                                        ),
                                        const SizedBox(height: 12),
                                        _buildReadOnlyField(_t('tab_about'), school.subscriptionPlan),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                  const SizedBox(height: 40),
                  const Divider(),
                  const SizedBox(height: 24),

                  // Quick actions menu grid
                  _buildSectionTitle(_t('settings_title')),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 800;
                      return GridView.count(
                        crossAxisCount: isWide ? 3 : 1,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: isWide ? 2.8 : 4.5,
                        children: [
                          _buildMenuCard(
                            icon: Icons.translate,
                            title: _t('tab_language'),
                            subtitle: _selectedLanguage == 'ar' ? 'العربية' : 'English',
                            onTap: _showLanguageDialog,
                          ),
                          _buildMenuCard(
                            icon: Icons.help_outline,
                            title: _t('tab_help'),
                            subtitle: _selectedLanguage == 'ar' ? 'التذاكر والدعم' : 'FAQs & Support Tickets',
                            onTap: _showHelpDialog,
                          ),
                          _buildMenuCard(
                            icon: Icons.gavel,
                            title: _t('tab_terms'),
                            subtitle: _selectedLanguage == 'ar' ? 'شروط الخدمة' : 'Terms & Conditions Agreement',
                            onTap: _showTermsDialog,
                          ),
                          _buildMenuCard(
                            icon: Icons.privacy_tip_outlined,
                            title: _t('tab_privacy'),
                            subtitle: _selectedLanguage == 'ar' ? 'بيان الخصوصية' : 'Data Privacy Policy',
                            onTap: _showPrivacyDialog,
                          ),
                          _buildMenuCard(
                            icon: Icons.info_outline,
                            title: _t('tab_about'),
                            subtitle: _selectedLanguage == 'ar' ? 'إصدار التطبيق والترخيص' : 'System Build & License Details',
                            onTap: _showAboutDialog,
                          ),
                          _buildMenuCard(
                            icon: Icons.logout,
                            title: _t('tab_logout'),
                            subtitle: _selectedLanguage == 'ar' ? 'تسجيل الخروج من النظام' : 'Sign Out of Administration',
                            iconColor: Colors.redAccent,
                            titleColor: Colors.redAccent,
                            onTap: () => _logout(context),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // --- MOCK TEXT DOCS ---

  String _getTermsText() {
    return _selectedLanguage == 'ar'
        ? "أهلاً بك في منصة Scholo لإدارة المدارس.\n\n"
            "باستخدامك لهذا النظام، فإنك توافق على الالتزام بالشروط والأحكام التالية:\n\n"
            "1. شروط الاستخدام: هذا النظام مخصص حصريًا لإدارة العمليات التعليمية والإدارية في مدرستك المرخصة. يمنع استخدام النظام لأي أغراض أخرى غير مصرح بها.\n\n"
            "2. سرية الحساب: أنت مسؤول مسؤولية كاملة عن الحفاظ على سرية معلومات حسابك وكلمة المرور الخاصة بك. أي نشاط يتم تحت حسابك يعتبر من مسؤوليتك.\n\n"
            "3. أمان البيانات: تتعهد المدرسة بإدخال بيانات صحيحة ودقيقة للطلاب والمعلمين، وعدم استغلال النظام في جمع بيانات غير قانونية.\n\n"
            "4. الملكية الفكرية: جميع حقوق الملكية الفكرية للنظام، بما في ذلك البرمجيات، الواجهات والتصميمات، تعود لشركة Scholo Inc.\n\n"
            "5. التحديثات والتعديلات: يحق لـ Scholo إجراء تحديثات دورية للنظام لتحسين الأداء وإضافة مزايا جديدة."
        : "Welcome to Scholo School Management Platform.\n\n"
            "By accessing and using this software, you agree to comply with the following Terms and Conditions:\n\n"
            "1. Permitted Use: This dashboard is provided solely to authorized educational institutions for administering student, teacher, and classroom data. Unauthorized access or reverse engineering is strictly prohibited.\n\n"
            "2. Account Security: Administrators must safeguard login credentials. You are entirely responsible for all administrative actions taken under your account.\n\n"
            "3. Data Integrity: You represent and warrant that all information supplied regarding students, admissions, and teachers is accurate and lawful.\n\n"
            "4. Intellectual Property: The software structure, logo, code, and interfaces are the exclusive property of Scholo Inc.\n\n"
            "5. Liability Limitations: Scholo Inc. is not liable for data deletions caused by user error. All administrative deletions must verify via Recycle Bin.\n\n"
            "6. Service Updates: We reserve the right to deploy updates, modifications, or temporary suspensions for security patches and service improvements.";
  }

  String _getPrivacyText() {
    return _selectedLanguage == 'ar'
        ? "تلتزم Scholo بحماية خصوصية بيانات مدرستك.\n\n"
            "1. جمع البيانات: نقوم بجمع وتخزين البيانات التي تدخلها مثل أسماء الطلاب، درجاتهم، السجلات، ومعلومات الاتصال بالمعلمين.\n\n"
            "2. حماية البيانات: يتم تشفير وتخزين جميع البيانات بشكل آمن على منصة Firebase و Cloudinary السحابية، مع حماية كاملة ضد الوصول غير المصرح به.\n\n"
            "3. استخدام البيانات: تُستخدم هذه البيانات حصريًا لتسهيل إدارة المدرسة وعرض السجلات التعليمية، ولن يتم بيعها أو مشاركتها مع أطراف ثالثة لأغراض تسويقية.\n\n"
            "4. الأطراف الثالثة: نستخدم خدمات سحابية موثوقة (مثل Cloudinary لرفع الصور) لتوفير أداء أسرع.\n\n"
            "5. حقوق المستخدمين: يمكن للمسؤولين تعديل أو حذف بيانات المدرسة والطلاب في أي وقت عبر لوحة التحكم."
        : "Scholo Inc. takes educational data privacy seriously.\n\n"
            "1. Data Collection: We collect school info, teacher registries, student rosters, phone configurations, and grades purely to provide management services.\n\n"
            "2. Data Processing & Hosting: All database entries reside on secure Firebase Firestore instances. Media assets are uploaded directly to verified Cloudinary storage.\n\n"
            "3. Data Sharing: Student and teacher records are never shared, sold, or distributed to third-party advertising companies. Your records belong exclusively to your school code.\n\n"
            "4. Information Security: We enforce encryption algorithms to protect credentials and private records. Administrators can view, update, or soft-delete data anytime.\n\n"
            "5. Compliance: Our platform is engineered to align with global privacy standards regarding educational records and student directories.";
  }
}
