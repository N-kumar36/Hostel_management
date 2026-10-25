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
  double _jumpRemaining = 0.0;
  double _timeLeft = 10;

  int _score = 0;
  int _bestScore = 0;

  String _question = '';
  int _correctAnswer = 0;
  List<int> _options = [];

  String _difficulty = 'Mixed';
  String _feedback = '';

  static const Color _purple = Color(0xFF8B5CF6);
  static const Color _cyan = Color(0xFF22D3EE);
  static const Color _background = Color(0xFF0B1020);
  static const Color _panel = Color(0xFF151D32);

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
      _jumpRemaining = 0.0;
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
          _feedback = 'Time is up!';
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

      final speed = 0.32 + math.min(_score * 0.005, 0.20);
      _hurdleProgress += speed * 0.04;

      if (_hurdleProgress >= 0.74) {
        _hurdleProgress = 0.74;
        _showQuestion();
      }

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

    final level = 10 + (_score ~/ 5) * 5;
    final maxNumber = math.min(level, 1000);

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
          final temp = a;
          a = b;
          b = temp;
        }
        symbol = '−';
        answer = a - b;
        break;

      case 'Multiplication':
        final multiplier = math.min(12, 2 + _score ~/ 10);
        a = _random.nextInt(multiplier) + 2;
        b = _random.nextInt(multiplier) + 2;
        symbol = '×';
        answer = a * b;
        break;

      default:
        b = _random.nextInt(11) + 2;
        answer = _random.nextInt(12) + 2;
        a = b * answer;
        symbol = '÷';
        break;
    }

    _correctAnswer = answer;
    _question = '$a $symbol $b = ?';

    final Set<int> choices = {answer};
    while (choices.length < 4) {
      final offset = _random.nextInt(11) - 5;
      final candidate = answer + (offset == 0 ? 1 : offset);
      if (candidate >= 0) choices.add(candidate);
    }

    _options = choices.toList()..shuffle(_random);
  }

  void _selectAnswer(int selected) {
    if (!_running || !_questionActive || _answering) return;

    if (selected != _correctAnswer) {
      setState(() {
        _feedback = 'Incorrect! The run is over.';
        _endGame();
      });
      return;
    }

    setState(() {
      _answering = true;
      _feedback = 'Correct! Nice jump!';
      _score++;

      if (_score > _bestScore) _bestScore = _score;

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
    setState(() => _difficulty = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(Icons.bolt_rounded, color: _cyan, size: 28),
            SizedBox(width: 8),
            Text(
              'MATHS RUNNER',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontSize: 17,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            enabled: !_running,
            tooltip: 'Difficulty',
            icon: const Icon(Icons.tune_rounded),
            color: _panel,
            onSelected: _changeDifficulty,
            itemBuilder: (_) => [
              for (final mode in [
                'Mixed',
                'Addition',
                'Subtraction',
                'Multiplication',
                'Division',
              ])
                PopupMenuItem(
                  value: mode,
                  child: Text(
                    mode,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Row(
                children: [
                  _statCard('SCORE', '$_score', Icons.bolt_rounded, _cyan),
                  const SizedBox(width: 10),
                  _statCard(
                    'PERSONAL BEST',
                    '$_bestScore',
                    Icons.emoji_events_rounded,
                    const Color(0xFFFBBF24),
                  ),
                  const SizedBox(width: 10),
                  _statCard(
                    'MODE',
                    _difficulty,
                    Icons.calculate_rounded,
                    const Color(0xFF34D399),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: _RunnerPainter(
                          elapsed: _elapsed,
                          hurdleProgress: _hurdleProgress,
                          running: _running,
                          jumping: _jumping,
                          jumpRemaining: _jumpRemaining,
                          crashed: _gameOver,
                        ),
                      ),
                      if (_running && !_questionActive)
                        Positioned(
                          top: 16,
                          left: 16,
                          right: 16,
                          child: _gameStatusBar(),
                        ),
                      if (!_running && !_gameOver) _startOverlay(),
                      if (_questionActive && _running) _questionOverlay(),
                      if (_gameOver) _gameOverOverlay(),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.tips_and_updates_rounded,
                    color: _cyan,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Solve quickly to leap over every hurdle.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    'BEST: $_bestScore',
                    style: const TextStyle(
                      color: Color(0xFFFBBF24),
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
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

  Widget _statCard(String title, String value, IconData icon, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 19),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 0.7,
                color: Colors.white.withValues(alpha: 0.55),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gameStatusBar() {
    return Row(
      children: [
        _pill(
          Icons.circle,
          _questionActive ? 'SOLVE NOW' : 'RUNNING',
          const Color(0xFF34D399),
        ),
        const Spacer(),
        _pill(Icons.bolt_rounded, 'LEVEL ${1 + _score ~/ 5}', _cyan),
      ],
    );
  }

  Widget _pill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xDD0B1020),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _startOverlay() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC10162A), Color(0xF20B1020)],
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [_purple, Color(0xFF4F46E5)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _purple.withValues(alpha: 0.35),
                    blurRadius: 35,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.directions_run_rounded,
                color: Colors.white,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'READY, RUNNER?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Solve the equation.\nBeat the clock. Clear the hurdle.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.6,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 22),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _featureChip(Icons.timer_rounded, '10 SEC'),
                _featureChip(
                  Icons.calculate_rounded,
                  _difficulty.toUpperCase(),
                ),
                _featureChip(Icons.emoji_events_rounded, 'HIGH SCORE'),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 250,
              height: 56,
              child: FilledButton.icon(
                onPressed: _startGame,
                icon: const Icon(Icons.play_arrow_rounded, size: 28),
                label: const Text(
                  'START RUNNING',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'ONE WRONG ANSWER ENDS YOUR RUN',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 10,
                letterSpacing: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _cyan, size: 15),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _questionOverlay() {
    final progress = (_timeLeft / 10).clamp(0.0, 1.0);
    final urgent = _timeLeft <= 3;

    return Container(
      color: const Color(0xE6090E1D),
      padding: const EdgeInsets.all(14),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: urgent ? const Color(0xFFF87171) : _purple,
                width: 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: _purple.withValues(alpha: 0.12),
                  blurRadius: 28,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFF87171),
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'HURDLE AHEAD',
                        style: TextStyle(
                          color: Color(0xFFF87171),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Solve to jump!',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _question,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(
                      Icons.timer_rounded,
                      color: urgent ? const Color(0xFFF87171) : _cyan,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_timeLeft.ceil()} seconds left',
                      style: TextStyle(
                        color: urgent ? const Color(0xFFF87171) : Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(progress * 100).round()}%',
                      style: TextStyle(
                        color: urgent ? const Color(0xFFF87171) : _cyan,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation(
                      urgent ? const Color(0xFFF87171) : _cyan,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth < 300 ? 1 : 2;
                    return GridView.count(
                      crossAxisCount: columns,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: columns == 1 ? 4.0 : 1.9,
                      children: [
                        for (int i = 0; i < _options.length; i++)
                          _answerButton(_options[i], i),
                      ],
                    );
                  },
                ),
                if (_feedback.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    _feedback,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF34D399),
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

  Widget _answerButton(int answer, int index) {
    final colors = [
      const Color(0xFF8B5CF6),
      const Color(0xFF0891B2),
      const Color(0xFF059669),
      const Color(0xFFD97706),
    ];
    final color = colors[index % colors.length];

    return ElevatedButton(
      onPressed: _answering ? null : () => _selectAnswer(answer),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.14),
        foregroundColor: Colors.white,
        disabledBackgroundColor: color.withValues(alpha: 0.08),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withValues(alpha: 0.7)),
        ),
      ),
      child: Text(
        '$answer',
        style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _gameOverOverlay() {
    final isRecord = _score > 0 && _score == _bestScore;

    return Container(
      color: const Color(0xF20B1020),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFF87171).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFF87171).withValues(alpha: 0.4),
                  ),
                ),
                child: Icon(
                  isRecord ? Icons.emoji_events_rounded : Icons.flag_rounded,
                  color: isRecord
                      ? const Color(0xFFFBBF24)
                      : const Color(0xFFF87171),
                  size: 52,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                isRecord ? 'NEW RECORD!' : 'RUN COMPLETE',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                _feedback.isNotEmpty
                    ? _feedback
                    : 'You collided with the hurdle!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 26),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF252044), Color(0xFF17243A)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _purple.withValues(alpha: 0.45)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'YOUR SCORE',
                      style: TextStyle(
                        color: Colors.white60,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_score',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 60,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBBF24).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        'PERSONAL BEST  $_bestScore',
                        style: const TextStyle(
                          color: Color(0xFFFBBF24),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: 250,
                height: 55,
                child: FilledButton.icon(
                  onPressed: _startGame,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text(
                    'RUN AGAIN',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
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
  final double jumpRemaining;
  final bool crashed;

  _RunnerPainter({
    required this.elapsed,
    required this.hurdleProgress,
    required this.running,
    required this.jumping,
    required this.jumpRemaining,
    required this.crashed,
  });

  // Keep the rest of your existing painter methods here.

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final groundY = h * 0.77;
    final background = Rect.fromLTWH(0, 0, w, h);

    canvas.drawRect(
      background,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF101A38), Color(0xFF263C66), Color(0xFF4D6A83)],
        ).createShader(background),
    );

    // Soft glowing moon/sun.
    canvas.drawCircle(
      Offset(w * 0.82, h * 0.18),
      33,
      Paint()..color = const Color(0xFF67E8F9).withValues(alpha: 0.10),
    );
    canvas.drawCircle(
      Offset(w * 0.82, h * 0.18),
      23,
      Paint()..color = const Color(0xFFBAE6FD),
    );

    // Stars.
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.55);
    for (int i = 0; i < 28; i++) {
      final x = (i * 73.0 + 29) % w;
      final y = (i * 47.0 + 17) % (h * 0.48);
      canvas.drawCircle(Offset(x, y), i % 4 == 0 ? 2 : 1, starPaint);
    }

    _drawCloud(canvas, Offset(w * 0.18, h * 0.20), 0.8);
    _drawCloud(canvas, Offset(w * 0.55, h * 0.30), 0.55);

    // Distant hills.
    final hillPaint = Paint()..color = const Color(0xFF314C68);
    final hills = Path()
      ..moveTo(0, groundY)
      ..lineTo(0, h * 0.58)
      ..quadraticBezierTo(w * 0.22, h * 0.40, w * 0.42, h * 0.59)
      ..quadraticBezierTo(w * 0.68, h * 0.39, w, h * 0.56)
      ..lineTo(w, groundY)
      ..close();
    canvas.drawPath(hills, hillPaint);

    // Ground.
    canvas.drawRect(
      Rect.fromLTWH(0, groundY, w, h - groundY),
      Paint()..color = const Color(0xFF132B3D),
    );

    canvas.drawRect(
      Rect.fromLTWH(0, groundY, w, 5),
      Paint()..color = const Color(0xFF22D3EE),
    );

    // Neon track markings.
    final dashPaint = Paint()
      ..color = const Color(0xFF67E8F9).withValues(alpha: 0.55)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final dashOffset = running ? (elapsed * 100) % 44 : 0.0;
    for (double x = -44; x < w + 44; x += 44) {
      canvas.drawLine(
        Offset(x - dashOffset, groundY + 24),
        Offset(x - dashOffset + 17, groundY + 24),
        dashPaint,
      );
    }

    if (!crashed) {
      final runnerX = w * 0.25;
      final hurdleX = w + 20 - (w * 0.75 + 20) * hurdleProgress;

      if (hurdleProgress > 0.001 || running) {
        _drawHurdle(canvas, hurdleX, groundY);
      }

      double runnerY = groundY;
      if (jumping) {
        final progress = (1 - jumpRemaining / 0.72).clamp(0.0, 1.0);
        runnerY -= math.sin(progress * math.pi) * h * 0.20;
      }

      _drawRunner(canvas, Offset(runnerX, runnerY), elapsed, jumping, false);
    } else {
      _drawHurdle(canvas, w * 0.31, groundY);
      _drawRunner(canvas, Offset(w * 0.25, groundY), elapsed, false, true);

      final crashPaint = Paint()..color = const Color(0xFFFBBF24);
      for (int i = 0; i < 5; i++) {
        final angle = i * math.pi * 2 / 5;
        canvas.drawCircle(
          Offset(
            w * 0.29 + math.cos(angle) * 26,
            groundY - 48 + math.sin(angle) * 24,
          ),
          4,
          crashPaint,
        );
      }
    }

    canvas.drawLine(
      Offset(0, groundY),
      Offset(w, groundY),
      Paint()
        ..color = const Color(0xFF22D3EE)
        ..strokeWidth = 3,
    );
  }

  void _drawCloud(Canvas canvas, Offset center, double scale) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.10);

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
    final shadow = Paint()
      ..color = const Color(0xFF000000).withValues(alpha: 0.2)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;

    final postPaint = Paint()
      ..color = const Color(0xFFFBBF24)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    final barPaint = Paint()
      ..color = const Color(0xFFFB7185)
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(x - 12, groundY),
      Offset(x - 12, groundY - 43),
      shadow,
    );
    canvas.drawLine(
      Offset(x + 12, groundY),
      Offset(x + 12, groundY - 43),
      shadow,
    );
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

    final cycle = elapsed * 12;
    final swing = crashed ? 0.0 : math.sin(cycle) * 14;
    final bounce = jumping
        ? 0.0
        : (running ? math.sin(cycle * 2).abs() * 3 : 0.0);

    final hip = Offset(feet.dx, feet.dy - 25 - bounce);
    final shoulder = Offset(feet.dx, feet.dy - 53 - bounce);
    final head = Offset(feet.dx, feet.dy - 68 - bounce);

    final bodyPaint = Paint()
      ..color = const Color(0xFF8B5CF6)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;

    final limbPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final skinPaint = Paint()..color = const Color(0xFFFFC9A5);

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

    canvas.drawLine(shoulder, hip, bodyPaint);

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

    canvas.drawCircle(head, 11, skinPaint);

    canvas.drawArc(
      Rect.fromCircle(center: head, radius: 11),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = const Color(0xFF111827)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke,
    );

    canvas.drawCircle(
      Offset(head.dx + 5, head.dy - 1),
      1.5,
      Paint()..color = const Color(0xFF111827),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RunnerPainter oldDelegate) => true;
}
