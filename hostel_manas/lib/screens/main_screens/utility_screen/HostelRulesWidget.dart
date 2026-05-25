import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Add this to pubspec.yaml

class HostelRulesWidget extends StatelessWidget {
  const HostelRulesWidget({super.key});

  // Helper function to launch URLs/Portfolio
  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Hostel Guide & Rules", 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        
        // 1. Dining Hall Hours & Access
        _buildRuleCard(
          title: "Dining Hall & Access",
          icon: Icons.access_time_filled,
          color: Colors.blue.shade700,
          content: [
            "Morning/Lunch: 9:00 AM to 12:30 PM",
            "Dinner: 9:00 PM to 10:00 PM",
            "Requirement: All students must eat inside the Hall only.",
          ],
        ),
        const SizedBox(height: 12),

        // 2. Payment Rules & Fees
        _buildRuleCard(
          title: "Payment Rules & Fees",
          icon: Icons.payments,
          color: Colors.green.shade700,
          content: [
            "₹1500 Allocation Fee: Monthly fee due within first 5 days.",
            "₹1000 Pro-Rata: Reduced rate for dining only 15 days/month.",
            "Guest Charges: Extra charges apply for guests/friends.",
          ],
        ),
        const SizedBox(height: 12),

        // 3. Discipline & Responsibility
        _buildRuleCard(
          title: "Discipline & Responsibility",
          icon: Icons.gavel_rounded,
          color: Colors.orange.shade800,
          content: [
            "Food Waste: ₹50 fine for wasting food.",
            "Property: Damages result in strictly imposed fines.",
            "Conservation: Wasting water is strictly discouraged.",
          ],
        ),
        const SizedBox(height: 24),

        // 4. Contact for Queries Section
        const Text("Contact for Queries", 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _buildContactItem("Prasenjit Singha Deb", "7909900791"),
              const Divider(),
              _buildContactItem("Ritanu Mondal", "8101744092"),
              const Divider(),
              _buildContactItem("Riju Hosen", "8101928261"),
              const Divider(),
              _buildContactItem("Sujoy", "9564934437"),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // --- NEW: Technical Support Section ---
        const Text("Technical Support", 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple.shade600, Colors.deepPurple.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: Colors.deepPurple.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Need any technical issue support? Contact developer:",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.code, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Nitya Kumar Barman",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          "+91 9064394702",
                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _launchURL("tel:9064394702"),
                    icon: const Icon(Icons.phone_in_talk, color: Colors.white),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 20),
              InkWell(
                onTap: () => _launchURL("http://nityakumar.netlify.app/"),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.language, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      "View Portfolio",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRuleCard({required String title, required IconData icon, required Color color, required List<String> content}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          ...content.map((text) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("• ", style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.black87))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildContactItem(String name, String phone) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(phone, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
          IconButton(
            onPressed: () => launchUrl(Uri.parse("tel:$phone")),
            icon: const Icon(Icons.call, color: Colors.green, size: 20),
          ),
        ],
      ),
    );
  }
}