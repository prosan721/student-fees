import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;

  static const String teacherEmail = "prosan721@gmail.com";

  // Initialize Firebase Web
  static Future<void> init() async {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyACNTVkt6dIX6tx9Ub3l1AL0nlnXNMrZj8",
        authDomain: "student-fees-8f7b7.firebaseapp.com",
        projectId: "student-fees-8f7b7",
        storageBucket: "student-fees-8f7b7.firebasestorage.app",
        messagingSenderId: "715775119348",
        appId: "1:715775119348:web:638e2a2b9f3e4bcad1b3a1",
      ),
    );
  }

  // Format ID for login (Mobile number gets suffixed)
  String formatLoginId(String inputId) {
    inputId = inputId.trim();
    if (RegExp(r'^\+?\d{8,15}$').hasMatch(inputId)) {
      return "$inputId@tuition.app";
    }
    return inputId;
  }

  // Authentication
  Future<UserCredential> signIn(String emailOrMobile, String password) async {
    final email = formatLoginId(emailOrMobile);
    return await auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> logout() async {
    await auth.signOut();
  }

  Future<void> sendForgotPassword(String email) async {
    await auth.sendPasswordResetEmail(email: email);
  }

  // Student Sign Up
  Future<void> signUpStudent({
    required String name,
    required String email,
    required String mobile,
    required String password,
    required String cls,
  }) async {
    final primaryId = email.isNotEmpty ? email : mobile;
    final loginId = formatLoginId(primaryId);

    // Create user in firebase auth
    final cred = await auth.createUserWithEmailAndPassword(email: loginId, password: password);
    final uid = cred.user!.uid;

    // Save to pending collection
    await db.collection('pending').doc(uid).set({
      'uid': uid,
      'name': name,
      'email': email,
      'mobile': mobile,
      'cls': cls,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });

    // Sign out immediately so teacher email doesn't get logged in
    await logout();
  }

  // Check if UID is in pending approvals
  Future<bool> isUidPending(String uid) async {
    final doc = await db.collection('pending').doc(uid).get();
    return doc.exists;
  }

  // Fetch pending requests
  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    final snap = await db.collection('pending').get();
    return snap.docs.map((doc) => doc.data()).toList();
  }

  // Load all students (for Teacher view)
  Future<Map<String, Map<String, dynamic>>> loadAllStudents() async {
    final snap = await db.collection('students').get();
    final Map<String, Map<String, dynamic>> students = {};
    for (var doc in snap.docs) {
      students[doc.id] = doc.data();
    }
    return students;
  }

  // Load current student profile
  Future<Map<String, dynamic>?> loadStudentDataByUid(String uid) async {
    final snap = await db.collection('students').where('uid', isEqualTo: uid).limit(1).get();
    if (snap.docs.isNotEmpty) {
      return snap.docs.first.data();
    }
    return null;
  }

  // Approve student signup
  Future<void> approveStudent({
    required String pendingId,
    required String name,
    required String email,
    required String mobile,
    required String cls,
    required String fixedFee,
    required String joinDate,
    required String uid,
  }) async {
    final studentId = 'STU${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    
    // Create initial 12-month records
    final Map<String, dynamic> records = {};
    const months = [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"
    ];
    for (var m in months) {
      records[m] = {
        'paid': '',
        'date': '',
        'due': '',
        'extraPay': '',
        'studentSign': null,
        'teacherSign': null,
        'firstSaveTime': null,
        'dueClearTime': null,
      };
    }

    final studentData = {
      'id': studentId,
      'name': name,
      'email': email,
      'mobile': mobile,
      'cls': cls,
      'date': joinDate,
      'fixedFee': fixedFee,
      'feeEditCount': 0,
      'profilePic': null,
      'records': records,
      'uid': uid,
      'routine': {},
      'attendance': {},
      'teacherFiles': [],
      'ownFiles': [],
    };

    // Save student profile
    await db.collection('students').doc(studentId).set(studentData);
    // Delete pending record
    await db.collection('pending').doc(pendingId).delete();
  }

  // Link pending credentials to an existing student profile
  Future<void> linkPending({
    required String pendingId,
    required String studentId,
    required String newUid,
  }) async {
    await db.collection('students').doc(studentId).update({'uid': newUid});
    await db.collection('pending').doc(pendingId).delete();
  }

  // Reject pending signup
  Future<void> rejectPending(String pendingId) async {
    await db.collection('pending').doc(pendingId).delete();
  }

  // Create student manually by teacher
  Future<void> createStudentManually({
    required String name,
    required String email,
    required String mobile,
    required String password,
    required String cls,
    required String fixedFee,
    required String joinDate,
  }) async {
    final primaryId = email.isNotEmpty ? email : mobile;
    final loginId = formatLoginId(primaryId);

    // Create Firebase auth user
    final cred = await auth.createUserWithEmailAndPassword(email: loginId, password: password);
    final uid = cred.user!.uid;

    final studentId = 'STU${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

    // Create initial 12-month records
    final Map<String, dynamic> records = {};
    const months = [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"
    ];
    for (var m in months) {
      records[m] = {
        'paid': '',
        'date': '',
        'due': '',
        'extraPay': '',
        'studentSign': null,
        'teacherSign': null,
        'firstSaveTime': null,
        'dueClearTime': null,
      };
    }

    final studentData = {
      'id': studentId,
      'name': name,
      'email': email,
      'mobile': mobile,
      'cls': cls,
      'date': joinDate,
      'fixedFee': fixedFee,
      'feeEditCount': 0,
      'profilePic': null,
      'records': records,
      'uid': uid,
      'routine': {},
      'attendance': {},
      'teacherFiles': [],
      'ownFiles': [],
    };

    await db.collection('students').doc(studentId).set(studentData);
  }

  // Update existing student profile
  Future<void> updateStudentProfile({
    required String studentId,
    required String name,
    required String cls,
    required String joinDate,
    required String fixedFee,
  }) async {
    await db.collection('students').doc(studentId).update({
      'name': name,
      'cls': cls,
      'date': joinDate,
      'fixedFee': fixedFee,
    });
  }

  // Delete student
  Future<void> deleteStudent(String studentId) async {
    await db.collection('students').doc(studentId).delete();
  }

  // Save/Update Monthly records
  Future<void> saveMonthlyRecord({
    required String studentId,
    required String month,
    required Map<String, dynamic> monthData,
  }) async {
    await db.collection('students').doc(studentId).update({
      'records.$month': monthData,
    });
  }

  // Save weekly routine
  Future<void> saveRoutine(String studentId, Map<String, dynamic> routine) async {
    await db.collection('students').doc(studentId).update({'routine': routine});
  }

  // Toggle/Update attendance
  Future<void> saveAttendance(String studentId, Map<String, dynamic> attendance) async {
    await db.collection('students').doc(studentId).update({'attendance': attendance});
  }

  // Upload profile picture (Base64 is fine for simple porting, or using bytes)
  Future<void> updateProfilePicUrl(String studentId, String picUrl) async {
    await db.collection('students').doc(studentId).update({'profilePic': picUrl});
  }

  // Upload/Add Teacher Note PDF
  Future<String> uploadTeacherFile(String studentId, Uint8List fileBytes, String fileName) async {
    final path = "teacher_notes/$studentId/${DateTime.now().millisecondsSinceEpoch}_$fileName";
    final ref = storage.ref().child(path);
    await ref.putData(fileBytes, SettableMetadata(contentType: 'application/pdf'));
    return await ref.getDownloadURL();
  }

  Future<void> addTeacherNote(String studentId, Map<String, dynamic> noteData) async {
    await db.collection('students').doc(studentId).update({
      'teacherFiles': FieldValue.arrayUnion([noteData])
    });
  }

  // Upload/Add Student Own File
  Future<String> uploadStudentOwnFile(String studentId, Uint8List fileBytes, String fileName) async {
    final path = "student_own_files/$studentId/${DateTime.now().millisecondsSinceEpoch}_$fileName";
    final ref = storage.ref().child(path);
    await ref.putData(fileBytes);
    return await ref.getDownloadURL();
  }

  Future<void> addOwnFile(String studentId, Map<String, dynamic> fileData) async {
    await db.collection('students').doc(studentId).update({
      'ownFiles': FieldValue.arrayUnion([fileData])
    });
  }

  // Delete Own File
  Future<void> deleteOwnFile(String studentId, int index, String fileName) async {
    final docRef = db.collection('students').doc(studentId);
    final path = "student_own_files/$studentId/$fileName";
    
    // Delete from storage
    try {
      await storage.ref().child(path).delete();
    } catch (e) {
      // It might have failed or been deleted already, ignore to proceed cleaning Firestore
    }

    // Delete from Firestore list
    final snapshot = await docRef.get();
    if (!snapshot.exists) return;
    final data = snapshot.data();
    if (data == null) return;
    final List<dynamic> ownFiles = List<dynamic>.from(data['ownFiles'] ?? []);
    if (index >= 0 && index < ownFiles.length) {
      ownFiles.removeAt(index);
      await docRef.update({'ownFiles': ownFiles});
    }
  }
}
