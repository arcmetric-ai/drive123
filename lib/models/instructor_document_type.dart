enum InstructorDocumentType {
  instructorLicense(
    storageKey: 'instructor_license',
    columnName: 'instructor_license_path',
    expiryColumnName: 'instructor_license_expires_at',
    title: 'Instructor License',
    uploadTitle: 'Upload Instructor License',
    description:
        'Please provide a clear copy of your certified instructor licence.',
    isRequired: true,
    requiresExpiry: true,
    iconSymbol: 'badge',
  ),
  insuranceDocument(
    storageKey: 'insurance_document',
    columnName: 'insurance_document_path',
    expiryColumnName: 'insurance_document_expires_at',
    title: '6D Insurance Document',
    uploadTitle: 'Upload 6D Insurance Document',
    description:
        'Please provide a clear copy of your current vehicle insurance certificate.',
    isRequired: true,
    requiresExpiry: true,
    iconSymbol: 'shield',
  ),
  backgroundCheck(
    storageKey: 'background_check',
    columnName: 'background_check_path',
    expiryColumnName: null,
    title: 'Background Check',
    uploadTitle: 'Upload Background Check',
    description:
        'Please provide a valid background check document for admin review.',
    isRequired: true,
    requiresExpiry: false,
    iconSymbol: 'person_check',
  ),
  municipalLicense(
    storageKey: 'municipal_license',
    columnName: 'municipal_license_path',
    expiryColumnName: 'municipal_license_expires_at',
    title: 'Municipal License',
    uploadTitle: 'Upload Municipal License',
    description:
        'Please provide your municipal driving-school licence if you have one.',
    isRequired: false,
    requiresExpiry: true,
    iconSymbol: 'city',
  );

  const InstructorDocumentType({
    required this.storageKey,
    required this.columnName,
    required this.expiryColumnName,
    required this.title,
    required this.uploadTitle,
    required this.description,
    required this.isRequired,
    required this.requiresExpiry,
    required this.iconSymbol,
  });

  final String storageKey;
  final String columnName;
  final String? expiryColumnName;
  final String title;
  final String uploadTitle;
  final String description;
  final bool isRequired;
  final bool requiresExpiry;
  final String iconSymbol;

  static InstructorDocumentType? fromName(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final type in InstructorDocumentType.values) {
      if (type.name == value) return type;
    }
    return null;
  }
}
