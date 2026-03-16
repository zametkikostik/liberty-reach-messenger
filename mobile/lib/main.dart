import 'package:flutter/material.dart';

void main() {
  runApp(const LibertyReachApp());
}

class LibertyReachApp extends StatelessWidget {
  const LibertyReachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Liberty Reach',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('Liberty Reach - Coming Soon'),
        ),
      ),
    );
  }
}
