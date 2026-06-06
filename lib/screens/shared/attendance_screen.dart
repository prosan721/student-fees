import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/localization.dart';

class AttendanceScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String mode; // 'teacher' or 'student'
  final Map<String, dynamic> initialAttendance;
  final bool isDark;
  final VoidCallback onBack;

  const AttendanceScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.mode,
    required this.initialAttendance,
    required this.isDark,
    required this.onBack,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  late DateTime _currentDate;
  late Map<String, dynamic> _attendanceData;
  bool _isSaving = false;

  final List<String> _monthsList = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ];

  @override
  void initState() {
    super.initState();
    _currentDate = DateTime.now();
    _attendanceData = Map<String, dynamic>.from(widget.initialAttendance);
  }

  void _prevMonth() {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month + 1);
    });
  }

  Future<void> _toggleAttendance(String dateStr) async {
    if (widget.mode == 'student') return;

    final currentStatus = _attendanceData[dateStr];
    String? newStatus;
    if (currentStatus == 'present') {
      newStatus = 'absent';
    } else if (currentStatus == 'absent') {
      newStatus = null; // Removed
    } else {
      newStatus = 'present';
    }

    setState(() {
      if (newStatus == null) {
        _attendanceData.remove(dateStr);
      } else {
        _attendanceData[dateStr] = newStatus;
      }
    });

    try {
      await _firebaseService.saveAttendance(widget.studentId, _attendanceData);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Failed to save attendance!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final year = _currentDate.year;
    final month = _currentDate.month;
    final monthName = _monthsList[month - 1];

    // Calendar Math
    final firstDayWeekday = DateTime(year, month, 1).weekday; // 1 (Mon) - 7 (Sun)
    final paddingDays = firstDayWeekday == 7 ? 0 : firstDayWeekday; // Sunday will be 0 padding if we start on Sunday?
    // Wait, Sunday is index 0 in headers.
    // In Dart, 7 is Sunday. If Sunday is start of week:
    // If weekday is 7 (Sun), padding should be 0.
    // If weekday is 1 (Mon), padding should be 1.
    // If weekday is 6 (Sat), padding should be 6.
    // So `firstDayWeekday % 7` gives exactly the correct Sunday-indexed weekday!
    final startPadding = firstDayWeekday % 7;
    final totalDays = DateUtils.getDaysInMonth(year, month);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
        title: Text(
          widget.mode == 'teacher' ? 'Attendance' : 'My Attendance',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 550),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.glassDecoration(
                    context: context,
                    isDark: widget.isDark,
                    borderRadius: 24,
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.mode == 'teacher' ? 'Student: ${widget.studentName}' : widget.studentName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Month selector
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left, color: Colors.white),
                              onPressed: _prevMonth,
                            ),
                            Text(
                              "$monthName $year",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right, color: Colors.white),
                              onPressed: _nextMonth,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Calendar Grid Header
                      GridView.count(
                        crossAxisCount: 7,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: const [
                          Center(child: Text("Sun", style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white60, fontSize: 12))),
                          Center(child: Text("Mon", style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white60, fontSize: 12))),
                          Center(child: Text("Tue", style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white60, fontSize: 12))),
                          Center(child: Text("Wed", style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white60, fontSize: 12))),
                          Center(child: Text("Thu", style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white60, fontSize: 12))),
                          Center(child: Text("Fri", style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white60, fontSize: 12))),
                          Center(child: Text("Sat", style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white60, fontSize: 12))),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Calendar Days
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                        ),
                        itemCount: startPadding + totalDays,
                        itemBuilder: (context, index) {
                          if (index < startPadding) {
                            return const SizedBox.shrink();
                          }
                          
                          final day = index - startPadding + 1;
                          final dateStr = "$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";
                          final status = _attendanceData[dateStr];

                          Color cellColor = Colors.white.withOpacity(0.08);
                          Color textColor = Colors.white;
                          Border border = Border.all(color: Colors.transparent);

                          if (status == 'present') {
                            cellColor = const Color(0xFFD1FAE5);
                            textColor = const Color(0xFF065F46);
                            border = Border.all(color: const Color(0xFF10B981), width: 2);
                          } else if (status == 'absent') {
                            cellColor = const Color(0xFFFEE2E2);
                            textColor = const Color(0xFF991B1B);
                            border = Border.all(color: const Color(0xFFEF4444), width: 2);
                          }

                          return InkWell(
                            onTap: widget.mode == 'teacher' ? () => _toggleAttendance(dateStr) : null,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: cellColor,
                                border: border,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "$day",
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 25),

                      // Legend
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildLegendItem(const Color(0xFF10B981), Localization.get('present')),
                            const SizedBox(width: 30),
                            _buildLegendItem(const Color(0xFFEF4444), Localization.get('absent')),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }
}
