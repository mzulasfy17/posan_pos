import 'package:intl/intl.dart';

/// Status absensi karyawan
enum AttendanceStatus {
  notCheckedIn, // Belum Absen
  working,      // Sedang Bekerja
  completed,    // Selesai Bekerja
}

extension AttendanceStatusExtension on AttendanceStatus {
  String get label {
    switch (this) {
      case AttendanceStatus.notCheckedIn:
        return 'Belum Absen';
      case AttendanceStatus.working:
        return 'Sedang Bekerja';
      case AttendanceStatus.completed:
        return 'Selesai Bekerja';
    }
  }

  String get badgeText {
    switch (this) {
      case AttendanceStatus.notCheckedIn:
        return 'Belum Masuk';
      case AttendanceStatus.working:
        return 'Aktif Bekerja';
      case AttendanceStatus.completed:
        return 'Shift Selesai';
    }
  }
}

/// Model data rekaman absensi karyawan
class AttendanceRecordModel {
  final String id;
  final String userId;
  final String userName;
  final String role;
  final DateTime date;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final AttendanceStatus status;
  final String? notes;

  const AttendanceRecordModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.role,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    required this.status,
    this.notes,
  });

  /// Menghitung durasi kerja secara dinamis
  Duration? get duration {
    if (checkInTime == null) return null;
    final end = checkOutTime ?? DateTime.now();
    return end.isAfter(checkInTime!) ? end.difference(checkInTime!) : Duration.zero;
  }

  /// Format string durasi kerja yang mudah dibaca (misal: "8 jam 15 menit")
  String get formattedDuration {
    if (checkInTime == null) return '-';
    
    // Jika belum checkout dan belum selesai, hitung waktu berjalan
    final end = checkOutTime;
    if (end == null) {
      if (status == AttendanceStatus.working) {
        final diff = DateTime.now().difference(checkInTime!);
        final hours = diff.inHours;
        final minutes = diff.inMinutes.remainder(60);
        if (hours > 0) {
          return '$hours jam $minutes mnt (berjalan)';
        }
        return '$minutes mnt (berjalan)';
      }
      return '-';
    }

    final diff = end.difference(checkInTime!);
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);

    if (hours > 0 && minutes > 0) {
      return '$hours jam $minutes mnt';
    } else if (hours > 0) {
      return '$hours jam';
    } else {
      return '$minutes mnt';
    }
  }

  /// Format tanggal Indonesia (misal: "11 Okt 2026")
  String get formattedDate {
    return DateFormat('d MMM yyyy', 'id_ID').format(date);
  }

  /// Format hari dan tanggal lengkap (misal: "Senin, 12 Oktober 2026")
  String get formattedFullDate {
    return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date);
  }

  /// Format jam masuk (24 jam, misal: "08:15")
  String get formattedCheckIn {
    if (checkInTime == null) return '--:--';
    return DateFormat('HH:mm').format(checkInTime!);
  }

  /// Format jam keluar (24 jam, misal: "17:00")
  String get formattedCheckOut {
    if (checkOutTime == null) return '--:--';
    return DateFormat('HH:mm').format(checkOutTime!);
  }

  AttendanceRecordModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? role,
    DateTime? date,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    AttendanceStatus? status,
    String? notes,
  }) {
    return AttendanceRecordModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      role: role ?? this.role,
      date: date ?? this.date,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'role': role,
      'date': date.toIso8601String(),
      'check_in_time': checkInTime?.toIso8601String(),
      'check_out_time': checkOutTime?.toIso8601String(),
      'status': status.name,
      'notes': notes,
    };
  }

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) {
    AttendanceStatus parsedStatus = AttendanceStatus.notCheckedIn;
    final statusStr = json['status']?.toString();
    if (statusStr == 'working' || statusStr == 'Sedang Bekerja') {
      parsedStatus = AttendanceStatus.working;
    } else if (statusStr == 'completed' || statusStr == 'Selesai Bekerja') {
      parsedStatus = AttendanceStatus.completed;
    }

    return AttendanceRecordModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? 'Karyawan',
      role: json['role']?.toString() ?? 'kasir',
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      checkInTime: json['check_in_time'] != null
          ? DateTime.tryParse(json['check_in_time'].toString())
          : null,
      checkOutTime: json['check_out_time'] != null
          ? DateTime.tryParse(json['check_out_time'].toString())
          : null,
      status: parsedStatus,
      notes: json['notes']?.toString(),
    );
  }
}
