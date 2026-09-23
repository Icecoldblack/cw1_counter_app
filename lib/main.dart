import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const CounterImageToggleApp());
}

/// Keys used to persist state with SharedPreferences.
class PrefKeys {
  static const String counter = 'counter';
  static const String step = 'step';
  static const String goal = 'goal';
  static const String isFirstImage = 'isFirstImage';
  static const String isDark = 'isDark';
}

/// Root widget. It owns the theme mode so that toggling Light/Dark
/// rebuilds the single MaterialApp for the whole app.
class CounterImageToggleApp extends StatefulWidget {
  const CounterImageToggleApp({super.key});

  @override
  State<CounterImageToggleApp> createState() => _CounterImageToggleAppState();
}

class _CounterImageToggleAppState extends State<CounterImageToggleApp> {
  bool _isDark = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _isDark = prefs.getBool(PrefKeys.isDark) ?? false);
  }

  Future<void> _toggleTheme() async {
    setState(() => _isDark = !_isDark);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefKeys.isDark, _isDark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CW1 Counter & Toggle',
      debugShowCheckedModeBanner: false,
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      home: HomePage(isDark: _isDark, onToggleTheme: _toggleTheme),
    );
  }
}

/// One entry in the undo history.
class CounterAction {
  const CounterAction({
    required this.label,
    required this.previousValue,
    required this.newValue,
  });

  final String label;
  final int previousValue;
  final int newValue;
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  static const int _historyLimit = 5;
  static const int _defaultGoal = 50;
  static const List<int> _stepOptions = [1, 5, 10];

  int _counter = 0;
  int _step = 1;
  int _goal = _defaultGoal;
  bool _isFirstImage = true;
  bool _goalCelebrated = false;
  final List<CounterAction> _history = [];

  late final AnimationController _controller;
  late final Animation<double> _animation;
  late final Animation<double> _turns;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _turns = Tween<double>(begin: 0, end: 1).animate(_animation);
    _loadState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _counter = prefs.getInt(PrefKeys.counter) ?? 0;
      _step = prefs.getInt(PrefKeys.step) ?? 1;
      _goal = prefs.getInt(PrefKeys.goal) ?? _defaultGoal;
      _isFirstImage = prefs.getBool(PrefKeys.isFirstImage) ?? true;
      _goalCelebrated = _counter >= _goal;
    });
    // Jump the animation to match the restored image without animating.
    _controller.value = _isFirstImage ? 0 : 1;
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(PrefKeys.counter, _counter);
    await prefs.setInt(PrefKeys.step, _step);
    await prefs.setInt(PrefKeys.goal, _goal);
    await prefs.setBool(PrefKeys.isFirstImage, _isFirstImage);
  }

  // ---------------------------------------------------------------------------
  // Task 1: counter logic
  // ---------------------------------------------------------------------------

  void _applyChange(int newValue, String label) {
    if (newValue == _counter) return;
    setState(() {
      _history.insert(
        0,
        CounterAction(
          label: label,
          previousValue: _counter,
          newValue: newValue,
        ),
      );
      if (_history.length > _historyLimit) {
        _history.removeLast();
      }
      _counter = newValue;
    });
    _checkGoal();
    _saveState();
  }

  void _incrementCounter() {
    _applyChange(_counter + _step, '+$_step');
  }

  void _decrementCounter() {
    final newValue = max(0, _counter - _step);
    _applyChange(newValue, '-${_counter - newValue}');
  }

  void _resetCounter() {
    _applyChange(0, 'Reset');
  }

  void _undo() {
    if (_history.isEmpty) return;
    setState(() {
      final last = _history.removeAt(0);
      _counter = last.previousValue;
    });
    _checkGoal();
    _saveState();
  }

  void _setStep(int step) {
    setState(() => _step = step);
    _saveState();
  }

  void _checkGoal() {
    final reached = _counter >= _goal;
    if (reached && !_goalCelebrated) {
      _goalCelebrated = true;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('🎉 Goal of $_goal reached! Nice work.')),
        );
    } else if (!reached) {
      _goalCelebrated = false;
    }
  }

  Future<void> _editGoal() async {
    final result = await showDialog<int>(
      context: context,
      builder: (_) => GoalDialog(initialGoal: _goal),
    );
    if (!mounted || result == null) return;
    setState(() {
      _goal = result;
      // Only celebrate when the goal is crossed by counting, not by editing.
      _goalCelebrated = _counter >= _goal;
    });
    _saveState();
  }

  double get _progress => (_counter / _goal).clamp(0.0, 1.0).toDouble();

  /// Bonus challenge: counter color shifts from green to red as it grows
  /// toward the goal.
  Color get _counterColor => Color.lerp(Colors.green, Colors.red, _progress)!;

  // ---------------------------------------------------------------------------
  // Task 2: image toggle
  // ---------------------------------------------------------------------------

  void _toggleImage() {
    if (_isFirstImage) {
      _controller.forward(); // Sun -> Moon
    } else {
      _controller.reverse(); // Moon -> Sun
    }
    setState(() => _isFirstImage = !_isFirstImage);
    HapticFeedback.selectionClick();
    _saveState();
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CW1 Counter & Toggle'),
        actions: [
          IconButton(
            tooltip: widget.isDark
                ? 'Switch to light mode'
                : 'Switch to dark mode',
            onPressed: widget.onToggleTheme,
            icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  _buildCounterCard(context),
                  const SizedBox(height: 16),
                  _buildImageCard(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCounterCard(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final goalReached = _counter >= _goal;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Counter', style: textTheme.titleMedium),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: textTheme.displayLarge!.copyWith(
                color: _counterColor,
                fontWeight: FontWeight.bold,
              ),
              child: Text('$_counter'),
            ),
            const SizedBox(height: 12),

            // Scale-up: multi-step controls
            Text('Step size: $_step', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: [
                for (final option in _stepOptions)
                  ButtonSegment<int>(value: option, label: Text('+$option')),
              ],
              selected: {_step},
              onSelectionChanged: (selection) => _setStep(selection.first),
            ),
            const SizedBox(height: 16),

            // Core requirement + scale-up: decrement / reset with disabled
            // states at 0
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _counter > 0 ? _decrementCounter : null,
                  icon: const Icon(Icons.remove),
                  label: const Text('Decrement'),
                ),
                ElevatedButton(
                  onPressed: _incrementCounter,
                  child: const Text('Increment'),
                ),
                TextButton.icon(
                  onPressed: _counter > 0 ? _resetCounter : null,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset'),
                ),
              ],
            ),
            const Divider(height: 32),

            // Scale-up: goal meter
            Row(
              children: [
                Expanded(
                  child: Text(
                    goalReached
                        ? '🎉 Goal reached: $_goal'
                        : 'Goal: $_goal (${(_progress * 100).round()}%)',
                    style: textTheme.titleSmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: _editGoal,
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Set goal'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 10,
                color: goalReached ? Colors.amber : _counterColor,
              ),
            ),
            const Divider(height: 32),

            // Scale-up: history + undo
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Last $_historyLimit actions',
                    style: textTheme.titleSmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: _history.isEmpty ? null : _undo,
                  icon: const Icon(Icons.undo),
                  label: const Text('Undo'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_history.isEmpty)
              Text('No actions yet', style: textTheme.bodySmall)
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final action in _history)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        '${action.label} '
                        '(${action.previousValue}→${action.newValue})',
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              _isFirstImage ? 'Day ☀️' : 'Night 🌙',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: 'Toggle between the sun and moon images',
              child: GestureDetector(
                onTap: _toggleImage,
                child: RotationTransition(
                  turns: _turns,
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: ClipOval(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Cross-fade: the sun fades out while the moon
                          // fades in, both driven by the same curve.
                          FadeTransition(
                            key: const ValueKey('sunFade'),
                            opacity: ReverseAnimation(_animation),
                            child: Image.asset(
                              'assets/images/sun.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                          FadeTransition(
                            key: const ValueKey('moonFade'),
                            opacity: _animation,
                            child: Image.asset(
                              'assets/images/moon.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _toggleImage,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Toggle Image'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for choosing a new goal. It owns its TextEditingController so the
/// controller is disposed only after the dialog's exit animation finishes.
class GoalDialog extends StatefulWidget {
  const GoalDialog({super.key, required this.initialGoal});

  final int initialGoal;

  @override
  State<GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<GoalDialog> {
  late final TextEditingController _textController =
      TextEditingController(text: '${widget.initialGoal}');
  String? _error;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_textController.text);
    if (value == null || value <= 0) {
      setState(() => _error = 'Enter a number greater than 0');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set a goal'),
      content: TextField(
        controller: _textController,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: 'Target count',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
