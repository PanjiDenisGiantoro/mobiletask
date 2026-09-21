import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

void main() {
  final dir = Directory('assets/lottie');
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final f in files) {
    test('parses ${f.path}', () async {
      final bytes = await f.readAsBytes();
      final data = ByteData.view(Uint8List.fromList(bytes).buffer);
      final comp = await LottieComposition.fromByteData(data);
      expect(comp.layers, isNotEmpty);
      // ignore: avoid_print
      print('${f.path}: layers=${comp.layers.length} duration=${comp.duration}');
    });
  }
}
