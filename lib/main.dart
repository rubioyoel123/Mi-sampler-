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
      title: 'Mi Sampler',
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
  AudioPlayer player;

  SamplePad({
    required this.id,
    required this.name,
    this.filePath,
  }) : player = AudioPlayer();
}

class SamplerScreen extends StatefulWidget {
  const SamplerScreen({super.key});

  @override
  State<SamplerScreen> createState() => _SamplerScreenState();
}

class _SamplerScreenState extends StatefulWidget {
  final List<SamplePad> _pads = List.generate(
    16,
    (index) => SamplePad(id: index, name: 'Pad ${index + 1}'),
  );

  String _status = 'Listo para cargar sonidos';

  @override
  void dispose() {
    for (var pad in _pads) {
      pad.player.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSample(int index) async {
    try {
      final files = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wav', 'mp3', 'ogg', 'm4a', 'aac'],
      );

      if (files == null || files.files.isEmpty) return;

      final file = files.files.single;
      final path = file.path;

      if (path == null) {
        if (!mounted) return;
        setState(() {
          _status = 'No se pudo acceder al archivo';
        });
        return;
      }

      if (!mounted) return;

      setState(() {
        _pads[index].filePath = path;
        _pads[index].name = file.name;
        _status = 'Sonido cargado: ${file.name}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = 'Error al cargar el sonido';
      });
    }
  }

  Future<void> _playSound(int index) async {
    final pad = _pads[index];
    if (pad.filePath != null) {
      await pad.player.stop();
      await pad.player.play(DeviceFileSource(pad.filePath!));
      setState(() {
        _status = 'Reproduciendo: ${pad.name}';
      });
    } else {
      // Si el pad está vacío, al presionarlo abre el selector para cargar audio
      await _loadSample(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Sampler DJ'),
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
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: GridView.builder(
                itemCount: _pads.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.0,
                ),
                itemBuilder: (context, index) {
                  final pad = _pads[index];
                  final bool hasAudio = pad.filePath != null;

                  return InkWell(
                    onTap: () => _playSound(index),
                    onLongPress: () => _loadSample(index),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: hasAudio ? Colors.deepOrange : Colors.grey[850],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: hasAudio ? Colors.orangeLight : Colors.grey[700]!,
                          width: 2,
                        ),
                        boxShadow: [
                          if (hasAudio)
                            BoxShadow(
                              color: Colors.deepOrange.withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                        ],
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            hasAudio ? Icons.music_note : Icons.add,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            pad.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
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
