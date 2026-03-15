import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:HostelMess/services/api_service.dart';
import 'package:HostelMess/services/localServices.dart';
import '../login_screens/login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final api = ApiService();
  final L_S = LocalService();

  Map<String, dynamic>? userData;
  Map<String, int> mealStats = {"total": 0, "consumed": 0};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }

  Future<void> _initializeProfile() async {
    if (mounted) setState(() => loading = true);
    // Force refresh from API to ensure we have the latest photoURL
    await Future.wait([_fetchProfileData(), _fetchStats()]);
    if (mounted) setState(() => loading = false);
  }

  Future<void> _fetchProfileData() async {
    // Pass forceRefresh: true if you updated the fetchProfile logic earlier
    final data = await L_S.fetchProfile(); 
    if (data != null && mounted) {
      setState(() {
        userData = data.containsKey('user') ? data['user'] : data;
      });
    }
  }

  Future<void> _fetchStats() async {
    final stats = await L_S.fetchAndCalculateMealStats();
    if (mounted) {
      setState(() {
        mealStats = stats;
      });
    }
  }

  Future<void> _updateImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 40, // Reduced quality for faster upload
    );

    if (pickedFile != null) {
      setState(() => loading = true);
      try {
        File imageFile = File(pickedFile.path);
        final response = await api.updateProfilePic(imageFile);

        if (response['success']) {
          // IMPORTANT: Explicitly fetch fresh data from API after upload
          await api.getProfile(); 
          await _initializeProfile();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Profile updated!"), backgroundColor: Colors.green),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(response['message'] ?? "Update failed"), backgroundColor: Colors.red),
            );
          }
        }
      } catch (e) {
        debugPrint("Upload Error: $e");
      } finally {
        if (mounted) setState(() => loading = false);
      }
    }
  }

  Future<void> _logout() async {
    await L_S.clearCache();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("My Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        
      ),
      body: RefreshIndicator(
        onRefresh: _initializeProfile,
        color: Colors.deepPurple,
        child: loading && userData == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _buildHeader(),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _sectionTitle("Monthly Statistics"),
                        _packageCard(),
                        const SizedBox(height: 25),
                        _sectionTitle("Personal Information"),
                        _buildInfoSection([
                          _infoTile(Icons.email_outlined, "Email", userData?['email'] ?? 'Not set'),
                          _infoTile(Icons.phone_outlined, "Phone", userData?['phone'] ?? 'Not set'),
                          _infoTile(Icons.school_outlined, "Department", userData?['department'] ?? 'N/A'),
                          _infoTile(Icons.security_outlined, "Role", userData?['role']?.toString().toUpperCase() ?? 'STUDENT'),
                        ]),
                        const SizedBox(height: 30),
                        _logoutButton(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 20, bottom: 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.deepPurple, Colors.purpleAccent],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        children: [
          _buildProfileImage(),
          const SizedBox(height: 15),
          Text(
            userData?['name'] ?? "User",
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text(
            "Reg: ${userData?['regNum'] ?? 'N/A'}",
            style: const TextStyle(color: Colors.white70, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage() {
    String? photoUrl = userData?['photoURL'];

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: CircleAvatar(
            radius: 55,
            backgroundColor: Colors.white,
            // Added key to force refresh when URL changes
            key: ValueKey(photoUrl), 
            backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                ? NetworkImage(photoUrl)
                : null,
            child: (photoUrl == null || photoUrl.isEmpty)
                ? const Icon(Icons.person, size: 60, color: Colors.deepPurple)
                : null,
          ),
        ),
        Positioned(
          bottom: 0,
          right: 4,
          child: GestureDetector(
            onTap: _updateImage,
            child: const CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.deepPurple,
                child: Icon(Icons.camera_alt, size: 14, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _packageCard() {
    int total = mealStats['total'] ?? 0;
    int used = mealStats['consumed'] ?? 0;
    int remaining = total - used;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem("Total", "$total"),
          _statItem("Consumed", "$used"),
          _statItem("Left", "${remaining < 0 ? 0 : remaining}"),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
      ],
    );
  }

  Widget _logoutButton() {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red,
        side: BorderSide(color: Colors.red.shade100),
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      onPressed: _logout,
      icon: const Icon(Icons.logout),
      label: const Text("Logout Session", style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildInfoSection(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(children: children),
    );
  }

  Widget _infoTile(IconData icon, String title, String value) {
    return ListTile(
      leading: Icon(icon, color: Colors.deepPurple, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
    );
  }
}