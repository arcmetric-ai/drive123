class UserModel {
  UserModel({
    required this.id,
    required this.email,
    this.phone,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.profileImageUrl,
    required this.createdAt,
    required this.updatedAt,
    this.isVerified = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    String _stringOrDefault(dynamic value, [String fallback = '']) {
      if (value == null) return fallback;
      if (value is String) return value;
      if (value is num || value is bool) return value.toString();
      return fallback;
    }

    String? _stringOrNull(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      if (value is num || value is bool) return value.toString();
      return null;
    }

    DateTime _parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String) return DateTime.parse(value);
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value is double) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt());
      }
      throw FormatException('Unsupported date value: $value');
    }

    return UserModel(
      id: json['id'] as String,
      email: _stringOrDefault(json['email']),
      phone: _stringOrNull(json['phone']),
      firstName: _stringOrDefault(json['first_name']),
      lastName: _stringOrDefault(json['last_name']),
      role: _stringOrDefault(json['role']),
      profileImageUrl: _stringOrNull(json['profile_image_url']),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }
  final String id;
  final String email;
  final String? phone;
  final String firstName;
  final String lastName;
  final String role; // 'learner' or 'instructor'
  final String? profileImageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isVerified;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'phone': phone,
      'first_name': firstName,
      'last_name': lastName,
      'role': role,
      'profile_image_url': profileImageUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_verified': isVerified,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? phone,
    String? firstName,
    String? lastName,
    String? role,
    String? profileImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isVerified,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role ?? this.role,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}
