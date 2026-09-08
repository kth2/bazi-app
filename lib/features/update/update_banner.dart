import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/update/app_update.dart';
import '../../theme.dart';

/// Watches for a newer deployed build and offers a one-tap reload.
///
/// Deliberately a prompt rather than a silent reload: the case journal has
/// forms holding unsaved feedback, and reloading underneath someone typing
/// would throw their work away. Detection is automatic; applying it is theirs.
class UpdateWatcher extends StatefulWidget {
  final Widget child;

  /// Injectable for tests.
  final UpdateChecker? checker;
  final Future<void> Function()? onApply;
  final Duration interval;
  final Duration startupDelay;

  const UpdateWatcher({
    super.key,
    required this.child,
    this.checker,
    this.onApply,
    this.interval = const Duration(minutes: 30),
    this.startupDelay = const Duration(seconds: 5),
  });

  @override
  State<UpdateWatcher> createState() => _UpdateWatcherState();
}

class _UpdateWatcherState extends State<UpdateWatcher>
    with WidgetsBindingObserver {
  late final UpdateChecker _checker = widget.checker ?? UpdateChecker.forApp();
  Timer? _timer;
  Timer? _startup;
  bool _updateReady = false;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    if (!_checker.isEnabled) return;
    WidgetsBinding.instance.addObserver(this);
    // Not immediately: first paint should not race a network call.
    _startup = Timer(widget.startupDelay, _check);
    _timer = Timer.periodic(widget.interval, (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _startup?.cancel();
    if (_checker.isEnabled) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back to an installed PWA is the most likely moment for a new
    // build to have landed since it was last open.
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_updateReady || !mounted) return;
    final available = await _checker.hasUpdate();
    if (!mounted || !available) return;
    setState(() => _updateReady = true);
  }

  Future<void> _apply() async {
    if (_applying) return;
    setState(() => _applying = true);
    await (widget.onApply ?? applyUpdate)();
    if (mounted) setState(() => _applying = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_updateReady)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(10),
                color: kPrimaryRed,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  child: Row(
                    children: [
                      const Icon(Icons.system_update_alt,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          '有新版本可用',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        onPressed: _applying ? null : _apply,
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.white),
                        child: Text(_applying ? '更新中…' : '立即更新'),
                      ),
                      IconButton(
                        tooltip: '稍后',
                        icon: const Icon(Icons.close,
                            color: Colors.white70, size: 18),
                        onPressed: () => setState(() => _updateReady = false),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
