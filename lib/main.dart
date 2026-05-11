import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

class AppColors {
  static const Color background = Color(0xFFF8F6F2);
  static const Color panel = Color(0xFFFFFFFF);
  static const Color panelAlt = Color(0xFFF5F3EE);

  static const Color appBarBlueTop = Color(0xFFB0D4EE);
  static const Color appBarCreamBottom = Color(0xFFF5F2EC);

  static const Color accent = Color(0xFF2D9F8C);
  static const Color secondary = Color(0xFF4A90D9);

  static const Color upColor = Color(0xFF27AE60);
  static const Color upColorLight = Color(0xFF2ECC71);
  static const Color downColor = Color(0xFF2980B9);
  static const Color downColorLight = Color(0xFF3498DB);
  static const Color fastColor = Color(0xFFE67E22);
  static const Color fastColorLight = Color(0xFFF39C12);
  static const Color eStopColor = Color(0xFFC0392B);
  static const Color eStopColorLight = Color(0xFFE74C3C);
  static const Color idleColor = Color(0xFF95A5A6);

  static const Color textPrimary = Color(0xFF2C3E50);
  static const Color textSecondary = Color(0xFF7F8C8D);
  static const Color textMuted = Color(0xFFBDC3C7);

  static const Color border = Color(0xFFE8E4DF);
}

class AppTheme {
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.accent,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      error: AppColors.eStopColor,
      onError: Colors.white,
      surface: AppColors.panel,
      onSurface: AppColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyMedium: TextStyle(fontSize: 14, color: AppColors.textSecondary),
      bodySmall: TextStyle(fontSize: 12, color: AppColors.textMuted),
    ),
  );
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const ControlScreen(),
    );
  }
}

// enum ButtonStage { notPressed, pressed, draggedFurther }

enum ControlState { idle, slow, fast }

const Map<ControlState, List<int>> plcOutputUp = {
  ControlState.idle: [0, 0, 0, 0],
  ControlState.slow: [0, 1, 0, 0],
  ControlState.fast: [0, 1, 0, 1],
};

const Map<ControlState, List<int>> plcOutputDown = {
  ControlState.idle: [0, 0, 0, 0],
  ControlState.slow: [0, 0, 1, 0],
  ControlState.fast: [0, 0, 1, 1],
};
const List<int> plcConflict = [0, 0, 0, 0];

class ControlButtonService extends ChangeNotifier {
  bool _estopActive = false;
  bool _upActive = false;
  bool _downActive = false;
  bool _fastActive = false;
  bool _conflictActive = false;

  final int _a1 = 24;
  final int _a2 = 12;

  bool get estopActive => _estopActive;
  bool get upActive => _upActive;
  bool get downActive => _downActive;
  bool get fastActive => _fastActive;
  bool get conflictActive => _conflictActive;
  int get a1 => _a1;
  int get a2 => _a2;

  ControlState get upStage {
    if (_estopActive || _conflictActive || !_upActive) {
      return ControlState.idle;
    }
    return _fastActive ? ControlState.fast : ControlState.slow;
  }

  ControlState get downStage {
    if (_estopActive || _conflictActive || !_downActive) {
      return ControlState.idle;
    }
    return _fastActive ? ControlState.fast : ControlState.slow;
  }

  String get statusLabel {
    if (_estopActive) return 'EMERGENCY STOP';
    if (_conflictActive) return 'INVALID INPUT';
    if (_upActive && _fastActive) return 'UP (FAST)';
    if (_upActive) return 'UP (SLOW)';
    if (_downActive && _fastActive) return 'DOWN (FAST)';
    if (_downActive) return 'DOWN (SLOW)';
    return 'IDLE';
  }

  Color get statusColor {
    if (_estopActive) return AppColors.eStopColor;
    if (_conflictActive) return AppColors.eStopColorLight;
    if (_upActive) return _fastActive ? AppColors.fastColor : AppColors.upColor;
    if (_downActive) {
      return _fastActive ? AppColors.fastColor : AppColors.downColor;
    }
    return AppColors.idleColor;
  }

  Future<void> sendCommand({
    required bool estop,
    required bool up,
    required bool down,
    required bool fast,
    bool conflict = false,
  }) async {
    if (estop) {
      _estopActive = true;
      _upActive = false;
      _downActive = false;
      _fastActive = false;
      _conflictActive = false;
      notifyListeners();
      debugPrint("E-STOP ACTIVATED! Sending E-STOP command to PLC...");
      return;
    }

    if (_conflictActive && !conflict) {
      return;
    }

    if (conflict || (up && down)) {
      _conflictActive = true;
      _upActive = false;
      _downActive = false;
      _fastActive = false;
      notifyListeners();
      debugPrint("CONFLICT DETECTED! Sending conflict state to PLC...");
      return;
    }
    _estopActive = false;
    _conflictActive = false;
    _upActive = up;
    _downActive = down;
    _fastActive = fast && (_upActive || _downActive);
    notifyListeners();
  }

  Future<void> triggerEStop() async {
    await sendCommand(estop: true, up: false, down: false, fast: false);
  }

  Future<void> resetEStop() async {
    await sendCommand(estop: false, up: false, down: false, fast: false);
  }

  void clearConflict() {
    _conflictActive = false;
    _upActive = false;
    _downActive = false;
    _fastActive = false;
    notifyListeners();
  }

  bool verifyLocalPassword(String password) {
    return password == 'Admin123';
  }
}

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  final ControlButtonService _controller = ControlButtonService();
  ControlState _upState = ControlState.idle;
  ControlState _downState = ControlState.idle;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateStates);
  }

  @override
  void dispose() {
    _controller.removeListener(_updateStates);
    super.dispose();
  }

  void _updateStates() {
    if (mounted) setState(() {});
  }

  void resetLocalButtonStates() {
    setState(() {
      _upState = ControlState.idle;
      _downState = ControlState.idle;
    });
  }

  void _applySafetyInterlock() {
    if (_controller.estopActive) return;

    final upPressed = _upState != ControlState.idle;
    final downPressed = _downState != ControlState.idle;

    // Strict mutual exclusion: simultaneous touch is always invalid.
    if (upPressed && downPressed) {
      _controller.sendCommand(
        estop: false,
        up: false,
        down: false,
        fast: false,
        conflict: true,
      );
      return;
    }

    // Conflict is latched and must be manually cleared.
    if (_controller.conflictActive) {
      return;
    }

    if (upPressed) {
      _controller.sendCommand(
        estop: false,
        up: true,
        down: false,
        fast: _upState == ControlState.fast,
      );
      return;
    }

    if (downPressed) {
      _controller.sendCommand(
        estop: false,
        up: false,
        down: true,
        fast: _downState == ControlState.fast,
      );
      return;
    }

    _controller.sendCommand(estop: false, up: false, down: false, fast: false);
  }

  void _onUpCommandChanged(ControlState state) {
    setState(() {
      _upState = state;
    });
    _applySafetyInterlock();
  }

  void _onDownCommandChanged(ControlState state) {
    setState(() {
      _downState = state;
    });
    _applySafetyInterlock();
  }

  Future<void> _onEStopTap() async {
    resetLocalButtonStates();
    await _controller.triggerEStop();
    Vibration.vibrate(duration: 600);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text(
                'EMERGENCY STOP ACTIVATED',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: AppColors.eStopColor,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _onResetEStop() async {
    final confirmed = await _showResetDialog();
    if (confirmed == true && mounted) {
      resetLocalButtonStates();
      await _controller.resetEStop();
      Vibration.vibrate(duration: 100);
    }
  }

  Future<bool> _showResetDialog() async {
    final ctrl = TextEditingController();
    bool obscure = true;
    String? errMsg;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setS) => AlertDialog(
              backgroundColor: AppColors.panel,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.lock_reset,
                    color: AppColors.eStopColorLight,
                    size: 22,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Reset Emergency Stop',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter your password to unlock crane controls.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (errMsg != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.eStopColorLight.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        errMsg!,
                        style: const TextStyle(
                          color: AppColors.eStopColorLight,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: ctrl,
                    obscureText: obscure,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility_off : Icons.visibility,
                          size: 20,
                        ),
                        onPressed: () => setS(() => obscure = !obscure),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_controller.verifyLocalPassword(ctrl.text)) {
                      Navigator.pop(ctx, true);
                    } else {
                      setS(() => errMsg = 'Incorrect password.');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.upColor,
                  ),
                  child: const Text(
                    'UNLOCK',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // appBar: AppBar(
      //   backgroundColor: Colors.transparent,
      //   surfaceTintColor: Colors.transparent,
      //   flexibleSpace: Container(
      //     decoration: const BoxDecoration(
      //       gradient: LinearGradient(
      //         begin: Alignment.topLeft,
      //         end: Alignment.bottomRight,
      //         colors: [AppColors.appBarBlueTop, AppColors.appBarCreamBottom],
      //       ),
      //     ),
      //   ),
      //   title: Column(
      //     crossAxisAlignment: CrossAxisAlignment.start,
      //     children: [
      //       const Text(
      //         'PLC14 Control',
      //         style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      //       ),
      //       Row(
      //         children: [
      //           Container(
      //             width: 7,
      //             height: 7,
      //             margin: const EdgeInsets.only(right: 5),
      //             decoration: const BoxDecoration(
      //               color: AppColors.accent,
      //               shape: BoxShape.circle,
      //             ),
      //           ),
      //           const Text(
      //             'UI Preview',
      //             style: TextStyle(fontSize: 11, color: AppColors.accent),
      //           ),
      //         ],
      //       ),
      //     ],
      //   ),
      //   actions: [
      //     IconButton(
      //       icon: const Icon(Icons.restart_alt, size: 20),
      //       onPressed: () {
      //         // _resetLocalButtonStates();
      //         // _controller.resetDemo();
      //       },
      //       tooltip: 'Reset demo',
      //     ),
      //   ],
      // ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Column(
            children: [
              _controller.estopActive ? _resetSection() : _eStopButton(),
              const SizedBox(height: 8),
              _sensorRow(),
              const SizedBox(height: 8),
              _liveLEDs(),
              const SizedBox(height: 8),
              // _statusBar(),
              // const SizedBox(height: 12),
              if (_controller.conflictActive) _conflictBanner(),
              if (_controller.conflictActive) const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: CraneSliderButton(
                      label: 'UP',
                      icon: Icons.arrow_upward_rounded,
                      isUp: true,
                      isDisabled: _controller.estopActive,
                      inConflict: _controller.conflictActive,
                      onCommandChanged: _onUpCommandChanged,
                      externalState: _controller.upStage,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CraneSliderButton(
                      label: 'DOWN',
                      icon: Icons.arrow_downward_rounded,
                      isUp: false,
                      isDisabled: _controller.estopActive,
                      inConflict: _controller.conflictActive,
                      onCommandChanged: _onDownCommandChanged,
                      externalState: _controller.downStage,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conflictBanner() {
    return GestureDetector(
      onTap: () {
        resetLocalButtonStates();
        _controller.clearConflict();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFE74C3C).withAlpha(20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE74C3C).withAlpha(100)),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Color(0xFFE74C3C), size: 14),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'INVALID INPUT — UP & DOWN pressed simultaneously. Tap to clear.',
                style: TextStyle(
                  color: Color(0xFFE74C3C),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eStopButton() {
    return GestureDetector(
      onTap: _controller.estopActive ? null : _onEStopTap,
      child: Container(
        width: double.infinity,
        height: 74,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6B0000), AppColors.eStopColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.eStopColor.withAlpha(115),
              blurRadius: 18,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(31),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withAlpha(64), width: 2),
              ),
              child: const Icon(
                Icons.power_settings_new,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EMERGENCY STOP',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  'Tap to stop all crane operations',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _resetSection() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.eStopColorLight.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.eStopColorLight.withAlpha(102),
              width: 2,
            ),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.eStopColorLight,
                size: 18,
              ),
              SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EMERGENCY STOP ACTIVE',
                    style: TextStyle(
                      color: AppColors.eStopColorLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    'All crane controls are locked',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: OutlinedButton.icon(
            onPressed: _onResetEStop,
            icon: const Icon(Icons.lock_open_rounded, size: 14),
            label: const Text(
              'RESET E-STOP → Password Required',
              style: TextStyle(fontSize: 11, letterSpacing: 0.5),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.eStopColorLight,
              side: const BorderSide(color: AppColors.eStopColorLight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sensorRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _sensorCard(
          label: 'Load 1',
          tag: 'A1',
          value: 1,
          color: AppColors.upColor,
        ),
        const SizedBox(width: 8),
        _sensorCard(
          label: 'Load 2',
          tag: 'A2',
          value: 0,
          color: AppColors.downColor,
        ),
      ],
    );
  }

  Widget _sensorCard({
    required String label,
    required String tag,
    required int value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 9,
                    ),
                  ),
                  Text(
                    '$value',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _liveLEDs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ledIndicator(
            label: 'ESTOP',
            active: _controller.estopActive,
            color: AppColors.eStopColor,
            pinName: 'R0_0',
          ),
          _ledIndicator(
            label: 'UP',
            active: _controller.upActive,
            color: AppColors.upColor,
            pinName: 'Q0.1',
          ),
          _ledIndicator(
            label: 'DOWN',
            active: _controller.downActive,
            color: AppColors.downColor,
            pinName: 'Q0.2',
          ),
          _ledIndicator(
            label: 'FAST',
            active: _controller.fastActive,
            color: AppColors.fastColor,
            pinName: 'Q0.3',
          ),
        ],
      ),
    );
  }

  Widget _ledIndicator({
    required String label,
    required Color color,
    required bool active,
    required String pinName,
  }) {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: active ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 300),
          builder: (context, value, child) {
            return Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: active ? color : Colors.grey.shade300,
                shape: BoxShape.circle,

                boxShadow: active
                    ? [
                        BoxShadow(
                          color: color.withAlpha(153),
                          blurRadius: (4 * value),
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          pinName,
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: active ? color : AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _statusBar() {
    final color = _controller.statusColor;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 8,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(
            _controller.statusLabel,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class RectSliderThumbShape extends SliderComponentShape {
  final double width;
  final double height;
  final double borderRadius;

  const RectSliderThumbShape({
    this.width = 14,
    this.height = 28,
    this.borderRadius = 5,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size(width, height);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final paint = Paint()
      ..color = sliderTheme.thumbColor ?? Colors.grey
      ..style = PaintingStyle.fill;

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: width, height: height),
      Radius.circular(borderRadius),
    );
    canvas.drawRRect(rect, paint);
  }
}

class CraneSliderButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isUp;
  final bool isDisabled;
  final bool inConflict;
  final void Function(ControlState state) onCommandChanged;
  final ControlState externalState;

  const CraneSliderButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isUp,
    this.isDisabled = false,
    this.inConflict = false,
    required this.onCommandChanged,
    this.externalState = ControlState.idle,
  });

  @override
  State<CraneSliderButton> createState() => _CraneSliderButtonState();
}

class _CraneSliderButtonState extends State<CraneSliderButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulsecontroller;
  late Animation<double> _pulseAnim;

  ControlState _state = ControlState.idle;
  double _sliderValue = 0.0; // 0.0 = idle, 0.0-0.55 = slow, 0.55-1.0 = fast
  bool _isTouching = false;

  static const double _fastThreshold = 0.55;

  @override
  void initState() {
    super.initState();
    _state = widget.externalState;
    _pulsecontroller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulsecontroller, curve: Curves.easeInOut),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(CraneSliderButton old) {
    super.didUpdateWidget(old);
    if ((widget.inConflict && !old.inConflict) ||
        (widget.isDisabled && !old.isDisabled)) {
      setState(() {
        _isTouching = false;
        _sliderValue = 0.0;
        _state = ControlState.idle;
      });
      _syncAnimation();
      return;
    }
    if (widget.externalState != old.externalState && !_isTouching) {
      setState(() {
        _state = widget.externalState;
        _sliderValue = _state == ControlState.fast
            ? 1.0
            : _state == ControlState.slow
            ? 0.5
            : 0.0;
      });
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    switch (_state) {
      case ControlState.idle:
        _pulsecontroller.stop();
        _pulsecontroller.value = 0;
        break;
      case ControlState.slow:
        _pulsecontroller.repeat(
          reverse: true,
          period: const Duration(milliseconds: 900),
        );
        break;
      case ControlState.fast:
        _pulsecontroller.repeat(
          reverse: true,
          period: const Duration(milliseconds: 420),
        );
        break;
    }
  }

  ControlState _getStateFromSlider(double value) {
    if (value <= 0.01) return ControlState.idle;
    if (value < _fastThreshold) return ControlState.slow;
    return ControlState.fast;
  }

  void _emitCommand(ControlState newState) {
    if (_state == newState) return;
    setState(() {
      _state = newState;
    });
    _syncAnimation();
    widget.onCommandChanged(newState);

    switch (newState) {
      case ControlState.idle:
        Vibration.vibrate(duration: 15);
        debugPrint("${widget.label} command: IDLE");
        break;
      case ControlState.slow:
        Vibration.vibrate(duration: 25, amplitude: 100);
        debugPrint("${widget.label} command: SLOW");
        break;
      case ControlState.fast:
        Vibration.vibrate(duration: 55, amplitude: 255);
        debugPrint("${widget.label} command: FAST");
        break;
    }
  }

  void _onSliderChanged(double value) {
    if (widget.isDisabled || widget.inConflict) return;

    setState(() {
      _sliderValue = value;
      _isTouching = true;
    });

    final newState = _getStateFromSlider(value);
    _emitCommand(newState);

    debugPrint(
      "${widget.label} slider: ${(value * 100).toStringAsFixed(1)}% - ${newState.name}",
    );
  }

  void _onSliderChangeStart(double value) {
    if (widget.isDisabled || widget.inConflict) return;
    _isTouching = true;
    debugPrint("Slider touch started: ${widget.label}");
  }

  void _onSliderChangeEnd(double value) {
    _isTouching = false;
    setState(() {
      _sliderValue = 0.0;
    });
    _emitCommand(ControlState.idle);
    _pulsecontroller.forward(from: 0.0);
    debugPrint("Slider released: ${widget.label}");
  }

  Color get _primaryColor {
    if (widget.isDisabled) return Colors.grey.shade400;
    if (widget.inConflict) return const Color(0xFFE74C3C);
    switch (_state) {
      case ControlState.idle:
        return AppColors.idleColor;
      case ControlState.slow:
        return widget.isUp ? AppColors.upColor : AppColors.downColor;
      case ControlState.fast:
        return AppColors.fastColor;
    }
  }

  Color get _bgColor {
    if (widget.isDisabled) return AppColors.idleColor.withAlpha(25);
    if (widget.inConflict) return AppColors.eStopColorLight.withAlpha(25);
    switch (_state) {
      case ControlState.idle:
        return AppColors.panelAlt;
      case ControlState.slow:
        return (widget.isUp ? AppColors.upColorLight : AppColors.downColorLight)
            .withAlpha((0.25 * 255).toInt());
      case ControlState.fast:
        return AppColors.fastColorLight.withAlpha((0.33 * 255).toInt());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, _) {
        final glow = _state != ControlState.idle
            ? _primaryColor.withAlpha(
                (0.14 + 0.26 * _pulseAnim.value * 255).toInt(),
              )
            : Colors.transparent;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // _stageDots(),
                  // const SizedBox(height: 10),
                  Icon(widget.icon, size: 18, color: _primaryColor),
                  const SizedBox(height: 4),
                  // Text(
                  //   widget.label,
                  //   textAlign: TextAlign.center,
                  //   style: TextStyle(
                  //     fontSize: 13,
                  //     fontWeight: FontWeight.bold,
                  //     color: _primaryColor,
                  //     letterSpacing: 0.5,
                  //     height: 1.25,
                  //   ),
                  // ),
                  // const SizedBox(height: 6),
                  _statusBadge(),
                ],
              ),
            ),

            // Vertical Slider Section
            Center(
              child: RotatedBox(
                quarterTurns: widget.isUp ? -1 : 1,
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 14,
                    thumbShape: const RectSliderThumbShape(
                      width: 18,
                      height: 32,
                      borderRadius: 5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 22,
                    ),
                    activeTrackColor: _sliderValue >= _fastThreshold
                        ? AppColors.fastColor
                        : (widget.isUp
                              ? AppColors.upColor
                              : AppColors.downColor),
                    inactiveTrackColor: Colors.grey.shade200,
                    thumbColor: _sliderValue >= _fastThreshold
                        ? AppColors.fastColor
                        : (widget.isUp
                              ? AppColors.upColor
                              : AppColors.downColor),
                    overlayColor: _primaryColor.withAlpha(50),
                  ),
                  child: Slider(
                    value: _sliderValue,
                    onChanged: widget.isDisabled || widget.inConflict
                        ? null
                        : _onSliderChanged,
                    onChangeStart: _onSliderChangeStart,
                    onChangeEnd: _onSliderChangeEnd,
                  ),
                ),
              ),
            ),

            // Bottom info section
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
              child: Column(
                children: [
                  _sliderIndicator(),
                  // const SizedBox(height: 5),
                  // _plcOutputDisplay(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _stageDots() {
    final slowColor = widget.isUp ? AppColors.upColor : AppColors.downColor;
    final slowactive =
        _state == ControlState.slow || _state == ControlState.fast;
    final fastactive = _state == ControlState.fast;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _dot(label: 'Slow', active: slowactive, color: slowColor),
        const SizedBox(width: 8),
        _dot(label: 'Fast', active: fastactive, color: AppColors.fastColor),
      ],
    );
  }

  Widget _dot({
    required String label,
    required bool active,
    required Color color,
  }) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: active ? color : Colors.grey.shade300,
            shape: BoxShape.circle,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: color.withAlpha((0.5 * 255).toInt()),
                      blurRadius: 5,
                    ),
                  ]
                : [],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            color: active ? color : Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  Widget _statusBadge() {
    if (widget.inConflict) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.eStopColorLight.withAlpha(25),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.eStopColorLight.withAlpha(102)),
        ),
        child: const Text(
          "CONFLICT",
          style: TextStyle(
            color: AppColors.eStopColorLight,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    String label;
    Color color;
    switch (_state) {
      case ControlState.idle:
        label = "IDLE";
        color = AppColors.idleColor;
        break;
      case ControlState.slow:
        label = "SLOW";
        color = widget.isUp ? AppColors.upColor : AppColors.downColor;
        break;
      case ControlState.fast:
        label = "FAST";
        color = AppColors.fastColor;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _state == ControlState.idle
            ? color.withAlpha((0.15 * 255).toInt())
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: _state == ControlState.idle
            ? Border.all(color: color.withAlpha((0.3 * 255).toInt()))
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _sliderIndicator() {
    final pct = (_sliderValue * 100).toInt();
    final indicatorColor = _sliderValue >= _fastThreshold
        ? AppColors.fastColor
        : (widget.isUp ? AppColors.upColor : AppColors.downColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'IDLE',
              style: TextStyle(fontSize: 8, color: AppColors.textMuted),
            ),
            Text(
              'SLOW',
              style: TextStyle(
                fontSize: 8,
                color: _sliderValue > 0.01 && _sliderValue < _fastThreshold
                    ? indicatorColor
                    : AppColors.textMuted,
              ),
            ),
            Text(
              'FAST',
              style: TextStyle(
                fontSize: 8,
                color: _sliderValue >= _fastThreshold
                    ? AppColors.fastColor
                    : AppColors.textMuted,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _sliderValue,
            minHeight: 5,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${pct}%',
          style: TextStyle(
            fontSize: 8,
            color: _isTouching ? indicatorColor : AppColors.textMuted,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _plcOutputDisplay() {
    final List<int> output = widget.inConflict
        ? plcConflict
        : (widget.isUp ? plcOutputUp[_state]! : plcOutputDown[_state]!);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...output.map((bit) {
          final active = bit == 1;
          return Container(
            margin: const EdgeInsets.only(right: 3),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: active
                  ? _primaryColor.withAlpha((0.2 * 255).toInt())
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              '$bit',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: active ? _primaryColor : Colors.grey.shade400,
                fontFamily: 'monospace',
              ),
            ),
          );
        }),
      ],
    );
  }

  @override
  void dispose() {
    _pulsecontroller.dispose();
    super.dispose();
  }
}
