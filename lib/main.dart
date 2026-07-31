import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin notifications =
    FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void openWakeUpChallenge() {
  final navigator = appNavigatorKey.currentState;
  if (navigator == null) return;
  navigator.push(MaterialPageRoute(builder: (_) => const WakeUpChallengePage()));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  final zone = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(zone.name));

  await notifications.initialize(
    const InitializationSettings(
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
    onDidReceiveNotificationResponse: (_) => openWakeUpChallenge(),
  );
  final launchDetails = await notifications.getNotificationAppLaunchDetails();
  runApp(const WakeUpInTimeApp());
  if (launchDetails?.didNotificationLaunchApp ?? false) {
    WidgetsBinding.instance.addPostFrameCallback((_) => openWakeUpChallenge());
  }
}

class WakeUpInTimeApp extends StatelessWidget {
  const WakeUpInTimeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Wake Up In Time',
        navigatorKey: appNavigatorKey,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xffe84f3d),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xff121415),
          useMaterial3: true,
        ),
        home: const AlarmSetupPage(),
      );
}

class AlarmSetupPage extends StatefulWidget {
  const AlarmSetupPage({super.key});

  @override
  State<AlarmSetupPage> createState() => _AlarmSetupPageState();
}

class _AlarmSetupPageState extends State<AlarmSetupPage> {
  TimeOfDay _time = TimeOfDay.now();
  String _sound = 'Morning Rise';
  bool _armed = false;

  Future<void> _pickTime() async {
    final time = await showTimePicker(context: context, initialTime: _time);
    if (time != null) setState(() => _time = time);
  }

  Future<void> _armAlarm() async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      _time.hour,
      _time.minute,
    );
    if (!scheduled.isAfter(now)) scheduled = scheduled.add(const Duration(days: 1));

    await notifications.zonedSchedule(
      1,
      'Wake up in time',
      'Open the app and complete 15 push-ups to dismiss.',
      scheduled,
      const NotificationDetails(
        iOS: DarwinNotificationDetails(presentSound: true),
        android: AndroidNotificationDetails(
          'alarm_channel',
          'Alarms',
          channelDescription: 'Wake-up alarms',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    if (mounted) setState(() => _armed = true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Wake Up In Time')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('NEXT ALARM', style: TextStyle(letterSpacing: 1.5)),
                const SizedBox(height: 10),
                Text(
                  _time.format(context),
                  style: const TextStyle(fontSize: 62, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 28),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Color(0xff404447)),
                  ),
                  leading: const Icon(Icons.schedule),
                  title: const Text('Alarm time'),
                  trailing: TextButton(onPressed: _pickTime, child: const Text('Change')),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _sound,
                  decoration: const InputDecoration(labelText: 'Ringtone'),
                  items: const ['Morning Rise', 'Pulse', 'Beacon']
                      .map((sound) => DropdownMenuItem(value: sound, child: Text(sound)))
                      .toList(),
                  onChanged: (value) => setState(() => _sound = value ?? _sound),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _armed ? null : _armAlarm,
                  icon: const Icon(Icons.alarm_add),
                  label: Text(_armed ? 'Alarm armed' : 'Set alarm'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WakeUpChallengePage()),
                  ),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Test wake-up challenge'),
                ),
              ],
            ),
          ),
        ),
      );
}

class WakeUpChallengePage extends StatefulWidget {
  const WakeUpChallengePage({super.key});

  @override
  State<WakeUpChallengePage> createState() => _WakeUpChallengePageState();
}

class _WakeUpChallengePageState extends State<WakeUpChallengePage> {
  CameraController? _camera;
  late final PoseDetector _detector;
  bool _detecting = false;
  bool _isDown = false;
  int _count = 0;
  String _status = 'Position your full upper body in frame';
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    _detector = PoseDetector(options: PoseDetectorOptions(mode: PoseDetectionMode.stream));
    _startCamera();
  }

  Future<void> _startCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup:
            Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21,
      );
      await controller.initialize();
      await controller.startImageStream(_processFrame);
      if (mounted) setState(() => _camera = controller);
    } on CameraException catch (error) {
      if (mounted) setState(() => _cameraError = error.description ?? error.code);
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_detecting || _count >= 15) return;
    _detecting = true;
    try {
      final input = _inputImageFromCameraImage(image, _camera!.description);
      if (input == null) return;
      final poses = await _detector.processImage(input);
      if (poses.isEmpty) {
        if (mounted) setState(() => _status = 'Person not detected');
        return;
      }
      final pose = poses.first;
      final nose = pose.landmarks[PoseLandmarkType.nose];
      final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
      final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
      if (nose == null || leftShoulder == null || rightShoulder == null) return;
      final shoulderY = (leftShoulder.y + rightShoulder.y) / 2;
      final headOffset = nose.y - shoulderY;
      // A down/up cycle is measured relative to the shoulders, which is less
      // sensitive to the phone being placed at a slight angle.
      if (headOffset > 42) _isDown = true;
      if (_isDown && headOffset < 18) {
        _isDown = false;
        setState(() {
          _count++;
          _status = _count == 15 ? 'Completed' : 'Good. Keep moving.';
        });
        if (_count == 15) await _dismiss();
      } else if (mounted && _count < 15) {
        setState(() => _status = _isDown ? 'Push up' : 'Lower down');
      }
    } finally {
      _detecting = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image, CameraDescription camera) {
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    final format = Platform.isIOS ? InputImageFormat.bgra8888 : InputImageFormat.nv21;
    if (rotation == null || image.planes.length != 1) return null;
    return InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Future<void> _dismiss() async {
    await notifications.cancel(1);
    if (mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Alarm dismissed'),
          content: const Text('15 push-ups completed.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
        ),
      );
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _camera?.dispose();
    _detector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_camera?.value.isInitialized ?? false)
              CameraPreview(_camera!)
            else if (_cameraError != null)
              Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Camera unavailable: $_cameraError')))
            else
              const Center(child: CircularProgressIndicator()),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Emergency dismissal',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const EmergencyDismissPage()),
                      ),
                      icon: const Icon(Icons.lock_open),
                    ),
                    const Spacer(),
                    Text('$_count / 15', style: const TextStyle(fontSize: 54, fontWeight: FontWeight.bold)),
                    Text(_status, style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: _count / 15),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class EmergencyDismissPage extends StatefulWidget {
  const EmergencyDismissPage({super.key});

  @override
  State<EmergencyDismissPage> createState() => _EmergencyDismissPageState();
}

class _EmergencyDismissPageState extends State<EmergencyDismissPage> {
  final _controller = TextEditingController();
  late final String _code;
  String? _error;

  @override
  void initState() {
    super.initState();
    final random = Random.secure();
    _code = List.generate(20, (_) => random.nextInt(10)).join();
  }

  Future<void> _verify() async {
    if (_controller.text == _code) {
      await notifications.cancel(1);
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      setState(() => _error = 'Code does not match.');
    }
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Emergency dismissal')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Enter this 20-digit code to dismiss the alarm.'),
            const SizedBox(height: 18),
            SelectableText(_code, style: const TextStyle(fontSize: 24, letterSpacing: 2)),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              maxLength: 20,
              decoration: InputDecoration(labelText: 'Verification code', errorText: _error),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _verify, child: const Text('Dismiss alarm')),
          ]),
        ),
      );
}
