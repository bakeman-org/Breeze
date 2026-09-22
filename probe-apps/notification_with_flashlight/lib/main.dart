import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ntfy/ntfy.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:torch_light/torch_light.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ntfy Flashlight',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // --- Notification plugin ---
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // --- ntfy plugin ---
  final Ntfy _ntfy = Ntfy();
  StreamSubscription<String>? _messageSub;

  // --- UI state ---
  bool _isListening = false;
  String _topic = 'my_flashlight_topic'; // 👈 change to your topic
  bool _torchOn = false;

  // --- Flash configuration ---
  int _flashCount = 3; // how many times to blink
  int _flashDurationMs = 1000; // how long the light stays ON each blink (ms)
  int _flashGapMs = 300; // gap between blinks (ms)

  // TextField controllers
  late final TextEditingController _topicCtrl;
  late final TextEditingController _countCtrl;
  late final TextEditingController _durationCtrl;

  // Prevent overlapping flash sequences
  bool _isFlashing = false;

  @override
  void initState() {
    super.initState();
    _topicCtrl = TextEditingController(text: _topic);
    _countCtrl = TextEditingController(text: _flashCount.toString());
    _durationCtrl = TextEditingController(text: _flashDurationMs.toString());
    _initNotifications();
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _ntfy.unsubscribe();
    _topicCtrl.dispose();
    _countCtrl.dispose();
    _durationCtrl.dispose();
    // Make sure torch is off when leaving
    TorchLight.disableTorch();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 1. Initialize local notifications
  // ---------------------------------------------------------------------------
  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Tapping the notification just triggers an extra manual flash.
        // Remove this line if you don't want tapping to flash.
        _flashSequence();
      },
    );

    await Permission.notification.request();
  }

  // ---------------------------------------------------------------------------
  // 2. Start listening to an ntfy topic
  // ---------------------------------------------------------------------------
  Future<void> _startListening() async {
    if (_isListening) return;

    _messageSub = _ntfy.messages.listen((String messageJson) {
      debugPrint('ntfy message: $messageJson');
      final data = jsonDecode(messageJson);
      final title = data['title'] ?? 'ntfy';
      final body = data['message'] ?? 'New notification';

      // Show the notification AND flash the torch
      _showNotification(title, body);
      _flashSequence();
    });

    await _ntfy.subscribe('https://ntfy.sh', _topic);
    setState(() => _isListening = true);
  }

  // ---------------------------------------------------------------------------
  // 3. Stop listening
  // ---------------------------------------------------------------------------
  Future<void> _stopListening() async {
    await _messageSub?.cancel();
    _messageSub = null;
    await _ntfy.unsubscribe();
    setState(() => _isListening = false);
  }

  // ---------------------------------------------------------------------------
  // 4. Show a local notification
  // ---------------------------------------------------------------------------
  Future<void> _showNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'ntfy_flashlight_channel',
      'ntfy Flashlight',
      channelDescription:
          'Notifications from ntfy.sh that trigger the flashlight',
      importance: Importance.max,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Blink the flashlight in a sequence
  //    ON for _flashDurationMs → OFF for _flashGapMs → repeat _flashCount times
  // ---------------------------------------------------------------------------
  Future<void> _flashSequence() async {
    if (_isFlashing) return; // ignore if a sequence is already running
    _isFlashing = true;

    final int count = _flashCount.clamp(1, 50);
    final int onMs = _flashDurationMs.clamp(50, 10000);
    final int gapMs = _flashGapMs.clamp(50, 10000);

    try {
      for (int i = 0; i < count; i++) {
        // Turn ON
        await TorchLight.enableTorch();
        if (mounted) setState(() => _torchOn = true);
        await Future.delayed(Duration(milliseconds: onMs));

        // Turn OFF
        await TorchLight.disableTorch();
        if (mounted) setState(() => _torchOn = false);

        // Gap (skip after the last flash)
        if (i < count - 1) {
          await Future.delayed(Duration(milliseconds: gapMs));
        }
      }
    } catch (e) {
      debugPrint('Torch error: $e');
      // Make sure we leave the torch off on error
      try {
        await TorchLight.disableTorch();
      } catch (_) {}
      if (mounted) setState(() => _torchOn = false);
    } finally {
      _isFlashing = false;
    }
  }

  // Manual on/off (for testing)
  Future<void> _manualToggle() async {
    if (_isFlashing) return;
    try {
      if (_torchOn) {
        await TorchLight.disableTorch();
      } else {
        await TorchLight.enableTorch();
      }
      setState(() => _torchOn = !_torchOn);
    } catch (e) {
      debugPrint('Torch error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ntfy Flashlight')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'ntfy topic',
                border: OutlineInputBorder(),
              ),
              controller: _topicCtrl,
              onChanged: (v) => _topic = v,
            ),
            const SizedBox(height: 16),

            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Flash count (how many times to blink)',
                border: OutlineInputBorder(),
              ),
              controller: _countCtrl,
              onChanged: (v) => _flashCount = int.tryParse(v) ?? _flashCount,
            ),
            const SizedBox(height: 16),

            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Duration per flash (ms)',
                helperText: '1000 ms = 1 second',
                border: OutlineInputBorder(),
              ),
              controller: _durationCtrl,
              onChanged: (v) =>
                  _flashDurationMs = int.tryParse(v) ?? _flashDurationMs,
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _isListening ? _stopListening : _startListening,
              icon: Icon(_isListening ? Icons.stop : Icons.play_arrow),
              label: Text(_isListening ? 'Stop listening' : 'Start listening'),
            ),
            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: _flashSequence,
              icon: const Icon(Icons.flash_on),
              label: const Text('Test flash sequence'),
            ),
            const SizedBox(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Manual torch:'),
                Switch(value: _torchOn, onChanged: (_) => _manualToggle()),
              ],
            ),
            const SizedBox(height: 24),

            Text(
              'Send a message to your ntfy topic. The phone will blink '
              '$_flashCount time(s), $_flashDurationMs ms per blink, '
              'and show a notification.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
