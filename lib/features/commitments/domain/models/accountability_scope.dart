/// Represents whether a commitment is held to an accountability circle or kept private.
enum AccountabilityScope {
  circle,
  private;

  static AccountabilityScope fromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'circle':
        return AccountabilityScope.circle;
      case 'private':
        return AccountabilityScope.private;
      default:
        throw ArgumentError('Unknown AccountabilityScope: $value');
    }
  }

  String toDbString() => name;

  bool get isCircle => this == AccountabilityScope.circle;
  bool get isPrivate => this == AccountabilityScope.private;
}
