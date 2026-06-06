enum InstructorDocumentType {
  instructorLicense(
    storageKey: 'instructor_license',
    columnName: 'instructor_license_path',
    title: 'Instructor License',
    uploadTitle: 'Upload Instructor License',
    description:
        'Please provide a clear copy of your certified instructor licence.',
    isRequired: true,
    iconSymbol: 'badge',
  ),
  insuranceDocument(
    storageKey: 'insurance_document',
    columnName: 'insurance_document_path',
    title: 'Insurance Document',
    uploadTitle: 'Upload Insurance Document',
    description:
        'Please provide a clear copy of your current vehicle insurance certificate.',
    isRequired: true,
    iconSymbol: 'shield',
  ),
  backgroundCheck(
    storageKey: 'background_check',
    columnName: 'background_check_path',
    title: 'Background Check',
    uploadTitle: 'Upload Background Check',
    description:
        'Please provide a valid background check document for admin review.',
    isRequired: true,
    iconSymbol: 'person_check',
  ),
  municipalLicense(
    storageKey: 'municipal_license',
    columnName: 'municipal_license_path',
    title: 'Municipal License',
    uploadTitle: 'Upload Municipal License',
    description:
        'Please provide your municipal driving-school licence if you have one.',
    isRequired: false,
    iconSymbol: 'city',
  );

  const InstructorDocumentType({
    required this.storageKey,
    required this.columnName,
    required this.title,
    required this.uploadTitle,
    required this.description,
    required this.isRequired,
    required this.iconSymbol,
  });

  final String storageKey;
  final String columnName;
  final String title;
  final String uploadTitle;
  final String description;
  final bool isRequired;
  final String iconSymbol;

  static InstructorDocumentType? fromName(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final type in InstructorDocumentType.values) {
      if (type.name == value) return type;
    }
    return null;
  }
}
