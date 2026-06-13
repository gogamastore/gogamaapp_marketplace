import 'package:cloud_firestore/cloud_firestore.dart';

class BankAccount {
  final String id;
  final String bankName;
  final String accountNumber;
  final String accountHolder;

  BankAccount({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    required this.accountHolder,
  });

  factory BankAccount.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return BankAccount(
      id: doc.id,
      bankName: data['bankName'] ?? '',
      accountNumber: data['accountNumber'] ?? '',
      accountHolder: data['accountHolder'] ?? '',
    );
  }
}
