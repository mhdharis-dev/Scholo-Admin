import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

const List<Map<String, dynamic>> countryCodes = [
  {'name': 'US', 'code': '+1', 'flag': '🇺🇸', 'isoCode': IsoCode.US},
  {'name': 'IN', 'code': '+91', 'flag': '🇮🇳', 'isoCode': IsoCode.IN},
  {'name': 'UK', 'code': '+44', 'flag': '🇬🇧', 'isoCode': IsoCode.GB},
  {'name': 'UAE', 'code': '+971', 'flag': '🇦🇪', 'isoCode': IsoCode.AE},
  {'name': 'KSA', 'code': '+966', 'flag': '🇸🇦', 'isoCode': IsoCode.SA},
  {'name': 'PK', 'code': '+92', 'flag': '🇵🇰', 'isoCode': IsoCode.PK},
  {'name': 'AU', 'code': '+61', 'flag': '🇦🇺', 'isoCode': IsoCode.AU},
  {'name': 'DE', 'code': '+49', 'flag': '🇩🇪', 'isoCode': IsoCode.DE},
  {'name': 'FR', 'code': '+33', 'flag': '🇫🇷', 'isoCode': IsoCode.FR},
  {'name': 'SG', 'code': '+65', 'flag': '🇸🇬', 'isoCode': IsoCode.SG},
];

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
  }

  @override
  void dispose() {
    _numberController.removeListener(_updateWidgetController);
    _numberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: _numberController,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: widget.labelText,
            labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xff1193D4), width: 1.5),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            try {
              final parsed = PhoneNumber.parse(number, destinationCountry: _selectedCountry['isoCode'] as IsoCode);
              if (!parsed.isValid()) {
                return 'Invalid mobile number for ${_selectedCountry['name']}';
              }
            } catch (_) {
              return 'Invalid mobile number';
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
