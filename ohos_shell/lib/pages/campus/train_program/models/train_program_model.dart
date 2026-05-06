class College {
  final String value;
  final String name;

  College({required this.value, required this.name});

  factory College.fromOption(String value, String name) {
    return College(value: value, name: name);
  }
}

class Grade {
  final String value;
  final String label;

  Grade({required this.value, required this.label});

  factory Grade.fromOption(String value, String label) {
    return Grade(value: value, label: label);
  }
}
