import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class MathsGamePage extends StatefulWidget {
  const MathsGamePage({super.key});

  @override
  State<MathsGamePage> createState() => _MathsGamePageState();
}

class _MathsGamePageState extends State<MathsGamePage> {
  final math.Random _random = math.Random();

  Timer? _timer;

  bool _running = false;
  bool _gameOver = false;
  bool _questionActive = false;
  bool _jumping = false;
  bool _answering = false;

  double _elapsed = 0;
  double _hurdleProgress = 0;
  double _jumpRemaining = 0;
  double _timeLeft = 10;

  int _score = 0;
  int _bestScore = 0;

  String _question = '';
  int _correctAnswer = 0;
  List<int> _options = [];

  String _difficulty = 'Mixed';
  String _feedback = '';

  static const Color _purple = Color(0xFF7C3AED);
  static const Color _dark = Color(0xFF111827);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startGame() {
    _timer?.cancel();

    setState(() {
      _running = true;
      _gameOver = false;
      _questionActive = false;
      _jumping = false;
      _answering = false;
      _elapsed = 0;
      _hurdleProgress = 0;
      _jumpRemaining = 0;
      _timeLeft = 10;
      _score = 0;
      _feedback = '';
      _question = '';
      _options = [];
    });

    _timer = Timer.periodic(const Duration(milliseconds: 40), (_) => _tick());
  }

  void _tick() {
    if (!mounted || !_running) return;

    setState(() {
      _elapsed += 0.04;

      if (_questionActive) {
        _timeLeft -= 0.04;

        if (_timeLeft <= 0) {
          _timeLeft = 0;
          _endGame();
        }

        return;
      }

      if (_jumping) {
        _jumpRemaining -= 0.04;

        if (_jumpRemaining <= 0) {
          _jumping = false;
          _hurdleProgress = 0;
        }

        return;
      }

      // The runner keeps moving towards the next hurdle.
      final double speed = 0.20 + math.min(_score * 0.003, 0.12);
      _hurdleProgress += speed * 0.04;

      // Display a question when the hurdle gets close.
      if (_hurdleProgress >= 0.74) {
        _hurdleProgress = 0.74;
        _showQuestion();
      }

      // Safety check if the obstacle reaches the runner.
      if (_hurdleProgress >= 1 && !_jumping) {
        _endGame();
      }
    });
  }

  void _showQuestion() {
    _questionActive = true;
    _answering = false;
    _timeLeft = 10;
    _feedback = '';

    _generateQuestion();
  }

  void _generateQuestion() {
    late int a;
    late int b;
    late String symbol;
    late int answer;

    String operation = _difficulty;

    if (operation == 'Mixed') {
      operation = [
        'Addition',
        'Subtraction',
        'Multiplication',
        'Division',
      ][_random.nextInt(4)];
    }

    // Questions gradually become harder as the score increases.
    final int level = 10 + (_score ~/ 5) * 5;
    final int maxNumber = math.min(level, 1000);

    switch (operation) {
      case 'Addition':
        a = _random.nextInt(maxNumber) + 1;
        b = _random.nextInt(maxNumber) + 1;
        symbol = '+';
        answer = a + b;
        break;

      case 'Subtraction':
        a = _random.nextInt(maxNumber) + 1;
        b = _random.nextInt(maxNumber) + 1;

        if (b > a) {
          final int temp = a;
          a = b;
          b = temp;
        }

        symbol = '−';
        answer = a - b;
        break;

      case 'Multiplication':
        final int multiplier = math.min(12, 2 + _score ~/ 10);
        a = _random.nextInt(multiplier) + 2;
        b = _random.nextInt(multiplier) + 2;
        symbol = '×';
        answer = a * b;
        break;

      default:
        b = _random.nextInt(12) + 2;
        answer = _random.nextInt(12) + 2;
        a = b * answer;
        symbol = '÷';
        break;
    }

    _correctAnswer = answer;
    _question = '$a $symbol $b = ?';

    final Set<int> choices = {answer};

    while (choices.length < 4) {
      final int offset = _random.nextInt(11) - 5;
      final int candidate = answer + (offset == 0 ? 1 : offset);

      if (candidate >= 0) {
        choices.add(candidate);
      }
    }

    _options = choices.toList()..shuffle(_random);
  }

  void _selectAnswer(int selected) {
    if (!_running || !_questionActive || _answering) return;

    if (selected != _correctAnswer) {
      setState(() {
        _feedback = 'Wrong answer! You hit the hurdle.';
        _endGame();
      });
      return;
    }

    setState(() {
      _answering = true;
      _feedback = 'Correct! Jump!';
      _score++;

      if (_score > _bestScore) {
        _bestScore = _score;
      }

      _questionActive = false;
      _jumping = true;
      _jumpRemaining = 0.72;
      _hurdleProgress = 0.74;
    });
  }

  void _endGame() {
    _running = false;
    _gameOver = true;
    _questionActive = false;
    _jumping = false;
    _timer?.cancel();
  }

  void _changeDifficulty(String? value) {
    if (value == null || _running) return;

    setState(() {
      _difficulty = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FB),
      appBar: AppBar(
        title: const Text(
          'Maths Runner',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _dark,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Difficulty',
            enabled: !_running,
            onSelected: _changeDifficulty,
            icon: const Icon(Icons.tune_rounded),
            itemBuilder: (_) => [
              for (final mode in [
                'Mixed',
                'Addition',
                'Subtraction',
                'Multiplication',
                'Division',
              ])
                PopupMenuItem(value: mode, child: Text(mode)),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  _statCard(
                    'SCORE',
                    '$_score',
                    Icons.stars_rounded,
                    const Color(0xFF7C3AED),
                  ),
                  const SizedBox(width: 10),
                  _statCard(
                    'BEST',
                    '$_bestScore',
                    Icons.emoji_events_rounded,
                    const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 10),
                  _statCard(
                    'MODE',
                    _difficulty,
                    Icons.calculate_rounded,
                    const Color(0xFF059669),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: _RunnerPainter(
                          elapsed: _elapsed,
                          hurdleProgress: _hurdleProgress,
                          running: _running,
                          jumping: _jumping,
                          crashed: _gameOver,
                        ),
                      ),

                      if (!_running && !_gameOver) _startOverlay(),

                      if (_questionActive && _running) _questionOverlay(),

                      if (_gameOver) _gameOverOverlay(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: _dark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _startOverlay() {
    return Container(
      color: const Color(0xAA111827),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.directions_run_rounded,
            size: 78,
            color: Colors.white,
          ),
          const SizedBox(height: 14),
          const Text(
            'MATHS RUNNER',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 29,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Run, solve and jump!\nOne wrong answer ends your run.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.5, color: Colors.white70),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _startGame,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('START RUNNING'),
            style: FilledButton.styleFrom(
              backgroundColor: _purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _questionOverlay() {
    return Container(
      color: const Color(0xB8111827),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFEA580C),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'HURDLE AHEAD!',
                      style: TextStyle(
                        color: Color(0xFFEA580C),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Solve to jump',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                Text(
                  _question,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer_rounded, color: Color(0xFFDC2626)),
                    const SizedBox(width: 6),
                    Text(
                      '${_timeLeft.ceil()} seconds left',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: (_timeLeft / 10).clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: const Color(0xFFFEE2E2),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFEF4444)),
                  ),
                ),
                const SizedBox(height: 18),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.0,
                  children: [
                    for (final option in _options)
                      ElevatedButton(
                        onPressed: _answering
                            ? null
                            : () => _selectAnswer(option),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF3F0FF),
                          foregroundColor: _purple,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Color(0xFFE3D9FF)),
                          ),
                        ),
                        child: Text(
                          '$option',
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
                if (_feedback.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _feedback,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF059669),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _gameOverOverlay() {
    return Container(
      color: const Color(0xDD111827),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.sentiment_dissatisfied_rounded,
                color: Color(0xFFF87171),
                size: 82,
              ),
              const SizedBox(height: 12),
              const Text(
                'GAME OVER',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _feedback.isNotEmpty
                    ? _feedback
                    : 'You collided with the hurdle!',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Text(
                      'YOUR SCORE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$_score',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 46,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Best score: $_bestScore',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _startGame,
                icon: const Icon(Icons.replay_rounded),
                label: const Text('PLAY AGAIN'),
                style: FilledButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RunnerPainter extends CustomPainter {
  final double elapsed;
  final double hurdleProgress;
  final bool running;
  final bool jumping;
  final bool crashed;

  _RunnerPainter({
    required this.elapsed,
    required this.hurdleProgress,
    required this.running,
    required this.jumping,
    required this.crashed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double groundY = h * 0.77;

    final Rect background = Rect.fromLTWH(0, 0, w, h);

    canvas.drawRect(
      background,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFBDEBFF), Color(0xFFE8F8FF), Color(0xFFF7FCEB)],
        ).createShader(background),
    );

    // Sun
    canvas.drawCircle(
      Offset(w * 0.82, h * 0.14),
      28,
      Paint()..color = const Color(0xFFFFD166),
    );

    // Clouds
    _drawCloud(canvas, Offset(w * 0.20, h * 0.16), 1);
    _drawCloud(canvas, Offset(w * 0.59, h * 0.25), 0.75);

    // Distant hills
    final hillPaint = Paint()..color = const Color(0xFFA7DDA8);
    final hills = Path()
      ..moveTo(0, groundY)
      ..lineTo(0, h * 0.57)
      ..quadraticBezierTo(w * 0.22, h * 0.40, w * 0.42, h * 0.59)
      ..quadraticBezierTo(w * 0.68, h * 0.39, w, h * 0.56)
      ..lineTo(w, groundY)
      ..close();

    canvas.drawPath(hills, hillPaint);

    // Grass
    canvas.drawRect(
      Rect.fromLTWH(0, groundY, w, h - groundY),
      Paint()..color = const Color(0xFF8BD17C),
    );

    canvas.drawRect(
      Rect.fromLTWH(0, groundY, w, 7),
      Paint()..color = const Color(0xFF4DAD54),
    );

    // Scrolling ground dashes
    final dashPaint = Paint()
      ..color = const Color(0xFF4DAD54)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final double dashOffset = running ? (elapsed * 100) % 44 : 0;

    for (double x = -44; x < w + 44; x += 44) {
      canvas.drawLine(
        Offset(x - dashOffset, groundY + 24),
        Offset(x - dashOffset + 17, groundY + 24),
        dashPaint,
      );
    }

    // Hurdle moves from the right towards the runner.
    if (!crashed) {
      final double runnerX = w * 0.25;
      final double hurdleX = w + 20 - (w * 0.75 + 20) * hurdleProgress;

      if (hurdleProgress > 0.001 || running) {
        _drawHurdle(canvas, hurdleX, groundY);
      }

      double runnerY = groundY;

      if (jumping) {
        final double progress =
            (1 - (0.72 - 0.72 * (1 - (elapsed % 0.72) / 0.72)) / 0.72).clamp(
              0.0,
              1.0,
            );

        runnerY -= math.sin(progress * math.pi) * h * 0.20;
      }

      _drawRunner(canvas, Offset(runnerX, runnerY), elapsed, jumping, false);
    } else {
      _drawHurdle(canvas, w * 0.31, groundY);
      _drawRunner(canvas, Offset(w * 0.25, groundY), elapsed, false, true);

      // Small collision stars
      final starPaint = Paint()..color = const Color(0xFFFFD166);
      for (int i = 0; i < 5; i++) {
        final double angle = i * math.pi * 2 / 5;
        final double x = w * 0.29 + math.cos(angle) * 26;
        final double y = groundY - 48 + math.sin(angle) * 24;
        canvas.drawCircle(Offset(x, y), 4, starPaint);
      }
    }

    // Track border
    canvas.drawLine(
      Offset(0, groundY),
      Offset(w, groundY),
      Paint()
        ..color = const Color(0xFF438E45)
        ..strokeWidth = 3,
    );
  }

  void _drawCloud(Canvas canvas, Offset center, double scale) {
    final paint = Paint()..color = Colors.white.withOpacity(0.8);

    canvas.drawCircle(center, 15 * scale, paint);
    canvas.drawCircle(
      center.translate(17 * scale, -7 * scale),
      19 * scale,
      paint,
    );
    canvas.drawCircle(center.translate(36 * scale, 0), 14 * scale, paint);
    canvas.drawRect(
      Rect.fromLTWH(center.dx - 1 * scale, center.dy, 37 * scale, 12 * scale),
      paint,
    );
  }

  void _drawHurdle(Canvas canvas, double x, double groundY) {
    final postPaint = Paint()
      ..color = const Color(0xFF92400E)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    final barPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(x - 12, groundY),
      Offset(x - 12, groundY - 43),
      postPaint,
    );

    canvas.drawLine(
      Offset(x + 12, groundY),
      Offset(x + 12, groundY - 43),
      postPaint,
    );

    canvas.drawLine(
      Offset(x - 21, groundY - 39),
      Offset(x + 21, groundY - 39),
      barPaint,
    );

    canvas.drawLine(
      Offset(x - 10, groundY - 39),
      Offset(x - 2, groundY - 39),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 5,
    );

    canvas.drawLine(
      Offset(x + 7, groundY - 39),
      Offset(x + 15, groundY - 39),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 5,
    );
  }

  void _drawRunner(
    Canvas canvas,
    Offset feet,
    double elapsed,
    bool jumping,
    bool crashed,
  ) {
    canvas.save();

    if (crashed) {
      canvas.translate(feet.dx, feet.dy - 15);
      canvas.rotate(1.15);
      canvas.translate(-feet.dx, -(feet.dy - 15));
    }

    final double cycle = elapsed * 12;
    final double swing = crashed ? 0 : math.sin(cycle) * 14;
    final double bounce = jumping
        ? 0
        : (running ? math.sin(cycle * 2).abs() * 3 : 0);

    final Offset hip = Offset(feet.dx, feet.dy - 25 - bounce);
    final Offset shoulder = Offset(feet.dx, feet.dy - 53 - bounce);
    final Offset head = Offset(feet.dx, feet.dy - 68 - bounce);

    final bodyPaint = Paint()
      ..color = const Color(0xFF4F46E5)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;

    final limbPaint = Paint()
      ..color = const Color(0xFF1F2937)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final skinPaint = Paint()..color = const Color(0xFFFFC9A5);

    // Legs
    if (jumping) {
      canvas.drawLine(hip, Offset(feet.dx - 15, feet.dy - 12), limbPaint);
      canvas.drawLine(
        Offset(feet.dx - 15, feet.dy - 12),
        Offset(feet.dx - 26, feet.dy - 19),
        limbPaint,
      );
      canvas.drawLine(hip, Offset(feet.dx + 14, feet.dy - 17), limbPaint);
      canvas.drawLine(
        Offset(feet.dx + 14, feet.dy - 17),
        Offset(feet.dx + 26, feet.dy - 28),
        limbPaint,
      );
    } else {
      canvas.drawLine(
        hip,
        Offset(feet.dx - 10 + swing, feet.dy - 12),
        limbPaint,
      );
      canvas.drawLine(
        Offset(feet.dx - 10 + swing, feet.dy - 12),
        Offset(feet.dx - 14 + swing, feet.dy),
        limbPaint,
      );

      canvas.drawLine(
        hip,
        Offset(feet.dx + 10 - swing, feet.dy - 12),
        limbPaint,
      );
      canvas.drawLine(
        Offset(feet.dx + 10 - swing, feet.dy - 12),
        Offset(feet.dx + 14 - swing, feet.dy),
        limbPaint,
      );
    }

    // Body
    canvas.drawLine(shoulder, hip, bodyPaint);

    // Arms
    canvas.drawLine(
      shoulder,
      Offset(feet.dx - 15 - swing * 0.45, feet.dy - 42 - bounce),
      limbPaint,
    );

    canvas.drawLine(
      Offset(feet.dx - 15 - swing * 0.45, feet.dy - 42 - bounce),
      Offset(feet.dx - 18 - swing * 0.45, feet.dy - 33 - bounce),
      limbPaint,
    );

    canvas.drawLine(
      shoulder,
      Offset(feet.dx + 14 + swing * 0.45, feet.dy - 43 - bounce),
      limbPaint,
    );

    canvas.drawLine(
      Offset(feet.dx + 14 + swing * 0.45, feet.dy - 43 - bounce),
      Offset(feet.dx + 17 + swing * 0.45, feet.dy - 34 - bounce),
      limbPaint,
    );

    // Head
    canvas.drawCircle(head, 11, skinPaint);

    // Hair
    canvas.drawArc(
      Rect.fromCircle(center: head, radius: 11),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = const Color(0xFF374151)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke,
    );

    // Eye
    canvas.drawCircle(
      Offset(head.dx + 5, head.dy - 1),
      1.5,
      Paint()..color = _darkColor,
    );

    canvas.restore();
  }

  Color get _darkColor => const Color(0xFF111827);

  @override
  bool shouldRepaint(covariant _RunnerPainter oldDelegate) => true;
}
