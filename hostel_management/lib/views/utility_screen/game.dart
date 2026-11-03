import 'package:flutter/material.dart';

class MathsGamePage extends StatefulWidget {
  const MathsGamePage({super.key});

  @override
  State<MathsGamePage> createState() => _MathsGamePageState();
}

class _MathsGamePageState extends State<MathsGamePage> {
  static const _background = Color(0xFF090B12);
  static const _surface = Color(0xFF131722);
  static const _line = Color(0xFF292F3D);
  static const _cyan = Color(0xFF55E6FF);
  static const _pink = Color(0xFFFF6BCB);
  static const _muted = Color(0xFF9299AA);

  final List<String> _board = List.filled(9, '');
  static const List<List<int>> _winningLines = [
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8],
    [2, 4, 6],
  ];

  String _turn = 'X';
  String? _winner;
  List<int> _winningCells = [];
  bool _draw = false;
  int _xScore = 0;
  int _oScore = 0;
  int _drawCount = 0;

  bool get _finished => _winner != null || _draw;

  void _play(int index) {
    if (_board[index].isNotEmpty || _finished) return;

    setState(() {
      _board[index] = _turn;
      for (final line in _winningLines) {
        if (line.every((cell) => _board[cell] == _turn)) {
          _winner = _turn;
          _winningCells = line;
          if (_turn == 'X') {
            _xScore++;
          } else {
            _oScore++;
          }
          return;
        }
      }

      if (_board.every((cell) => cell.isNotEmpty)) {
        _draw = true;
        _drawCount++;
      } else {
        _turn = _turn == 'X' ? 'O' : 'X';
      }
    });
  }

  void _newRound() {
    setState(() {
      _board.fillRange(0, _board.length, '');
      _turn = 'X';
      _winner = null;
      _winningCells = [];
      _draw = false;
    });
  }

  void _resetMatch() {
    setState(() {
      _board.fillRange(0, _board.length, '');
      _turn = 'X';
      _winner = null;
      _winningCells = [];
      _draw = false;
      _xScore = 0;
      _oScore = 0;
      _drawCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'TIC TAC TOE',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _playerCard(
                          name: 'PLAYER X',
                          mark: 'X',
                          score: _xScore,
                          color: _cyan,
                          active: !_finished && _turn == 'X',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _playerCard(
                          name: 'PLAYER O',
                          mark: 'O',
                          score: _oScore,
                          color: _pink,
                          active: !_finished && _turn == 'O',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _turnIndicator(),
                  const SizedBox(height: 18),
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: _line),
                      ),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 9,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 9,
                              mainAxisSpacing: 9,
                            ),
                        itemBuilder: (context, index) => _cell(index),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _miniScore('DRAWS', _drawCount.toString()),
                      const SizedBox(width: 22),
                      Container(width: 1, height: 28, color: _line),
                      const SizedBox(width: 22),
                      const Icon(
                        Icons.touch_app_rounded,
                        size: 16,
                        color: _muted,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Tap a square to play',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _finished ? _newRound : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: _cyan,
                        foregroundColor: _background,
                        disabledBackgroundColor: _surface,
                        disabledForegroundColor: _muted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Text(
                        _finished
                            ? 'PLAY AGAIN'
                            : 'FINISH THE ROUND TO CONTINUE',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: .8,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _resetMatch,
                    style: TextButton.styleFrom(foregroundColor: _muted),
                    child: const Text(
                      'Reset scores',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _playerCard({
    required String name,
    required String mark,
    required int score,
    required Color color,
    required bool active,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: .09) : _surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: active ? color.withValues(alpha: .7) : _line),
      ),
      child: Row(
        children: [
          Text(
            mark,
            style: TextStyle(
              color: color,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$score',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (active)
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }

  Widget _turnIndicator() {
    final Color color = _winner != null
        ? (_winner == 'X' ? _cyan : _pink)
        : _draw
        ? Colors.white
        : (_turn == 'X' ? _cyan : _pink);
    final String message = _winner != null
        ? 'PLAYER $_winner WINS!'
        : _draw
        ? 'IT’S A DRAW'
        : 'PLAYER $_turn’S TURN';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _finished ? Icons.emoji_events_rounded : Icons.circle,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 9),
          Text(
            message,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(int index) {
    final mark = _board[index];
    final color = mark == 'X' ? _cyan : _pink;
    final isWinningCell = _winningCells.contains(index);

    return Semantics(
      button: true,
      label: mark.isEmpty ? 'Empty square' : '$mark square',
      child: Material(
        color: isWinningCell
            ? color.withValues(alpha: .13)
            : const Color(0xFF0D111A),
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: () => _play(index),
          borderRadius: BorderRadius.circular(15),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isWinningCell ? color : _line,
                width: isWinningCell ? 1.6 : 1,
              ),
              boxShadow: isWinningCell
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: .10),
                        blurRadius: 14,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: AnimatedScale(
                scale: mark.isEmpty ? .75 : 1,
                duration: const Duration(milliseconds: 160),
                child: Text(
                  mark,
                  style: TextStyle(
                    color: color,
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    shadows: mark.isEmpty
                        ? null
                        : [
                            Shadow(
                              color: color.withValues(alpha: .35),
                              blurRadius: 14,
                            ),
                          ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniScore(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
