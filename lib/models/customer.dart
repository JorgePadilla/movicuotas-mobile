class Customer {
  final int id;
  final String identificationNumber;
  final String fullName;
  final String? email;
  final String phone;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? address;
  final String? city;
  final String status;

  Customer({
    required this.id,
    required this.identificationNumber,
    required this.fullName,
    this.email,
    required this.phone,
    this.dateOfBirth,
    this.gender,
    this.address,
    this.city,
    required this.status,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as int,
      identificationNumber: json['identification_number'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'] as String)
          : null,
      gender: json['gender'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      status: json['status'] as String,
    );
  }

  bool get isActive => status == 'active';
}
