```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SamplerPerreoApp());
}

const bg = Color(0xFF101217);
const panel = Color(0xFF191D25);
const accent = Color(0xFF75A7D2);

class SamplerPerreoApp extends StatelessWidget {
  const SamplerPerreoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sampler Perreo - DJ Dannys Yoel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
        ),
      ),
      home: const SamplerStudio(),
    );
  }
}

class SoundLayer {
  String name;
  String? path;
  double gain;
  double start;
  double end;
  double pitch;
  AudioPlayer? player;
  Timer? trimTimer;

  SoundLayer({
    this.name = 'Capa',
    this.path,
    this.gain = 1,
    this.start = 0,
    this.end = 1,
    this.pitch = 1,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
    'gain': gain,
    'start': start,
    'end': end,
    'pitch': pitch,
  };

  factory SoundLayer.fromJson(Map<String, dynamic> json) => SoundLayer(
    name: json['name'] ?? 'Capa',
    path: json['path'],
    gain: (json['gain'] as num?)?.toDouble() ?? 1,
    start: (json['start'] as num?)?.toDouble() ?? 0,
    end: (json['end'] as num?)?.toDouble() ?? 1,
    pitch: (json['pitch'] as num?)?.toDouble() ?? 1,
  );
}

class SoundPad {
  String name;
  int midi;
  String key;
  Color color;
  List<SoundLayer> layers = [];
  bool active = false;
  double gain = 1;

  SoundPad(this.name, this.midi, this.key, this.color);

  Map<String, dynamic> toJson() => {
    'name': name,
    'midi': midi,
    'key': key,
    'gain': gain,
    'layers': layers.map((e) => e.toJson()).toList(),
  };

  void loadJson(Map<String, dynamic> json) {
    name = json['name'] ?? name;
    midi = json['midi'] ?? midi;
    gain = (json['gain'] as num?)?.toDouble() ?? 1;
    layers = ((json['layers'] as List?) ?? [])
        .map((e) => SoundLayer.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

class SamplerStudio extends StatefulWidget {
  const SamplerStudio({super.key});

  @override
  State<SamplerStudio> createState() => _SamplerStudioState();
}

class _SamplerStudioState extends State<SamplerStudio> {
  final FocusNode focusNode = FocusNode();
  final MidiCommand midi = MidiCommand();
  StreamSubscription<dynamic>? midiSubscription;

  final List<List<SoundPad>> banks = [];
  int bankIndex = 0;
  int selectedPad = 0;
  double masterVolume = 0.8;
  double masterPitch = 1;
  double bpm = 128;
  bool midiLearn = false;
  bool midiConnected = false;
  String midiStatus = 'Buscando controlador MIDI...';
  List<MidiDevice> devices = [];
  String? learnTarget;

  List<SoundPad> get pads => banks[bankIndex];
  SoundPad get currentPad => pads[selectedPad];

  final List<String> padNames = const [
    'KICK', 'SNARE', 'HI-HAT', 'CLAP',
    'LOOP 1', 'LOOP 2', 'SAMPLE 1', 'SAMPLE 2',
    'SYNTH', 'BASS', 'VOX 1', 'VOX 2',
    'FX 1', 'FX 2', 'SHOT 1', 'SHOT 2',
  ];

  final List<String> keys = const [
    '1', '2', '3', '4',
    'Q', 'W', 'E', 'R',
    'A', 'S', 'D', 'F',
    'Z', 'X', 'C', 'V',
  ];

  final List<Color> colors = const [
    Colors.deepOrange,
    Colors.deepOrange,
    Colors.orange,
    Colors.orange,
    Colors.blue,
    Colors.blue,
    Colors.lightBlue,
    Colors.teal,
    Colors.green,
    Colors.green,
    Colors.lightGreen,
    Colors.lightGreen,
    Colors.purpleAccent,
    Colors.purpleAccent,
    Colors.amber,
    Colors.amber,
  ];

  @override
  void initState() {
    super.initState();

    for (int b = 0; b < 8; b++) {
      banks.add(List.generate(16, (i) {
        return SoundPad(
          padNames[i],
          36 + i,
          keys[i],
          colors[i],
        );
      }));
    }

    _restore();
    _initMidi();
  }

  @override
  void dispose() {
    midiSubscription?.cancel();
    for (final bank in banks) {
      for (final pad in bank) {
        for (final layer in pad.layers) {
          layer.trimTimer?.cancel();
          layer.player?.dispose();
        }
      }
    }
    focusNode.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('sampler_perreo_state_v1');
      if (saved == null) return;

      final data = jsonDecode(saved) as Map<String, dynamic>;
      final savedBanks = data['banks'] as List?;

      if (savedBanks != null) {
        for (int b = 0; b < math.min(8, savedBanks.length); b++) {
          final savedPads = savedBanks[b] as List;
          for (int p = 0; p < math.min(16, savedPads.length); p++) {
            banks[b][p].loadJson(
              Map<String, dynamic>.from(savedPads[p] as Map),
            );
          }
        }
      }

      if (!mounted) return;
      setState(() {
        bankIndex = (data['bankIndex'] as num?)?.toInt() ?? 0;
        masterVolume =
            (data['masterVolume'] as num?)?.toDouble() ?? 0.8;
        masterPitch =
            (data['masterPitch'] as num?)?.toDouble() ?? 1;
        bpm = (data['bpm'] as num?)?.toDouble() ?? 128;
      });
    } catch (e) {
      debugPrint('No se pudo restaurar la sesión: $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sampler_perreo_state_v1', jsonEncode({
        'bankIndex': bankIndex,
        'masterVolume': masterVolume,
        'masterPitch': masterPitch,
        'bpm': bpm,
        'banks': banks.map((b) => b.map((p) => p.toJson()).toList()).toList(),
      }));
    } catch (e) {
      debugPrint('Error guardando sesión: $e');
    }
  }

  Future<void> _initMidi() async {
    try {
      devices = await midi.devices ?? [];
      midiSubscription = midi.onMidiDataReceived?.listen((event) {
        final data = event.data;
        if (data.length < 3) return;

        final status = data[0] & 0xF0;
        final note = data[1];
        final velocity = data[2];

        if (status != 0x90 || velocity == 0) return;

        if (midiLearn && learnTarget != null) {
          final target = learnTarget!;
          final parts = target.split(':');
          final b = int.parse(parts[0]);
          final p = int.parse(parts[1]);

          setState(() {
            banks[b][p].midi = note;
            midiLearn = false;
            learnTarget = null;
            midiStatus = 'Nota $note asignada al pad ${p + 1}';
          });
          _save();
          return;
        }

        for (int b = 0; b < banks.length; b++) {
          for (int p = 0; p < banks[b].length; p++) {
            if (banks[b][p].midi == note && b == bankIndex) {
              _playPad(p);
              return;
            }
          }
        }
      });

      if (mounted) {
        setState(() {
          midiStatus = devices.isEmpty
              ? 'No se detectó controlador MIDI'
              : '${devices.length} dispositivo(s) MIDI detectado(s)';
        });
      }
    } catch (e) {
      if (mounted) setState(() => midiStatus = 'MIDI no disponible: $e');
    }
  }

  Future<void> _refreshMidi() async {
    try {
      devices = await midi.devices ?? [];
      if (mounted) setState(() {});
    } catch (e) {
      _message('No se pudieron buscar dispositivos MIDI.');
    }
  }

  Future<void> _chooseMidi() async {
    await _refreshMidi();
    if (!mounted) return;

    if (devices.isEmpty) {
      _message('Conecta tu controlador y vuelve a buscar dispositivos.');
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Controladores MIDI'),
        content: SizedBox(
          width: 420,
          child: ListView(
            shrinkWrap: true,
            children: devices.map((device) => ListTile(
              leading: const Icon(Icons.piano),
              title: Text(device.name ?? 'Controlador MIDI'),
              subtitle: Text(device.id),
              onTap: () async {
                try {
                  await midi.connectToDevice(device);
                  if (mounted) {
                    setState(() {
                      midiConnected = true;
                      midiStatus = 'Conectado: ${device.name}';
                    });
                  }
                } catch (e) {
                  _message('No se pudo conectar: $e');
                }
                if (context.mounted) Navigator.pop(context);
              },
            )).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<String> _copyIntoLibrary(String source) async {
    final directory = await getApplicationSupportDirectory();
    final sampleDir = Directory('${directory.path}${Platform.pathSeparator}samples');
    await sampleDir.create(recursive: true);

    final fileName = source.split(Platform.pathSeparator).last;
    final safeName = '${DateTime.now().microsecondsSinceEpoch}_$fileName';
    final destination = '${sampleDir.path}${Platform.pathSeparator}$safeName';
    await File(source).copy(destination);
    return destination;
  }

  Future<void> _addLayer(int padIndex) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );
      if (result == null || result.files.single.path == null) return;

      final copied = await _copyIntoLibrary(result.files.single.path!);
      final layer = SoundLayer(
        name: result.files.single.name,
        path: copied,
      );

      setState(() {
        pads[padIndex].layers.add(layer);
        selectedPad = padIndex;
      });
      await _save();
    } catch (e) {
      _message('No se pudo cargar el audio: $e');
    }
  }

  Future<void> _removeLayer(int padIndex, int layerIndex) async {
    final layer = pads[padIndex].layers[layerIndex];
    layer.trimTimer?.cancel();
    await layer.player?.dispose();

    setState(() => pads[padIndex].layers.removeAt(layerIndex));
    await _save();
  }

  Future<void> _playPad(int index) async {
    final pad = pads[index];
    setState(() {
      selectedPad = index;
      pad.active = true;
    });

    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => pad.active = false);
    });

    // Cada capa tiene su propio reproductor: se pueden superponer.
    for (final layer in pad.layers) {
      final path = layer.path;
      if (path == null || !File(path).existsSync()) continue;

      try {
        layer.trimTimer?.cancel();
        await layer.player?.dispose();
        final player = AudioPlayer();
        layer.player = player;

        await player.setVolume(
          (masterVolume * pad.gain * layer.gain).clamp(0.0, 1.0),
        );
        await player.setPlaybackRate(
          (masterPitch * layer.pitch).clamp(0.5, 2.0),
        );

        await player.play(DeviceFileSource(path));

        if (layer.start > 0) {
          await player.seek(Duration(
            milliseconds: (layer.start * 1000).round(),
          ));
        }

        if (layer.end > layer.start) {
          final remaining = (layer.end - layer.start) * 1000;
          if (remaining > 0) {
            layer.trimTimer = Timer(
              Duration(milliseconds: remaining.round()),
              () => player.stop(),
            );
          }
        }
      } catch (e) {
        debugPrint('Error reproduciendo capa: $e');
      }
    }
  }

  void _handleKey(RawKeyEvent event) {
    if (event is! RawKeyDownEvent || event.repeat) return;
    final key = event.logicalKey.keyLabel.toUpperCase();

    final index = pads.indexWhere((p) => p.key == key);
    if (index != -1) _playPad(index);
  }

  Future<void> _editLayer(int padIndex, int layerIndex) async {
    final layer = pads[padIndex].layers[layerIndex];
    double gain = layer.gain;
    double start = layer.start;
    double end = layer.end;
    double pitch = layer.pitch;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text('Editar ${layer.name}'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _sliderRow('Ganancia', gain, 0, 1,
                      (v) => setDialog(() => gain = v),
                      '${(gain * 100).round()}%'),
                  _sliderRow('Inicio (segundos)', start, 0, 60,
                      (v) => setDialog(() {
                        start = math.min(v, end - 0.01).clamp(0, 60);
                      }), start.toStringAsFixed(2)),
                  _sliderRow('Final (segundos)', end, 0.01, 120,
                      (v) => setDialog(() {
                        end = math.max(v, start + 0.01).clamp(0.01, 120);
                      }), end.toStringAsFixed(2)),
                  _sliderRow('Pitch de capa', pitch, 0.5, 2,
                      (v) => setDialog(() => pitch = v),
                      '${pitch.toStringAsFixed(2)}×'),
                  const Text(
                    'El inicio y el final se expresan en segundos. '
                    'Ajusta el final según la duración del sonido.',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                setState(() {
                  layer.gain = gain;
                  layer.start = start;
                  layer.end = end;
                  layer.pitch = pitch;
                });
                await _save();
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> changed,
    String valueText,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(valueText, style: const TextStyle(color: accent)),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: changed,
        ),
      ],
    );
  }

  Future<void> _clearBank() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vaciar banco'),
        content: const Text('¿Quieres quitar las capas de los 16 pads de este banco?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    for (final pad in pads) {
      for (final layer in pad.layers) {
        layer.trimTimer?.cancel();
        await layer.player?.dispose();
      }
      pad.layers.clear();
    }
    setState(() {});
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: focusNode,
      autofocus: true,
      onKey: _handleKey,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF171B22),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SAMPLER PERREO',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              Text('DJ DANNYS YOEL',
                  style: TextStyle(fontSize: 9, letterSpacing: 3, color: accent)),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Configuración MIDI',
              onPressed: _chooseMidi,
              icon: Icon(
                Icons.piano,
                color: midiConnected ? Colors.greenAccent : accent,
              ),
            ),
            IconButton(
              tooltip: 'Guardar sesión',
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildBankSelector(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 900;
                    if (narrow) {
                      return Column(
                        children: [
                          _buildMasterPanel(),
                          Expanded(child: _buildPadGrid()),
                          _buildEditorPanel(),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        SizedBox(width: 225, child: _buildMasterPanel()),
                        Expanded(child: _buildPadGrid()),
                        SizedBox(width: 310, child: _buildEditorPanel()),
                      ],
                    );
                  },
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: const Color(0xFF080A0E),
                child: Text(
                  midiStatus,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBankSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFF13171D),
      child: Row(
        children: [
          const Text('BANCOS', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          for (int i = 0; i < banks.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(String.fromCharCode(65 + i)),
                selected: bankIndex == i,
                onSelected: (_) async {
                  setState(() => bankIndex = i);
                  await _save();
                },
              ),
            ),
          const Spacer(),
          Text('${pads.where((p) => p.layers.isNotEmpty).length}/16 pads',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMasterPanel() {
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('CONTROLES MAESTROS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              RotaryKnob(
                label: 'VOLUMEN',
                value: masterVolume,
                display: '${(masterVolume * 100).round()}%',
                onChanged: (v) {
                  setState(() => masterVolume = v);
                  _save();
                },
              ),
              RotaryKnob(
                label: 'PITCH',
                value: (masterPitch - 0.5) / 1.5,
                display: '${masterPitch.toStringAsFixed(2)}×',
                onChanged: (v) {
                  setState(() => masterPitch = 0.5 + v * 1.5);
                  _save();
                },
              ),
            ],
          ),
          const Divider(height: 26),
          Row(
            children: [
              const Text('BPM'),
              const Spacer(),
              IconButton(
                onPressed: () {
                  setState(() => bpm = math.max(40, bpm - 1));
                  _save();
                },
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(bpm.toStringAsFixed(0),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(
                onPressed: () {
                  setState(() => bpm = math.min(300, bpm + 1));
                  _save();
                },
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _chooseMidi,
              icon: const Icon(Icons.piano),
              label: const Text('Configurar MIDI'),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _clearBank,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Vaciar banco'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPadGrid() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: GridView.builder(
        itemCount: 16,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 9,
          mainAxisSpacing: 9,
          childAspectRatio: 1.12,
        ),
        itemBuilder: (context, index) {
          final pad = pads[index];
          final color = pad.color;
          final selected = selectedPad == index;
          final active = pad.active;
          return GestureDetector(
            onTap: () {
              setState(() => selectedPad = index);
              _playPad(index);
            },
            onSecondaryTap: () => _addLayer(index),
            onLongPress: () => _addLayer(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              decoration: BoxDecoration(
                color: active
                    ? color.withValues(alpha: 0.65)
                    : color.withValues(alpha: pad.layers.isEmpty ? 0.06 : 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? Colors.white : color,
                  width: selected ? 2.5 : 1,
                ),
                boxShadow: active
                    ? [BoxShadow(color: color, blurRadius: 18)]
                    : [],
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.graphic_eq, color: color, size: 24),
                        const SizedBox(height: 5),
                        Text(pad.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          '${pad.layers.length} capa(s) · ${pad.key}',
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 3,
                    top: 3,
                    child: IconButton(
                      tooltip: 'Añadir capa',
                      visualDensity: VisualDensity.compact,
                      iconSize: 17,
                      onPressed: () => _addLayer(index),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEditorPanel() {
    final pad = currentPad;
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EDITOR · ${pad.name}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text('Ganancia del pad ${(pad.gain * 100).round()}%',
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          Slider(
            value: pad.gain,
            min: 0,
            max: 1,
            onChanged: (v) {
              setState(() => pad.gain = v);
              _save();
            },
          ),
          Row(
            children: [
              const Expanded(
                child: Text('Capas de audio',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              IconButton(
                tooltip: 'Añadir sonido',
                onPressed: () => _addLayer(selectedPad),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          Expanded(
            child: pad.layers.isEmpty
                ? const Center(
                    child: Text(
                      'Este pad está vacío.\nPulsa + para cargar un sonido.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    itemCount: pad.layers.length,
                    itemBuilder: (context, index) {
                      final layer = pad.layers[index];
                      return Card(
                        color: const Color(0xFF222833),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.audiotrack, size: 18),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      layer.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Editar recorte y ganancia',
                                    onPressed: () => _editLayer(selectedPad, index),
                                    icon: const Icon(Icons.tune, size: 18),
                                  ),
                                  IconButton(
                                    tooltip: 'Eliminar capa',
                                    onPressed: () => _removeLayer(selectedPad, index),
                                    icon: const Icon(Icons.close, size: 18),
                                  ),
                                ],
                              ),
                              Text(
                                'Ganancia ${(layer.gain * 100).round()}% · '
                                'Inicio ${layer.start.toStringAsFixed(2)} s · '
                                'Final ${layer.end.toStringAsFixed(2)} s',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 10),
                              ),
                              TextButton.icon(
                                onPressed: () async {
                                  final player = AudioPlayer();
                                  await player.setVolume(
                                    (masterVolume * pad.gain * layer.gain)
                                        .clamp(0.0, 1.0),
                                  );
                                  await player.setPlaybackRate(
                                    (masterPitch * layer.pitch).clamp(0.5, 2.0),
                                  );
                                  if (layer.path != null &&
                                      File(layer.path!).existsSync()) {
                                    await player.play(
                                      DeviceFileSource(layer.path!),
                                    );
                                  }
                                  Future.delayed(
                                    const Duration(seconds: 15),
                                    () => player.dispose(),
                                  );
                                },
                                icon: const Icon(Icons.play_arrow, size: 18),
                                label: const Text('Vista previa'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Text(
            'Clic: reproducir · Clic derecho o pulsación larga: añadir capa',
            style: TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class RotaryKnob extends StatelessWidget {
  final String label;
  final double value;
  final String display;
  final ValueChanged<double> onChanged;

  const RotaryKnob({
    super.key,
    required this.label,
    required this.value,
    required this.display,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onPanUpdate: (details) {
            onChanged((value - details.delta.dy * 0.008).clamp(0.0, 1.0));
          },
          onDoubleTap: () => onChanged(label == 'PITCH' ? 1 / 1.5 : 0.8),
          child: SizedBox(
            width: 76,
            height: 76,
            child: CustomPaint(
              painter: KnobPainter(value),
              child: Center(
                child: Text(
                  display,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold)),
        const Text('ARRASTRAR',
            style: TextStyle(fontSize: 8, color: Colors.white38)),
      ],
    );
  }
}

class KnobPainter extends CustomPainter {
  final double value;
  KnobPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.39;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final base = Paint()
      ..color = const Color(0xFF303947)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final active = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    const start = math.pi * 0.75;
    const sweep = math.pi * 1.5;

    canvas.drawArc(rect, start, sweep, false, base);
    canvas.drawArc(rect, start, sweep * value, false, active);

    final angle = start + sweep * value;
    final point = Offset(
      center.dx + math.cos(angle) * radius,
      center.dy + math.sin(angle) * radius,
    );

    canvas.drawCircle(
      center,
      radius - 7,
      Paint()..color = const Color(0xFF242B35),
    );

    canvas.drawLine(
      center,
      point,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(center, 3, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant KnobPainter oldDelegate) =>
      oldDelegate.value != value;
}
```
