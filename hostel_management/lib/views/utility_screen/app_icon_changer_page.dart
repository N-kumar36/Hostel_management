import 'package:flutter/material.dart';
import 'package:dynamic_app_icon_changer/dynamic_app_icon_changer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppIconChangerPage extends StatefulWidget {
  const AppIconChangerPage({super.key});

  @override
  State<AppIconChangerPage> createState() => _AppIconChangerPageState();
}

class _AppIconChangerPageState extends State<AppIconChangerPage> {
  String _selectedIcon = 'default';
  bool _loading = false;

  final List<Map<String, dynamic>> _icons = [
    {
      'id': 'default',
      'name': 'HostelMess Default',
      'description': 'Original HostelMess branding',
      'color': const Color(0xFF673AB7),
      'symbol': Icons.apartment_rounded,
    },
    {
      'id': 'kazi',
      'name': 'Kazi Nazrul University',
      'description': 'University-themed icon',
      'color': const Color(0xFF1976D2),
      'symbol': Icons.school_rounded,
    },
    {
      'id': 'bbc',
      'name': 'B.B. College',
      'description': 'College-themed icon',
      'color': const Color(0xFF00897B),
      'symbol': Icons.account_balance_rounded,
    },
    {
      'id': 'green',
      'name': 'Forest Green',
      'description': 'Green HostelMess icon',
      'color': const Color(0xFF2E7D32),
      'symbol': Icons.eco_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadSelection();
  }

  Future<void> _loadSelection() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _selectedIcon = prefs.getString('selected_app_icon') ?? 'default';
    });
  }

  Future<void> _changeIcon(String icon) async {
    if (_loading || icon == _selectedIcon) return;

    setState(() => _loading = true);

    try {
      final String? alias;

      switch (icon) {
        case 'kazi':
          alias = 'IconKazi';
          break;
        case 'bbc':
          alias = 'IconBBC';
          break;
        case 'green':
          alias = 'IconGreen';
          break;
        default:
          alias = null; // Restore the default icon
      }

      await DynamicAppIconChanger.setAlternateIconName(alias, relaunch: false);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_app_icon', icon);

      if (!mounted) return;
      setState(() => _selectedIcon = icon);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Icon updated! Return to your home screen to view it.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not change icon: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Change App Icon'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.dashboard_customize_rounded,
                  size: 48,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(height: 12),
                Text(
                  'Make it yours',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose how HostelMess appears on your home screen.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'AVAILABLE ICONS',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          ..._icons.map((item) {
            final id = item['id'] as String;
            final color = item['color'] as Color;
            final selected = _selectedIcon == id;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _loading ? null : () => _changeIcon(id),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          item['symbol'] as IconData,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'] as String,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['description'] as String,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (_loading && selected)
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (selected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                        )
                      else
                        const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Text(
            'Icon previews are illustrative. The actual home-screen icons '
            'come from the PNG files bundled with the Android app.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
