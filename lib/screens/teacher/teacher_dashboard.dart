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

class TeacherDashboard extends StatefulWidget {
  final VoidCallback onLogout;
  final VoidCallback onThemeToggle;
  final Function(Color color) onColorChange;
  final Function(String lang) onLanguageChange;
  final Function(String msg) showToast;
  final bool isDark;
  final Color primaryColor;

  const TeacherDashboard({
    super.key,
    required this.onLogout,
    required this.onThemeToggle,
    required this.onColorChange,
    required this.onLanguageChange,
    required this.showToast,
    required this.isDark,
    required this.primaryColor,
  });

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  final FirebaseService _firebaseService = FirebaseService();

  // Navigation Stack inside Teacher View
  // 'home', 'pending', 'mgmt', 'add_student', 'classes', 'students_list', 'profile', 'month_detail', 'attendance', 'finance'
  List<String> _screenStack = ['home'];
  
  // State variables
  Map<String, Map<String, dynamic>> _students = {};
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _isLoading = false;

  // Selection state
  String? _selectedClass;
  String? _selectedStudentId;
  String? _selectedMonth;

  // Financial Summary state
  String _financeTab = 'monthly'; // 'monthly' or 'yearly'
  String? _selectedFinanceMonth;

  // Routine dialog controllers
  final Map<String, TextEditingController> _subjectControllers = {};
  final Map<String, TextEditingController> _timeControllers = {};
  final List<String> _daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  // Add student form controllers
  final _addNameCtrl = TextEditingController();
  final _addEmailCtrl = TextEditingController();
  final _addMobileCtrl = TextEditingController();
  final _addPassCtrl = TextEditingController();
  final _addFeeCtrl = TextEditingController();
  String _addType = 'email'; // 'email' or 'mobile'
  String? _addClassSelection;
  DateTime? _addJoinDate;

  // Edit profile form controllers
  final _editNameCtrl = TextEditingController();
  final _editClassCtrl = TextEditingController();
  final _editFeeCtrl = TextEditingController();
  DateTime? _editJoinDate;

  // Month Detail form controllers
  final _monthPaidCtrl = TextEditingController();
  final _monthDueCtrl = TextEditingController();
  final _monthExtraCtrl = TextEditingController();
  DateTime? _monthPaidDate;
  String? _tempStudentSign;
  String? _tempTeacherSign;

  final List<String> _monthsList = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ];

  @override
  void initState() {
    super.initState();
    for (var day in _daysOfWeek) {
      _subjectControllers[day] = TextEditingController();
      _timeControllers[day] = TextEditingController();
    }
    _loadData();
  }

  @override
  void dispose() {
    for (var day in _daysOfWeek) {
      _subjectControllers[day]?.dispose();
      _timeControllers[day]?.dispose();
    }
    _addNameCtrl.dispose();
    _addEmailCtrl.dispose();
    _addMobileCtrl.dispose();
    _addPassCtrl.dispose();
    _addFeeCtrl.dispose();
    _editNameCtrl.dispose();
    _editClassCtrl.dispose();
    _editFeeCtrl.dispose();
    _monthPaidCtrl.dispose();
    _monthDueCtrl.dispose();
    _monthExtraCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _students = await _firebaseService.loadAllStudents();
      _pendingRequests = await _firebaseService.getPendingRequests();
    } catch (e) {
      widget.showToast("❌ Error loading database records");
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
      case 'pending':
        return Localization.get('newRequests');
      case 'mgmt':
        return "Management";
      case 'add_student':
        return "Add Student";
      case 'classes':
        return Localization.get('classes');
      case 'students_list':
        return _selectedClass ?? "Students";
      case 'profile':
        return "Profile";
      case 'month_detail':
        return "${_selectedMonth ?? ''} Entry";
      case 'finance':
        return Localization.get('financeSummary');
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

  // File Picker for Profile Picture Upload (Base64)
  Future<void> _pickProfilePic() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.bytes != null) {
      setState(() => _isLoading = true);
      try {
        final bytes = result.files.single.bytes!;
        final base64String = base64Encode(bytes);
        final picUrl = "data:image/png;base64,$base64String";
        
        await _firebaseService.updateProfilePicUrl(_selectedStudentId!, picUrl);
        widget.showToast("✅ Profile picture updated!");
        await _loadData();
      } catch (e) {
        widget.showToast("❌ Image upload failed");
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // File Picker for Teacher PDF note upload
  Future<void> _pickAndUploadPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.bytes != null) {
      final name = result.files.single.name;
      final bytes = result.files.single.bytes!;

      // Ask for Title
      final titleController = TextEditingController(text: name);
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: widget.isDark ? const Color(0xFF09090B) : const Color(0xFF1E293B),
          title: const Text("Share PDF note"),
          content: TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: "PDF Title"),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Upload")),
          ],
        ),
      );

      if (confirm == true) {
        setState(() => _isLoading = true);
        try {
          final downloadUrl = await _firebaseService.uploadTeacherFile(_selectedStudentId!, bytes, name);
          await _firebaseService.addTeacherNote(_selectedStudentId!, {
            'title': titleController.text.trim(),
            'url': downloadUrl,
            'fileName': name,
            'uploadedAt': DateTime.now().millisecondsSinceEpoch,
          });
          widget.showToast("✅ PDF Shared successfully!");
          await _loadData();
        } catch (e) {
          widget.showToast("❌ PDF upload failed");
        } finally {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  // Teacher manual creation
  Future<void> _addStudentManually() async {
    final name = _addNameCtrl.text.trim();
    final email = _addEmailCtrl.text.trim();
    final mobile = _addMobileCtrl.text.trim();
    final pass = _addPassCtrl.text.trim();
    final fee = _addFeeCtrl.text.trim();

    if (name.isEmpty || pass.isEmpty || fee.isEmpty || _addClassSelection == null || _addJoinDate == null) {
      widget.showToast("⚠️ Please fill all fields!");
      return;
    }

    final loginStr = _addType == 'email' ? email : mobile;
    if (loginStr.isEmpty) {
      widget.showToast("⚠️ Missing login identifier!");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _firebaseService.createStudentManually(
        name: name,
        email: _addType == 'email' ? email : '',
        mobile: _addType == 'mobile' ? mobile : '',
        password: pass,
        cls: _addClassSelection!,
        fixedFee: fee,
        joinDate: _addJoinDate!.toIso8601String().substring(0, 10),
      );
      widget.showToast("✅ Student profile created!");
      _addNameCtrl.clear();
      _addEmailCtrl.clear();
      _addMobileCtrl.clear();
      _addPassCtrl.clear();
      _addFeeCtrl.clear();
      _addClassSelection = null;
      _addJoinDate = null;
      await _loadData();
      _popScreen();
    } catch (e) {
      widget.showToast("❌ User creation failed. Identifier might be in use.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Approval logic
  Future<void> _approveRequest(Map<String, dynamic> request) async {
    final name = request['name'];
    final pendingId = request['uid'];

    final classSelection = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: widget.isDark ? const Color(0xFF09090B) : const Color(0xFF1E293B),
        title: Text("Assign class for $name"),
        children: ["Class 2", "Class 6", "Class 7", "Class 9", "Class 10", "Other Batch"]
            .map((c) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, c),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(c, style: const TextStyle(fontSize: 16)),
                  ),
                ))
            .toList(),
      ),
    );

    if (classSelection == null) return;

    final feeCtrl = TextEditingController();
    final feeConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF09090B) : const Color(0xFF1E293B),
        title: const Text("Enter Monthly Fee (₹)"),
        content: TextField(
          controller: feeCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: "E.g., 500"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Save")),
        ],
      ),
    );

    if (feeConfirm != true || feeCtrl.text.isEmpty) return;

    final joinDate = DateTime.now().toIso8601String().substring(0, 10);

    setState(() => _isLoading = true);
    try {
      await _firebaseService.approveStudent(
        pendingId: pendingId,
        name: name,
        email: request['email'] ?? '',
        mobile: request['mobile'] ?? '',
        cls: classSelection,
        fixedFee: feeCtrl.text,
        joinDate: joinDate,
        uid: request['uid'],
      );
      widget.showToast("✅ Student Approved!");
      await _loadData();
    } catch (e) {
      widget.showToast("❌ Approval failed!");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Link approval to existing profile
  Future<void> _linkRequest(Map<String, dynamic> request) async {
    final list = _students.keys.map((k) => "$k: ${_students[k]?['name'] ?? ''} (${_students[k]?['cls'] ?? ''})").toList();
    if (list.isEmpty) {
      widget.showToast("⚠️ No students exist to link with.");
      return;
    }

    final selectedLink = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: widget.isDark ? const Color(0xFF09090B) : const Color(0xFF1E293B),
        title: const Text("Select Student to Link:"),
        children: _students.keys
            .map((k) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, k),
                  child: Text("${_students[k]?['name']} (${_students[k]?['cls']})"),
                ))
            .toList(),
      ),
    );

    if (selectedLink == null) return;

    setState(() => _isLoading = true);
    try {
      await _firebaseService.linkPending(
        pendingId: request['uid'],
        studentId: selectedLink,
        newUid: request['uid'],
      );
      widget.showToast("✅ Account linked successfully!");
      await _loadData();
    } catch (e) {
      widget.showToast("❌ Linking failed.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Save student profile edit
  Future<void> _saveProfileEdits() async {
    if (_editNameCtrl.text.isEmpty || _editClassCtrl.text.isEmpty || _editFeeCtrl.text.isEmpty || _editJoinDate == null) {
      widget.showToast("⚠️ Fill all fields!");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _firebaseService.updateStudentProfile(
        studentId: _selectedStudentId!,
        name: _editNameCtrl.text.trim(),
        cls: _editClassCtrl.text.trim(),
        joinDate: _editJoinDate!.toIso8601String().substring(0, 10),
        fixedFee: _editFeeCtrl.text.trim(),
      );
      widget.showToast("✅ Profile Updated!");
      await _loadData();
      Navigator.pop(context); // Close dialog
    } catch (e) {
      widget.showToast("❌ Profile update failed");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Delete student
  Future<void> _deleteStudent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF09090B) : const Color(0xFF1E293B),
        title: const Text("Delete Profile"),
        content: const Text("Are you sure you want to permanently delete this student's data?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _firebaseService.deleteStudent(_selectedStudentId!);
        widget.showToast("✅ Student profile deleted");
        await _loadData();
        _popScreen(); // Go back to student list
      } catch (e) {
        widget.showToast("❌ Error deleting student");
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // Password reset
  Future<void> _resetPassword() async {
    final student = _students[_selectedStudentId!];
    if (student == null) return;
    final email = student['email'];
    if (email == null || email.toString().isEmpty) {
      widget.showToast("❌ Student email not found");
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF09090B) : const Color(0xFF1E293B),
        title: const Text("Reset Password"),
        content: Text("Send password reset email to ${student['name']} ($email)?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes")),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _firebaseService.sendForgotPassword(email);
        widget.showToast("✅ Link sent successfully!");
      } catch (e) {
        widget.showToast("❌ Error sending reset email");
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // Routine Manager Modal
  void _openRoutineModal() {
    final student = _students[_selectedStudentId!];
    if (student == null) return;
    final routine = student['routine'] ?? {};

    for (var day in _daysOfWeek) {
      final lowDay = day.toLowerCase();
      _subjectControllers[day]?.text = routine[lowDay]?['subject'] ?? '';
      _timeControllers[day]?.text = routine[lowDay]?['time'] ?? '';
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.glassDecoration(context: context, isDark: widget.isDark, borderRadius: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("Set Weekly Routine", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 15),
                Expanded(
                  child: ListView(
                    children: _daysOfWeek.map((day) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(day, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: _subjectControllers[day],
                                      decoration: const InputDecoration(labelText: "Subject", filled: false),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 1,
                                    child: TextField(
                                      controller: _timeControllers[day],
                                      decoration: const InputDecoration(labelText: "Time", filled: false),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () async {
                        final Map<String, dynamic> newRoutine = {};
                        for (var d in _daysOfWeek) {
                          final lowD = d.toLowerCase();
                          final subj = _subjectControllers[d]!.text.trim();
                          final time = _timeControllers[d]!.text.trim();
                          if (subj.isNotEmpty || time.isNotEmpty) {
                            newRoutine[lowD] = {'subject': subj, 'time': time};
                          }
                        }
                        try {
                          await _firebaseService.saveRoutine(_selectedStudentId!, newRoutine);
                          widget.showToast("✅ Routine saved!");
                          await _loadData();
                          Navigator.pop(context);
                        } catch (e) {
                          widget.showToast("❌ Saving routine failed");
                        }
                      },
                      child: const Text("Save"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Monthly Records operations
  void _openMonthDetail(String month) {
    setState(() {
      _selectedMonth = month;
      final student = _students[_selectedStudentId!];
      final rec = student?['records']?[month] ?? {};
      _monthPaidCtrl.text = rec['paid'] ?? '';
      _monthDueCtrl.text = rec['due'] ?? '';
      _monthExtraCtrl.text = rec['extraPay'] ?? '';
      _monthPaidDate = rec['date'] != null && rec['date'].toString().isNotEmpty
          ? DateTime.tryParse(rec['date'])
          : null;
      _tempStudentSign = rec['studentSign'];
      _tempTeacherSign = rec['teacherSign'];
    });
    _pushScreen('month_detail');
  }

  Future<void> _saveMonthData() async {
    final student = _students[_selectedStudentId!];
    if (student == null) return;
    
    final rec = student['records']?[_selectedMonth] ?? {};
    final isLocked = _isMonthLocked(rec);

    if (isLocked) {
      widget.showToast("🔒 Record is locked from further changes.");
      return;
    }

    final oldDue = int.tryParse(rec['due'].toString()) ?? int.tryParse(student['fixedFee'].toString()) ?? 0;
    final newDue = int.tryParse(_monthDueCtrl.text.trim()) ?? 0;

    final updatedRecord = Map<String, dynamic>.from(rec);
    updatedRecord['paid'] = _monthPaidCtrl.text.trim();
    updatedRecord['due'] = _monthDueCtrl.text.trim();
    updatedRecord['extraPay'] = _monthExtraCtrl.text.trim();
    updatedRecord['date'] = _monthPaidDate != null
        ? _monthPaidDate!.toIso8601String().substring(0, 10)
        : '';
    updatedRecord['studentSign'] = _tempStudentSign;
    updatedRecord['teacherSign'] = _tempTeacherSign;

    final hasData = _monthPaidCtrl.text.isNotEmpty ||
        _monthDueCtrl.text.isNotEmpty ||
        _monthExtraCtrl.text.isNotEmpty ||
        updatedRecord['date'].toString().isNotEmpty ||
        _tempStudentSign != null ||
        _tempTeacherSign != null;

    if (hasData) {
      if (updatedRecord['firstSaveTime'] == null) {
        updatedRecord['firstSaveTime'] = DateTime.now().millisecondsSinceEpoch;
      } else {
        if (oldDue > 0 && newDue == 0 && updatedRecord['dueClearTime'] == null) {
          updatedRecord['dueClearTime'] = DateTime.now().millisecondsSinceEpoch;
        } else if (newDue > 0) {
          updatedRecord['dueClearTime'] = null;
        }
      }
    } else {
      updatedRecord['firstSaveTime'] = null;
      updatedRecord['dueClearTime'] = null;
    }

    setState(() => _isLoading = true);
    try {
      await _firebaseService.saveMonthlyRecord(
        studentId: _selectedStudentId!,
        month: _selectedMonth!,
        monthData: updatedRecord,
      );
      widget.showToast("✅ Saved Monthly Data!");
      await _loadData();
      _popScreen();
    } catch (e) {
      widget.showToast("❌ Saving monthly records failed");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Signature triggers
  void _openSignPad(String type) {
    showDialog(
      context: context,
      builder: (context) => SignaturePadModal(
        title: type == 'student' ? 'Student Signature' : 'Teacher Signature',
        isDark: widget.isDark,
        onSave: (dataUrl) {
          setState(() {
            if (type == 'student') {
              _tempStudentSign = dataUrl;
            } else {
              _tempTeacherSign = dataUrl;
            }
          });
          Navigator.pop(context);
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

  // Master Build method
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final popped = _popScreen();
        return !popped; // Prevent closing app if popped screen stack
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
      case 'pending':
        return _buildPendingView();
      case 'mgmt':
        return _buildManagementView();
      case 'add_student':
        return _buildAddStudentView();
      case 'classes':
        return _buildClassesView();
      case 'students_list':
        return _buildStudentsListView();
      case 'profile':
        return _buildProfileView();
      case 'month_detail':
        return _buildMonthDetailView();
      case 'finance':
        return _buildFinanceView();
      default:
        return _buildHomeView();
    }
  }

  // Screen View 1: Home View
  Widget _buildHomeView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: AppTheme.glassDecoration(context: context, isDark: widget.isDark, borderRadius: 24),
          child: Center(
            child: FaIcon(
              FontAwesomeIcons.graduationCap,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 15),
        Text(
          "Institution",
          style: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        Text(
          "Manager Pro",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 35),
        
        // Navigation Options
        Row(
          children: [
            Expanded(
              child: _buildHomeGridCard(
                title: Localization.get('studentMgmt'),
                icon: FontAwesomeIcons.userGraduate,
                color: Theme.of(context).colorScheme.primary,
                onTap: () => _pushScreen('mgmt'),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildHomeGridCard(
                title: Localization.get('financeSummary'),
                icon: FontAwesomeIcons.chartPie,
                color: const Color(0xFF059669),
                onTap: () => _pushScreen('finance'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _pushScreen('pending'),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
                  decoration: AppTheme.glassDecoration(context: context, isDark: widget.isDark),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const FaIcon(FontAwesomeIcons.userClock, color: Color(0xFF8B5CF6)),
                      const SizedBox(width: 12),
                      Text(
                        Localization.get('newRequests'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (_pendingRequests.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "${_pendingRequests.length}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 35),
        const Text("App Version 9.2 • Firebase Live", style: TextStyle(color: Colors.white38, fontSize: 12)),
      ],
    );
  }

  Widget _buildHomeGridCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 150,
        decoration: AppTheme.glassDecoration(context: context, isDark: widget.isDark),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(icon, size: 40, color: color),
            const SizedBox(height: 15),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // Screen View 2: Pending approvals
  Widget _buildPendingView() {
    if (_pendingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 80, color: Color(0xFF10B981)),
            const SizedBox(height: 15),
            Text(
              "No pending requests!",
              style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _pendingRequests.length,
      itemBuilder: (context, index) {
        final request = _pendingRequests[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      request['name'] ?? '',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (request['cls'] != null && request['cls'].toString().isNotEmpty)
                      Chip(label: Text(request['cls'])),
                  ],
                ),
                const SizedBox(height: 8),
                Text("📧 Email: ${request['email'] ?? 'None'}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                Text("📱 Mobile: ${request['mobile'] ?? 'None'}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ) == null
                          ? const SizedBox()
                          : ElevatedButton(
                              onPressed: () => _approveRequest(request),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                              child: const Text("Approve"),
                            ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _linkRequest(request),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white24),
                        child: const Text("Link Ext."),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: widget.isDark ? const Color(0xFF09090B) : const Color(0xFF1E293B),
                            title: const Text("Reject Request"),
                            content: const Text("Are you sure you want to reject this request?"),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
                              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes")),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          setState(() => _isLoading = true);
                          await _firebaseService.rejectPending(request['uid']);
                          await _loadData();
                          setState(() => _isLoading = false);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Screen View 3: Management Grid (Classes vs Manual Student)
  Widget _buildManagementView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildHomeGridCard(
                title: "Add Student",
                icon: FontAwesomeIcons.addressCard,
                color: const Color(0xFF10B981),
                onTap: () => _pushScreen('add_student'),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildHomeGridCard(
                title: "Manage Classes",
                icon: FontAwesomeIcons.chalkboardUser,
                color: const Color(0xFF8B5CF6),
                onTap: () => _pushScreen('classes'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Screen View 4: Add Student manually
  Widget _buildAddStudentView() {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.glassDecoration(context: context, isDark: widget.isDark, borderRadius: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Add student manually. User details will be auto-generated.", style: TextStyle(fontSize: 13, color: Colors.white60), textAlign: TextAlign.center),
            const SizedBox(height: 15),

            Row(
              children: [
                Expanded(
                  child: _buildTypeTab(
                    active: _addType == 'email',
                    label: "📧 Email",
                    onTap: () => setState(() => _addType = 'email'),
                  ),
                ),
                Expanded(
                  child: _buildTypeTab(
                    active: _addType == 'mobile',
                    label: "📱 Mobile",
                    onTap: () => setState(() => _addType = 'mobile'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            TextFormField(
              controller: _addNameCtrl,
              decoration: const InputDecoration(labelText: "Student Full Name", hintText: "E.g., Rahul Das"),
            ),
            const SizedBox(height: 12),

            if (_addType == 'email')
              TextFormField(
                controller: _addEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: "Student Email", hintText: "E.g., student@email.com"),
              )
            else
              TextFormField(
                controller: _addMobileCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "Student Mobile No.", hintText: "E.g., 9876543210"),
              ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _addPassCtrl,
              decoration: const InputDecoration(labelText: "Password for Student", hintText: "E.g., pass123"),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _addClassSelection,
              decoration: const InputDecoration(labelText: "Class"),
              items: ["Class 2", "Class 6", "Class 7", "Class 9", "Class 10", "Other Batch"]
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (val) => setState(() => _addClassSelection = val),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _addFeeCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Monthly Fee (₹)", hintText: "E.g., 500"),
            ),
            const SizedBox(height: 12),

            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  setState(() => _addJoinDate = date);
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: "Joining Date"),
                child: Text(_addJoinDate != null ? _addJoinDate!.toIso8601String().substring(0, 10) : "Select Date..."),
              ),
            ),
            const SizedBox(height: 25),

            ElevatedButton(
              onPressed: _addStudentManually,
              child: const Text("Create Student Profile"),
            ),
          ],
        ),
      ),
    );
  }

  // Screen View 5: Class selector grid
  Widget _buildClassesView() {
    final Set<String> classes = {};
    for (var s in _students.values) {
      if (s['cls'] != null && s['cls'].toString().trim().isNotEmpty) {
        classes.add(s['cls'].toString().trim());
      }
    }

    if (classes.isEmpty) {
      return const Center(child: Text("No classes created yet. Add a student first."));
    }

    final classArray = classes.toList()..sort();

    return GridView.builder(
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
      ),
      itemCount: classArray.length,
      itemBuilder: (context, index) {
        final c = classArray[index];
        return InkWell(
          onTap: () {
            setState(() {
              _selectedClass = c;
            });
            _pushScreen('students_list');
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: AppTheme.glassDecoration(
              context: context,
              isDark: widget.isDark,
              customColor: Colors.black38,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const FaIcon(FontAwesomeIcons.chalkboardUser, size: 40, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text(c, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
        );
      },
    );
  }

  // Screen View 6: Student List Screen
  Widget _buildStudentsListView() {
    final filtered = _students.keys.where((k) => _students[k]?['cls'] == _selectedClass).toList();

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final id = filtered[index];
        final s = _students[id]!;
        
        final pic = s['profilePic'];
        Widget avatar = const CircleAvatar(
          radius: 25,
          backgroundColor: Colors.grey,
          child: Icon(Icons.person, color: Colors.white),
        );

        if (pic != null && pic.toString().startsWith("data:image")) {
          try {
            final uri = pic.toString().split(',')[1];
            final bytes = base64Decode(uri);
            avatar = CircleAvatar(
              radius: 25,
              backgroundImage: MemoryImage(bytes),
            );
          } catch (e) {
            // Decoded failed
          }
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: avatar,
            title: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("ID: $id"),
            trailing: const Icon(Icons.chevron_right, color: Colors.white60),
            onTap: () {
              setState(() {
                _selectedStudentId = id;
              });
              _pushScreen('profile');
            },
          ),
        );
      },
    );
  }

  // Screen View 7: Student Profile screen
  Widget _buildProfileView() {
    final s = _students[_selectedStudentId];
    if (s == null) return const Center(child: Text("Student not found"));

    final pic = s['profilePic'];
    ImageProvider avatarProvider = const AssetImage('assets/placeholder.png'); // fallback
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
          Container(
            padding: const EdgeInsets.all(22),
            decoration: AppTheme.glassDecoration(context: context, isDark: widget.isDark),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: const [BoxShadow(color: Colors.black24, blurRadius: 15)],
                      ),
                      child: ClipOval(
                        child: hasLocalPic
                            ? Image.memory(localBytes!, fit: Cover)
                            : Container(color: Colors.grey, child: const Icon(Icons.person, size: 60, color: Colors.white)),
                      ),
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                      ),
                      onPressed: _pickProfilePic,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(s['name'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text("ID: ${_selectedStudentId!}  |  Class: ${s['cls']}", style: const TextStyle(color: Colors.white60)),
                Text("📧 Email: ${s['email'] ?? 'None'}", style: const TextStyle(color: Colors.white60, fontSize: 13)),
                Text("📱 Phone: ${s['mobile'] ?? 'None'}", style: const TextStyle(color: Colors.white60, fontSize: 13)),
                const SizedBox(height: 15),

                // Fee Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Monthly Fee: ₹${s['fixedFee'] ?? '0'}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      ElevatedButton(
                        onPressed: () {
                          _editNameCtrl.text = s['name'] ?? '';
                          _editClassCtrl.text = s['cls'] ?? '';
                          _editFeeCtrl.text = s['fixedFee'] ?? '';
                          _editJoinDate = s['date'] != null ? DateTime.tryParse(s['date']) : null;
                          showDialog(
                            context: context,
                            builder: (context) => StatefulBuilder(
                              builder: (context, setDialogState) => AlertDialog(
                                backgroundColor: widget.isDark ? const Color(0xFF09090B) : const Color(0xFF1E293B),
                                title: const Text("Edit Profile"),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(controller: _editNameCtrl, decoration: const InputDecoration(labelText: "Name")),
                                    const SizedBox(height: 8),
                                    TextField(controller: _editClassCtrl, decoration: const InputDecoration(labelText: "Class")),
                                    const SizedBox(height: 8),
                                    TextField(controller: _editFeeCtrl, decoration: const InputDecoration(labelText: "Monthly Fee")),
                                    const SizedBox(height: 8),
                                    InkWell(
                                      onTap: () async {
                                        final date = await showDatePicker(
                                          context: context,
                                          initialDate: _editJoinDate ?? DateTime.now(),
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime(2030),
                                        );
                                        if (date != null) {
                                          setDialogState(() => _editJoinDate = date);
                                        }
                                      },
                                      child: InputDecorator(
                                        decoration: const InputDecoration(labelText: "Joining Date"),
                                        child: Text(_editJoinDate != null ? _editJoinDate!.toIso8601String().substring(0, 10) : "Select Date..."),
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                                  ElevatedButton(onPressed: _saveProfileEdits, child: const Text("Save")),
                                ],
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                        child: const Text("Edit"),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Horizontal Buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        // Open attendance view
                        _pushScreen('attendance');
                      },
                      icon: const Icon(Icons.calendar_month),
                      label: const Text("Attendance"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
                    ),
                    ElevatedButton.icon(
                      onPressed: _openRoutineModal,
                      icon: const Icon(Icons.alarm),
                      label: const Text("Routine"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
                    ),
                    ElevatedButton.icon(
                      onPressed: _pickAndUploadPdf,
                      icon: const Icon(Icons.file_upload),
                      label: const Text("Send PDF"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        // View uploaded files
                        showDialog(
                          context: context,
                          builder: (context) => StatefulBuilder(
                            builder: (context, setDialogState) {
                              final currentStudent = _students[_selectedStudentId];
                              final ownFiles = List<dynamic>.from(currentStudent?['ownFiles'] ?? []);
                              return AlertDialog(
                                backgroundColor: widget.isDark ? const Color(0xFF09090B) : const Color(0xFF1E293B),
                                title: const Text("Student's Uploaded Files"),
                                content: SizedBox(
                                  width: double.maxFinite,
                                  child: ownFiles.isEmpty
                                      ? const Padding(
                                          padding: EdgeInsets.all(20),
                                          child: Text("No files uploaded by student.", textAlign: TextAlign.center),
                                        )
                                      : ListView.builder(
                                          shrinkWrap: true,
                                          itemCount: ownFiles.length,
                                          itemBuilder: (context, index) {
                                            final file = ownFiles[index];
                                            return ListTile(
                                              title: Text(file['title'] ?? ''),
                                              trailing: IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.red),
                                                onPressed: () async {
                                                  final confirm = await showDialog<bool>(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      backgroundColor: widget.isDark ? const Color(0xFF09090B) : const Color(0xFF1E293B),
                                                      title: const Text("Delete File"),
                                                      content: const Text("Delete this file permanently?"),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
                                                        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes")),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm == true) {
                                                    setState(() => _isLoading = true);
                                                    try {
                                                      await _firebaseService.deleteOwnFile(
                                                        _selectedStudentId!,
                                                        index,
                                                        file['fileName'],
                                                      );
                                                      widget.showToast("✅ File Deleted!");
                                                      await _loadData();
                                                      setDialogState(() {});
                                                    } catch (e) {
                                                      widget.showToast("❌ Error deleting file");
                                                    } finally {
                                                      setState(() => _isLoading = false);
                                                    }
                                                  }
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
                                ],
                              );
                            },
                          ),
                        );
                      },
                      icon: const Icon(Icons.folder_open),
                      label: const Text("Files"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
                    ),
                    ElevatedButton.icon(
                      onPressed: _resetPassword,
                      icon: const Icon(Icons.vpn_key),
                      label: const Text("Reset Pass"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
                    ),
                    ElevatedButton.icon(
                      onPressed: _deleteStudent,
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      label: const Text("Delete"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Academic Year (12 Months)",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 15),

          // 12 Months Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            itemCount: _monthsList.length,
            itemBuilder: (context, index) {
              final month = _monthsList[index];
              final record = s['records']?[month];
              final hasData = record != null && record['firstSaveTime'] != null;
              final isLocked = _isMonthLocked(record);

              return InkWell(
                onTap: () => _openMonthDetail(month),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: AppTheme.glassDecoration(
                    context: context,
                    isDark: widget.isDark,
                    customColor: Colors.black26,
                    borderRadius: 16,
                  ),
                  child: Stack(
                    children: [
                      if (isLocked)
                        const PositionPoint(icon: Icons.lock, color: Colors.redAccent),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(month, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 10),
                          Icon(
                            Icons.check_circle,
                            size: 26,
                            color: hasData ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 25),
        ],
      ),
    );
  }

  // Screen View 8: Month Detail Screen
  Widget _buildMonthDetailView() {
    final student = _students[_selectedStudentId];
    if (student == null) return const SizedBox.shrink();
    
    final rec = student['records']?[_selectedMonth] ?? {};
    final isLocked = _isMonthLocked(rec);

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(20),
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
            if (isLocked) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.lock, color: Colors.redAccent, size: 16),
                    SizedBox(width: 8),
                    Text("Edit locked (Lock duration expired)", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.25)),
              ),
              alignment: Alignment.center,
              child: Text(
                "Target Amount: ₹${student['fixedFee'] ?? '0'}",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _monthPaidCtrl,
              keyboardType: TextInputType.number,
              enabled: !isLocked,
              decoration: const InputDecoration(labelText: "💰 Paid Amount (₹)", hintText: "Enter collected amount"),
            ),
            const SizedBox(height: 12),

            InkWell(
              onTap: isLocked
                  ? null
                  : () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _monthPaidDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setState(() => _monthPaidDate = date);
                      }
                    },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: "📅 Paid Date"),
                child: Text(_monthPaidDate != null
                    ? _monthPaidDate!.toIso8601String().substring(0, 10)
                    : "Select Date..."),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _monthDueCtrl,
              keyboardType: TextInputType.number,
              enabled: !isLocked,
              decoration: const InputDecoration(labelText: "⚠️ Due Amount (₹)", hintText: "Enter remaining due"),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _monthExtraCtrl,
              keyboardType: TextInputType.number,
              enabled: !isLocked,
              decoration: const InputDecoration(labelText: "🎁 Extra Pay / Advance (₹)", hintText: "Enter extra pay if any"),
            ),
            const SizedBox(height: 20),

            // Signatures block
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
                    child: _buildSignatureCell(
                      title: "Student Sign",
                      signatureDataUrl: _tempStudentSign,
                      onTap: isLocked ? null : () => _openSignPad('student'),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildSignatureCell(
                      title: "Teacher Sign",
                      signatureDataUrl: _tempTeacherSign,
                      onTap: isLocked ? null : () => _openSignPad('teacher'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            ElevatedButton(
              onPressed: isLocked ? null : _saveMonthData,
              style: ElevatedButton.styleFrom(
                backgroundColor: isLocked ? Colors.grey : const Color(0xFF10B981),
              ),
              child: Text(isLocked ? "Data Locked" : "Save Monthly Data"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignatureCell({required String title, String? signatureDataUrl, VoidCallback? onTap}) {
    Uint8List? signBytes;
    if (signatureDataUrl != null && signatureDataUrl.startsWith("data:image")) {
      try {
        final uri = signatureDataUrl.split(',')[1];
        signBytes = base64Decode(uri);
      } catch (e) {}
    }

    return Column(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          height: 80,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white10),
            borderRadius: BorderRadius.circular(12),
            color: Colors.black12,
          ),
          child: signBytes != null
              ? Image.memory(signBytes, fit: BoxFit.contain)
              : const Center(child: Text("Not Signed", style: TextStyle(color: Colors.white38, fontSize: 11))),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
          child: Text(signatureDataUrl != null ? "Retake" : "Sign"),
        ),
      ],
    );
  }

  // Screen View 9: Financial Summary
  Widget _buildFinanceView() {
    int totalCollected = 0;
    int totalDue = 0;

    for (var s in _students.values) {
      for (var month in _monthsList) {
        final rec = s['records']?[month] ?? {};
        totalCollected += int.tryParse(rec['paid']?.toString() ?? '') ?? 0;
        totalDue += int.tryParse(rec['due']?.toString() ?? '') ?? 0;
      }
    }

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
                  active: _financeTab == 'monthly',
                  label: "Monthly Report",
                  onTap: () => setState(() {
                    _financeTab = 'monthly';
                    _selectedFinanceMonth = null;
                  }),
                ),
              ),
              Expanded(
                child: _buildTypeTab(
                  active: _financeTab == 'yearly',
                  label: "Yearly (2026)",
                  onTap: () => setState(() => _financeTab = 'yearly'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (_financeTab == 'monthly') ...[
          if (_selectedFinanceMonth == null)
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                ),
                itemCount: _monthsList.length,
                itemBuilder: (context, index) {
                  final m = _monthsList[index];
                  return InkWell(
                    onTap: () => setState(() => _selectedFinanceMonth = m),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: AppTheme.glassDecoration(context: context, isDark: widget.isDark, customColor: Colors.black26),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_month, color: Colors.blueAccent, size: 28),
                          const SizedBox(height: 8),
                          Text(m, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          else
            _buildFinanceMonthDetailView(),
        ] else ...[
          // Yearly totals cards
          _buildFinanceSummaryCard(
            title: "Total Collected (2026)",
            amount: totalCollected,
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 15),
          _buildFinanceSummaryCard(
            title: "Total Due (2026)",
            amount: totalDue,
            color: const Color(0xFFEF4444),
          ),
        ],
      ],
    );
  }

  Widget _buildFinanceSummaryCard({required String title, required int amount, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: AppTheme.glassDecoration(context: context, isDark: widget.isDark),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Text("₹$amount", style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1)),
        ],
      ),
    );
  }

  Widget _buildFinanceMonthDetailView() {
    final month = _selectedFinanceMonth!;
    int totalPaid = 0;
    int totalDue = 0;
    final Map<String, Map<String, int>> classStats = {};

    for (var s in _students.values) {
      final c = s['cls'] ?? 'Unassigned';
      final rec = s['records']?[month] ?? {};
      final p = int.tryParse(rec['paid']?.toString() ?? '') ?? 0;
      final d = int.tryParse(rec['due']?.toString() ?? '') ?? 0;
      totalPaid += p;
      totalDue += d;

      if (!classStats.containsKey(c)) {
        classStats[c] = {'paid': 0, 'due': 0};
      }
      classStats[c]!['paid'] = classStats[c]!['paid']! + p;
      classStats[c]!['due'] = classStats[c]!['due']! + d;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: () => setState(() => _selectedFinanceMonth = null),
          icon: const Icon(Icons.arrow_back),
          label: const Text("Back to Month List"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.white24),
        ),
        const SizedBox(height: 20),
        Text("$month Report", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 15),

        Row(
          children: [
            Expanded(child: _buildFinanceSummaryCard(title: "Total Collected", amount: totalPaid, color: const Color(0xFF10B981))),
            const SizedBox(width: 15),
            Expanded(child: _buildFinanceSummaryCard(title: "Total Due", amount: totalDue, color: const Color(0xFFEF4444))),
          ],
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.glassDecoration(context: context, isDark: widget.isDark),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text("Class", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white54)),
                  Text("Paid", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                  Text("Due", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                ],
              ),
              const Divider(color: Colors.white24),
              ...classStats.keys.map((c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(c, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text("₹${classStats[c]!['paid']}", style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w800)),
                        Text("₹${classStats[c]!['due']}", style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w800)),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  // Helper type toggling tab
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

class PositionPoint extends StatelessWidget {
  final IconData icon;
  final Color color;

  const PositionPoint({super.key, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 5,
      right: 5,
      child: Icon(icon, color: color, size: 14),
    );
  }
}

const Cover = BoxFit.cover;
