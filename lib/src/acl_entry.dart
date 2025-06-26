class AclEntry {
  final String type;
  final String id;
  final String displayName;
  final int permissions;

  const AclEntry(
      {required this.type,
      required this.id,
      required this.displayName,
      required this.permissions});
}
