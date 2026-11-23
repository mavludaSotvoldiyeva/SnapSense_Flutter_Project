import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'services/classifier.dart';
import 'services/image_sources.dart';
import 'theme/app_theme.dart';

void main() => runApp(const ClassifierApp());

class ScanEntry {
  ScanEntry(this.bytes, this.source, this.predictions, this.duration);
  final Uint8List bytes;
  final String source;
  final List<Prediction> predictions;
  final Duration duration;
}

class ClassifierApp extends StatefulWidget {
  const ClassifierApp({super.key});
  @override
  State<ClassifierApp> createState() => _ClassifierAppState();
}

class _ClassifierAppState extends State<ClassifierApp> {
  Classifier? classifier;
  String? loadError;
  bool started = false;
  bool busy = false;
  int tab = 0;
  final history = <ScanEntry>[];
  final sources = ImageSources();

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  Future<void> loadModel() async {
    setState(() => loadError = null);
    try {
      final loaded = await Classifier.load();
      if (!mounted) { loaded.close(); return; }
      setState(() => classifier = loaded);
    } catch (error) {
      if (mounted) setState(() => loadError = 'Unable to load assets/model/model_unquant.tflite or labels.txt.\n$error');
    }
  }

  @override
  void dispose() {
    classifier?.close();
    super.dispose();
  }

  Future<void> runSource(String source, Future<Uint8List?> Function() acquire) async {
    if (busy || classifier == null) return;
    setState(() => busy = true);
    try {
      final bytes = await acquire();
      if (bytes == null || !mounted) return;
      final timer = Stopwatch()..start();
      final predictions = classifier!.classify(bytes);
      timer.stop();
      final entry = ScanEntry(bytes, source, predictions, timer.elapsed);
      setState(() => history.insert(0, entry));
      if (mounted) await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultScreen(entry: entry)));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not classify image: $error')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> downloadDialog() async {
    final controller = TextEditingController();
    final url = await showDialog<String>(context: context, builder: (context) => AlertDialog(
      title: const Text('Download an image'),
      content: TextField(controller: controller, keyboardType: TextInputType.url, autofocus: true, decoration: const InputDecoration(hintText: 'https://example.com/photo.jpg')),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Download'))],
    ));
    controller.dispose();
    if (url != null && url.trim().isNotEmpty && mounted) await runSource('Download', () => sources.fromUrl(url));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SnapSense',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Builder(builder: (context) {
        if (!started || classifier == null) {
          return Scaffold(body: SafeArea(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(Icons.auto_awesome_rounded, size: 76, color: AppTheme.accent),
            const SizedBox(height: 24),
            Text('SnapSense', textAlign: TextAlign.center, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Recognise numbers from zero to five using your own offline AI model.', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Wrap(alignment: WrapAlignment.center, spacing: 8, children: (classifier?.labels ?? ['zero', 'one', 'two', 'three', 'four', 'five']).map((label) => Chip(label: Text(label))).toList()),
            const SizedBox(height: 28),
            if (loadError != null) ...[Text(loadError!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)), const SizedBox(height: 12), FilledButton(onPressed: loadModel, child: const Text('Retry loading'))]
            else if (classifier == null) const Center(child: CircularProgressIndicator())
            else FilledButton(onPressed: () => setState(() => started = true), child: const Text('Get started')),
          ]))));
        }
        return Scaffold(
          appBar: AppBar(title: Text(['SnapSense', 'History', 'Model details'][tab], style: const TextStyle(fontWeight: FontWeight.bold))),
          body: Stack(children: [
            IndexedStack(index: tab, children: [
              HomeScreen(last: history.isEmpty ? null : history.first, camera: () => runSource('Camera', sources.fromCamera), gallery: () => runSource('Gallery', sources.fromGallery), download: downloadDialog, openLast: () { if (history.isNotEmpty) Navigator.push(context, MaterialPageRoute(builder: (_) => ResultScreen(entry: history.first))); }),
              HistoryScreen(entries: history),
              ModelScreen(classifier: classifier!),
            ]),
            if (busy) Container(color: Colors.black26, child: const Center(child: Card(child: Padding(padding: EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Processing image...')]))))),
          ]),
          bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (value) => setState(() => tab = value), destinations: const [NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'), NavigationDestination(icon: Icon(Icons.history), label: 'History'), NavigationDestination(icon: Icon(Icons.memory), label: 'Model')]),
        );
      }),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.last, required this.camera, required this.gallery, required this.download, required this.openLast});
  final ScanEntry? last;
  final VoidCallback camera;
  final VoidCallback gallery;
  final VoidCallback download;
  final VoidCallback openLast;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('What would you like to scan?', style: style.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Choose an image source. Recognition runs on your device.'),
      const SizedBox(height: 24),
      ActionTile(icon: Icons.camera_alt_outlined, title: 'Take a photo', subtitle: 'Use your phone camera', onTap: camera),
      ActionTile(icon: Icons.photo_library_outlined, title: 'Choose from gallery', subtitle: 'Select an existing image', onTap: gallery),
      ActionTile(icon: Icons.cloud_download_outlined, title: 'Download an image', subtitle: 'Paste an image URL', onTap: download),
      const SizedBox(height: 28),
      Text('Most recent result', style: style.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      if (last == null) const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No scans yet. Try one of the options above.'))))
      else ScanTile(entry: last!, onTap: openLast),
    ]);
  }
}

class ActionTile extends StatelessWidget {
  const ActionTile({super.key, required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(icon)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right), onTap: onTap));
}

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.entry});
  final ScanEntry entry;
  @override
  Widget build(BuildContext context) {
    final top = entry.predictions.first;
    return Scaffold(
      appBar: AppBar(title: const Text('Result'), actions: [Padding(padding: const EdgeInsets.only(right: 18), child: Center(child: Text(entry.source)))]),
      body: LayoutBuilder(builder: (context, constraints) => ListView(padding: const EdgeInsets.all(20), children: [
        Container(height: constraints.maxHeight * .42, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.memory(entry.bytes, fit: BoxFit.contain))),
        const SizedBox(height: 20),
        Text('Best match: ${top.label}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Inference: ${entry.duration.inMilliseconds} ms'),
        const SizedBox(height: 20),
        ...entry.predictions.asMap().entries.map((item) {
          final prediction = item.value;
          final best = item.key == 0;
          return Padding(padding: const EdgeInsets.only(bottom: 18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(prediction.label, style: TextStyle(fontWeight: best ? FontWeight.bold : FontWeight.normal))), Text('${(prediction.confidence * 100).toStringAsFixed(1)}%', style: TextStyle(fontWeight: best ? FontWeight.bold : FontWeight.normal))]),
            const SizedBox(height: 7),
            LinearProgressIndicator(value: prediction.confidence.clamp(0.0, 1.0), minHeight: 9, borderRadius: BorderRadius.circular(8), backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest, color: best ? AppTheme.accent : AppTheme.accent.withValues(alpha: .35)),
          ]));
        }),
      ])),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.entries});
  final List<ScanEntry> entries;
  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.history_toggle_off, size: 64), SizedBox(height: 14), Text('No history yet'), SizedBox(height: 8), Text('Your scans will appear here during this session.', textAlign: TextAlign.center)])));
    return ListView.builder(padding: const EdgeInsets.all(16), itemCount: entries.length, itemBuilder: (context, index) => ScanTile(entry: entries[index], onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ResultScreen(entry: entries[index])))));
  }
}

class ScanTile extends StatelessWidget {
  const ScanTile({super.key, required this.entry, required this.onTap});
  final ScanEntry entry;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(onTap: onTap, contentPadding: const EdgeInsets.all(12), leading: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(entry.bytes, width: 58, height: 58, fit: BoxFit.cover)), title: Text(entry.predictions.first.label, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${(entry.predictions.first.confidence * 100).toStringAsFixed(1)}% • ${entry.source}'), trailing: const Icon(Icons.chevron_right)));
}

class ModelScreen extends StatelessWidget {
  const ModelScreen({super.key, required this.classifier});
  final Classifier classifier;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    const Icon(Icons.psychology_outlined, size: 72, color: AppTheme.accent),
    const SizedBox(height: 12),
    Text('Your trained model', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
    const SizedBox(height: 20),
    Card(child: Column(children: [ListTile(title: const Text('Model file'), subtitle: const Text('model_unquant.tflite')), ListTile(title: const Text('Input image size'), subtitle: Text('${classifier.inputSize} × ${classifier.inputSize} RGB')), ListTile(title: const Text('Number of classes'), subtitle: Text('${classifier.labels.length}')), const ListTile(title: Text('Processing'), subtitle: Text('Offline, on-device TensorFlow Lite'))])),
    const SizedBox(height: 20),
    Text('Recognised classes', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
    const SizedBox(height: 12),
    Wrap(spacing: 8, runSpacing: 4, children: classifier.labels.map((label) => Chip(label: Text(label))).toList()),
    const SizedBox(height: 24),
    const Text('Interface: original Material 3 design built for this project.'),
  ]);
}
