import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/localization.dart';
import '../shared/attendance_screen.dart';
import '../shared/signature_pad.dart';

class StudentDashboard extends StatefulWidget {
  final Map<String, dynamic> studentProfile;
  final VoidCallback onLogout;
  final VoidCallback onThemeToggle;
  final Function(Color color) onColorChange;
  final Function(String lang) onLanguageChange;
  final Function(String msg) showToast;
  final bool isDark;
  final Color primaryColor;

  const StudentDashboard({
    super.key,
    required this.studentProfile,
    required this.onLogout,
    required this.onThemeToggle,
    required this.onColorChange,
    required this.onLanguageChange,
    required this.showToast,
    required this.isDark,
    required this.primaryColor,
  });

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final FirebaseService _firebaseService = FirebaseService();
  
  // Navigation stack
  // 'home', 'fees', 'month_detail', 'attendance', 'files'
  List<String> _screenStack = ['home'];

  late Map<String, dynamic> _profile;
  bool _isLoading = false;
  String? _selectedMonth;

  // Files tab state
  String _fileTab = 'teacher'; // 'teacher' or 'own'

  final List<String> _monthsList = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ];

  @override
  void initState() {
    super.initState();
    _profile = Map<String, dynamic>.from(widget.studentProfile);
    _refreshProfile();
  }

  Future<void> _refreshProfile() async {
    setState(() => _isLoading = true);
    try {
      final updated = await _firebaseService.loadStudentDataByUid(_profile['uid']);
      if (updated != null) {
        setState(() {
          _profile = updated;
        });
      }
    } catch (e) {
      widget.showToast("❌ Sync error");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _pushScreen(String screen) {
    setState(() {
      _screenStack.add(screen);
    });
  }

  bool _popScreen() {
    if (_screenStack.length > 1) {
      setState(() {
        _screenStack.removeLast();
      });
      return true;
    }
    return false;
  }

  String get _currentScreen => _screenStack.last;

  String _getScreenTitle() {
    switch (_currentScreen) {
      case 'home':
        return Localization.get('appTitle');
      case 'fees':
        return Localization.get('monthlyFees');
      case 'month_detail':
        return "${_selectedMonth ?? ''} Details";
      case 'files':
        return Localization.get('files');
      default:
        return Localization.get('appTitle');
    }
  }

  // Edit lock checks
  bool _isMonthLocked(Map<String, dynamic>? rec) {
    if (rec == null || rec['firstSaveTime'] == null) return false;
    int due = int.tryParse(rec['due'].toString()) ?? 0;
    int extra = int.tryParse(rec['extraPay'].toString()) ?? 0;
    if (extra > 0) return false;
    if (due > 0) return false;
    if (rec['dueClearTime'] != null) {
      return (DateTime.now().millisecondsSinceEpoch - rec['dueClearTime'] > 2 * 60 * 60 * 1000);
    }
    return (DateTime.now().millisecondsSinceEpoch - rec['firstSaveTime'] > 6 * 60 * 60 * 1000);
  }

  // Pick profile picture
  Future<void> _pickProfilePic() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.bytes != null) {
      setState(() => _isLoading = true);
      try {
        final bytes = result.files.single.bytes!;
        final base64String = base64Encode(bytes);
        final picUrl = "data:image/png;base64,$base64String";
        
        await _firebaseService.updateProfilePicUrl(_profile['id'], picUrl);
        widget.showToast("✅ Profile picture updated!");
        await _refreshProfile();
      } catch (e) {
        widget.showToast("❌ Image upload failed");
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // Student upload own study file
  Future<void> _uploadOwnFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() => _isLoading = true);
      final name = result.files.single.name;
      final bytes = result.files.single.bytes!;

      try {
        final downloadUrl = await _firebaseService.uploadStudentOwnFile(_profile['id'], bytes, name);
        await _firebaseService.addOwnFile(_profile['id'], {
          'title': name,
          'url': downloadUrl,
          'fileName': name,
          'uploadedAt': DateTime.now().millisecondsSinceEpoch,
        });
        widget.showToast("✅ File uploaded successfully!");
        await _refreshProfile();
      } catch (e) {
        widget.showToast("❌ File upload failed");
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // Delete own uploaded file
  Future<void> _deleteOwnFile(int index, String fileName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF09090B) : const Color(0xFF1E293B),
        title: const Text("Delete File"),
        content: const Text("Are you sure you want to permanently delete this file?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes")),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _firebaseService.deleteOwnFile(_profile['id'], index, fileName);
        widget.showToast("✅ File Deleted!");
        await _refreshProfile();
      } catch (e) {
        widget.showToast("❌ Error deleting file");
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // Student signs their monthly receipt
  void _openSignPad() {
    final record = _profile['records']?[_selectedMonth];
    final isLocked = _isMonthLocked(record);

    if (isLocked) {
      widget.showToast("🔒 Locked from changes.");
      return;
    }

    showDialog(
      context: context,
      builder: (context) => SignaturePadModal(
        title: "Student Signature",
        isDark: widget.isDark,
        onSave: (dataUrl) async {
          Navigator.pop(context);
          setState(() => _isLoading = true);
          try {
            final updatedRecord = Map<String, dynamic>.from(record ?? {});
            updatedRecord['studentSign'] = dataUrl;
            
            await _firebaseService.saveMonthlyRecord(
              studentId: _profile['id'],
              month: _selectedMonth!,
              monthData: updatedRecord,
            );
            widget.showToast("✅ Signed successfully!");
            await _refreshProfile();
            
            // Auto reopen month view to see updated sign
            setState(() {
              // Refresh state
            });
          } catch (e) {
            widget.showToast("❌ Signing failed!");
          } finally {
            setState(() => _isLoading = false);
          }
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  // Settings Modal
  void _openSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF09090B) : const Color(0xFF1E293B),
        title: const Text("App Settings", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: Localization.activeLanguage,
              decoration: const InputDecoration(labelText: "App Language"),
              items: const [
                DropdownMenuItem(value: 'en', child: Text("English")),
                DropdownMenuItem(value: 'bn', child: Text("Bengali (বাংলা)")),
                DropdownMenuItem(value: 'hi', child: Text("Hindi (हिंदी)")),
                DropdownMenuItem(value: 'as', child: Text("Assamese (অসমীয়া)")),
                DropdownMenuItem(value: 'ko', child: Text("Korean (한국어)")),
              ],
              onChanged: (val) {
                if (val != null) {
                  widget.onLanguageChange(val);
                  Navigator.pop(context);
                }
              },
            ),
            const SizedBox(height: 15),
            const Text("Theme Color", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                _colorBubble(const Color(0xFFB33939)),
                _colorBubble(const Color(0xFF10B981)),
                _colorBubble(const Color(0xFF3B82F6)),
                _colorBubble(const Color(0xFF8B5CF6)),
                _colorBubble(const Color(0xFFEC4899)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorBubble(Color color) {
    return InkWell(
      onTap: () {
        widget.onColorChange(color);
        Navigator.pop(context);
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: widget.primaryColor == color ? 3 : 1),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final popped = _popScreen();
        return !popped;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: _currentScreen != 'home'
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _popScreen,
                )
              : IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: _openSettingsDialog,
                ),
          title: Text(
            _getScreenTitle(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode, color: Colors.white),
              onPressed: widget.onThemeToggle,
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: widget.onLogout,
            ),
          ],
        ),
        body: Stack(
          children: [
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 550),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildScreenContent(),
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black45,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenContent() {
    switch (_currentScreen) {
      case 'home':
        return _buildHomeView();
      case 'fees':
        return _buildFeesGridView();
      case 'month_detail':
        return _buildMonthDetailView();
      case 'files':
        return _buildFilesView();
      case 'attendance':
        return AttendanceScreen(
          studentId: _profile['id'],
          studentName: _profile['name'],
          mode: 'student',
          initialAttendance: _profile['attendance'] ?? {},
          isDark: widget.isDark,
          onBack: _popScreen,
        );
      default:
        return _buildHomeView();
    }
  }

  // View 1: Home View
  Widget _buildHomeView() {
    // Routine
    final Map<String, dynamic> routine = _profile['routine'] ?? {};
    final List<Widget> routineList = [];
    final Map<String, String> dayNames = {
      'mon': 'Monday', 'tue': 'Tuesday', 'wed': 'Wednesday', 'thu': 'Thursday',
      'fri': 'Friday', 'sat': 'Saturday', 'sun': 'Sunday'
    };

    for (var day in ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']) {
      if (routine[day] != null && (routine[day]['subject'].toString().isNotEmpty || routine[day]['time'].toString().isNotEmpty)) {
        routineList.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    dayNames[day]!,
                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                  ),
                ),
                Expanded(
                  child: Text(
                    routine[day]['subject'] ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  routine[day]['time'] ?? '-',
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        );
      }
    }

    // Avatar pic decoding
    final pic = _profile['profilePic'];
    bool hasLocalPic = false;
    Uint8List? localBytes;

    if (pic != null && pic.toString().startsWith("data:image")) {
      try {
        final uri = pic.toString().split(',')[1];
        localBytes = base64Decode(uri);
        hasLocalPic = true;
      } catch (e) {}
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Student Info Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: AppTheme.glassDecoration(
              context: context,
              isDark: widget.isDark,
              customColor: Theme.of(context).colorScheme.primary,
              opacity: 0.9,
            ),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 65,
                      height: 65,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.5), width: 3),
                      ),
                      child: ClipOval(
                        child: hasLocalPic
                            ? Image.memory(localBytes!, fit: Cover)
                            : Container(color: Colors.grey, child: const Icon(Icons.person, size: 40, color: Colors.white)),
                      ),
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                      ),
                      onPressed: _pickProfilePic,
                    ),
                  ],
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _profile['name'] ?? '',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text("Class: ${_profile['cls']}", style: const TextStyle(fontSize: 13, color: Colors.white70)),
                      Text("Joined: ${_profile['date'] ?? 'N/A'}", style: const TextStyle(fontSize: 13, color: Colors.white70)),
                      Text(
                        "Monthly Fee: ₹${_profile['fixedFee'] ?? '0'}",
                        style: const TextStyle(fontSize: 13, color: Color(0xFFD1FAE5), fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                        child: Text("ID: ${_profile['id']}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),

          ElevatedButton.icon(
            onPressed: () => _pushScreen('attendance'),
            icon: Icon(Icons.calendar_month, color: Theme.of(context).colorScheme.primary),
            label: const Text("View Attendance Calendar"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
          const SizedBox(height: 15),

          // Weekly Routine
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.glassDecoration(context: context, isDark: widget.isDark),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Weekly Routine",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 10),
                if (routineList.isEmpty)
                  const Text("Routine not set by teacher yet.", style: TextStyle(color: Colors.white38))
                else
                  ...routineList,
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Lower Grid Options
          Row(
            children: [
              Expanded(
                child: _buildOptionCard(
                  title: Localization.get('monthlyFees'),
                  icon: FontAwesomeIcons.indianRupeeSign,
                  color: const Color(0xFF10B981),
                  onTap: () => _pushScreen('fees'),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildOptionCard(
                  title: Localization.get('files'),
                  icon: FontAwesomeIcons.folderOpen,
                  color: const Color(0xFF3B82F6),
                  onTap: () => _pushScreen('files'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 140,
        decoration: AppTheme.glassDecoration(context: context, isDark: widget.isDark),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(icon, size: 32, color: color),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  // View 2: Monthly Fees list Grid
  Widget _buildFeesGridView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.yellow.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.lock_outline, color: Colors.yellow, size: 16),
              SizedBox(width: 8),
              Text(
                "Fee data is managed by your teacher.",
                style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView.builder(
            itemCount: _monthsList.length,
            itemBuilder: (context, index) {
              final month = _monthsList[index];
              final record = _profile['records']?[month];
              final hasData = record != null && record['firstSaveTime'] != null;

              int paid = int.tryParse(record?['paid']?.toString() ?? '') ?? 0;
              int due = int.tryParse(record?['due']?.toString() ?? '') ?? 0;
              int extra = int.tryParse(record?['extraPay']?.toString() ?? '') ?? 0;

              String statusText = "Not Updated Yet";
              Color statusColor = Colors.grey;
              Color borderSideColor = Colors.white12;

              if (hasData) {
                if (extra > 0) {
                  statusText = "Extra: ₹$extra";
                  statusColor = const Color(0xFF3B82F6);
                  borderSideColor = const Color(0xFF3B82F6);
                } else if (due > 0) {
                  statusText = "Due: ₹$due";
                  statusColor = const Color(0xFFEF4444);
                  borderSideColor = const Color(0xFFEF4444);
                } else {
                  statusText = "Paid ✓";
                  statusColor = const Color(0xFF10B981);
                  borderSideColor = const Color(0xFF10B981);
                }
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: borderSideColor.withOpacity(0.5), width: 1.5),
                ),
                child: ListTile(
                  title: Text(month, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(hasData ? "Paid: ₹$paid${record['date'] != null && record['date'].toString().isNotEmpty ? ' • ' + record['date'] : ''}" : "Waiting for update"),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  onTap: hasData
                      ? () {
                          setState(() {
                            _selectedMonth = month;
                          });
                          _pushScreen('month_detail');
                        }
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // View 3: Month Detail receipt
  Widget _buildMonthDetailView() {
    final record = _profile['records']?[_selectedMonth];
    if (record == null) return const SizedBox.shrink();

    final paid = record['paid'] ?? '0';
    final date = record['date'] ?? '-';
    final due = record['due'] ?? '0';
    final extra = record['extraPay'] ?? '0';
    final hasExtra = int.tryParse(extra.toString()) != null && (int.tryParse(extra.toString()) ?? 0) > 0;

    final isLocked = _isMonthLocked(record);

    // Decoding Signatures
    Uint8List? studentSignBytes;
    if (record['studentSign'] != null && record['studentSign'].toString().startsWith("data:image")) {
      try {
        final uri = record['studentSign'].toString().split(',')[1];
        studentSignBytes = base64Decode(uri);
      } catch (e) {}
    }

    Uint8List? teacherSignBytes;
    if (record['teacherSign'] != null && record['teacherSign'].toString().startsWith("data:image")) {
      try {
        final uri = record['teacherSign'].toString().split(',')[1];
        teacherSignBytes = base64Decode(uri);
      } catch (e) {}
    }

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: AppTheme.glassDecoration(context: context, isDark: widget.isDark, borderRadius: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _selectedMonth ?? '',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),

            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.25)),
              ),
              alignment: Alignment.center,
              child: Text(
                "Target Fee: ₹${_profile['fixedFee'] ?? '0'}",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 20),

            _buildDetailRow("💰 Paid Amount", "₹$paid"),
            _buildDetailRow("📅 Paid Date", date),
            _buildDetailRow("⚠️ Due Amount", "₹$due", isAccent: true),
            if (hasExtra) _buildDetailRow("🎁 Extra Pay", "₹$extra", isExtra: true),
            const SizedBox(height: 25),

            // Signatures Section
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text("Student Sign", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 8),
                        Container(
                          height: 80,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white10),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.black12,
                          ),
                          child: studentSignBytes != null
                              ? Image.memory(studentSignBytes, fit: BoxFit.contain)
                              : const Center(child: Text("Not Signed", style: TextStyle(color: Colors.white38, fontSize: 11))),
                        ),
                        const SizedBox(height: 8),
                        if (studentSignBytes == null)
                          ElevatedButton(
                            onPressed: isLocked ? null : _openSignPad,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            child: const Text("Sign Here"),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      children: [
                        const Text("Teacher Sign", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 8),
                        Container(
                          height: 80,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white10),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.black12,
                          ),
                          child: teacherSignBytes != null
                              ? Image.memory(teacherSignBytes, fit: BoxFit.contain)
                              : const Center(child: Text("Not Signed", style: TextStyle(color: Colors.white38, fontSize: 11))),
                        ),
                        const SizedBox(height: 38), // matching button size space
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isAccent = false, bool isExtra = false}) {
    Color valColor = Colors.white;
    if (isAccent) valColor = const Color(0xFFEF4444);
    if (isExtra) valColor = const Color(0xFF3B82F6);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: valColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // View 4: Study Files view (Teacher shared vs Own)
  Widget _buildFilesView() {
    final teacherFiles = List<dynamic>.from(_profile['teacherFiles'] ?? []);
    final ownFiles = List<dynamic>.from(_profile['ownFiles'] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildTypeTab(
                  active: _fileTab == 'teacher',
                  label: "👨‍🏫 Teacher Notes",
                  onTap: () => setState(() => _fileTab = 'teacher'),
                ),
              ),
              Expanded(
                child: _buildTypeTab(
                  active: _fileTab == 'own',
                  label: "📁 My Files",
                  onTap: () => setState(() => _fileTab = 'own'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (_fileTab == 'teacher') ...[
          Expanded(
            child: teacherFiles.isEmpty
                ? const Center(child: Text("No teacher notes shared yet.", style: TextStyle(color: Colors.white38)))
                : ListView.builder(
                    itemCount: teacherFiles.length,
                    itemBuilder: (context, index) {
                      final file = teacherFiles[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                          title: Text(file['title'] ?? ''),
                          subtitle: const Text("Tap to view PDF note"),
                          trailing: const Icon(Icons.open_in_new),
                          onTap: () {
                            // Open url in browser
                          },
                        ),
                      );
                    },
                  ),
          ),
        ] else ...[
          ElevatedButton.icon(
            onPressed: _uploadOwnFile,
            icon: const Icon(Icons.cloud_upload),
            label: const Text("Upload File"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: ownFiles.isEmpty
                ? const Center(child: Text("No personal files uploaded yet.", style: TextStyle(color: Colors.white38)))
                : ListView.builder(
                    itemCount: ownFiles.length,
                    itemBuilder: (context, index) {
                      final file = ownFiles[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(Icons.insert_drive_file, color: Colors.blueAccent),
                          title: Text(file['title'] ?? ''),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () => _deleteOwnFile(index, file['fileName']),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ],
    );
  }

  // Type tab helper
  Widget _buildTypeTab({required bool active, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white60,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

const Cover = BoxFit.cover;
