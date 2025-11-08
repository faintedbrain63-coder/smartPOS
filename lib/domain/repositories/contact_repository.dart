import '../entities/owner_contact.dart';

abstract class ContactRepository {
  Future<List<OwnerContact>> getAllContacts();
  Future<int> insertContact(OwnerContact contact);
  Future<int> deleteContact(int id);
  Future<bool> contactExists(String contactNumber);
  Future<OwnerContact?> getContactById(int id);
  Future<int> updateContact(OwnerContact contact);
}