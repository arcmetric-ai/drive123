class SignupFlowState {
  const SignupFlowState({
    required this.email,
    required this.authUserId,
    required this.flowToken,
  });

  final String email;
  final String authUserId;
  final String flowToken;

  static SignupFlowState fromMap(Map<String, dynamic> map) {
    return SignupFlowState(
      email: (map['email'] as String?) ?? '',
      authUserId: (map['authUserId'] as String?) ?? '',
      flowToken: (map['flowToken'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'authUserId': authUserId,
      'flowToken': flowToken,
    };
  }
}
