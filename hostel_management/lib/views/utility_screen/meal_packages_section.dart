import 'package:flutter/material.dart';
import 'package:HostelMess/services/api_service.dart';

class MealPackagesSection extends StatefulWidget {
  final VoidCallback? onActionSuccess;

  const MealPackagesSection({super.key, this.onActionSuccess});

  @override
  State<MealPackagesSection> createState() => _MealPackagesSectionState();
}

class _MealPackagesSectionState extends State<MealPackagesSection> {
  final api = ApiService();

  List<dynamic> availablePackages = [];

  bool isSectionLoading = true;
  bool isProcessing = false;

  // ===========================================================================
  // CYCLE MANAGEMENT STATE
  // ===========================================================================

  bool hasCurrentActiveCycle = false;
  String? activeCycleLabel;

  // ===========================================================================
  // THEME HELPERS
  // ===========================================================================

  Color get _surface => Theme.of(context).colorScheme.surface;

  Color get _textPrimary => Theme.of(context).colorScheme.onSurface;

  Color get _textSecondary => Theme.of(context).colorScheme.onSurfaceVariant;

  Color get _primary => Theme.of(context).colorScheme.primary;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _borderColor =>
      _isDark ? const Color(0xFF2C303A) : const Color(0xFFE2E3E8);

  Color get _disabledSurface =>
      _isDark ? const Color(0xFF242831) : const Color(0xFFF3F4F6);

  Color get _disabledText => _isDark ? const Color(0xFF777D89) : Colors.grey;

  Color get _dialogSurface => Theme.of(context).dialogBackgroundColor;

  // ===========================================================================
  // INIT
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    _loadSectionDataAutonomous();
  }

  // ===========================================================================
  // DATE PARSER
  // ===========================================================================

  /// Parses date string in format "DD/MM/YYYY"
  /// safely to a DateTime object.
  DateTime? _parseCycleDate(String dateStr) {
    try {
      final parts = dateStr.split('/');

      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);

        return DateTime(year, month, day);
      }
    } catch (e) {
      debugPrint("Error parsing date: $e");
    }

    return null;
  }

  // ===========================================================================
  // LOAD SECTION DATA
  // ===========================================================================

  Future<void> _loadSectionDataAutonomous() async {
    if (!mounted) return;

    setState(() {
      isSectionLoading = true;
    });

    try {
      // Parallel API operations.
      final results = await Future.wait([
        api.getmealPackages(),
        api.getMealCycleDateBounds(),
      ]);

      final Map<String, dynamic> packageResponse =
          results[0] as Map<String, dynamic>;

      final Map<String, dynamic> cycleResponse =
          results[1] as Map<String, dynamic>;

      bool activeCycleFound = false;
      String? cycleLabel;

      // -----------------------------------------------------------------------
      // CHECK CURRENT ACTIVE CYCLE
      // -----------------------------------------------------------------------

      if (cycleResponse['success'] == true && cycleResponse['cycles'] != null) {
        final List<dynamic> cycleList = cycleResponse['cycles'];

        final activeCycle = cycleList.firstWhere(
          (cycle) => cycle['isCurrentActive'] == true,
          orElse: () => null,
        );

        if (activeCycle != null) {
          final String? startStr = activeCycle['startDateStr']?.toString();

          final String? endStr = activeCycle['endDateStr']?.toString();

          if (startStr != null && endStr != null) {
            final startDate = _parseCycleDate(startStr);

            final endDate = _parseCycleDate(endStr);

            if (startDate != null && endDate != null) {
              final now = DateTime.now();

              final today = DateTime(now.year, now.month, now.day);

              // Strict check:
              // today must fall within
              // [startDate, endDate].
              if ((today.isAfter(startDate) ||
                      today.isAtSameMomentAs(startDate)) &&
                  (today.isBefore(endDate) ||
                      today.isAtSameMomentAs(endDate))) {
                activeCycleFound = true;

                cycleLabel = activeCycle['label']?.toString();
              } else {
                debugPrint(
                  "A cycle is active, but today's "
                  "date ($today) falls outside "
                  "of boundaries: "
                  "$startDate to $endDate",
                );
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          availablePackages = packageResponse['data'] ?? [];

          hasCurrentActiveCycle = activeCycleFound;

          activeCycleLabel = cycleLabel;

          isSectionLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Autonomous Section Loading Error: $e");

      if (mounted) {
        setState(() {
          isSectionLoading = false;
        });
      }
    }
  }

  // ===========================================================================
  // NETWORK OPERATION
  // ===========================================================================

  void _executeNetworkOperation(String packageId) async {
    if (mounted) {
      setState(() {
        isProcessing = true;
      });
    }

    try {
      final result = await api.selectPackage(packageId);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? "Package updated successfully!",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
        );

        // Refresh package collection.
        await _loadSectionDataAutonomous();

        // Notify parent.
        if (widget.onActionSuccess != null) {
          widget.onActionSuccess!();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceAll("Exception: ", ""),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    if (isSectionLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }

    // Check if any package is active.
    final bool hasActiveSubscription = availablePackages.any(
      (pkg) => pkg['isActivePlan'] == true,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // =====================================================================
        // CYCLE WARNING
        // =====================================================================
        if (!hasCurrentActiveCycle) ...[
          _buildCycleWarning(),

          const SizedBox(height: 0),
        ],

        // =====================================================================
        // SECTION TITLE
        // =====================================================================
        Text(
          !hasActiveSubscription
              ? "SELECT MEAL PACKAGE"
              : "AVAILABLE SUBSCRIPTION TIERS",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: _textSecondary,
            letterSpacing: 0.3,
          ),
        ),

        const SizedBox(height: 12),

        // =====================================================================
        // PROCESSING
        // =====================================================================
        if (isProcessing)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          )
        else
          ...availablePackages.map((pkg) {
            final String pkgId = pkg['_id'].toString();

            final String pkgTitle = pkg['planType'] ?? "";

            final int displayPrice = (pkg['monthlyPrice'] ?? 0).toInt();

            final bool isActive = pkg['isActivePlan'] ?? false;

            final bool isUpgradeOption = pkg['isUpgradeOption'] ?? false;

            final bool isDowngradeOption = pkg['isDowngradeOption'] ?? false;

            return _buildOptionCard(
              id: pkgId,
              title: pkgTitle,
              price: displayPrice,
              isActive: isActive,
              isUpgrade: isUpgradeOption,
              isDowngrade: isDowngradeOption,
            );
          }),
      ],
    );
  }

  // ===========================================================================
  // CYCLE WARNING
  // ===========================================================================

  Widget _buildCycleWarning() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF351C20) : Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDark ? const Color(0xFF673038) : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: _isDark ? const Color(0xFFFF7777) : Colors.red.shade700,
            size: 24,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Now No Current Meal",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isDark
                        ? const Color(0xFFFF8A8A)
                        : Colors.red.shade900,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  "An active meal cycle is not "
                  "running currently. Please wait "
                  "for the manager to initialize "
                  "the active cycle.",
                  style: TextStyle(
                    color: _isDark
                        ? const Color(0xFFFFA5A5)
                        : Colors.red.shade700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PACKAGE OPTION CARD
  // ===========================================================================

  Widget _buildOptionCard({
    required String id,
    required String title,
    required int price,
    required bool isActive,
    required bool isUpgrade,
    required bool isDowngrade,
  }) {
    Color cardBorderColor = _borderColor;

    Color titleColor = _textPrimary;

    Widget actionBadge = const SizedBox.shrink();

    // -------------------------------------------------------------------------
    // ACTIVE
    // -------------------------------------------------------------------------

    if (isActive) {
      cardBorderColor = Colors.green;

      titleColor = Colors.green.shade700;

      actionBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _isDark
              ? Colors.green.withOpacity(0.14)
              : Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          "ACTIVE PLAN",
          style: TextStyle(
            color: Colors.green,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    // -------------------------------------------------------------------------
    // UPGRADE
    // -------------------------------------------------------------------------
    else if (isUpgrade) {
      cardBorderColor = Colors.orange.shade300;

      actionBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _isDark
              ? Colors.orange.withOpacity(0.14)
              : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          "UPGRADE TIER",
          style: TextStyle(
            color: Colors.orange,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    // -------------------------------------------------------------------------
    // DOWNGRADE
    // -------------------------------------------------------------------------
    else if (isDowngrade) {
      cardBorderColor = _isDark
          ? const Color(0xFF30343D)
          : Colors.grey.shade100;

      titleColor = _disabledText;
    }

    // -------------------------------------------------------------------------
    // DISABLED
    // -------------------------------------------------------------------------

    final bool isCardDisabled = isDowngrade || !hasCurrentActiveCycle;

    final Color actualTitleColor = isCardDisabled && !isActive
        ? _disabledText
        : titleColor;

    final Color actualPriceColor = isCardDisabled
        ? _disabledText
        : (isActive ? Colors.green : _primary);

    return GestureDetector(
      onTap: (isProcessing || isActive || isCardDisabled)
          ? null
          : () {
              if (isUpgrade) {
                _showUpgradeConfirmDialog(id, title, price);
              } else {
                _showConfirmPlanDialog(id, title, price);
              }
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCardDisabled ? _disabledSurface : _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorderColor, width: isActive ? 2 : 1),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.green.withOpacity(_isDark ? 0.16 : 0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: actualTitleColor,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      actionBadge,
                    ],
                  ),

                  const SizedBox(height: 4),

                  Text(
                    isActive
                        ? "Your current active subscription"
                        : "Monthly Subscriptions Pack",
                    style: TextStyle(
                      color: isCardDisabled ? _disabledText : _textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            Text(
              "₹$price",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: actualPriceColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // CONFIRM PLAN DIALOG
  // ===========================================================================

  void _showConfirmPlanDialog(String id, String title, int price) {
    showDialog(
      context: context,
      builder: (BuildContext dialogCtx) => AlertDialog(
        backgroundColor: _dialogSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Confirm Selection",
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w800),
        ),
        content: Text(
          "Do you want to subscribe "
          "to the $title plan for ₹$price?",
          style: TextStyle(color: _textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              "CANCEL",
              style: TextStyle(
                color: _textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);

              _executeNetworkOperation(id);
            },
            child: const Text(
              "CONFIRM",
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // UPGRADE CONFIRMATION DIALOG
  // ===========================================================================

  void _showUpgradeConfirmDialog(String id, String title, int cost) {
    showDialog(
      context: context,
      builder: (BuildContext dialogCtx) => AlertDialog(
        backgroundColor: _dialogSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.unfold_more_rounded, color: Colors.orange),

            const SizedBox(width: 10),

            Expanded(
              child: Text(
                "Confirm Upgrade",
                style: TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want "
          "to upgrade to $title?\n\n"
          "An additional upgrade charge "
          "of ₹$cost will be applied to "
          "your account.",
          style: TextStyle(fontSize: 15, height: 1.4, color: _textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              "NOT NOW",
              style: TextStyle(
                color: _textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);

              _executeNetworkOperation(id);
            },
            child: const Text(
              "CONFIRM & PAY",
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
