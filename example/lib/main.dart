import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:paddle_ocr_native/paddle_ocr_native.dart';

void main() => runApp(const PaddleOcrExampleApp());

class PaddleOcrExampleApp extends StatelessWidget {
  const PaddleOcrExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Paddle OCR Native',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff176b55),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xfff7f8f7),
        useMaterial3: true,
      ),
      home: const OcrDemoScreen(),
    );
  }
}

class OcrDemoScreen extends StatefulWidget {
  const OcrDemoScreen({super.key});

  @override
  State<OcrDemoScreen> createState() => _OcrDemoScreenState();
}

class _OcrDemoScreenState extends State<OcrDemoScreen> {
  final PaddleOcr _ocr = PaddleOcr();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _imageBytes;
  OcrRunResult? _run;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    unawaited(_ocr.dispose());
    super.dispose();
  }

  Future<void> _runBundledSample() async {
    final data = await rootBundle.load('assets/ocr_sample.png');
    final bytes = data.buffer.asUint8List();
    final file = File('${Directory.systemTemp.path}/paddle_ocr_sample.png');
    await file.writeAsBytes(bytes, flush: true);
    await _recognize(file.path, bytes);
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    await _recognize(image.path, await image.readAsBytes());
  }

  Future<void> _recognize(String path, Uint8List bytes) async {
    setState(() {
      _busy = true;
      _error = null;
      _run = null;
      _imageBytes = bytes;
    });

    try {
      await _ocr.init();
      final result = await _ocr.recognize(path);
      if (!mounted) return;
      setState(() => _run = result);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final run = _run;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paddle OCR Native'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_busy)
              const LinearProgressIndicator(key: ValueKey('ocr_progress')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _SourcePreview(bytes: _imageBytes),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          key: const ValueKey('run_sample_button'),
                          onPressed: _busy ? null : _runBundledSample,
                          icon: const ExcludeSemantics(
                            child: Icon(Icons.play_arrow),
                          ),
                          label: const Text('Run sample'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('pick_image_button'),
                          onPressed: _busy ? null : _pickImage,
                          icon: const ExcludeSemantics(
                            child: Icon(Icons.photo_library_outlined),
                          ),
                          label: const Text('Choose image'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_error != null)
                    _ErrorMessage(message: _error!)
                  else if (run != null)
                    _ResultSection(run: run)
                  else
                    const _EmptyMessage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourcePreview extends StatelessWidget {
  const _SourcePreview({required this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xffe6e9e7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xffc7ceca)),
      ),
      clipBehavior: Clip.antiAlias,
      child: bytes == null
          ? const Center(
              child: Icon(
                Icons.document_scanner_outlined,
                size: 52,
                color: Color(0xff57625d),
                semanticLabel: 'No source image selected',
              ),
            )
          : Image.memory(
              bytes!,
              fit: BoxFit.contain,
              semanticLabel: 'OCR source image',
            ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({required this.run});

  final OcrRunResult run;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Results', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          '${run.results.length} regions | detection ${run.detectionTimeMs} ms | '
          'recognition ${run.recognitionTimeMs} ms',
          key: const ValueKey('ocr_metrics'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        ListView.separated(
          key: const ValueKey('ocr_result_list'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: run.results.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final result = run.results[index];
            final points = result.points
                .map((point) => point.toString())
                .join(' ');
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(result.text.isEmpty ? '(empty)' : result.text),
              subtitle: Text(points),
              trailing: Text(
                '${(result.confidence * 100).toStringAsFixed(1)}%',
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(
        message,
        key: const ValueKey('ocr_error'),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Select an image or run the bundled sample.',
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}
