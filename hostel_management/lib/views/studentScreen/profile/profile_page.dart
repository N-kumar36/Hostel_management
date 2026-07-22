import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:HostelMess/services/api_service.dart';
import 'package:HostelMess/services/localServices.dart';
import '../../auth/login/login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final api = ApiService();
  final L_S = LocalService();

  Map<String, dynamic>? userData;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }

  Future<void> _initializeProfile() async {
    if (mounted) setState(() => loading = true);
    await Future.wait([_fetchProfileData()]);
    if (mounted) setState(() => loading = false);
  }

  Future<void> _fetchProfileData() async {
    final data = await L_S.fetchProfile();
    if (data != null && mounted) {
      setState(() {
        userData = data.containsKey('user') ? data['user'] : data;
        print("Profile Data Loaded: $userData");
      });
    }
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              maxScale: 4.0,
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 40,
    );

    if (pickedFile != null) {
      setState(() => loading = true);
      try {
        File imageFile = File(pickedFile.path);
        final response = await api.updateProfilePic(imageFile);

        if (response['success']) {
          await api.getProfile();
          await _initializeProfile();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text("Profile picture updated successfully!"),
                  ],
                ),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.green.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint("Error updating image: $e");
      } finally {
        if (mounted) setState(() => loading = false);
      }
    }
  }

  void _showEditProfileBottomSheet() {
    final TextEditingController nameController = TextEditingController(
      text: userData?['name'] ?? "",
    );
    final TextEditingController phoneController = TextEditingController(
      text: userData?['phone'] ?? "",
    );
    final TextEditingController deptController = TextEditingController(
      text: userData?['department'] ?? "",
    );
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Update Account Info",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      IconButton(
                        icon: CircleAvatar(
                          backgroundColor: Colors.grey.shade100,
                          child: Icon(
                            Icons.close,
                            color: Colors.grey.shade700,
                            size: 20,
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: "Full Name",
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? "Name cannot be empty"
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: "Phone Number",
                      prefixIcon: const Icon(Icons.phone_outlined),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? "Phone number cannot be empty"
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: deptController,
                    decoration: InputDecoration(
                      labelText: "Department",
                      prefixIcon: const Icon(Icons.school_outlined),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? "Department cannot be empty"
                        : null,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple.shade700,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () async {
                        if (formKey.currentState?.validate() ?? false) {
                          final newName = nameController.text.trim();
                          final newPhone = phoneController.text.trim();
                          final newDept = deptController.text.trim();

                          Navigator.pop(context);
                          setState(() => loading = true);

                          try {
                            final Map<String, dynamic> updatePayload = {
                              "name": newName,
                              "phone": newPhone,
                              "department": newDept,
                            };

                            final response = await api.updateProfile(
                              updatePayload,
                            );
                            if (response['success'] == true) {
                              await api.getProfile();
                              await _initializeProfile();
                            } else {
                              throw Exception("API Error");
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() {
                                if (userData != null) {
                                  userData!['name'] = newName;
                                  userData!['phone'] = newPhone;
                                  userData!['department'] = newDept;
                                }
                              });
                            }
                          } finally {
                            if (mounted) setState(() => loading = false);
                          }
                        }
                      },
                      child: const Text(
                        "Save Profile Changes",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Profile Hub",
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.2),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.mode_edit_outline_rounded, size: 22),
            onPressed: _showEditProfileBottomSheet,
            tooltip: "Edit Settings",
          ),
          const SizedBox(width: 8),
        ],
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
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle("Account Verification"),
                        const SizedBox(height: 10),
                        _buildStatusRow(),
                        const SizedBox(height: 28),
                        _sectionTitle("Personal Credentials"),
                        const SizedBox(height: 10),
                        _buildInfoSection([
                          _infoTile(
                            Icons.person_outline_rounded,
                            "Legal Identity Name",
                            userData?['name'] ?? 'Not set',
                          ),
                          _divider(),
                          _infoTile(
                            Icons.email_outlined,
                            "Email Address Address",
                            userData?['email'] ?? 'Not set',
                          ),
                          _divider(),
                          _infoTile(
                            Icons.phone_outlined,
                            "Active Mobile Contact",
                            userData?['phone'] ?? 'Not set',
                          ),
                          _divider(),
                          _infoTile(
                            Icons.school_outlined,
                            "Academic Stream / Dept",
                            userData?['department'] ?? 'N/A',
                          ),
                        ]),
                        const SizedBox(height: 35),
                        _logoutButton(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _divider() =>
      Divider(height: 1, thickness: 1, color: Colors.grey.shade100, indent: 60);

  Widget _buildStatusRow() {
    String role = userData?['role']?.toString().toUpperCase() ?? 'STUDENT';
    String status = userData?['status']?.toString().toUpperCase() ?? 'PENDING';

    bool isApproved = status == 'APPROVE';
    bool isAdmin = role == 'ADMIN';

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: isAdmin ? Colors.deepPurple.shade50 : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isAdmin
                    ? Colors.deepPurple.shade100
                    : Colors.blue.shade100,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isAdmin ? Icons.shield_rounded : Icons.assignment_ind_rounded,
                  color: isAdmin ? Colors.deepPurple : Colors.blue.shade700,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "ROLE ASSIGNMENT",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      role,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isAdmin
                            ? Colors.deepPurple.shade900
                            : Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: isApproved ? Colors.green.shade50 : Colors.amber.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isApproved
                    ? Colors.green.shade100
                    : Colors.amber.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isApproved ? Icons.verified_rounded : Icons.pending_rounded,
                  color: isApproved
                      ? Colors.green.shade700
                      : Colors.amber.shade800,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "GATE STATUS",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isApproved ? "APPROVED" : status,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isApproved
                            ? Colors.green.shade900
                            : Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileImage() {
    String? photoUrl = userData?['photoURL'];

    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            if (photoUrl != null && photoUrl.isNotEmpty) {
              _showFullScreenImage(photoUrl);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: CircleAvatar(
              radius: 52,
              backgroundColor: Colors.grey.shade100,
              key: ValueKey(photoUrl),
              backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                  ? NetworkImage(photoUrl)
                  : null,
              child: (photoUrl == null || photoUrl.isEmpty)
                  ? Icon(
                      Icons.person_rounded,
                      size: 55,
                      color: Colors.deepPurple.shade300,
                    )
                  : null,
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 4,
          child: GestureDetector(
            onTap: _updateImage,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.deepPurple.shade600,
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade900],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildProfileImage(),
          const SizedBox(height: 16),
          Text(
            userData?['name'] ?? "User Node",
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              "Reg: ${userData?['regNum'] ?? 'N/A'}  •  ${userData?['year'] ?? 'N/A'}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Divider(
            color: Colors.white.withOpacity(0.1),
            thickness: 1,
            indent: 40,
            endIndent: 40,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _headerSubTile(
                Icons.home_work_rounded,
                "HOSTEL",
                userData?['hostelName'] ?? 'N/A',
              ),
              Container(
                width: 1,
                height: 24,
                color: Colors.white.withOpacity(0.15),
              ),
              _headerSubTile(
                Icons.door_sliding_rounded,
                "ROOM NO",
                userData?['roomNumber'] ?? 'Not Set',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerSubTile(IconData icon, String label, String value) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 15),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _logoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red.shade700,
          side: BorderSide(color: Colors.red.shade200, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.red.shade50.withOpacity(0.2),
        ),
        onPressed: () {
          showDialog(
            context: context,
            builder: (c) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                "Logout Session?",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: const Text(
                "Are you sure you want to terminate your active dashboard login session?",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: Text(
                    "CANCEL",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(c);
                    _logout();
                  },
                  child: const Text(
                    "LOGOUT",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        icon: const Icon(Icons.power_settings_new_rounded, size: 20),
        label: const Text(
          "Logout from Application",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
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

  Widget _sectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Colors.grey.shade500,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildInfoSection(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _infoTile(IconData icon, String title, String value) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.deepPurple.shade50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: Colors.deepPurple.shade600, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey.shade400,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
      ),
    );
  }
}
