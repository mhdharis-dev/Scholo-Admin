import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

const List<Map<String, dynamic>> countryCodes = [
  {'name': 'US', 'code': '+1', 'flag': '🇺🇸', 'isoCode': IsoCode.US, 'min': 10, 'max': 10},
  {'name': 'IN', 'code': '+91', 'flag': '🇮🇳', 'isoCode': IsoCode.IN, 'min': 10, 'max': 10},
  {'name': 'UK', 'code': '+44', 'flag': '🇬🇧', 'isoCode': IsoCode.GB, 'min': 9, 'max': 11},
  {'name': 'UAE', 'code': '+971', 'flag': '🇦🇪', 'isoCode': IsoCode.AE, 'min': 9, 'max': 9},
  {'name': 'KSA', 'code': '+966', 'flag': '🇸🇦', 'isoCode': IsoCode.SA, 'min': 9, 'max': 9},
  {'name': 'PK', 'code': '+92', 'flag': '🇵🇰', 'isoCode': IsoCode.PK, 'min': 10, 'max': 10},
  {'name': 'AU', 'code': '+61', 'flag': '🇦🇺', 'isoCode': IsoCode.AU, 'min': 9, 'max': 9},
  {'name': 'DE', 'code': '+49', 'flag': '🇩🇪', 'isoCode': IsoCode.DE, 'min': 10, 'max': 11},
  {'name': 'FR', 'code': '+33', 'flag': '🇫🇷', 'isoCode': IsoCode.FR, 'min': 9, 'max': 9},
  {'name': 'SG', 'code': '+65', 'flag': '🇸🇬', 'isoCode': IsoCode.SG, 'min': 8, 'max': 8},
];

bool isValidPhoneNumber(String fullNumber) {
  final text = fullNumber.trim();
  if (text.isEmpty) return false;

  Map<String, dynamic>? matchedCountry;
  for (final c in countryCodes) {
    final code = c['code'] as String;
    if (text.startsWith(code)) {
      matchedCountry = c;
      break;
    }
  }

  if (matchedCountry == null) return false;
  final code = matchedCountry['code'] as String;
  final nationalNumber = text.substring(code.length);
  final minLen = matchedCountry['min'] as int;
  final maxLen = matchedCountry['max'] as int;

  if (nationalNumber.length < minLen || nationalNumber.length > maxLen) {
    return false;
  }

  try {
    final parsed = PhoneNumber.parse(nationalNumber, destinationCountry: matchedCountry['isoCode'] as IsoCode);
    return parsed.isValid();
  } catch (_) {
    return true; // Fallback to length validation if parsing throws
  }
}

String getPhoneValidationErrorMessage(String fullNumber) {
  final text = fullNumber.trim();
  if (text.isEmpty) return 'Mobile number cannot be empty';

  Map<String, dynamic>? matchedCountry;
  for (final c in countryCodes) {
    final code = c['code'] as String;
    if (text.startsWith(code)) {
      matchedCountry = c;
      break;
    }
  }

  if (matchedCountry == null) return 'Invalid country prefix';
  final code = matchedCountry['code'] as String;
  final nationalNumber = text.substring(code.length);
  final minLen = matchedCountry['min'] as int;
  final maxLen = matchedCountry['max'] as int;

  if (nationalNumber.length < minLen || nationalNumber.length > maxLen) {
    if (minLen == maxLen) {
      return 'Mobile number must be exactly $minLen digits for ${matchedCountry['name']}';
    }
    return 'Mobile number must be between $minLen and $maxLen digits for ${matchedCountry['name']}';
  }

  try {
    final parsed = PhoneNumber.parse(nationalNumber, destinationCountry: matchedCountry['isoCode'] as IsoCode);
    if (!parsed.isValid()) {
      return 'Invalid mobile number for ${matchedCountry['name']}';
    }
  } catch (_) {}

  return '';
}

class CountryPhoneField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  const CountryPhoneField({
    super.key,
    required this.controller,
    this.labelText = 'Mobile No',
    this.onChanged,
    this.validator,
  });

  @override
  State<CountryPhoneField> createState() => _CountryPhoneFieldState();
}

class _CountryPhoneFieldState extends State<CountryPhoneField> {
  late Map<String, dynamic> _selectedCountry;
  final TextEditingController _numberController = TextEditingController();
  bool _showCountryPicker = false;

  @override
  void initState() {
    super.initState();
    _initFromController();
    _numberController.addListener(_updateWidgetController);
  }

  @override
  void didUpdateWidget(covariant CountryPhoneField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentFull = widget.controller.text;
    final activeFull = '${_selectedCountry['code']}${_numberController.text}';
    if (currentFull != activeFull) {
      _initFromController();
    }
  }

  void _initFromController() {
    final text = widget.controller.text.trim();
    Map<String, dynamic>? matchedCountry;

    for (final c in countryCodes) {
      final code = c['code'] as String;
      if (text.startsWith(code)) {
        matchedCountry = c;
        break;
      }
    }

    _selectedCountry = matchedCountry ?? countryCodes.firstWhere((c) => c['name'] == 'IN', orElse: () => countryCodes.first);
    
    if (matchedCountry != null) {
      final code = matchedCountry['code'] as String;
      _numberController.text = text.substring(code.length);
    } else {
      _numberController.text = text;
    }
  }

  void _updateWidgetController() {
    final fullNumber = '${_selectedCountry['code']}${_numberController.text}';
    if (widget.controller.text != fullNumber) {
      widget.controller.text = fullNumber;
      if (widget.onChanged != null) {
        widget.onChanged!(fullNumber);
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _numberController.removeListener(_updateWidgetController);
    _numberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final number = _numberController.text.trim();
    final bool isTouched = number.isNotEmpty;
    final minLen = _selectedCountry['min'] as int;
    final maxLen = _selectedCountry['max'] as int;
    final bool isPhoneValid = isTouched && number.length >= minLen && number.length <= maxLen;

    final Color borderColor = !isTouched
        ? Colors.grey.shade200
        : (isPhoneValid ? const Color(0xFF10B981) : Colors.redAccent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: _numberController,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(maxLen),
          ],
          decoration: InputDecoration(
            labelText: widget.labelText,
            labelStyle: TextStyle(
              color: isTouched
                  ? (isPhoneValid ? const Color(0xFF10B981) : Colors.redAccent)
                  : Colors.grey.shade600,
              fontSize: 13,
            ),
            filled: true,
            fillColor: isTouched && !isPhoneValid
                ? Colors.red.shade50
                : (isTouched && isPhoneValid ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor, width: isTouched ? 1.5 : 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isTouched ? (isPhoneValid ? const Color(0xFF10B981) : Colors.redAccent) : const Color(0xff1193D4),
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            suffixIcon: !isTouched
                ? null
                : Icon(
                    isPhoneValid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: isPhoneValid ? const Color(0xFF10B981) : Colors.redAccent,
                  ),
            prefixIcon: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showCountryPicker = !_showCountryPicker;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_selectedCountry['flag'] as String, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 4),
                      Text(_selectedCountry['code'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Icon(
                        _showCountryPicker ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                        size: 18,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 1,
                        height: 20,
                        color: Colors.grey.shade300,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          validator: (value) {
            final number = _numberController.text.trim();
            if (number.isEmpty) {
              return 'Please enter a mobile number';
            }
            final minLen = _selectedCountry['min'] as int;
            final maxLen = _selectedCountry['max'] as int;
            if (number.length < minLen || number.length > maxLen) {
              if (minLen == maxLen) {
                return 'Number must be exactly $minLen digits';
              }
              return 'Number must be between $minLen and $maxLen digits';
            }
            try {
              final parsed = PhoneNumber.parse(number, destinationCountry: _selectedCountry['isoCode'] as IsoCode);
              if (!parsed.isValid()) {
                return 'Invalid mobile number for ${_selectedCountry['name']}';
              }
            } catch (_) {
              // Ignore parser errors and just rely on length if it fails
            }
            if (widget.validator != null) {
              return widget.validator!(widget.controller.text);
            }
            return null;
          },
        ),
        if (_showCountryPicker) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: countryCodes.map((country) {
                final isSelected = country['name'] == _selectedCountry['name'];
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedCountry = country;
                      _showCountryPicker = false;
                      final maxLen = country['max'] as int;
                      if (_numberController.text.length > maxLen) {
                        _numberController.text = _numberController.text.substring(0, maxLen);
                      }
                    });
                    _updateWidgetController();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xff1193D4).withValues(alpha: 0.1) : Colors.white,
                      border: Border.all(
                        color: isSelected ? const Color(0xff1193D4) : Colors.grey.shade200,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(country['flag'] as String, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          country['name'] as String,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isSelected ? const Color(0xff1193D4) : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          country['code'] as String,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}
