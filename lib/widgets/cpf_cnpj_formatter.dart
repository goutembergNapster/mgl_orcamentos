import 'package:flutter/services.dart';

class CpfCnpjInputFormatter extends TextInputFormatter {
  const CpfCnpjInputFormatter();

  String _onlyDigits(String v) => v.replaceAll(RegExp(r'[^0-9]'), '');

  String _formatCpf(String digits) {
    // ###.###.###-##
    final buf = StringBuffer();
    for (var i = 0; i < digits.length && i < 11; i++) {
      if (i == 3 || i == 6) buf.write('.');
      if (i == 9) buf.write('-');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  String _formatCnpj(String digits) {
    // ##.###.###/####-##
    final buf = StringBuffer();
    for (var i = 0; i < digits.length && i < 14; i++) {
      if (i == 2 || i == 5) buf.write('.');
      if (i == 8) buf.write('/');
      if (i == 12) buf.write('-');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = _onlyDigits(newValue.text);

    // decide CPF x CNPJ pelo comprimento (<=11 => CPF; >11 => CNPJ)
    final formatted = digits.length <= 11 ? _formatCpf(digits) : _formatCnpj(digits);

    // posiciona o cursor no final do texto formatado
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
      composing: TextRange.empty,
    );
  }
}
