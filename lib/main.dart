
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const MiSamplerApp());
}

class MiSamplerApp extends StatelessWidget {
  const MiSamplerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sampler Perreo',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.deepOrange,
      ),
      home: const SamplerScreen(),
    );
  }
}

class SamplePad {
  final int id;
  String name;
  String? filePath;
  final AudioPlayer player;

  SamplePad({
    required this.id,
    required this.name,
    this.filePath,
  }) : player = AudioPlayer();

  void dispose() {
    player.dispose();
  }
}

class SamplerScreen extends StatefulWidget {
  const SamplerScreen({super.key});

  @override
  State<SamplerScreen> createState() => _SamplerScreenState();
}

class _SamplerScreenState extends State<SamplerScreen> {
  final List<SamplePad> _pads = List.generate(
    16,
    (index) => SamplePad(
      id: index,
      name: 'Pad ${index + 1}',
    ),
  );

  String _status = 'Listo para cargar sonidos';

  @override
  void dispose() {
    for (final pad in _pads) {
      pad.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSample(int index) async {
    try {
      final FilePickerResult? result =
          await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wav', 'mp3', 'ogg', 'm4a', 'aac'],
      );

      if (result == null || result.files.isEmpty) return;

      final PlatformFile file = result.files.single;
      final String? path = file.path;

      if (path == null) {
        if (!mounted) return;
        setState(() {
          _status = 'No se pudo acceder al archivo de audio';
        });
        return;
      }

      if (!mounted) return;

      setState(() {
        _pads[index].filePath = path;
        _pads[index].name = file.name;
        _status = 'Sonido cargado: ${file.name}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Error al cargar el sonido';
      });
    }
  }

  Future<void> _playSound(int index) async {
    final SamplePad pad = _pads[index];

    if (pad.filePath == null) {
      await _loadSample(index);
      return;
    }

    try {
      await pad.player.stop();
      await pad.player.play(
        DeviceFileSource(pad.filePath!),
      );

      if (!mounted) return;

      setState(() {
        _status = 'Reproduciendo: ${pad.name}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Error al reproducir el sonido';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sampler Perreo'),
        centerTitle: true,
        backgroundColor: Colors.black54,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.black87,
            width: double.infinity,
            child: Text(
              _status,
              style: const TextStyle(
                color: Colors.deepOrange,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: GridView.builder(
                itemCount: _pads.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  final SamplePad pad = _pads[index];
                  final bool hasSound = pad.filePath != null;

                  return GestureDetector(
                    onTap: () => _playSound(index),
                    onLongPress: () => _loadSample(index),
                    child: Container(
                      decoration: BoxDecoration(
                        color: hasSound
                            ? Colors.deepOrange
                            : Colors.grey[850],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: hasSound
                              ? Colors.orangeAccent
                              : Colors.grey,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            hasSound
                                ? Icons.music_note
                                : Icons.add_circle_outline,
                            size: 32,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            child: Text(
                              pad.name,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
