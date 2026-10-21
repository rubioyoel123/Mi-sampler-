import 'package:flutter/material.dart';

void main() {
  runApp(const MiSamplerApp());
}

class MiSamplerApp extends StatelessWidget {
  const MiSamplerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi Sampler - Windows',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E24),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF25252D),
          elevation: 0,
        ),
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
        title: const Text('Mi Sampler', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.circle, color: Colors.redAccent, size: 28),
            onPressed: () {},
          ),
          IconButton(icon: const Icon(Icons.play_arrow, size: 30), onPressed: () {}),
          IconButton(icon: const Icon(Icons.pause, size: 30), onPressed: () {}),
          IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
          const SizedBox(width: 15),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _buildLeftPanel(),
                _buildCenterPads(),
                _buildRightPanel(),
              ],
            ),
          ),
          _buildStatusBar(),
        ],
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Expanded(
      flex: 1,
      child: Container(
        margin: const EdgeInsets.all(8.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: const Color(0xFF18181D),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(15, (index) {
                  return Container(
                    width: 6,
                    height: (index % 4 + 1) * 20.0 + (index % 3) * 10.0,
                    color: Colors.cyanAccent.withOpacity(0.8),
                  );
                }),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildFakeKnob('VOLUME'),
                _buildFakeKnob('PITCH'),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildVerticalSlider(),
                _buildVerticalSlider(),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterPads() {
    final List<Map<String, dynamic>> pads = [
      {'label': 'KICK', 'color': Colors.orange},
      {'label': 'SNARE', 'color': Colors.orange},
      {'label': 'HI-HAT', 'color': Colors.orange},
      {'label': 'CLAP', 'color': Colors.orange},
      {'label': 'LOOP 1', 'color': Colors.blue},
      {'label': 'LOOP 2', 'color': Colors.blue},
      {'label': 'SAMPLE', 'color': Colors.blue},
      {'label': 'SAMPLE', 'color': Colors.greenAccent},
      {'label': 'SYNTH', 'color': Colors.green},
      {'label': 'BASS', 'color': Colors.green},
      {'label': 'CHORD', 'color': Colors.green},
      {'label': 'VOX 1', 'color': Colors.green},
      {'label': 'FX 1', 'color': Colors.purpleAccent},
      {'label': 'FX 2', 'color': Colors.purpleAccent},
      {'label': 'SHOT 1', 'color': Colors.yellowAccent},
      {'label': 'SHOT 2', 'color': Colors.yellowAccent},
    ];

    return Expanded(
      flex: 2,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 16,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (context, index) {
            final color = pads[index]['color'] as Color;
            return Container(
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                border: Border.all(color: color.withOpacity(0.8), width: 2),
                borderRadius: BorderRadius.
                
