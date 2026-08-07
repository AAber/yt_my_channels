import 'dart:convert';

void main() {
  // Test Hebrew encoding
  final hebrewText = 'שלום וברכה! מצאתי עבורך שיעורים מעניינים';
  
  print('Original text: $hebrewText');
  print('Text length: ${hebrewText.length} chars');
  
  // Test UTF-8 encoding/decoding
  final encoded = utf8.encode(hebrewText);
  print('UTF-8 encoded bytes: ${encoded.length} bytes');
  print('UTF-8 bytes: $encoded');
  
  final decoded = utf8.decode(encoded);
  print('Decoded text: $decoded');
  print('Texts match: ${hebrewText == decoded}');
  
  // Test JSON encoding/decoding
  final jsonData = {'message': hebrewText};
  final jsonString = jsonEncode(jsonData);
  print('JSON encoded: $jsonString');
  
  final jsonDecoded = jsonDecode(jsonString);
  final decodedFromJson = jsonDecoded['message'];
  print('Decoded from JSON: $decodedFromJson');
  print('JSON texts match: ${hebrewText == decodedFromJson}');
}