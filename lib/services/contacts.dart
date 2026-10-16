import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('dorosi/contacts');

/// Opens the phone's contacts and returns the chosen number and name, or null
/// when nothing was chosen.
Future<({String number, String name})?> pickContactPhone() async {
  if (kIsWeb) return null;
  final r = await _channel.invokeMapMethod<String, String>('pickPhone');
  final number = r?['number'] ?? '';
  if (number.isEmpty) return null;
  return (number: number, name: r?['name'] ?? '');
}
