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
import 'package:scholo_admin/models/helpAndSupport_model.dart';
import 'package:scholo_admin/core/config/session_manager.dart';
import 'package:scholo_admin/core/constant/firebase_constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:scholo_admin/models/admin_device_model.dart';
import 'package:scholo_admin/features/settings/repository/admin_device_repository.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (SessionManager.schoolId.isNotEmpty) {
        ref.read(adminDeviceRepositoryProvider).registerOrUpdateCurrentDevice(
          schoolId: SessionManager.schoolId,
        );
      }
    });
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
    await prefs.setString('settings_language', 'en');
    setState(() {
      _selectedLanguage = 'en';
    });
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
      if (mounted) {
        final errText = _selectedLanguage == 'ar' ? 'رقم الهاتف غير صالح' : phoneError;
        AlertInfo.show(
          context: context,
          text: errText,
          typeInfo: TypeInfo.error,
          backgroundColor: Colors.redAccent,
          iconColor: Colors.white,
          textColor: Colors.white,
          position: MessagePosition.top,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
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
        final successText = _t('save_success');
        AlertInfo.show(
          context: context,
          text: successText,
          typeInfo: TypeInfo.success,
          backgroundColor: const Color(0xFF27AE60),
          iconColor: Colors.white,
          textColor: Colors.white,
          position: MessagePosition.top,
        );
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        successText,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "Your school details (email, phone, address, etc.) have been updated successfully.",
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF27AE60),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
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
        final errStr = '${_t('save_error')}: $e';
        AlertInfo.show(
          context: context,
          text: errStr,
          typeInfo: TypeInfo.error,
          backgroundColor: Colors.redAccent,
          iconColor: Colors.white,
          textColor: Colors.white,
          position: MessagePosition.top,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errStr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
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
                  final schoolId = SessionManager.schoolId;
                  await ref.read(adminDeviceRepositoryProvider).logoutCurrentDevice(schoolId);
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
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 460,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDialogHeader(title: _t('select_language'), context: context),
                const SizedBox(height: 20),

                // English Option Box (Default & Active)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xff1293d4).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xff1293d4), width: 1.5),
                  ),
                  child: RadioListTile<String>(
                    title: Row(
                      children: const [
                        Text(
                          'English (Default)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.check_circle_rounded, size: 18, color: Color(0xff1293d4)),
                      ],
                    ),
                    subtitle: const Text(
                      'Primary system language for admin controls',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    value: 'en',
                    groupValue: 'en',
                    activeColor: const Color(0xff1293d4),
                    onChanged: (val) {},
                  ),
                ),

                const SizedBox(height: 18),

                // Boxed Alert Content Notice
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEF3C7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFFD97706),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "Language Support Alert",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF92400E),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "In this version, only English language is supported.",
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFB45309),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHelpDialog([SchoolModel? school]) {
    if (school != null) {
      _supportNameCtrl.text = school.schoolName;
      _supportEmailCtrl.text = school.officialEmail.isNotEmpty
          ? school.officialEmail
          : school.email;
    }
    _supportMsgCtrl.clear();

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
                                                : () async {
                                                    if (!supportFormKeyLocal.currentState!.validate()) return;
                                                    setModalState(() => isSubmittingLocal = true);
                                                    try {
                                                      final targetSchoolId = (school?.schoolId.isNotEmpty == true)
                                                          ? school!.schoolId
                                                          : SessionManager.schoolId;

                                                      final collectionRef = FirebaseFirestore.instance
                                                          .collection(FirebaseConstant.helpAndSupport);

                                                      final snapshot = await collectionRef.get();
                                                      int count = snapshot.docs.length + 1;
                                                      String generatedId = "H&S@${count.toString().padLeft(3, '0')}";

                                                      while ((await collectionRef.doc(generatedId).get()).exists) {
                                                        count++;
                                                        generatedId = "H&S@${count.toString().padLeft(3, '0')}";
                                                      }

                                                      final ticket = HelpAndSupportModel(
                                                        id: generatedId,
                                                        name: _supportNameCtrl.text.trim(),
                                                        schoolName: school?.schoolName ?? _supportNameCtrl.text.trim(),
                                                        officialEmail: _supportEmailCtrl.text.trim(),
                                                        message: _supportMsgCtrl.text.trim(),
                                                        createdAt: DateTime.now(),
                                                        status: 'Pending',
                                                        schoolId: targetSchoolId,
                                                      );

                                                      await collectionRef.doc(generatedId).set(ticket.toMap());

                                                      if (context.mounted) {
                                                        AlertInfo.show(
                                                          context: context,
                                                          text: "${_t('support_success')} (ID: $generatedId)",
                                                          typeInfo: TypeInfo.success,
                                                          backgroundColor: const Color(0xFF27AE60),
                                                          iconColor: Colors.white,
                                                          textColor: Colors.white,
                                                          position: MessagePosition.top,
                                                        );
                                                        _supportMsgCtrl.clear();
                                                        Navigator.pop(context);
                                                      }
                                                    } catch (e) {
                                                      if (context.mounted) {
                                                        AlertInfo.show(
                                                          context: context,
                                                          text: "Error submitting ticket: $e",
                                                          typeInfo: TypeInfo.error,
                                                          backgroundColor: Colors.redAccent,
                                                          iconColor: Colors.white,
                                                          textColor: Colors.white,
                                                          position: MessagePosition.top,
                                                        );
                                                      }
                                                    } finally {
                                                      setModalState(() => isSubmittingLocal = false);
                                                    }
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
                              // Contact & Support Quick Actions Card
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _t('support_contacts'),
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(height: 12),
                                    // Email Row + Quick Email Button
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xff1293d4).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(Icons.email_outlined, color: Color(0xff1293d4), size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(_t('support_email'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                                              const SizedBox(height: 2),
                                              const Text("app.scholo@gmail.com", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                                            ],
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFEA4335),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            elevation: 0,
                                          ),
                                          onPressed: () async {
                                            final mailtoUri = Uri.parse("https://mail.google.com/mail/?view=cm&fs=1&to=app.scholo@gmail.com");
                                            final fallbackUri = Uri.parse("mailto:app.scholo@gmail.com");
                                            if (await canLaunchUrl(mailtoUri)) {
                                              await launchUrl(mailtoUri, webOnlyWindowName: '_blank');
                                            } else if (await canLaunchUrl(fallbackUri)) {
                                              await launchUrl(fallbackUri, webOnlyWindowName: '_blank');
                                            }
                                          },
                                          icon: const Icon(Icons.send_rounded, size: 14),
                                          label: const Text("Email Us", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(height: 1),
                                    const SizedBox(height: 12),
                                    // WhatsApp Row + Quick WhatsApp Button
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF25D366).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366), size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(_t('support_phone'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                                              const SizedBox(height: 2),
                                              const Text("+91 9544234298", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                                            ],
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF25D366),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            elevation: 0,
                                          ),
                                          onPressed: () async {
                                            final uri = Uri.parse("https://wa.me/919544234298");
                                            if (await canLaunchUrl(uri)) {
                                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                                            }
                                          },
                                          icon: const Icon(Icons.chat_rounded, size: 14),
                                          label: const Text("WhatsApp", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
              maxWidth: 720,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Banner with Blue Gradient
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1D9BF0), Color(0xFF1193D4)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  "ENTERPRISE v1.0.2",
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Logo circle
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/imagesJpg/Scholo_LogoTransperent.png',
                              height: 64,
                              width: 64,
                              fit: BoxFit.contain,
                              errorBuilder: (ctx, err, stack) => const Icon(Icons.school_rounded, size: 50, color: Color(0xFF1193D4)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "SCHOLO",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Next-Gen Cloud School Management & Administration",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    // Main Details Section
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Features Grid
                          const Text(
                            "PLATFORM HIGHLIGHTS",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1.1),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _buildAboutFeatureChip(Icons.how_to_reg_rounded, "Real-Time Attendance"),
                              _buildAboutFeatureChip(Icons.notifications_active_rounded, "FCM Push Notifications"),
                              _buildAboutFeatureChip(Icons.receipt_long_rounded, "Subscription & Invoice PDF"),
                              _buildAboutFeatureChip(Icons.security_rounded, "Multi-Device Remote Security"),
                            ],
                          ),

                          const SizedBox(height: 24),
                          const Divider(height: 1),
                          const SizedBox(height: 20),

                          // Information Cards
                          const Text(
                            "SYSTEM SPECIFICATIONS",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1.1),
                          ),
                          const SizedBox(height: 12),

                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: [
                                _buildAboutDetailRow(Icons.memory_rounded, "App Version", "1.0.2 (Build 4120)"),
                                const Divider(height: 16, color: Color(0xFFF1F5F9)),
                                _buildAboutDetailRow(
                                  Icons.verified_user_rounded,
                                  "System Status",
                                  "Operational • All Systems Online",
                                  valueColor: const Color(0xFF10B981),
                                ),
                                const Divider(height: 16, color: Color(0xFFF1F5F9)),
                                _buildAboutDetailRow(Icons.business_rounded, "Developer & License", "ScholoMates Inc"),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Quick Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showTermsDialog();
                                  },
                                  icon: const Icon(Icons.gavel_rounded, size: 16, color: Color(0xFF475569)),
                                  label: const Text("Terms", style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showPrivacyDialog();
                                  },
                                  icon: const Icon(Icons.privacy_tip_outlined, size: 16, color: Color(0xFF475569)),
                                  label: const Text("Privacy", style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          Center(
                            child: Text(
                              "© 2026 Scholo Inc. All Rights Reserved.",
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAboutFeatureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1193D4).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1193D4).withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF1193D4)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutDetailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor ?? const Color(0xFF0F172A),
          ),
        ),
      ],
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
                            subtitle: 'English (Default)',
                            onTap: _showLanguageDialog,
                          ),
                          _buildMenuCard(
                            icon: Icons.help_outline,
                            title: _t('tab_help'),
                            subtitle: _selectedLanguage == 'ar' ? 'التذاكر والدعم' : 'FAQs & Support Tickets',
                            onTap: () => _showHelpDialog(school),
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
                            icon: Icons.devices_rounded,
                            title: 'Admin Devices',
                            subtitle: _selectedLanguage == 'ar' ? 'الأجهزة والجلسات النشطة' : 'Logged-in Devices & FCM Sessions',
                            onTap: _showAdminDevicesDialog,
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

  // ── 📱 ADMIN DEVICES & FCM SESSIONS MODAL ─────────────────────────
  void _showAdminDevicesDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final devicesAsync = ref.watch(adminDevicesStreamProvider);
            final currentDeviceIdAsync = ref.watch(currentDeviceIdProvider);
            final currentDeviceId = currentDeviceIdAsync.value ?? '';
            final schoolId = SessionManager.schoolId;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                width: 820,
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1193D4).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.devices_rounded, color: Color(0xFF1193D4), size: 24),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  "Admin Devices & FCM Sessions",
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Monitor logged-in devices, active push tokens, and remote session security",
                                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    Expanded(
                      child: devicesAsync.when(
                        data: (devices) {
                          if (devices.isEmpty) {
                            return const Center(
                              child: Text("No registered devices found.", style: TextStyle(color: Colors.grey)),
                            );
                          }

                          final activeDevices = devices.where((d) => d.isActive).toList();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Summary & Bulk Actions Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                                        ),
                                        child: Text(
                                          "Active Sessions: ${activeDevices.length}",
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          "Total Registered: ${devices.length}",
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF1193D4),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        icon: const Icon(Icons.notifications_active_rounded, size: 14),
                                        label: const Text('Allow Permission & Save FCM Token', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        onPressed: () async {
                                          final token = await ref
                                              .read(adminDeviceRepositoryProvider)
                                              .requestAndSaveFcmToken(schoolId: schoolId, deviceId: currentDeviceId);
                                          if (context.mounted) {
                                            if (token.isNotEmpty) {
                                              AlertInfo.show(
                                                context: context,
                                                text: 'FCM Token saved successfully!',
                                                typeInfo: TypeInfo.success,
                                                backgroundColor: Colors.green,
                                                textColor: Colors.white,
                                              );
                                            } else {
                                              AlertInfo.show(
                                                context: context,
                                                text: 'Could not obtain FCM token or permission denied.',
                                                typeInfo: TypeInfo.error,
                                                backgroundColor: Colors.orange,
                                                textColor: Colors.white,
                                              );
                                            }
                                          }
                                        },
                                      ),
                                      if (activeDevices.length > 1)
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text('Logout All Other Devices?'),
                                                content: const Text('This will revoke access for all other logged-in sessions except this current device.'),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                                    onPressed: () => Navigator.pop(ctx, true),
                                                    child: const Text('Logout All Others'),
                                                  ),
                                                ],
                                              ),
                                            );

                                            if (confirm == true) {
                                              await ref.read(adminDeviceRepositoryProvider).logoutAllOtherDevices(schoolId, currentDeviceId);
                                              if (context.mounted) {
                                                AlertInfo.show(
                                                  context: context,
                                                  text: 'All other devices logged out successfully!',
                                                  typeInfo: TypeInfo.success,
                                                  backgroundColor: Colors.green,
                                                  textColor: Colors.white,
                                                );
                                              }
                                            }
                                          },
                                          icon: const Icon(Icons.no_cell_rounded, size: 14),
                                          label: const Text('Logout All Other Devices', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Device Items List
                              Expanded(
                                child: ListView.builder(
                                  itemCount: devices.length,
                                  itemBuilder: (ctx, idx) {
                                    final item = devices[idx];
                                    final isThisDevice = item.deviceId == currentDeviceId;
                                    return _buildAdminDeviceCard(ctx, item, isThisDevice, schoolId, ref);
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF1193D4))),
                        error: (err, stack) => Center(child: Text("Error loading devices: $err", style: const TextStyle(color: Colors.red))),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAdminDeviceCard(
    BuildContext context,
    AdminDeviceModel device,
    bool isThisDevice,
    String schoolId,
    WidgetRef ref,
  ) {
    IconData icon = Icons.laptop_chromebook_rounded;
    Color iconColor = const Color(0xFF3B82F6);

    final platformLower = device.platform.toLowerCase();
    if (platformLower.contains('android')) {
      icon = Icons.phone_android_rounded;
      iconColor = const Color(0xFF10B981);
    } else if (platformLower.contains('ios') || platformLower.contains('apple')) {
      icon = Icons.phone_iphone_rounded;
      iconColor = const Color(0xFF8B5CF6);
    } else if (platformLower.contains('win')) {
      icon = Icons.desktop_windows_rounded;
      iconColor = const Color(0xFF0284C7);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isThisDevice ? const Color(0xFFF0F9FF) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isThisDevice ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
          width: isThisDevice ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "${device.deviceName} (${device.platform})",
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ),
                        if (isThisDevice) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "THIS DEVICE",
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: device.isActive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: device.isActive ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            device.isActive ? "ACTIVE" : "LOGGED OUT",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: device.isActive ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Manufacturer: ${device.manufacturer} • Model: ${device.model} • OS: ${device.osVersion} • App v${device.appVersion}",
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Details Grid (First login, last login, last seen, FCM token)
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildDeviceDetailItem(Icons.key_rounded, "Device ID", device.deviceId),
              _buildDeviceDetailItem(Icons.login_rounded, "First Login", _formatDate(device.firstLoginAt)),
              _buildDeviceDetailItem(Icons.access_time_rounded, "Last Login", _formatDate(device.lastLoginAt)),
              _buildDeviceDetailItem(Icons.visibility_rounded, "Last Seen", _formatDate(device.lastSeenAt)),
              if (device.logoutAt != null)
                _buildDeviceDetailItem(Icons.logout_rounded, "Logged Out At", _formatDate(device.logoutAt!)),
              _buildDeviceDetailItem(
                Icons.notifications_active_rounded,
                "FCM Token",
                device.fcmToken.isNotEmpty
                    ? "${device.fcmToken.substring(0, device.fcmToken.length > 18 ? 18 : device.fcmToken.length)}..."
                    : "No Token",
              ),
            ],
          ),

          if (device.isActive && !isThisDevice) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  await ref.read(adminDeviceRepositoryProvider).logoutDevice(schoolId, device.deviceId);
                  if (context.mounted) {
                    AlertInfo.show(
                      context: context,
                      text: 'Device access revoked successfully',
                      typeInfo: TypeInfo.success,
                      backgroundColor: Colors.redAccent,
                      textColor: Colors.white,
                    );
                  }
                },
                icon: const Icon(Icons.logout_rounded, size: 14),
                label: const Text("Logout Device", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeviceDetailItem(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(
          "$label: ",
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return "${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
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
