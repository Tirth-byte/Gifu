/// Supported proof types for Gufi V1.
/// V1 supports ONLY photo and text.
enum ProofType {
  photo,
  text;

  static ProofType fromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'photo':
        return ProofType.photo;
      case 'text':
        return ProofType.text;
      default:
        throw ArgumentError('Unsupported ProofType: $value');
    }
  }

  String toDbString() => name;
}
