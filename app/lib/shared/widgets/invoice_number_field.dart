import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Invoice amount/qty field — no keyboard suggestions and clean decimal input.
class InvoiceNumberField extends StatelessWidget {
  const InvoiceNumberField({
    super.key,
    required this.controller,
    required this.labelText,
    this.helperText,
    this.readOnly = false,
    this.filled,
    this.fillColor,
    this.onChanged,
    this.validator,
    this.decimal = true,
    this.valueKey,
  });

  final TextEditingController controller;
  final String labelText;
  final String? helperText;
  final bool readOnly;
  final bool? filled;
  final Color? fillColor;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool decimal;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: valueKey,
      controller: controller,
      readOnly: readOnly,
      keyboardType: decimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      autofillHints: const [],
      enableSuggestions: false,
      autocorrect: false,
      enableIMEPersonalizedLearning: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
      inputFormatters: [
        if (decimal)
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
        else
          FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(
        labelText: labelText,
        helperText: helperText,
        filled: filled,
        fillColor: fillColor,
      ),
      onChanged: onChanged,
      validator: validator,
    );
  }
}
