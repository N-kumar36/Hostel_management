import 'package:flutter/material.dart';
import 'package:HostelMess/services/api_service.dart';

class MealPackagesSection extends StatefulWidget {
  final VoidCallback? onActionSuccess;

  const MealPackagesSection({
    super.key, 
    this.onActionSuccess,
  });

  @override
  State<MealPackagesSection> createState() => _MealPackagesSectionState();
}

class _MealPackagesSectionState extends State<MealPackagesSection> {
  final api = ApiService();
  
  List<dynamic> availablePackages = [];
  bool isSectionLoading = true;
  bool isProcessing = false;

  // 🌟 Cycle Management State Trackers
  bool hasCurrentActiveCycle = false;
  String? activeCycleLabel;

  @override
  void initState() {
    super.initState();
    _loadSectionDataAutonomous();
  }

  /// Parses date string in format "DD/MM/YYYY" safely to a DateTime object
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

  /// Fetches package info and verifies current active cycle limits in parallel
  Future<void> _loadSectionDataAutonomous() async {
    if (!mounted) return;
    setState(() => isSectionLoading = true);

    try {
      // 🌟 Parallel API operations to fetch meal packages and dynamic cycle bounds
      final results = await Future.wait([
        api.getmealPackages(),
        api.getMealCycleDateBounds(),
      ]);

      final Map<String, dynamic> packageResponse = results[0] as Map<String, dynamic>;
      final Map<String, dynamic> cycleResponse = results[1] as Map<String, dynamic>;

      bool activeCycleFound = false;
      String? cycleLabel;

      // Parse cycle list safely to check for active state blocks and date ranges
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
              // Strip hours/minutes to get clean date-only boundaries
              final today = DateTime(now.year, now.month, now.day);

              // 🌟 Strict check: Allow operations ONLY if today falls within [startDate, endDate] inclusive
              if ((today.isAfter(startDate) || today.isAtSameMomentAs(startDate)) &&
                  (today.isBefore(endDate) || today.isAtSameMomentAs(endDate))) {
                activeCycleFound = true;
                cycleLabel = activeCycle['label']?.toString();
              } else {
                debugPrint("A cycle is active, but today's date ($today) falls outside of boundaries: $startDate to $endDate");
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
      if (mounted) setState(() => isSectionLoading = false);
    }
  }

  void _executeNetworkOperation(String packageId) async {
    setState(() => isProcessing = true);
    try {
      final result = await api.selectPackage(packageId); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? "Package updated successfully!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // 1. Refresh its own card collection array definitions natively
        await _loadSectionDataAutonomous();
        
        // 2. Notify parent container metrics sheets to force progress chart updates
        if (widget.onActionSuccess != null) {
          widget.onActionSuccess!();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll("Exception: ", "")),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isSectionLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
      );
    }

    // Safely check if ANY package in the list returned from backend is marked active
    final bool hasActiveSubscription = availablePackages.any((pkg) => pkg['isActivePlan'] == true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🌟 Cycle Warning Section: Shows beautiful warning banner if no current active cycle exists
        if (!hasCurrentActiveCycle) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Now No Current Meal",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "An active meal cycle is not running currently. Please wait for the manager to initialize the active cycle.",
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        Text(
          !hasActiveSubscription ? "SELECT MEAL PACKAGE" : "AVAILABLE SUBSCRIPTION TIERS",
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        if (isProcessing)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
          )
        else
          ...availablePackages.map((pkg) {
            final String pkgId = pkg['_id'].toString();
            final String pkgTitle = pkg['planType'] ?? "";
            
            // Map straight to backend layout definitions schema matrices
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

  Widget _buildOptionCard({
    required String id,
    required String title,
    required int price,
    required bool isActive,
    required bool isUpgrade,
    required bool isDowngrade,
  }) {
    Color cardBorderColor = Colors.grey.shade300;
    Color titleColor = Colors.black87;
    Widget actionBadge = const SizedBox.shrink();

    if (isActive) {
      cardBorderColor = Colors.green;
      titleColor = Colors.green.shade700;
      actionBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
        child: const Text("ACTIVE PLAN", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
      );
    } else if (isUpgrade) {
      cardBorderColor = Colors.orange.shade300;
      actionBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
        child: const Text("UPGRADE TIER", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
      );
    } else if (isDowngrade) {
      cardBorderColor = Colors.grey.shade100;
      titleColor = Colors.grey;
    }

    // 🌟 Check if interactions should be disabled because there is no active cycle
    final bool isCardDisabled = isDowngrade || !hasCurrentActiveCycle;

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
          color: isCardDisabled ? Colors.grey[100]!.withOpacity(0.5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorderColor, width: isActive ? 2 : 1),
          boxShadow: isActive ? [BoxShadow(color: Colors.green.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))] : [],
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
                      Text(
                        title, 
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 16, 
                          color: isCardDisabled && !isActive ? Colors.grey : titleColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      actionBadge,
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isActive ? "Your current active subscription" : "Monthly Subscriptions Pack",
                    style: TextStyle(color: isCardDisabled ? Colors.grey : Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              "₹$price",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isCardDisabled ? Colors.grey : (isActive ? Colors.green : Colors.deepPurple),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmPlanDialog(String id, String title, int price) {
    showDialog(
      context: context,
      builder: (BuildContext dialogCtx) => AlertDialog( 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Confirm Selection"),
        content: Text("Do you want to subscribe to the $title plan for ₹$price?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              _executeNetworkOperation(id);
            },
            child: const Text("CONFIRM"),
          ),
        ],
      ),
    );
  }

  void _showUpgradeConfirmDialog(String id, String title, int cost) {
    showDialog(
      context: context,
      builder: (BuildContext dialogCtx) => AlertDialog( 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.unfold_more, color: Colors.orange),
            SizedBox(width: 10),
            Text("Confirm Upgrade"),
          ],
        ),
        content: Text(
          "Are you sure you want to upgrade to $title?\n\nAn additional upgrade charge of ₹$cost will be applied to your account.",
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("NOT NOW", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              _executeNetworkOperation(id);
            },
            child: const Text("CONFIRM & PAY"),
          ),
        ],
      ),
    );
  }
}