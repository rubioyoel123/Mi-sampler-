import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const MiSamplerApp());
}

class MiSamplerApp extends StatelessWidget {
  const MiSamplerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi Sampler',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E24),
      ),
      home: const SamplerHome(),
    );
  }
}

class SamplerHome extends StatefulWidget {
  const SamplerHome({super.key});

  @override
  State<SamplerHome> createState() => _SamplerHomeState();
}

class _SamplerHomeState extends State<SamplerHome> {
  final List<Map<String, dynamic>> pads = [
    {'name': 'KICK', 'color': Colors.orange, 'path': null, 'player': AudioPlayer()},
    {'name': 'SNARE', 'color': Colors.orange, 'path': null, 'player': AudioPlayer()},
    {'name': 'HI-HAT', 'color': Colors.orange, 'path': null, 'player': AudioPlayer()},
    {'name': 'CLAP', 'color': Colors.orange, 'path': null, 'player': AudioPlayer()},
    {'name': 'LOOP 1', 'color': Colors.blue, 'path': null, 'player': AudioPlayer()},
    {'name': 'LOOP 2', 'color': Colors.blue, 'path': null, 'player': AudioPlayer()},
    {'name': 'SAMPLE 1', 'color': Colors.blue, 'path': null, 'player': AudioPlayer()},
    {'name': 'SAMPLE 2', 'color': Colors.blue, 'path': null, 'player': AudioPlayer()},
    {'name': 'SYNTH', 'color': Colors.green, 'path': null, 'player': AudioPlayer()},
    {'name': 'BASS', 'color': Colors.green, 'path': null, 'player': AudioPlayer()},
    {'name': 'VOX 1', 'color': Colors.green, 'path': null, 'player': AudioPlayer()},
    {'name': 'VOX 2', 'color': Colors.green, 'path': null, 'player': AudioPlayer()},
    {'name': 'FX 1', 'color': Colors.purpleAccent, 'path': null, 'player': AudioPlayer()},
    {'name': 'FX 2', 'color': Colors.purpleAccent, 'path': null, 'player': AudioPlayer()},
    {'name': 'SHOT 1', 'color': Colors.amber, 'path': null, 'player': AudioPlayer()},
    {'name': 'SHOT 2', 'color': Colors.amber, 'path': null, 'player': AudioPlayer()},
  ];

  @override
  void dispose() {
    for (var pad in pads) {
      (pad['player'] as AudioPlayer).dispose();
    }
    super.dispose();
  }

  Future<void> _playPad(int index) async {
    final pad = pads[index];
    final AudioPlayer player = pad['player'] as AudioPlayer;
    final String? path = pad['path'] as String?;

    if (path != null && path.isNotEmpty) {
      await player.stop();
      await player.play(DeviceFileSource(path));
    } else {
      await _loadAudioForPad(index);
    }
  }

  Future<void> _loadAudioForPad(int index) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        pads[index]['path'] = result.files.single.path;
      });
      _playPad(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Sampler'),
        backgroundColor: const Color(0xFF25252D),
        actions: const [
          Icon(Icons.circle, color: Colors.redAccent, size: 22),
          SizedBox(width: 12),
          Icon(Icons.play_arrow, size: 26),
          SizedBox(width: 12),
          Icon(Icons.pause, size: 26),
          SizedBox(width: 12),
          Icon(Icons.settings),
          SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildSidePanel('IZQUIERDO', Colors.cyanAccent)),
                Expanded(flex: 2, child: _buildPadsGrid()),
                Expanded(child: _buildSidePanel('DERECHO', Colors.blueAccent)),
              ],
            ),
          ),
          Container(
            height: 32,
            color: const Color(0xFF121216),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            child: const Text('Sampler listo - Haz clic en un pad para cargar o reproducir audio',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildSidePanel(String titulo, Color color) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF18181D),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 90,
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Center(
              child: Icon(Icons.graphic_eq, color: color, size: 40),
            ),
          ),
          const SizedBox(height: 16),
          Text('PANEL $titulo', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPadsGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 16,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (context, index) {
        final item = pads[index];
        final Color col = item['color'] as Color;
        final String name = item['name'] as String;
        final bool hasAudio = item['path'] != null;

        return InkWell(
          onTap: () => _playPad(index),
          onLongPress: () => _loadAudioForPad(index),
          child: Container(
            decoration: BoxDecoration(
              color: hasAudio ? col.withOpacity(0.4) : col.withOpacity(0.15),
              border: Border.all(color: col, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: col,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Icon(
                  hasAudio ? Icons.music_note : Icons.folder_open,
                  size: 16,
                  color: hasAudio ? Colors.white : col.withOpacity(0.6),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
