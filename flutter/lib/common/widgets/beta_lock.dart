import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class BetaLockWidget extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const BetaLockWidget({
    Key? key,
    required this.child,
    this.enabled = true,
  }) : super(key: key);

  @override
  State<BetaLockWidget> createState() => _BetaLockWidgetState();
}

class _BetaLockWidgetState extends State<BetaLockWidget> {
  static const String _password = '29802988';
  static const int _durationHours = 24;

  bool _verified = false;
  bool _expired = false;
  int _remainingSeconds = _durationHours * 3600;
  Timer? _timer;
  final _passwordCtrl = TextEditingController();
  String _errorMsg = '';
  File? _startFile;
  File? _verifiedFile;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _initFiles();
    } else {
      _verified = true;
    }
  }

  Future<void> _initFiles() async {
    final dir = await getApplicationSupportDirectory();
    _startFile = File('${dir.path}/.rds_beta_ts');
    _verifiedFile = File('${dir.path}/.rds_beta_vf');
    await _checkState();
  }

  Future<void> _checkState() async {
    if (_startFile == null || _verifiedFile == null) return;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    int startTs = now;
    try {
      final data = await _startFile!.readAsString();
      startTs = int.tryParse(data.trim()) ?? now;
    } catch (_) {
      setState(() {
        _remainingSeconds = _durationHours * 3600;
        _verified = false;
      });
      return;
    }

    final elapsed = now - startTs;
    final totalSeconds = _durationHours * 3600;
    final remaining = totalSeconds - elapsed;

    if (remaining <= 0) {
      setState(() {
        _expired = true;
        _remainingSeconds = 0;
      });
      return;
    }

    _remainingSeconds = remaining;

    try {
      _verified = await _verifiedFile!.exists();
    } catch (_) {
      _verified = false;
    }

    if (_verified) {
      _startCountdown(remaining);
    }

    setState(() {});
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds <= 1) {
        _timer?.cancel();
        setState(() {
          _expired = true;
          _verified = false;
          _remainingSeconds = 0;
        });
      } else {
        setState(() {
          _remainingSeconds--;
        });
      }
    });
  }

  void _verifyPassword() async {
    if (_expired) return;
    if (_passwordCtrl.text == _password) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (_startFile != null && !await _startFile!.exists()) {
        await _startFile!.writeAsString(now.toString());
      }
      await _verifiedFile?.writeAsString('1', flush: true);
      setState(() {
        _verified = true;
        _errorMsg = '';
      });
      _startCountdown(_remainingSeconds);
    } else {
      setState(() {
        _errorMsg = 'Password incorrect';
      });
    }
  }

  String _formatTime(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Widget _lockScreen(Widget body) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: body,
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || _verified) {
      return Stack(
        children: [
          widget.child,
          if (_verified && widget.enabled)
            Positioned(
              bottom: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _remainingSeconds < 3600
                      ? Colors.red.withOpacity(0.75)
                      : Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _formatTime(_remainingSeconds),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    if (_expired) {
      return _lockScreen(
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_off, size: 64, color: Colors.red),
              const SizedBox(height: 20),
              const Text(
                'Beta period expired',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'This beta version has expired.\nPlease download a newer version.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return _lockScreen(
      Center(
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                'Beta Version',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Password required to continue\nRemaining: ${_formatTime(_remainingSeconds)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter password',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF0F3460),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  errorText: _errorMsg.isNotEmpty ? _errorMsg : null,
                ),
                onSubmitted: (_) => _verifyPassword(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _verifyPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Unlock',
                      style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
