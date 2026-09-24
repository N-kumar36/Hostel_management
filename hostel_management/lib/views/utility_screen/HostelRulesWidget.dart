import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HostelRulesWidget extends StatelessWidget {
  const HostelRulesWidget({super.key});

  // ============================================================
  // HOSTELMESS THEME
  // ============================================================

  static const Color primary = Color(0xFF5146E5);
  static const Color primaryDark = Color(0xFF3B32A0);

  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);
  static const Color blue = Color(0xFF2563EB);

  Color _background(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  Color _surface(BuildContext context) => Theme.of(context).colorScheme.surface;

  Color _textPrimary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  Color _textSecondary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  Color _divider(BuildContext context) => Theme.of(context).dividerColor;

  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  Color _border(BuildContext context) {
    return _isDark(context) ? const Color(0xFF2C303A) : const Color(0xFFE5E7EB);
  }

  Color _softPrimary(BuildContext context) {
    return _isDark(context) ? const Color(0xFF25234A) : const Color(0xFFEEEDFF);
  }

  Color _softBlue(BuildContext context) {
    return _isDark(context) ? const Color(0xFF17243D) : const Color(0xFFEFF6FF);
  }

  Color _softGreen(BuildContext context) {
    return _isDark(context) ? const Color(0xFF163126) : const Color(0xFFECFDF5);
  }

  Color _softOrange(BuildContext context) {
    return _isDark(context) ? const Color(0xFF382819) : const Color(0xFFFFF7ED);
  }

  Color _softRed(BuildContext context) {
    return _isDark(context) ? const Color(0xFF351D24) : const Color(0xFFFFF1F2);
  }

  List<BoxShadow> _cardShadow(BuildContext context) {
    return [
      BoxShadow(
        color: _isDark(context)
            ? Colors.black.withOpacity(0.24)
            : Colors.black.withOpacity(0.045),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ];
  }

  // ============================================================
  // URL LAUNCHER
  // ============================================================

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);

    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $url');
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final textPrimary = _textPrimary(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ========================================================
        // PAGE HEADER
        // ========================================================
        _buildSectionHeader(
          context,
          icon: Icons.menu_book_rounded,
          title: "Hostel Guide & Rules",
          subtitle: "Important information for hostel residents",
        ),

        const SizedBox(height: 14),

        // ========================================================
        // MESS RULES - STUDENTS
        // ========================================================
        _buildRuleCard(
          context: context,
          title: "Mess Rules • Students",
          subtitle: "Rules every hostel boarder should follow",
          icon: Icons.restaurant_rounded,
          color: blue,
          softColor: _softBlue(context),
          compactDropdown: true,
          content: [
            "Every Hostel Boarder should have to take a meal pack",
            "You have to pay your meal pack amount before starting the meal cycle",
            "For meal upgradation you must have to pay upgradation fee before 31st meal",
            "If anyone caught when taking extra any kind of meal/food (extra chicken, fish, egg) he must have to pay a minimum fine of Rs 500",
            "No students are allowed to use mess gas (except in case of emergency) or pay a fine of the price of whole cylinder.",
            "Guest meals should not be more than 2 meals. If exceeds then you must have to pay the full meal pack.",
            "Who will do cash payment there should be must present 2 or more witnesses.",
          ],
        ),

        const SizedBox(height: 12),

        // ========================================================
        // MESS RULES - MANAGERS
        // ========================================================
        _buildRuleCard(
          context: context,
          title: "Mess Rules • Managers",
          subtitle: "Responsibilities and operating guidelines",
          icon: Icons.admin_panel_settings_rounded,
          color: primary,
          softColor: _softPrimary(context),
          compactDropdown: true,
          content: [
            "Every manager should contribute equally (No carelessness will be entertained), No seniority will be tolerated.",
            "Manager should have to upload all the bills daily. (must be verified by seniors)",
            "You must have to give a valid reason to off a meal.",
            "To proceed a temporary meal cycle there should not be more than 15 students and the cycle should not exceed more than 10 days.",
            "If any Senior caught you doing unwanted expenditure, you will have to face certain action.",
            "Raw Vegetables should not brought in bulk. The vegetables must be fresh.",
            "The masala will brought should be good quality and from mills.",
            "The quality and Quantity of Jhatka and Halal both Chickens should be same. 150gm/Student.",
            "The stomach and livers will be excluded from Chicken. If you caught then you have to answer for it.",
            "The quantity of Fish must be 100gm/student.",
            "The Routine must be followed.",
          ],
        ),

        const SizedBox(height: 12),

        // ========================================================
        // DINING HALL
        // ========================================================
        _buildRuleCard(
          context: context,
          title: "Dining Hall & Access",
          subtitle: "Meal timings and dining requirements",
          icon: Icons.access_time_filled_rounded,
          color: success,
          softColor: _softGreen(context),
          content: [
            "Morning/Lunch: 9:00 AM to 12:30 PM",
            "Dinner: 9:00 PM to 10:00 PM",
            "Requirement: All students must eat inside the Hall only.",
          ],
        ),

        const SizedBox(height: 24),

        // ========================================================
        // PAYMENT
        // ========================================================
        _buildSectionHeader(
          context,
          icon: Icons.account_balance_wallet_rounded,
          title: "Payments & Fees",
          subtitle: "Important financial information",
        ),

        const SizedBox(height: 14),

        _buildRuleCard(
          context: context,
          title: "Payment Rules & Fees",
          subtitle: "Meal allocation and guest charges",
          icon: Icons.payments_rounded,
          color: success,
          softColor: _softGreen(context),
          content: [
            "₹1500 Allocation Fee: Monthly fee due within first 5 days.",
            "₹1000 Pro-Rata: Reduced rate for dining only 15 days/month.",
            "Guest Charges: Extra charges apply for guests/friends.",
          ],
        ),

        const SizedBox(height: 24),

        // ========================================================
        // DISCIPLINE
        // ========================================================
        _buildSectionHeader(
          context,
          icon: Icons.gavel_rounded,
          title: "Discipline & Responsibility",
          subtitle: "Maintain cleanliness and hostel property",
        ),

        const SizedBox(height: 14),

        _buildRuleCard(
          context: context,
          title: "Discipline & Responsibility",
          subtitle: "Everyone is responsible for maintaining the mess",
          icon: Icons.gavel_rounded,
          color: warning,
          softColor: _softOrange(context),
          content: [
            "Food Waste: ₹50 fine for wasting food.",
            "Property: Damages result in strictly imposed fines.",
            "Conservation: Wasting water is strictly discouraged.",
          ],
        ),

        const SizedBox(height: 26),

        // ========================================================
        // CONTACT
        // ========================================================
        _buildSectionHeader(
          context,
          icon: Icons.support_agent_rounded,
          title: "Contact for Queries",
          subtitle: "Contact the mess representatives for assistance",
        ),

        const SizedBox(height: 14),

        _buildContactCard(
          context,
          children: [
            _buildContactItem(
              context,
              name: "Prasenjit Singha Deb",
              phone: "7909900791",
              avatarColor: blue,
            ),
            Divider(color: _divider(context), height: 22),
            _buildContactItem(
              context,
              name: "Riju Hosen",
              phone: "8101928261",
              avatarColor: primary,
            ),
          ],
        ),

        const SizedBox(height: 26),

        // ========================================================
        // TECHNICAL SUPPORT
        // ========================================================
        _buildSectionHeader(
          context,
          icon: Icons.build_circle_rounded,
          title: "Technical Support",
          subtitle: "Need help with the HostelMess application?",
        ),

        const SizedBox(height: 14),

        _buildTechnicalSupport(context),

        const SizedBox(height: 20),

        // Bottom spacing
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Center(
            child: Text(
              "HostelMess • Making hostel management simple",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textPrimary.withOpacity(0.45),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SECTION HEADER
  // ============================================================

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final textPrimary = _textPrimary(context);
    final textSecondary = _textSecondary(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _softPrimary(context),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.info_outline_rounded,
            color: primary,
            size: 21,
          ),
        ),

        const SizedBox(width: 11),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.25,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // RULE CARD
  // ============================================================

  Widget _buildRuleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color softColor,
    required List<String> content,
    bool compactDropdown = false,
  }) {
    final textPrimary = _textPrimary(context);
    final textSecondary = _textSecondary(context);

    if (compactDropdown) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border(context)),
          boxShadow: _cardShadow(context),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: color.withOpacity(0.06),
            highlightColor: color.withOpacity(0.03),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 3,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            iconColor: color,
            collapsedIconColor: textSecondary,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: softColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            title: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            children: [
              Container(height: 1, color: _divider(context).withOpacity(0.65)),
              const SizedBox(height: 11),

              ...List.generate(content.length, (index) {
                final text = content[index];

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == content.length - 1 ? 0 : 8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 5),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          text,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 11.5,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      );
    }

    // Normal rule card for all other sections
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 14),
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border(context)),
        boxShadow: _cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: softColor,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 21),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.1,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Container(height: 1, color: _divider(context).withOpacity(0.65)),

          const SizedBox(height: 12),

          ...List.generate(content.length, (index) {
            final text = content[index];

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == content.length - 1 ? 0 : 9,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),

                  const SizedBox(width: 9),

                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 12.5,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ============================================================
  // CONTACT CARD
  // ============================================================

  Widget _buildContactCard(
    BuildContext context, {
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 9, 15, 9),
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border(context)),
        boxShadow: _cardShadow(context),
      ),
      child: Column(children: children),
    );
  }

  // ============================================================
  // CONTACT ITEM
  // ============================================================

  Widget _buildContactItem(
    BuildContext context, {
    required String name,
    required String phone,
    required Color avatarColor,
  }) {
    final textPrimary = _textPrimary(context);
    final textSecondary = _textSecondary(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: _isDark(context)
                  ? avatarColor.withOpacity(0.17)
                  : avatarColor.withOpacity(0.09),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.person_rounded, color: avatarColor, size: 21),
          ),

          const SizedBox(width: 11),

          // Name / Phone
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.phone_outlined, size: 13, color: textSecondary),
                    const SizedBox(width: 5),
                    Text(
                      phone,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Call Button
          Material(
            color: _softGreen(context),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => launchUrl(Uri.parse("tel:$phone")),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: success.withOpacity(_isDark(context) ? 0.25 : 0.12),
                  ),
                ),
                child: const Icon(Icons.call_rounded, color: success, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TECHNICAL SUPPORT
  // ============================================================

  Widget _buildTechnicalSupport(BuildContext context) {
    final bool dark = _isDark(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, primaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(dark ? 0.30 : 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ------------------------------------------------------
          // SUPPORT HEADER
          // ------------------------------------------------------
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: const Icon(
                  Icons.code_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Technical Support",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "HostelMess application support",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.70),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          // ------------------------------------------------------
          // DESCRIPTION
          // ------------------------------------------------------
          Text(
            "Need any technical issue support? Contact developer:",
            style: TextStyle(
              color: Colors.white.withOpacity(0.78),
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 12),

          // ------------------------------------------------------
          // DEVELOPER
          // ------------------------------------------------------
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.09),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.13),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ),

                const SizedBox(width: 11),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Nitya Kumar Barman",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "+91 9064394702",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.78),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                Material(
                  color: Colors.white.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(11),
                  child: InkWell(
                    onTap: () => _launchURL("tel:9064394702"),
                    borderRadius: BorderRadius.circular(11),
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.phone_in_talk_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 13),

          // ------------------------------------------------------
          // PORTFOLIO
          // ------------------------------------------------------
          Material(
            color: Colors.white.withOpacity(0.09),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _launchURL("https://nityakumar.web.app/"),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.language_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "View Portfolio",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(
                      Icons.open_in_new_rounded,
                      color: Colors.white.withOpacity(0.70),
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
