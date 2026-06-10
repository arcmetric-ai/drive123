class SignupFlowState {
  const SignupFlowState({
    required this.email,
    required this.authUserId,
    required this.flowToken,
    this.role = 'learner',
    this.learnerAccountType = 'learner',
  });

  final String email;
  final String authUserId;
  final String flowToken;
  final String role;
  final String learnerAccountType;

  static SignupFlowState fromMap(Map<String, dynamic> map) {
    return SignupFlowState(
      email: (map['email'] as String?) ?? '',
      authUserId: (map['authUserId'] as String?) ?? '',
      flowToken: (map['flowToken'] as String?) ?? '',
      role: (map['role'] as String?) ?? 'learner',
      learnerAccountType: (map['learnerAccountType'] as String?) ?? 'learner',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'authUserId': authUserId,
      'flowToken': flowToken,
      'role': role,
      'learnerAccountType': learnerAccountType,
    };
  }
}
