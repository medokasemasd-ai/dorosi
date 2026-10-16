// Phone numbers are stored with their country code, like +201012345678.

import 'format.dart';

/// Countries offered for phone numbers: name, flag and dialling code.
const countries = [
  ('مصر', '🇪🇬', '20'),
  ('السعودية', '🇸🇦', '966'),
  ('الإمارات', '🇦🇪', '971'),
  ('الكويت', '🇰🇼', '965'),
  ('قطر', '🇶🇦', '974'),
  ('البحرين', '🇧🇭', '973'),
  ('عُمان', '🇴🇲', '968'),
  ('الأردن', '🇯🇴', '962'),
  ('ليبيا', '🇱🇾', '218'),
  ('السودان', '🇸🇩', '249'),
  ('العراق', '🇮🇶', '964'),
];

/// Splits a stored or typed number into its country code and the local part.
/// A number without a code is taken to be from [fallback].
(String code, String local) splitPhone(String phone, {String fallback = '20'}) {
  var p = westernDigits(phone).replaceAll(RegExp(r'[^0-9+]'), '');
  if (p.startsWith('00')) p = '+${p.substring(2)}';
  if (p.startsWith('+')) {
    p = p.substring(1);
    for (final (_, _, code) in countries) {
      if (p.startsWith(code)) return (code, _local(p.substring(code.length)));
    }
    return ('', p);
  }
  return (fallback, _local(p));
}

String _local(String p) => p.startsWith('0') ? p.substring(1) : p;

/// The number to store, like +201012345678, or empty when there is no number.
String joinPhone(String code, String local) {
  final l = _local(westernDigits(local).replaceAll(RegExp(r'[^0-9]'), ''));
  if (l.isEmpty) return '';
  return code.isEmpty ? '+$l' : '+$code$l';
}
