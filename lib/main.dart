import 'package:flutter/material.dart';

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

class SamplerHome extends StatelessWidget {
  const SamplerHome({super.key});

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
            child: const Text('Sampler listo', style: TextStyle(color: Colors.white54, fontSize: 12)),
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
    final List<Map<String, dynamic>> pads = [
      {'name': 'KICK', 'color': Colors.orange},
      {'name': 'SNARE', 'color': Colors.orange},
      {'name': 'HI-HAT', 'color': Colors.orange},
      {'name': 'CLAP', 'color': Colors.orange},
      {'name': 'LOOP 1', 'color': Colors.blue},
      {'name': 'LOOP 2', 'color': Colors.blue},
      {'name': 'SAMPLE 1', 'color': Colors.blue},
      {'name': 'SAMPLE 2', 'color': Colors.blue},
      {'name': 'SYNTH', 'color': Colors.green},
      {'name': 'BASS', 'color': Colors.green},
      {'name': 'VOX 1', 'color': Colors.green},
      {'name': 'VOX 2', 'color': Colors.green},
      {'name': 'FX 1', 'color': Colors.purpleAccent},
      {'name': 'FX 2', 'color': Colors.purpleAccent},
      {'name': 'SHOT 1', 'color': Colors.amber},
      {'name': 'SHOT 2', 'color': Colors.amber},
    ];

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

        return Container(
          decoration: BoxDecoration(
            color: col.withOpacity(0.15),
            border: Border.all(color: col, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              name,
              style: TextStyle(
                color: col,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        );
      },
    );
  }
}
