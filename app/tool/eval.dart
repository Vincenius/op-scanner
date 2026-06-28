// ignore_for_file: avoid_print
// Recognition eval harness. Decodes a folder of card photos, hashes each (per
// /shared/HASHING.md), matches against a phash database, and reports top-1 /
// top-3 accuracy + latency. Bring your own photos (third-party card art is not
// committed to this repo).
//
//   dart run tool/eval.dart <phashDb.json> <imagesDir>
//
// - phashDb.json: { "<variantId>": "<48-hex phash>", ... } (export from the API
//   /catalog/sync or the DB).
// - imagesDir: files named "<expectedVariantId>.(png|jpg)". Suffixes after a
//   "__" are ignored, so "OP01-016__angle1.jpg" expects "OP01-016".
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:op_scanner/src/scan/matcher.dart';
import 'package:op_scanner/src/scan/phash.dart';

RgbImage _toRgb(img.Image im) {
  final w = im.width, h = im.height;
  final d = Uint8List(w * h * 3);
  var i = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = im.getPixel(x, y);
      d[i++] = p.r.toInt();
      d[i++] = p.g.toInt();
      d[i++] = p.b.toInt();
    }
  }
  return RgbImage(d, w, h);
}

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('usage: dart run tool/eval.dart <phashDb.json> <imagesDir>');
    exit(2);
  }
  final db = (jsonDecode(File(args[0]).readAsStringSync()) as Map).cast<String, String>();
  final files = Directory(args[1])
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.png') || f.path.endsWith('.jpg'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  var top1 = 0, top3 = 0;
  final latencies = <int>[];

  for (final f in files) {
    final name = f.uri.pathSegments.last.replaceAll(RegExp(r'\.(png|jpg)$'), '');
    final expected = name.split('__').first;
    final decoded = img.decodeImage(f.readAsBytesSync());
    if (decoded == null) {
      print('$name: could not decode');
      continue;
    }
    final rgb = _toRgb(decoded);
    final sw = Stopwatch()..start();
    final hash = phashFromRgb(rgb);
    final res = matchHash(hash, db);
    sw.stop();
    latencies.add(sw.elapsedMicroseconds);

    final t1 = res.top1!.variantId;
    final inTop3 = res.top3.any((c) => c.variantId == expected);
    if (t1 == expected) top1++;
    if (inTop3) top3++;
    final tag = t1 == expected ? 'OK ' : 'MISS';
    print('[$tag] $expected -> top1=$t1 d=${res.top1!.distance} '
        'accepted=${res.accepted} | ${res.top3.map((c) => "${c.variantId}:${c.distance}").join(", ")}');
  }

  final n = latencies.length;
  final avgMs = n == 0 ? 0 : latencies.reduce((a, b) => a + b) / n / 1000;
  print('-' * 60);
  print('images: $n | top-1: $top1/$n | top-3: $top3/$n | '
      'avg hash+match: ${avgMs.toStringAsFixed(2)} ms | db size: ${db.length}');
}
