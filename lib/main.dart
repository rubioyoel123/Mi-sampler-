import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'dart:math' as math;

void main() {
  runApp(const MiSamplerApp());
}

class MiSamplerApp extends StatelessWidget {
  const MiSamplerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi Sampler - DJ Dannys Yoel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1B1B22),
      ),
      home: const SamplerStudio(),
    );
  }
}

class SamplerStudio extends StatefulWidget {
  const SamplerStudio({super.key});

  @override
  State<SamplerStudio> createState() => _SamplerStudioState();
}

class _SamplerStudioState extends State<SamplerStudio> with TickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  final MidiCommand _midiCommand = MidiCommand();
  double masterVolume = 1.0;
  double masterPitch = 1.0;

  late AnimationController _visualizerController;

  final List<Map<String, dynamic>> pads = [
    {'name': 'KICK', 'color': Colors.orange, 'key': '1', 'midi': 36},
    {'name': 'SNARE', 'color': Colors.orange, 'key': '2', 'midi': 37},
    {'name': 'HI-HAT', 'color': Colors.orange, 'key': '3', 'midi': 38},
    {'name': 'CLAP', 'color': Colors.orange, 'key': '4', 'midi': 39},
    {'name': 'LOOP 1', 'color': Colors.blue, 'key': 'Q', 'midi': 40},
    {'name': 'LOOP 2', 'color': Colors.blue, 'key': 'W', 'midi': 41},
    {'name': 'SAMPLE 1', 'color': Colors.blueAccent, 'key': 'E', 'midi': 42},
    {'name': 'SAMPLE 2', 'color': Colors.greenAccent, 'key': 'R', 'midi': 43},
    {'name': 'SYNTH', 'color': Colors.green, 'key': 'A', 'midi': 44},
    {'name': 'BASS', 'color': Colors.green, 'key': 'S', 'midi': 45},
    {'name': 'VOX 1', 'color': Colors.green, 'key': 'D', 'midi': 46},
    {'name': 'VOX 2', 'color': Colors.green, 'key': 'F', 'midi': 47},
    {'name': 'FX 1', 'color': Colors.purpleAccent, 'key': 'Z', 'midi': 48},
    {'name': 'FX 2', 'color': Colors.purpleAccent, 'key': 'X', 'midi': 49},
    {'name': 'SHOT 1', 'color': Colors.amber, 'key': 'C', 'midi': 50},
    {'name': 'SHOT 2', 'color': Colors.amber, 'key': 'V', 'midi': 51},
  ];

  @override
  void initState() {
    super.initState();
    for (var pad in pads) {
      pad['player'] = AudioPlayer();
      pad['path'] = null;
      pad['active'] = false;
    }
    _initMidi();

    _visualizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
  }

  @override
  void dispose() {
    _visualizerController.dispose();
    for (var pad in pads) {
      (pad['player'] as AudioPlayer).dispose();
    }
    super.dispose();
  }

  Future<void> _initMidi() async {
    List<MidiDevice>? devices = await _midiCommand.devices;
    if (devices != null && devices.isNotEmpty) {
      _midiCommand.connectToDevice(devices.first);
      _midiCommand.onMidiDataReceived?.listen((event) {
        if (event.data[0] == 144 && event.data[2] > 0) {
          int note = event.data[1];
          int padIndex = pads.indexWhere((p) => p['midi'] == note);
          if (padIndex != -1) _playPad(padIndex);
        }
      });
    }
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      String key = event.logicalKey.keyLabel.toUpperCase();
      int padIndex = pads.indexWhere((p) => p['key'] == key);
      if (padIndex != -1) _playPad(padIndex);
    }
  }

  Future<void> _playPad(int index) async {
    final pad = pads[index];
    final AudioPlayer player = pad['player'];
    final String? path = pad['path'];

    setState(() => pad['active'] = true);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => pad['active'] = false);
    });

    if (path != null) {
      await player.setVolume(masterVolume);
      await player.setPlaybackRate(masterPitch);
      await player.stop();
      await player.play(DeviceFileSource(path));
    }
  }

  Future<void> _loadAudio(int index) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      setState(() => pads[index]['path'] = result.files.single.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    FocusScope.of(context).requestFocus(_focusNode);
    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: _handleKeyEvent,
      child: Scaffold(
        appBar: _buildTopBar(),
        body: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  _buildLeftPanel(),
                  _buildPadsArea(),
                  _buildRightPanel(),
                ],
              ),
            ),
            _buildStatusBar(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildTopBar() {
    return AppBar(
      title: const Text('Mi Sampler - Windows', style: TextStyle(fontSize: 16)),
      backgroundColor: const Color(0xFF202028),
      elevation: 2,
      actions: [
        IconButton(icon: const Icon(Icons.circle, color: Colors.redAccent, size: 24), onPressed: () {}),
        IconButton(icon: const Icon(Icons.play_arrow, size: 28), onPressed: () {}),
        IconButton(icon: const Icon(Icons.pause, size: 28), onPressed: () {}),
        IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
      ],
    );
  }

  Widget _buildLeftPanel() {
    return Expanded(
      flex: 3,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF141419),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const Text(
              'ESPECTRO CANAL L',
              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            _buildAnimatedVisualizer(Colors.cyanAccent),
            const Divider(color: Colors.white10, height: 20),
            const Text(
              'CONTROLES MAESTROS',
              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _KnobControl(
                  label: 'VOLUME',
                  value: masterVolume,
                  onChanged: (v) => setState(() => masterVolume = v),
                ),
                _KnobControl(
                  label: 'PITCH',
                  value: masterPitch,
                  onChanged: (v) => setState(() => masterPitch = v),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedVisualizer(Color color) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: AnimatedBuilder(
        animation: _visualizerController,
        builder: (context, child) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(16, (i) {
              final waveHeight = math.sin(_visualizerController.value * 2 * math.pi + i) * 0.5 + 0.5;
              return Container(
                width: 6,
                height: 20.0 + (waveHeight * 80.0),
                color: color.withOpacity(0.85),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildPadsArea() {
    return Expanded(
      flex: 5,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 16,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.1,
        ),
        itemBuilder: (context, index) {
          final pad = pads[index];
          final Color col = pad['color'];
          final bool active = pad['active'];
          final bool hasAudio = pad['path'] != null;

          return GestureDetector(
            onTapDown: (_) => _playPad(index),
            onDoubleTap: () => _loadAudio(index),
            onSecondaryTapDown: (_) => _loadAudio(index),
            onLongPress: () => _loadAudio(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 50),
              decoration: BoxDecoration(
                color: active ? col.withOpacity(0.8) : col.withOpacity(hasAudio ? 0.25 : 0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: active ? Colors.white : col, width: 2),
                boxShadow: active ? [BoxShadow(color: col, blurRadius: 15, spreadRadius: 2)] : [],
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          pad['name'],
                          style: TextStyle(
                            color: active ? Colors.white : col,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tecla: ${pad['key']}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasAudio)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Icon(Icons.music_note, size: 12, color: col.withOpacity(0.8)),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRightPanel() {
    return Expanded(
      flex: 3,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF141419),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const Text(
              'ESPECTRO CANAL R',
              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            _buildAnimatedVisualizer(Colors.blueAccent),
            const Divider(color: Colors.white10, height: 20),
            const Text(
              'ESTADO DEL TEMPO',
              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
              ),
              child: Column(
                children: const [
                  Text('128.0', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('BPM', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFF101014),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('DOBLE CLIC izquierdo o CLIC DERECHO para cargar un sonido', style: TextStyle(color: Colors.white54, fontSize: 11)),
          Row(
            children: [
              const Text('CPU/memoria ', style: TextStyle(color: Colors.white54, fontSize: 11)),
              Container(
                width: 50,
                height: 8,
                color: Colors.blueGrey[900],
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.3,
                  child: Container(color: Colors.blueAccent),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class _KnobControl extends StatefulWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _KnobControl({required this.label, required this.value, required this.onChanged});

  @override
  State<_KnobControl> createState() => _KnobControlState();
}

class _KnobControlState extends State<_KnobControl> {
  late double _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              _currentValue -= details.delta.dy * 0.01;
              _currentValue = _currentValue.clamp(0.0, 1.0);
              widget.onChanged(_currentValue);
            });
          },
          child: Transform.rotate(
            angle: (_currentValue * 2 * math.pi) - math.pi,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF282833),
                border: Border.all(color: Colors.black, width: 2),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(2, 2))],
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 3,
                  height: 12,
                  color: Colors.blueAccent,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.label,
          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
