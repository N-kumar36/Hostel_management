import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:HostelMess/services/api_service.dart';
import 'package:HostelMess/services/localServices.dart';
import '../../auth/login/login_page.dart';
import 'package:HostelMess/core/theme/theme_controller.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ApiService api = ApiService();
  final LocalService localService = LocalService();

  // ============================================================
  // HOSTELMESS COLOR SYSTEM
  // ============================================================

  static const Color primary = Color(0xFF5146E5);
  static const Color primaryDark = Color(0xFF4638D6);
  static const Color primarySoft = Color(0xFFEEEEFF);

  static const Color background = Color(0xFFF7F7FC);
  static const Color textPrimary = Color(0xFF181B2E);
  static const Color textSecondary = Color(0xFF74788B);
  static const Color border = Color(0xFFE7E7EF);

  static const Color blue = Color(0xFF3867FF);
  static const Color green = Color(0xFF18A957);
  static const Color orange = Color(0xFFFFA726);
  static const Color red = Color(0xFFFF5252);
  static const Color teal = Color(0xFF10A6A0);

  // ============================================================
  // STATE
  // ============================================================

  Map<String, dynamic>? userData;

  bool loading = true;
  bool uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }

  // ============================================================
  // THEME
  // ============================================================

  Future<void> _toggleTheme() async {
    final controller = ThemeController.instance;

    if (controller.mode == AppThemeMode.dark) {
      await controller.setTheme(AppThemeMode.light);
    } else {
      await controller.setTheme(AppThemeMode.dark);
    }
  }

  // ============================================================
  // PROFILE LOADING
  // IMPORTANT:
  // Keeping the same working profile-photo flow from old version.
  // ============================================================

  Future<void> _initializeProfile() async {
    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    await Future.wait([_fetchProfileData()]);

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _fetchProfileData() async {
    try {
      final data = await localService.fetchProfile();

      if (data != null && mounted) {
        setState(() {
          userData = data.containsKey('user')
              ? Map<String, dynamic>.from(data['user'])
              : Map<String, dynamic>.from(data);
        });

        debugPrint('Profile Data Loaded: $userData');
      }
    } catch (e) {
      debugPrint('Profile loading error: $e');
    }
  }

  // ============================================================
  // PROFILE PHOTO
  // SAME WORKING APPROACH AS OLD VERSION
  // ============================================================

  String? _getPhotoUrl() {
    final value = userData?['photoURL'];

    if (value == null) {
      return null;
    }

    final url = value.toString().trim();

    if (url.isEmpty || url == 'null') {
      return null;
    }

    return url;
  }

  // ============================================================
  // UPDATE PROFILE PHOTO
  // SAME FLOW AS OLD WORKING VERSION
  // ============================================================

  Future<void> _updateImage() async {
    if (uploadingPhoto) return;

    final picker = ImagePicker();

    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 40,
    );

    if (pickedFile == null) {
      return;
    }

    if (mounted) {
      setState(() {
        loading = true;
        uploadingPhoto = true;
      });
    }

    try {
      final File imageFile = File(pickedFile.path);

      final response = await api.updateProfilePic(imageFile);

      debugPrint('Profile photo response: $response');

      if (response['success'] == true) {
        // --------------------------------------------------------
        // KEEP THE ORIGINAL WORKING FLOW
        // --------------------------------------------------------

        await api.getProfile();

        await _initializeProfile();

        if (mounted) {
          _showSnackBar(
            'Profile picture updated successfully!',
            green,
            Icons.check_circle_rounded,
          );
        }
      } else {
        if (mounted) {
          _showSnackBar(
            response['message']?.toString() ??
                'Unable to update profile picture',
            red,
            Icons.error_outline_rounded,
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating image: $e');

      if (mounted) {
        _showSnackBar(
          'Unable to update profile picture',
          red,
          Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          uploadingPhoto = false;
        });
      }
    }
  }

  // ============================================================
  // FULL SCREEN PHOTO
  // ============================================================

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
            title: const Text(
              'Profile Photo',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.7,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white54,
                    size: 64,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EDIT PROFILE
  // ============================================================

  void _showEditProfileBottomSheet() {
    final TextEditingController nameController = TextEditingController(
      text: userData?['name']?.toString() ?? '',
    );

    final TextEditingController phoneController = TextEditingController(
      text: userData?['phone']?.toString() ?? '',
    );

    final TextEditingController deptController = TextEditingController(
      text: userData?['department']?.toString() ?? '',
    );

    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 10,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: SafeArea(
            top: false,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),

                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: primarySoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.edit_rounded, color: primary),
                        ),

                        const SizedBox(width: 12),

                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Edit Profile',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Update your account information',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              color: background,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    _editField(
                      controller: nameController,
                      label: 'Full Name',
                      icon: Icons.person_outline_rounded,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Name cannot be empty';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    _editField(
                      controller: phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Phone number cannot be empty';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    _editField(
                      controller: deptController,
                      label: 'Department',
                      icon: Icons.school_outlined,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Department cannot be empty';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 22),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }

                          final newName = nameController.text.trim();

                          final newPhone = phoneController.text.trim();

                          final newDept = deptController.text.trim();

                          Navigator.pop(sheetContext);

                          if (mounted) {
                            setState(() {
                              loading = true;
                            });
                          }

                          try {
                            final payload = {
                              'name': newName,
                              'phone': newPhone,
                              'department': newDept,
                            };

                            final response = await api.updateProfile(payload);

                            if (response['success'] == true) {
                              // Keep same
                              // working refresh
                              // pattern.

                              await api.getProfile();

                              await _initializeProfile();

                              if (mounted) {
                                _showSnackBar(
                                  'Profile updated successfully',
                                  green,
                                  Icons.check_circle_rounded,
                                );
                              }
                            } else {
                              throw Exception('Profile update failed');
                            }
                          } catch (e) {
                            debugPrint('Profile update error: $e');

                            if (mounted) {
                              _showSnackBar(
                                'Unable to update profile',
                                red,
                                Icons.error_outline_rounded,
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                loading = false;
                              });
                            }
                          }
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save_rounded, size: 19),
                            SizedBox(width: 8),
                            Text(
                              'Save Profile Changes',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _editField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
        prefixIcon: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primarySoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: primary, size: 20),
        ),
        filled: true,
        fillColor: background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: red),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,

        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Profile',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Manage your account',
              style: TextStyle(
                fontSize: 11,
                color: textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),

        actions: [
          // ======================================================
          // THEME TOGGLE
          // ======================================================
          AnimatedBuilder(
            animation: ThemeController.instance,
            builder: (context, _) {
              final bool isDark =
                  ThemeController.instance.mode == AppThemeMode.dark;

              return IconButton(
                tooltip: isDark ? 'Light Mode' : 'Dark Mode',
                onPressed: _toggleTheme,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) {
                    return RotationTransition(
                      turns: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: Container(
                    key: ValueKey(isDark),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.amber.withOpacity(0.12)
                          : primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: isDark ? Colors.amber : primary,
                      size: 19,
                    ),
                  ),
                ),
              );
            },
          ),

          // ======================================================
          // EDIT PROFILE
          // ======================================================
          IconButton(
            tooltip: 'Edit Profile',
            onPressed: _showEditProfileBottomSheet,
            icon: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.edit_rounded, color: primary, size: 19),
            ),
          ),

          // ======================================================
          // LOGOUT
          // ======================================================
          IconButton(
            tooltip: 'Logout',
            onPressed: _confirmLogout,
            icon: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.logout_rounded, color: red, size: 19),
            ),
          ),

          const SizedBox(width: 10),
        ],

        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: border),
        ),
      ),

      body: RefreshIndicator(
        color: primary,
        onRefresh: _initializeProfile,

        child: loading && userData == null
            ? const Center(
                child: CircularProgressIndicator(
                  color: primary,
                  strokeWidth: 3,
                ),
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),

                // Extra scroll space for
                // bottom navigation.
                padding: const EdgeInsets.only(bottom: 160),

                children: [
                  _buildProfileHero(),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('Account Status'),

                        const SizedBox(height: 10),

                        _buildStatusSection(),

                        const SizedBox(height: 24),

                        _sectionTitle('Personal Information'),

                        const SizedBox(height: 10),

                        _buildPersonalInfo(),

                        const SizedBox(height: 24),

                        _sectionTitle('Hostel Information'),

                        const SizedBox(height: 10),

                        _buildHostelInfo(),

                        const SizedBox(height: 24),

                        _sectionTitle('Account Actions'),

                        const SizedBox(height: 10),

                        _buildAccountActions(),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ============================================================
  // PROFILE HERO
  // ============================================================

  Widget _buildProfileHero() {
    final String name = userData?['name']?.toString() ?? 'User';

    final String regNum = userData?['regNum']?.toString() ?? 'N/A';

    final String year = userData?['year']?.toString() ?? 'N/A';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, primaryDark],
        ),
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildProfileImage(),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        const Icon(
                          Icons.badge_outlined,
                          color: Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'Reg. $regNum',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Text(
                      year,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Container(height: 1, color: Colors.white.withOpacity(0.13)),

          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(
                child: _heroInfo(
                  Icons.home_work_outlined,
                  'HOSTEL',
                  userData?['hostelName'] ?? 'N/A',
                ),
              ),

              Container(
                width: 1,
                height: 32,
                color: Colors.white.withOpacity(0.15),
              ),

              Expanded(
                child: _heroInfo(
                  Icons.meeting_room_outlined,
                  'ROOM',
                  userData?['roomNumber'] ?? 'Not Set',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PROFILE IMAGE
  // THIS IS BASED DIRECTLY ON YOUR OLD WORKING VERSION
  // ============================================================

  Widget _buildProfileImage() {
    final String? photoUrl = _getPhotoUrl();

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

              // IMPORTANT:
              // Same key approach from
              // your old working code.
              key: ValueKey(photoUrl),

              backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                  ? NetworkImage(photoUrl)
                  : null,

              child: photoUrl == null || photoUrl.isEmpty
                  ? const Icon(Icons.person_rounded, size: 55, color: primary)
                  : null,
            ),
          ),
        ),

        // CAMERA BUTTON
        Positioned(
          bottom: 0,
          right: 4,
          child: GestureDetector(
            onTap: uploadingPhoto ? null : _updateImage,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: primaryDark,
                  child: uploadingPhoto
                      ? const Padding(
                          padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
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

  Widget _heroInfo(IconData icon, String label, dynamic value) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: Colors.white70),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: Colors.white60,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        Text(
          value.toString(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ACCOUNT STATUS
  // ============================================================

  Widget _buildStatusSection() {
    final String role =
        userData?['role']?.toString().toUpperCase() ?? 'STUDENT';

    final String status =
        userData?['status']?.toString().toUpperCase() ?? 'PENDING';

    final bool isAdmin = role == 'ADMIN';

    final bool isApproved = status == 'APPROVE' || status == 'APPROVED';

    return Row(
      children: [
        Expanded(
          child: _statusCard(
            title: 'ROLE',
            value: role,
            icon: isAdmin
                ? Icons.admin_panel_settings_rounded
                : Icons.school_rounded,
            color: isAdmin ? primary : blue,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _statusCard(
            title: 'ACCOUNT',
            value: isApproved ? 'APPROVED' : status,
            icon: isApproved ? Icons.verified_rounded : Icons.pending_rounded,
            color: isApproved ? green : orange,
          ),
        ),
      ],
    );
  }

  Widget _statusCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.09),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: color),
          ),

          const SizedBox(height: 10),

          Text(
            title,
            style: const TextStyle(
              fontSize: 9,
              color: textSecondary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PERSONAL INFORMATION
  // ============================================================

  Widget _buildPersonalInfo() {
    return _infoCard(
      children: [
        _infoTile(
          Icons.person_outline_rounded,
          'Full Name',
          userData?['name'] ?? 'Not set',
          primary,
        ),

        _divider(),

        _infoTile(
          Icons.email_outlined,
          'Email Address',
          userData?['email'] ?? 'Not set',
          blue,
        ),

        _divider(),

        _infoTile(
          Icons.phone_outlined,
          'Mobile Number',
          userData?['phone'] ?? 'Not set',
          green,
        ),

        _divider(),

        _infoTile(
          Icons.school_outlined,
          'Department',
          userData?['department'] ?? 'N/A',
          orange,
        ),
      ],
    );
  }

  // ============================================================
  // HOSTEL INFORMATION
  // ============================================================

  Widget _buildHostelInfo() {
    return _infoCard(
      children: [
        _infoTile(
          Icons.home_work_outlined,
          'Hostel',
          userData?['hostelName'] ?? 'N/A',
          teal,
        ),

        _divider(),

        _infoTile(
          Icons.meeting_room_outlined,
          'Room Number',
          userData?['roomNumber'] ?? 'Not Set',
          primary,
        ),

        _divider(),

        _infoTile(
          Icons.badge_outlined,
          'Registration Number',
          userData?['regNum'] ?? 'N/A',
          blue,
        ),

        _divider(),

        _infoTile(
          Icons.calendar_today_outlined,
          'Academic Year',
          userData?['year'] ?? 'N/A',
          green,
        ),
      ],
    );
  }

  Widget _infoCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Column(children: children),
    );
  }

  Widget _infoTile(IconData icon, String title, dynamic value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 20, color: color),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    color: textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value.toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Divider(
      height: 1,
      thickness: 1,
      color: border,
      indent: 71,
      endIndent: 16,
    );
  }

  // ============================================================
  // ACCOUNT ACTIONS
  // ============================================================

  Widget _buildAccountActions() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          _actionButton(
            icon: Icons.edit_rounded,
            title: 'Edit Profile',
            subtitle: 'Update your personal information',
            color: primary,
            onTap: _showEditProfileBottomSheet,
          ),

          const SizedBox(height: 8),

          _actionButton(
            icon: Icons.logout_rounded,
            title: 'Logout',
            subtitle: 'Sign out from this account',
            color: red,
            onTap: _confirmLogout,
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 20),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        color: color == red ? red : textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        color: textPrimary,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.2,
      ),
    );
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.logout_rounded, color: red),
              ),

              const SizedBox(width: 12),

              const Text(
                'Logout?',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to logout from your HostelMess account?',
            style: TextStyle(fontSize: 13, height: 1.5, color: textSecondary),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 5, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(dialogContext);

                _logout();
              },
              child: const Text(
                'Logout',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    try {
      await localService.clearCache();
    } catch (e) {
      debugPrint('Clear cache error: $e');
    }

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white,
        elevation: 8,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withOpacity(0.09),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
