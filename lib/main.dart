import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const FlipPuzzleApp());
}

class FlipPuzzleApp extends StatelessWidget {
  const FlipPuzzleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Emoji Flip Puzzle',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const FlipPuzzlePage(),
    );
  }
}

class PuzzleTile {
  PuzzleTile({
    required this.id,
    required this.emoji,
  });

  final int id;
  final String emoji;
  bool isOpen = false;
  bool isMatched = false;
}

class PuzzlePreset {
  const PuzzlePreset({
    required this.gridSize,
    required this.matchCount,
  });

  final int gridSize;
  final int matchCount;
}

class PuzzleMode {
  const PuzzleMode({
    required this.name,
    required this.icon,
    required this.description,
    required this.presets,
  });

  final String name;
  final IconData icon;
  final String description;
  final List<PuzzlePreset> presets;
}

class FlipPuzzlePage extends StatefulWidget {
  const FlipPuzzlePage({super.key});

  @override
  State<FlipPuzzlePage> createState() => _FlipPuzzlePageState();
}

class _FlipPuzzlePageState extends State<FlipPuzzlePage> with SingleTickerProviderStateMixin {
  static const String _savedGameKey = 'emoji_flip_puzzle_saved_game_v1';
  static const String _bgMusicKey = 'emoji_flip_puzzle_bg_music_enabled_v1';
  static const String _matchSfxKey = 'emoji_flip_puzzle_match_sfx_enabled_v1';
  static const String _mismatchSfxKey = 'emoji_flip_puzzle_mismatch_sfx_enabled_v1';
  static const String _walkthroughSeenKey = 'emoji_flip_puzzle_walkthrough_seen_v1';

  final Random _random = Random();

  final List<String> _emojiPool = const [
    // Ordered for visual clarity. The first groups are intentionally very different
    // so custom levels like 6 x 6 Match 18 do not use two almost-identical smile emojis.
    '😀','🐶','🍎','🚗','⭐','⚽','🎸','💎','🔥','🌙',
    '🐱','🍕','🚀','🌈','🏆','💻','🔑','🎯','🦋','☕',
    '🐭','🍌','🚌','☀️','🎲','📱','🔔','🧩','🐢','🍩',
    '🐰','🍇','🚑','❄️','🎧','📷','❤️','🪁','🐙','🍔',
    '🦊','🍓','🚒','🌻','🎹','💡','💜','🎾','🐸','🍟',
    '🐻','🍒','🚕','🌵','🎺','⌚','🧡','🏀','🐵','🌮',
    '🐼','🍍','🚙','🌲','🥊','📚','🟦','🏈','🐔','🍪',
    '🐯','🥝','🏎️','💧','🏸','✏️','🟩','⚾','🐧','🍫',
    '🦁','🍉','🚓','🌊','🏐','📌','🟨','🏓','🐦','🍿',
    '🐮','🌭','🚎','⛰️','🎱','📎','🟧','🎮','🦉','🍭',
    '🐷','🥪','✈️','🌍','🎳','🖊️','🟥','🎁','🦄','🥤',
    '🐺','🥨','🚲','🌋','🛼','📝','⬛','🎨','🐝','🥐',
    '🐴','🧀','🚂','🌧️','🎿','📖','⬜','🎭','🐞','🥞',
    '🐬','🥕','🚁','🌪️','🏹','📁','🟪','🎤','🦀','🍦',
    '🐳','🌽','🛵','🌟','🪀','📮','🟫','🎬','🦖','🧁',
    '🦓','🥦','🛳️','🌺','🧸','🧭','🔵','🎪','🦕','🍰',
    '🦒','🍄','🚜','🍀','🧲','🧪','🟢','🎠','🦩','🍜',
    '🐘','🥥','🚤','🌹','🪄','🧯','🟡','🎡','🦚','🍣',
    '🦏','🥔','🛸','🌼','🔮','🧰','🟠','🎢','🦜','🍱',
    '🦛','🍋','🚦','🌿','🪕','🧵','🔴','🎆','🦇','🥟',
  ];
  int _gridSize = 3;
  int _matchCount = 3;
  int _moves = 0;
  String _currentModeName = 'Easy';
  bool _gameStarted = false;
  PuzzleMode? _selectedMode;
  bool _isCustomLevelScreen = false;
  int _customGridSize = 10;
  int _customMatchCount = 2;
  bool _isChecking = false;
  bool _isAutoSolving = false;
  bool _hasSavedGame = false;
  bool _bgMusicEnabled = true;
  bool _isMusicPlaying = false;
  bool _matchSfxEnabled = true;
  bool _mismatchSfxEnabled = true;
  bool _showFireworks = false;
  bool _winDialogShown = false;

  late final AnimationController _fireworksController;
  late final AudioPlayer _musicPlayer;
  late final AudioPlayer _matchSfxPlayer;
  late final AudioPlayer _mismatchSfxPlayer;

  List<PuzzleTile> _tiles = [];
  final List<int> _openTileIndexes = [];

  static const List<PuzzleMode> _modes = [
    PuzzleMode(
      name: 'Easy',
      icon: Icons.sentiment_satisfied_alt,
      description: 'Small grids and many repeated emojis.',
      presets: [
        PuzzlePreset(gridSize: 2, matchCount: 4),
        PuzzlePreset(gridSize: 2, matchCount: 2),
        PuzzlePreset(gridSize: 3, matchCount: 3),
        PuzzlePreset(gridSize: 5, matchCount: 5),
      ],
    ),
    PuzzleMode(
      name: 'Medium',
      icon: Icons.extension,
      description: 'Medium grids with medium emoji groups.',
      presets: [
        PuzzlePreset(gridSize: 6, matchCount: 6),
        PuzzlePreset(gridSize: 6, matchCount: 4),
        PuzzlePreset(gridSize: 6, matchCount: 3),
        PuzzlePreset(gridSize: 7, matchCount: 7),
        PuzzlePreset(gridSize: 8, matchCount: 8),
        PuzzlePreset(gridSize: 8, matchCount: 4),
        PuzzlePreset(gridSize: 9, matchCount: 9),
      ],
    ),
    PuzzleMode(
      name: 'Expert',
      icon: Icons.psychology,
      description: 'Big grids and fewer repeats.',
      presets: [
        PuzzlePreset(gridSize: 6, matchCount: 2),
        PuzzlePreset(gridSize: 8, matchCount: 2),
        PuzzlePreset(gridSize: 9, matchCount: 3),
        PuzzlePreset(gridSize: 10, matchCount: 10),
        PuzzlePreset(gridSize: 10, matchCount: 5),
        PuzzlePreset(gridSize: 10, matchCount: 4),
      ],
    ),
    PuzzleMode(
      name: 'Impossible',
      icon: Icons.local_fire_department,
      description: 'The hardest mode: 10 x 10 with Match 2.',
      presets: [
        PuzzlePreset(gridSize: 10, matchCount: 2),
      ],
    ),
  ];


  @override
  void initState() {
    super.initState();
    _fireworksController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _musicPlayer = AudioPlayer();
    _matchSfxPlayer = AudioPlayer();
    _mismatchSfxPlayer = AudioPlayer();
    _refreshSavedGameStatus();
    _loadSoundSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowFirstLaunchWalkthrough();
    });
  }

  @override
  void dispose() {
    _fireworksController.dispose();
    _musicPlayer.dispose();
    _matchSfxPlayer.dispose();
    _mismatchSfxPlayer.dispose();
    super.dispose();
  }


  Future<void> _maybeShowFirstLaunchWalkthrough() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool(_walkthroughSeenKey) ?? false;
    if (!mounted || hasSeen) return;

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    await _showWalkthroughDialog(markSeen: true);
  }

  Future<void> _showWalkthroughDialog({bool markSeen = false}) async {
    if (markSeen) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_walkthroughSeenKey, true);
    }
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.school, color: Colors.deepPurple),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'How to Play',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _walkthroughStep(
                      icon: Icons.grid_view_rounded,
                      title: '1. Choose a level',
                      text: 'Pick Easy, Medium, Expert, Impossible, or Make Your Own. Then choose one puzzle option.',
                    ),
                    _walkthroughStep(
                      icon: Icons.touch_app_rounded,
                      title: '2. Flip tiles',
                      text: 'Tap hidden tiles to reveal emojis. The app waits until you open the required group size.',
                    ),
                    _walkthroughStep(
                      icon: Icons.check_circle_rounded,
                      title: '3. Match the full group',
                      text: 'Example: Match 4 means open 4 tiles. If all 4 emojis are same, they become ✅. If one is different, all 4 close.',
                    ),
                    _walkthroughStep(
                      icon: Icons.smart_toy_outlined,
                      title: '4. Robot helper',
                      text: 'Tap the robot button to watch a human-like auto solver. While it plays, tap Stop to confirm and return to level selection.',
                    ),
                    _walkthroughStep(
                      icon: Icons.save_alt,
                      title: '5. Save and load',
                      text: 'Tap Save during a game. On the level page, use Load Saved Game to continue later.',
                    ),
                    _walkthroughStep(
                      icon: Icons.volume_up_rounded,
                      title: '6. Sound controls',
                      text: 'Tap the speaker icon to turn background music, match sound, and mismatch sound on or off.',
                    ),
                    _walkthroughStep(
                      icon: Icons.more_vert_rounded,
                      title: '7. Restart or change level',
                      text: 'During the game, use the 3-dot menu to restart the same puzzle or change level.',
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'You can open this guide again anytime from the Help button.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Start'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _walkthroughStep({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.deepPurple, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(text),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSoundSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _bgMusicEnabled = prefs.getBool(_bgMusicKey) ?? true;
      _matchSfxEnabled = prefs.getBool(_matchSfxKey) ?? true;
      _mismatchSfxEnabled = prefs.getBool(_mismatchSfxKey) ?? true;
    });

    if (_bgMusicEnabled) {
      await _startBackgroundMusic();
    }
  }

  Future<void> _startBackgroundMusic() async {
    if (!_bgMusicEnabled || _isMusicPlaying) return;
    try {
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(0.22);
      await _musicPlayer.play(AssetSource('sounds/bg_music.wav'));
      _isMusicPlaying = true;
    } catch (_) {
      // Browser/Android can block audio until the first user gesture.
      // We retry from user actions such as tile tap / robot start / sound button.
      _isMusicPlaying = false;
    }
  }

  Future<void> _ensureBackgroundMusicAfterUserAction() async {
    if (_bgMusicEnabled && !_isMusicPlaying) {
      await _startBackgroundMusic();
    }
  }

  Future<void> _stopBackgroundMusic() async {
    try {
      await _musicPlayer.stop();
    } catch (_) {}
    _isMusicPlaying = false;
  }

  Future<void> _toggleBackgroundMusic(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_bgMusicKey, enabled);
    if (!mounted) return;

    setState(() => _bgMusicEnabled = enabled);
    if (enabled) {
      _isMusicPlaying = false;
      await _startBackgroundMusic();
    } else {
      await _stopBackgroundMusic();
    }
  }

  Future<void> _toggleMatchSfx(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_matchSfxKey, enabled);
    if (!mounted) return;
    setState(() => _matchSfxEnabled = enabled);
  }

  Future<void> _toggleMismatchSfx(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_mismatchSfxKey, enabled);
    if (!mounted) return;
    setState(() => _mismatchSfxEnabled = enabled);
  }

  Future<void> _playMatchSound() async {
    if (!_matchSfxEnabled) return;
    try {
      await _matchSfxPlayer.stop();
      await _matchSfxPlayer.play(AssetSource('sounds/match.wav'), volume: 0.75);
    } catch (_) {}
  }

  Future<void> _playMismatchSound() async {
    if (!_mismatchSfxEnabled) return;
    try {
      await _mismatchSfxPlayer.stop();
      await _mismatchSfxPlayer.play(AssetSource('sounds/mismatch.wav'), volume: 0.75);
    } catch (_) {}
  }

  void _showSoundSettingsDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              title: const Text('Sound Settings'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.music_note),
                    title: const Text('Background music'),
                    value: _bgMusicEnabled,
                    onChanged: (value) async {
                      await _toggleBackgroundMusic(value);
                      if (mounted) dialogSetState(() {});
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.check_circle_outline),
                    title: const Text('Group match sound'),
                    value: _matchSfxEnabled,
                    onChanged: (value) async {
                      await _toggleMatchSfx(value);
                      if (value) await _playMatchSound();
                      if (mounted) dialogSetState(() {});
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.cancel_outlined),
                    title: const Text('Group not match sound'),
                    value: _mismatchSfxEnabled,
                    onChanged: (value) async {
                      await _toggleMismatchSfx(value);
                      if (value) await _playMismatchSound();
                      if (mounted) dialogSetState(() {});
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _refreshSavedGameStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _hasSavedGame = prefs.containsKey(_savedGameKey);
    });
  }

  Future<void> _saveGame() async {
    if (!_gameStarted || _isChecking || _isAutoSolving || _tiles.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{
      'gridSize': _gridSize,
      'matchCount': _matchCount,
      'moves': _moves,
      'currentModeName': _currentModeName,
      'tiles': _tiles.map((tile) {
        return <String, dynamic>{
          'id': tile.id,
          'emoji': tile.emoji,
          'isOpen': tile.isOpen,
          'isMatched': tile.isMatched,
        };
      }).toList(),
      'openTileIndexes': List<int>.from(_openTileIndexes),
      'savedAt': DateTime.now().toIso8601String(),
    };

    await prefs.setString(_savedGameKey, jsonEncode(data));
    if (!mounted) return;
    setState(() => _hasSavedGame = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Game saved.')),
    );
  }

  Future<void> _loadSavedGame() async {
    if (_isChecking || _isAutoSolving) return;

    final prefs = await SharedPreferences.getInstance();
    final rawSave = prefs.getString(_savedGameKey);
    if (rawSave == null) {
      if (!mounted) return;
      setState(() => _hasSavedGame = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved game found.')),
      );
      return;
    }

    try {
      final data = jsonDecode(rawSave) as Map<String, dynamic>;
      final savedTiles = (data['tiles'] as List<dynamic>).map((item) {
        final tileMap = item as Map<String, dynamic>;
        final tile = PuzzleTile(
          id: tileMap['id'] as int,
          emoji: tileMap['emoji'] as String,
        );
        tile.isOpen = tileMap['isOpen'] as bool? ?? false;
        tile.isMatched = tileMap['isMatched'] as bool? ?? false;
        return tile;
      }).toList();

      final savedGridSize = data['gridSize'] as int;
      final savedMatchCount = data['matchCount'] as int;
      final expectedTiles = savedGridSize * savedGridSize;

      if (savedTiles.length != expectedTiles || expectedTiles % savedMatchCount != 0) {
        throw const FormatException('Invalid saved puzzle data.');
      }

      final savedOpenIndexes = (data['openTileIndexes'] as List<dynamic>? ?? [])
          .map((value) => value as int)
          .where((index) => index >= 0 && index < savedTiles.length)
          .toList();

      setState(() {
        _gridSize = savedGridSize;
        _matchCount = savedMatchCount;
        _moves = data['moves'] as int? ?? 0;
        _currentModeName = data['currentModeName'] as String? ?? 'Saved';
        _tiles = savedTiles;
        _openTileIndexes
          ..clear()
          ..addAll(savedOpenIndexes);
        _selectedMode = null;
        _isCustomLevelScreen = false;
        _isChecking = false;
        _isAutoSolving = false;
        _showFireworks = false;
        _winDialogShown = false;
        _gameStarted = true;
        _hasSavedGame = true;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved game loaded.')),
      );
    } catch (_) {
      await prefs.remove(_savedGameKey);
      if (!mounted) return;
      setState(() => _hasSavedGame = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved game was broken and has been removed.')),
      );
    }
  }

  Future<void> _deleteSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedGameKey);
    if (!mounted) return;
    setState(() => _hasSavedGame = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved game deleted.')),
    );
  }

  int get _totalTiles => _gridSize * _gridSize;

  List<int> get _gridSizes => List<int>.generate(19, (index) => index + 2);

  List<int> _validMatchCountsForGrid(int gridSize) {
    final totalTiles = gridSize * gridSize;
    return List<int>.generate(19, (index) => index + 2)
        .where((matchCount) => totalTiles % matchCount == 0)
        .toList();
  }

  List<String> _emojiLabelsForGroups(int groupCount) {
    final labels = <String>[];
    var cycle = 0;

    while (labels.length < groupCount) {
      for (final emoji in _emojiPool) {
        if (labels.length >= groupCount) break;
        labels.add(cycle == 0 ? emoji : '$emoji${cycle + 1}');
      }
      cycle++;
    }

    return labels;
  }

  void _openCustomLevelScreen() {
    final validCounts = _validMatchCountsForGrid(_customGridSize);
    setState(() {
      _selectedMode = null;
      _isCustomLevelScreen = true;
      if (!validCounts.contains(_customMatchCount)) {
        _customMatchCount = validCounts.first;
      }
    });
  }

  void _startCustomLevel() {
    _gridSize = _customGridSize;
    _matchCount = _customMatchCount;
    _currentModeName = 'Custom';
    _newGame();
    setState(() {
      _gameStarted = true;
      _isCustomLevelScreen = false;
    });
  }

  void _selectMode(PuzzleMode mode) {
    setState(() {
      _selectedMode = mode;
    });
  }

  void _startPreset(PuzzleMode mode, PuzzlePreset preset) {
    _gridSize = preset.gridSize;
    _matchCount = preset.matchCount;
    _currentModeName = mode.name;
    _newGame();
    setState(() => _gameStarted = true);
  }

  void _backToModes() {
    setState(() {
      _selectedMode = null;
      _isCustomLevelScreen = false;
      _isChecking = false;
      _isAutoSolving = false;
      _openTileIndexes.clear();
    });
  }

  void _changeLevel() {
    setState(() {
      _gameStarted = false;
      _selectedMode = null;
      _isCustomLevelScreen = false;
      _isChecking = false;
      _isAutoSolving = false;
      _showFireworks = false;
      _winDialogShown = false;
      _openTileIndexes.clear();
    });
  }

  void _newGame() {
    final generatedTiles = <PuzzleTile>[];
    final fullGroups = _totalTiles ~/ _matchCount;
    final shuffledEmojis = _emojiLabelsForGroups(fullGroups)..shuffle(_random);

    int id = 0;
    for (int groupIndex = 0; groupIndex < fullGroups; groupIndex++) {
      final emoji = shuffledEmojis[groupIndex % shuffledEmojis.length];
      for (int i = 0; i < _matchCount; i++) {
        generatedTiles.add(PuzzleTile(id: id++, emoji: emoji));
      }
    }

    generatedTiles.shuffle(_random);

    setState(() {
      _tiles = generatedTiles;
      _moves = 0;
      _isChecking = false;
      _isAutoSolving = false;
      _showFireworks = false;
      _winDialogShown = false;
      _openTileIndexes.clear();
    });
  }

  Future<void> _onTileTap(int index) async {
    unawaited(_ensureBackgroundMusicAfterUserAction());
    if (_isChecking || _isAutoSolving) return;

    final tile = _tiles[index];
    if (tile.isOpen || tile.isMatched) return;

    setState(() {
      tile.isOpen = true;
      _openTileIndexes.add(index);
    });

    if (_openTileIndexes.length < _matchCount) return;

    setState(() {
      _moves++;
      _isChecking = true;
    });

    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    final selected = _openTileIndexes.map((i) => _tiles[i]).toList();
    final allSameEmoji = selected.every((t) => t.emoji == selected.first.emoji);

    setState(() {
      if (allSameEmoji) {
        for (final i in _openTileIndexes) {
          _tiles[i].isMatched = true;
          _tiles[i].isOpen = false;
        }
      } else {
        for (final i in _openTileIndexes) {
          _tiles[i].isOpen = false;
        }
      }
      _openTileIndexes.clear();
      _isChecking = false;
    });

    if (allSameEmoji) {
      unawaited(_playMatchSound());
    } else {
      unawaited(_playMismatchSound());
    }

    _checkWin();
  }

  Future<void> _requestStopAutoSolve() async {
    if (!_isAutoSolving) return;

    final shouldStop = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Stop robot?'),
          content: const Text('Do you really want to stop the robot and go back to level selection?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('No, continue'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Yes, stop'),
            ),
          ],
        );
      },
    );

    if (shouldStop != true || !mounted) return;

    setState(() {
      _isAutoSolving = false;
      _isChecking = false;
      _showFireworks = false;
      _winDialogShown = false;
      _openTileIndexes.clear();
      for (final tile in _tiles) {
        if (!tile.isMatched) tile.isOpen = false;
      }
      _gameStarted = false;
      _selectedMode = null;
      _isCustomLevelScreen = false;
    });
  }

  Future<void> _autoSolveHumanLike() async {
    unawaited(_ensureBackgroundMusicAfterUserAction());
    if (_isAutoSolving || _isChecking || !_gameStarted) return;

    final Map<String, List<int>> memory = {};
    final Set<int> seenIndexes = {};

    setState(() {
      _isAutoSolving = true;
      _isChecking = false;
      _openTileIndexes.clear();
      for (final tile in _tiles) {
        if (!tile.isMatched) tile.isOpen = false;
      }
    });

    while (mounted && _isAutoSolving && _tiles.any((tile) => !tile.isMatched)) {
      // Human-like rule:
      // The robot makes one full attempt of Match N tiles.
      // Example Match 4: it keeps 4 tiles open, then checks all 4 together.
      // If all 4 are same, they are matched. Otherwise all 4 close together.
      final completeEntry = _findCompleteMemoryGroup(memory);
      if (completeEntry != null) {
        await _autoMatchKnownGroup(completeEntry.value);
        memory.remove(completeEntry.key);
        seenIndexes.removeAll(completeEntry.value);
        continue;
      }

      final partialEntry = _bestPartialMemoryGroup(memory);
      final List<int> attempt = [];
      String? targetEmoji = partialEntry?.key;

      // First reopen the best remembered partial group.
      // Example: if robot remembers 3 pizzas in Match 4, it opens those 3 first.
      if (partialEntry != null) {
        for (final index in partialEntry.value) {
          if (!mounted || !_isAutoSolving || attempt.length >= _matchCount) break;
          if (_tiles[index].isMatched || attempt.contains(index)) continue;
          await _autoOpenTileForAttempt(index, attempt, memory, seenIndexes);
        }
      }

      // Then search unknown tiles until the full attempt size is reached.
      // If the last tile is wrong, all currently opened attempt tiles close together.
      while (mounted &&
          _isAutoSolving &&
          attempt.length < _matchCount &&
          _tiles.any((tile) => !tile.isMatched)) {
        final nextIndex = _nextUnknownTileIndex(seenIndexes, exclude: attempt);

        // If every remaining tile is already seen, use remembered but unmatched tiles
        // that are not already part of this attempt.
        final fallbackIndex = nextIndex ?? _nextKnownUnmatchedIndex(attempt);
        if (fallbackIndex == null) break;

        await _autoOpenTileForAttempt(fallbackIndex, attempt, memory, seenIndexes);
        targetEmoji ??= _tiles[fallbackIndex].emoji;
      }

      if (!mounted || !_isAutoSolving || attempt.isEmpty) break;

      if (attempt.length == _matchCount) {
        await _autoResolveAttempt(attempt, memory, seenIndexes);
      } else {
        await _autoCloseAttempt(attempt);
        break;
      }
    }

    if (!mounted) return;
    setState(() {
      _isAutoSolving = false;
      _isChecking = false;
      _openTileIndexes.clear();
      for (final tile in _tiles) {
        if (!tile.isMatched) tile.isOpen = false;
      }
    });
    _checkWin();
  }

  Future<void> _autoOpenTileForAttempt(
    int index,
    List<int> attempt,
    Map<String, List<int>> memory,
    Set<int> seenIndexes,
  ) async {
    if (!mounted || !_isAutoSolving) return;
    if (_tiles[index].isMatched || attempt.contains(index)) return;

    setState(() {
      _tiles[index].isOpen = true;
      attempt.add(index);
      _openTileIndexes
        ..clear()
        ..addAll(attempt);
    });

    await Future.delayed(const Duration(milliseconds: 420));
    if (!mounted || !_isAutoSolving) return;

    _rememberRevealedTile(index, memory, seenIndexes);
  }

  void _rememberRevealedTile(
    int index,
    Map<String, List<int>> memory,
    Set<int> seenIndexes,
  ) {
    seenIndexes.add(index);
    final emoji = _tiles[index].emoji;
    memory.putIfAbsent(emoji, () => []);
    if (!memory[emoji]!.contains(index)) {
      memory[emoji]!.add(index);
    }
  }

  Future<void> _autoResolveAttempt(
    List<int> attempt,
    Map<String, List<int>> memory,
    Set<int> seenIndexes,
  ) async {
    if (!mounted || !_isAutoSolving || attempt.length != _matchCount) return;

    setState(() => _isChecking = true);
    await Future.delayed(const Duration(milliseconds: 750));
    if (!mounted || !_isAutoSolving) return;

    final selectedTiles = attempt.map((index) => _tiles[index]).toList();
    final allSameEmoji = selectedTiles.every(
      (tile) => tile.emoji == selectedTiles.first.emoji,
    );

    setState(() {
      _moves++;

      if (allSameEmoji) {
        final matchedEmoji = selectedTiles.first.emoji;
        for (final index in attempt) {
          _tiles[index].isMatched = true;
          _tiles[index].isOpen = false;
        }
        memory.remove(matchedEmoji);
        seenIndexes.removeAll(attempt);
      } else {
        for (final index in attempt) {
          if (!_tiles[index].isMatched) {
            _tiles[index].isOpen = false;
          }
        }
      }

      _openTileIndexes.clear();
      _isChecking = false;
    });

    if (allSameEmoji) {
      unawaited(_playMatchSound());
    } else {
      unawaited(_playMismatchSound());
    }

    await Future.delayed(const Duration(milliseconds: 260));
  }

  Future<void> _autoCloseAttempt(List<int> attempt) async {
    if (!mounted || !_isAutoSolving) return;
    setState(() {
      for (final index in attempt) {
        if (!_tiles[index].isMatched) {
          _tiles[index].isOpen = false;
        }
      }
      _openTileIndexes.clear();
    });
    await Future.delayed(const Duration(milliseconds: 180));
  }

  MapEntry<String, List<int>>? _bestPartialMemoryGroup(
    Map<String, List<int>> memory,
  ) {
    MapEntry<String, List<int>>? best;

    for (final entry in memory.entries) {
      final availableIndexes = entry.value
          .where((index) => !_tiles[index].isMatched)
          .toList();

      if (availableIndexes.isEmpty || availableIndexes.length >= _matchCount) {
        continue;
      }

      if (best == null || availableIndexes.length > best.value.length) {
        best = MapEntry(entry.key, availableIndexes);
      }
    }

    return best;
  }

  int? _nextKnownUnmatchedIndex(List<int> exclude) {
    for (int i = 0; i < _tiles.length; i++) {
      if (!_tiles[i].isMatched && !_tiles[i].isOpen && !exclude.contains(i)) {
        return i;
      }
    }
    return null;
  }

  MapEntry<String, List<int>>? _findCompleteMemoryGroup(
    Map<String, List<int>> memory,
  ) {
    for (final entry in memory.entries) {
      final availableIndexes = entry.value
          .where((index) => !_tiles[index].isMatched)
          .toList();
      if (availableIndexes.length >= _matchCount) {
        return MapEntry(entry.key, availableIndexes.take(_matchCount).toList());
      }
    }
    return null;
  }

  int? _nextUnknownTileIndex(Set<int> seenIndexes, {List<int> exclude = const []}) {
    for (int i = 0; i < _tiles.length; i++) {
      if (!_tiles[i].isMatched &&
          !_tiles[i].isOpen &&
          !seenIndexes.contains(i) &&
          !exclude.contains(i)) {
        return i;
      }
    }
    return null;
  }

  Future<void> _autoMatchKnownGroup(List<int> positions) async {
    if (!mounted || !_isAutoSolving || positions.length < _matchCount) return;

    final attempt = <int>[];
    final dummyMemory = <String, List<int>>{};
    final dummySeen = <int>{};

    for (final index in positions.take(_matchCount)) {
      await _autoOpenTileForAttempt(index, attempt, dummyMemory, dummySeen);
    }

    if (!mounted || !_isAutoSolving) return;

    setState(() => _isChecking = true);
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted || !_isAutoSolving) return;

    setState(() {
      for (final index in attempt) {
        _tiles[index].isMatched = true;
        _tiles[index].isOpen = false;
      }
      _moves++;
      _openTileIndexes.clear();
      _isChecking = false;
    });

    unawaited(_playMatchSound());
    await Future.delayed(const Duration(milliseconds: 240));
  }

  void _checkWin() {
    if (_tiles.isNotEmpty && _tiles.every((t) => t.isMatched) && mounted && !_winDialogShown) {
      _winDialogShown = true;
      _startFireworksEffect();
      _showWinDialog();
    }
  }

  Future<void> _startFireworksEffect() async {
    if (!mounted) return;
    setState(() => _showFireworks = true);
    _fireworksController.repeat();
    await Future.delayed(const Duration(seconds: 4));
    if (!mounted) return;
    _fireworksController.stop();
    setState(() => _showFireworks = false);
  }

  void _showWinDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('🎉 You won!'),
          content: Text(
            'Mode: $_currentModeName\n'
            'Grid: $_gridSize x $_gridSize\n'
            'Difficulty: Match $_matchCount\n'
            'Moves: $_moves',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _newGame();
              },
              child: const Text('Play Again'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _changeLevel();
              },
              child: const Text('Change Level'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _gameStarted
        ? (_isAutoSolving ? 'Auto solving...  Moves: $_moves' : 'Moves: $_moves')
        : 'Emoji Flip Puzzle';

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        leading: IconButton(
          tooltip: 'Sound Settings',
          onPressed: () {
            unawaited(_ensureBackgroundMusicAfterUserAction());
            _showSoundSettingsDialog();
          },
          icon: Icon(_bgMusicEnabled ? Icons.volume_up : Icons.volume_off),
        ),
        title: _gameStarted
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_currentModeName • ${_gridSize}x$_gridSize • M$_matchCount',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    _isAutoSolving ? 'Robot playing • Moves: $_moves' : 'Moves: $_moves',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              )
            : const Text('Emoji Flip Puzzle'),
        centerTitle: !_gameStarted,
        actions: [
          if (!_gameStarted)
            IconButton(
              tooltip: 'How to Play',
              onPressed: () => _showWalkthroughDialog(),
              icon: const Icon(Icons.help_outline),
            ),
          if (_gameStarted)
            IconButton(
              tooltip: 'Save Game',
              visualDensity: VisualDensity.compact,
              onPressed: (_isChecking || _isAutoSolving) ? null : _saveGame,
              icon: const Icon(Icons.save_alt),
            ),
          if (_gameStarted)
            IconButton(
              tooltip: _isAutoSolving ? 'Stop Robot' : 'Auto Solve Like Human',
              visualDensity: VisualDensity.compact,
              onPressed: _isAutoSolving ? _requestStopAutoSolve : _autoSolveHumanLike,
              icon: Icon(_isAutoSolving ? Icons.stop_circle_outlined : Icons.smart_toy_outlined),
            ),
          if (_gameStarted)
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (value) {
                if (value == 'change') _changeLevel();
                if (value == 'restart') _newGame();
                if (value == 'help') _showWalkthroughDialog();
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'change',
                  enabled: !_isAutoSolving,
                  child: const ListTile(
                    leading: Icon(Icons.tune),
                    title: Text('Change Level'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'restart',
                  enabled: !_isAutoSolving,
                  child: const ListTile(
                    leading: Icon(Icons.refresh),
                    title: Text('Restart'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'help',
                  child: ListTile(
                    leading: Icon(Icons.help_outline),
                    title: Text('How to Play'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            _gameStarted
                ? _buildGameScreen()
                : (_isCustomLevelScreen
                    ? _buildCustomLevelScreen()
                    : (_selectedMode == null
                        ? _buildLevelScreen()
                        : _buildGridOptionsScreen(_selectedMode!))),
            if (_showFireworks)
              Positioned.fill(
                child: IgnorePointer(
                  child: FireworksOverlay(animation: _fireworksController),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameScreen() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use almost full screen height. No dropdown/menu row is kept in the game area.
        final boardSize = min(constraints.maxWidth, constraints.maxHeight) - 12;

        return Center(
          child: SizedBox.square(
            dimension: boardSize.clamp(220.0, 1200.0),
            child: GridView.builder(
              padding: const EdgeInsets.all(4),
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _gridSize,
                crossAxisSpacing: _gridSize <= 3 ? 10 : (_gridSize <= 5 ? 6 : 3),
                mainAxisSpacing: _gridSize <= 3 ? 10 : (_gridSize <= 5 ? 6 : 3),
              ),
              itemCount: _tiles.length,
              itemBuilder: (context, index) {
                final tile = _tiles[index];
                return FlipTileCard(
                  key: ValueKey(tile.id),
                  tile: tile,
                  gridSize: _gridSize,
                  onTap: () => _onTileTap(index),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildLevelScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose Level',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (_hasSavedGame) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _loadSavedGame,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Load Saved Game'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _deleteSavedGame,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete Save'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 22),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  for (final mode in _modes)
                    _ModeChoice(
                      mode: mode,
                      onTap: () => _selectMode(mode),
                    ),
                  _CustomModeChoice(
                    onTap: _openCustomLevelScreen,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildCustomLevelScreen() {
    final validMatchCounts = _validMatchCountsForGrid(_customGridSize);
    final totalTiles = _customGridSize * _customGridSize;
    final groups = totalTiles ~/ _customMatchCount;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: _backToModes,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      Flexible(
                        child: Text(
                          'Make Your Own Level',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 18,
                    runSpacing: 18,
                    alignment: WrapAlignment.center,
                    children: [
                      SizedBox(
                        width: 260,
                        child: DropdownButtonFormField<int>(
                          value: _customGridSize,
                          decoration: const InputDecoration(
                            labelText: 'Grid Size',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final size in _gridSizes)
                              DropdownMenuItem(
                                value: size,
                                child: Text('$size x $size'),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            final newValidCounts = _validMatchCountsForGrid(value);
                            setState(() {
                              _customGridSize = value;
                              if (!newValidCounts.contains(_customMatchCount)) {
                                _customMatchCount = newValidCounts.first;
                              }
                            });
                          },
                        ),
                      ),
                      SizedBox(
                        width: 260,
                        child: DropdownButtonFormField<int>(
                          value: _customMatchCount,
                          decoration: const InputDecoration(
                            labelText: 'Same Emoji Count',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final matchCount in validMatchCounts)
                              DropdownMenuItem(
                                value: matchCount,
                                child: Text('Match $matchCount'),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _customMatchCount = value);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '$totalTiles tiles • $groups emoji types • $_customMatchCount same tiles per match • no extra tiles',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _startCustomLevel,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Custom Puzzle'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildGridOptionsScreen(PuzzleMode mode) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: _backToModes,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Flexible(
                    child: Text(
                      '${mode.name} Grid Options',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                mode.description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  for (final preset in mode.presets)
                    _PresetChoice(
                      preset: preset,
                      onTap: () => _startPreset(mode, preset),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeChoice extends StatelessWidget {
  const _ModeChoice({
    required this.mode,
    required this.onTap,
  });

  final PuzzleMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 185,
        constraints: const BoxConstraints(minHeight: 190),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: colorScheme.surfaceContainerHighest,
          border: Border.all(color: colorScheme.outlineVariant),
          boxShadow: const [
            BoxShadow(blurRadius: 6, offset: Offset(1, 3), color: Colors.black12),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(mode.icon, size: 42, color: colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              mode.name,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              mode.description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onTap,
              child: const Text('Show Options'),
            ),
          ],
        ),
      ),
    );
  }
}


class _CustomModeChoice extends StatelessWidget {
  const _CustomModeChoice({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 185,
        constraints: const BoxConstraints(minHeight: 190),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: colorScheme.primaryContainer.withAlpha(125),
          border: Border.all(color: colorScheme.primary, width: 2),
          boxShadow: const [
            BoxShadow(blurRadius: 6, offset: Offset(1, 3), color: Colors.black12),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tune, size: 42, color: colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              'Make Your Own',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose grid up to 20 x 20 and valid same-emoji count.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onTap,
              child: const Text('Customize'),
            ),
          ],
        ),
      ),
    );
  }
}


class _PresetChoice extends StatelessWidget {
  const _PresetChoice({
    required this.preset,
    required this.onTap,
  });

  final PuzzlePreset preset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalTiles = preset.gridSize * preset.gridSize;
    final groups = totalTiles ~/ preset.matchCount;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 190,
        constraints: const BoxConstraints(minHeight: 170),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: colorScheme.surfaceContainerHighest,
          border: Border.all(color: colorScheme.outlineVariant),
          boxShadow: const [
            BoxShadow(blurRadius: 6, offset: Offset(1, 3), color: Colors.black12),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grid_view, size: 40, color: colorScheme.primary),
            const SizedBox(height: 10),
            Text(
              '${preset.gridSize} x ${preset.gridSize}',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Match ${preset.matchCount}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '$totalTiles tiles • $groups groups',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onTap,
              child: const Text('Play'),
            ),
          ],
        ),
      ),
    );
  }
}


class FireworksOverlay extends StatelessWidget {
  const FireworksOverlay({super.key, required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _FireworksPainter(
            progress: animation.value,
            colorScheme: Theme.of(context).colorScheme,
          ),
        );
      },
    );
  }
}

class _FireworksPainter extends CustomPainter {
  _FireworksPainter({
    required this.progress,
    required this.colorScheme,
  });

  final double progress;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final centers = <Offset>[
      Offset(size.width * 0.22, size.height * 0.22),
      Offset(size.width * 0.78, size.height * 0.24),
      Offset(size.width * 0.50, size.height * 0.18),
      Offset(size.width * 0.28, size.height * 0.70),
      Offset(size.width * 0.72, size.height * 0.68),
    ];

    final colors = <Color>[
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
      Colors.orangeAccent,
      Colors.pinkAccent,
      Colors.lightGreenAccent,
    ];

    for (int fireworkIndex = 0; fireworkIndex < centers.length; fireworkIndex++) {
      final localProgress = (progress + fireworkIndex * 0.18) % 1.0;
      final opacity = (1.0 - localProgress).clamp(0.0, 1.0);
      final radius = 24 + localProgress * min(size.width, size.height) * 0.18;
      final center = centers[fireworkIndex];

      for (int ray = 0; ray < 18; ray++) {
        final angle = (2 * pi * ray / 18) + fireworkIndex * 0.25;
        final start = center + Offset(cos(angle), sin(angle)) * radius * 0.45;
        final end = center + Offset(cos(angle), sin(angle)) * radius;
        final paint = Paint()
          ..color = colors[(ray + fireworkIndex) % colors.length].withOpacity(opacity)
          ..strokeWidth = 3.0 * opacity + 0.6
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(start, end, paint);
      }

      final dotPaint = Paint()
        ..color = Colors.white.withOpacity(opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 4 + 4 * opacity, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FireworksPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.colorScheme != colorScheme;
  }
}

class FlipTileCard extends StatelessWidget {
  const FlipTileCard({
    super.key,
    required this.tile,
    required this.gridSize,
    required this.onTap,
  });

  final PuzzleTile tile;
  final int gridSize;
  final VoidCallback onTap;

  double get _emojiSize {
    if (gridSize <= 2) return 96;
    if (gridSize == 3) return 82;
    if (gridSize <= 5) return 46;
    if (gridSize <= 7) return 34;
    if (gridSize <= 9) return 28;
    return 24;
  }

  double get _iconSize {
    if (gridSize <= 2) return 64;
    if (gridSize == 3) return 54;
    if (gridSize <= 5) return 32;
    if (gridSize <= 7) return 26;
    if (gridSize <= 9) return 22;
    return 20;
  }

  double get _radius {
    if (gridSize <= 2) return 22;
    if (gridSize == 3) return 18;
    if (gridSize <= 5) return 12;
    if (gridSize <= 7) return 10;
    return 8;
  }

  @override
  Widget build(BuildContext context) {
    final Widget visibleCard = tile.isMatched
        ? _matchedCard(context)
        : tile.isOpen
            ? _frontCard(context)
            : _backCard(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          final rotate = Tween<double>(begin: pi, end: 0).animate(animation);
          return AnimatedBuilder(
            animation: rotate,
            child: child,
            builder: (context, child) {
              return Transform(
                transform: Matrix4.rotationY(rotate.value),
                alignment: Alignment.center,
                child: child,
              );
            },
          );
        },
        child: visibleCard,
      ),
    );
  }

  Widget _backCard(BuildContext context) {
    return Container(
      key: ValueKey('back-${tile.id}'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: const [
          BoxShadow(blurRadius: 4, offset: Offset(1, 2), color: Colors.black26),
        ],
      ),
      child: Center(
        child: Icon(Icons.question_mark, size: _iconSize),
      ),
    );
  }

  Widget _frontCard(BuildContext context) {
    return Container(
      key: ValueKey('front-${tile.id}'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2.5),
      ),
      child: Center(
        child: FittedBox(
          child: Padding(
            padding: EdgeInsets.all(gridSize <= 5 ? 8 : 3),
            child: Text(tile.emoji, style: TextStyle(fontSize: _emojiSize)),
          ),
        ),
      ),
    );
  }

  Widget _matchedCard(BuildContext context) {
    return Container(
      key: ValueKey('matched-${tile.id}'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(150),
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Center(
        child: Icon(Icons.check_circle, size: _iconSize),
      ),
    );
  }
}
