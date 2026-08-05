import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_litert/flutter_litert.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

const _forest = Color(0xff104b37);
const _leaf = Color(0xff287a58);
const _cream = Color(0xfff7f7f1);
const _ink = Color(0xff17221d);

void main() => runApp(const FlauraApp());

class FlauraApp extends StatelessWidget {
  const FlauraApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Flaura: Flower ID',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _leaf,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: _cream,
      fontFamily: 'SF Pro Display',
    ),
    home: const IdentifyPage(),
  );
}

class Prediction {
  const Prediction(this.label, this.confidence);
  final String label;
  final double confidence;
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
  List<Prediction>? _predictions;
  String? _error;
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
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final selected = await _picker.pickImage(
        source: source,
        imageQuality: 96,
        maxWidth: 2048,
      );
      if (selected == null) return;
      if (mounted) {
        setState(() {
          _image = selected;
          _predictions = null;
        });
      }
      await _load();
      final predictions = await _classify(await selected.readAsBytes());
      if (mounted) setState(() => _predictions = predictions);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'We could not read that photo. Try another image.',
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<List<Prediction>> _classify(Uint8List bytes) async {
    final source = img.decodeImage(bytes);
    if (source == null) throw const FormatException('Unsupported image format');
    final resized = img.copyResize(source, width: 224, height: 224);
    final input = [
      List.generate(
        224,
        (y) => List.generate(224, (x) {
          final pixel = resized.getPixel(x, y);
          return [pixel.r.toDouble(), pixel.g.toDouble(), pixel.b.toDouble()];
        }),
      ),
    ];
    final output = [List<double>.filled(_labels!.length, 0)];
    _interpreter!.run(input, output);
    final ranked = List<int>.generate(output[0].length, (index) => index)
      ..sort((a, b) => output[0][b].compareTo(output[0][a]));
    return ranked
        .take(3)
        .map((index) => Prediction(_labels![index], output[0][index]))
        .toList();
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prediction = _predictions?.first;
    final isUncertain = prediction != null && prediction.confidence < 0.45;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xffeaf5ed), _cream, Color(0xfffffdf8)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _BrandHeader(onReset: _image == null ? null : _reset),
                    const SizedBox(height: 30),
                    Text(
                      _image == null ? 'Meet a flower\nin the wild.' : 'Let’s identify\nthis bloom.',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: _ink,
                        fontWeight: FontWeight.w700,
                        height: 1.03,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Private, on-device identification across 102 flower species.',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _ink.withValues(alpha: 0.72),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _PhotoPanel(image: _image, loading: _working),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      child: _error != null
                          ? _MessageCard(
                              key: const ValueKey('error'),
                              icon: Icons.info_outline_rounded,
                              text: _error!,
                              color: Colors.deepOrange,
                            )
                          : _predictions != null
                          ? _ResultCard(
                              key: const ValueKey('result'),
                              predictions: _predictions!,
                              uncertain: isUncertain,
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _working ? null : () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: const Text('Use camera'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _forest,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(58),
                        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                        shape: const StadiumBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _working ? null : () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Choose from library'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _forest,
                        minimumSize: const Size.fromHeight(56),
                        side: const BorderSide(color: Color(0xffb7c9bd)),
                        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                        shape: const StadiumBorder(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Tip: frame one flower in good daylight for the clearest match.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xff66746a), height: 1.35),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _reset() => setState(() {
    _image = null;
    _predictions = null;
    _error = null;
  });
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({this.onReset});
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x160e4935), blurRadius: 18, offset: Offset(0, 8))],
        ),
        padding: const EdgeInsets.all(7),
        child: Image.asset('assets/branding/flaura-logo.png'),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Text('Flaura', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: _forest, letterSpacing: -0.8)),
      ),
      if (onReset != null)
        IconButton.filledTonal(
          onPressed: onReset,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Start over',
        ),
    ],
  );
}

class _PhotoPanel extends StatelessWidget {
  const _PhotoPanel({required this.image, required this.loading});
  final XFile? image;
  final bool loading;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1.15,
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xffe0ece3),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(color: Color(0x190d3b2c), blurRadius: 28, offset: Offset(0, 14))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image != null)
            Image.file(File(image!.path), fit: BoxFit.cover)
          else
            Padding(
              padding: const EdgeInsets.all(42),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/branding/flaura-logo.png', width: 128, height: 128),
                  const SizedBox(height: 18),
                  const Text('Your next flower story starts here.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _forest)),
                ],
              ),
            ),
          if (loading)
            const ColoredBox(
              color: Color(0xAA104B37),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Looking closely…', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({super.key, required this.predictions, required this.uncertain});
  final List<Prediction> predictions;
  final bool uncertain;

  @override
  Widget build(BuildContext context) {
    final best = predictions.first;
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: uncertain ? const Color(0xfffff7e5) : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: uncertain ? const Color(0xfff2d18b) : const Color(0xffd5e3d9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(uncertain ? Icons.auto_awesome_outlined : Icons.local_florist_rounded, color: _leaf),
              const SizedBox(width: 8),
              Text(uncertain ? 'Needs a closer look' : 'Best match', style: const TextStyle(color: _forest, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          Text(_title(best.label), style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -0.7)),
          const SizedBox(height: 4),
          Text(
            uncertain ? 'This is a low-confidence match. Try one flower, closer and in daylight.' : '${(best.confidence * 100).toStringAsFixed(0)}% confident',
            style: TextStyle(color: _ink.withValues(alpha: 0.68), height: 1.35),
          ),
          const SizedBox(height: 14),
          for (final prediction in predictions.skip(1))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(child: Text(_title(prediction.label), style: const TextStyle(fontWeight: FontWeight.w600))),
                  Text('${(prediction.confidence * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Color(0xff66746a))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _title(String value) => value.split('-').map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}').join(' ');
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({super.key, required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 18),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
    child: Row(children: [Icon(icon, color: color), const SizedBox(width: 12), Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)))]),
  );
}
