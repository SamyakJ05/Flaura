import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

void main() => runApp(const FlauraApp());

class FlauraApp extends StatelessWidget {
  const FlauraApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Flaura',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff176b43)),
      useMaterial3: true,
    ),
    home: const IdentifyPage(),
  );
}

class IdentifyPage extends StatefulWidget {
  const IdentifyPage({super.key});
  @override
  State<IdentifyPage> createState() => _IdentifyPageState();
}

class _IdentifyPageState extends State<IdentifyPage> {
  final _picker = ImagePicker();
  Interpreter? _interpreter;
  List<String>? _labels;
  XFile? _image;
  String? _result;
  bool _working = false;

  Future<void> _load() async {
    _interpreter ??= await Interpreter.fromAsset(
      'assets/models/flaura_flowers102.tflite',
    );
    _labels ??= List<String>.from(
      jsonDecode(await rootBundle.loadString('assets/models/labels.json'))
          as List,
    );
  }

  Future<void> _pick(ImageSource source) async {
    final selected = await _picker.pickImage(source: source, imageQuality: 90);
    if (selected == null) return;
    setState(() {
      _image = selected;
      _result = null;
      _working = true;
    });
    try {
      await _load();
      final prediction = await _classify(await selected.readAsBytes());
      if (mounted) {
        setState(
          () => _result =
              '${prediction.$1}  •  ${(prediction.$2 * 100).toStringAsFixed(1)}% confident',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _result = 'Could not identify this photo: $error');
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<(String, double)> _classify(Uint8List bytes) async {
    final source = img.decodeImage(bytes);
    if (source == null) throw const FormatException('Unsupported image format');
    final resized = img.copyResize(source, width: 224, height: 224);
    final input = [
      List.generate(
        224,
        (y) => List.generate(224, (x) {
          final p = resized.getPixel(x, y);
          return [p.r.toDouble(), p.g.toDouble(), p.b.toDouble()];
        }),
      ),
    ];
    final output = [List<double>.filled(_labels!.length, 0)];
    _interpreter!.run(input, output);
    var index = 0;
    for (var i = 1; i < output[0].length; i++) {
      if (output[0][i] > output[0][index]) index = i;
    }
    return (_labels![index], output[0][index]);
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Flaura')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Identify a flower',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text('On-device recognition across 102 flower categories.'),
          const SizedBox(height: 20),
          Expanded(
            child: _image == null
                ? const Center(child: Icon(Icons.local_florist, size: 120))
                : Image.file(File(_image!.path), fit: BoxFit.contain),
          ),
          if (_working)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            ),
          if (_result != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _result!,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          FilledButton.icon(
            onPressed: _working ? null : () => _pick(ImageSource.camera),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Take photo'),
          ),
          OutlinedButton.icon(
            onPressed: _working ? null : () => _pick(ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('Choose photo'),
          ),
        ],
      ),
    ),
  );
}
