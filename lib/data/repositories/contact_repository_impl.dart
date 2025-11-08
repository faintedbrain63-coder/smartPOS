import '../../domain/entities/owner_contact.dart';
import '../../domain/repositories/contact_repository.dart';
import '../datasources/database_helper.dart';
import '../models/owner_contact_model.dart';

class ContactRepositoryImpl implements ContactRepository {
  final DatabaseHelper _databaseHelper;

  ContactRepositoryImpl(this._databaseHelper);

  @override
  Future<List<OwnerContact>> getAllContacts() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'owner_contacts',
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) {
      return OwnerContactModel.fromMap(maps[i]);
    });
  }

  @override
  Future<int> insertContact(OwnerContact contact) async {
    final db = await _databaseHelper.database;
    final contactModel = OwnerContactModel.fromEntity(contact);
    
    final contactMap = contactModel.toMap();
    contactMap.remove('id'); // Remove id for auto-increment
    contactMap['created_at'] = DateTime.now().toIso8601String();
    contactMap['updated_at'] = DateTime.now().toIso8601String();
    
    return await db.insert('owner_contacts', contactMap);
  }

  @override
  Future<int> deleteContact(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'owner_contacts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<bool> contactExists(String contactNumber) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'owner_contacts',
      where: 'contact_number = ?',
      whereArgs: [contactNumber],
      limit: 1,
    );
    
    return maps.isNotEmpty;
  }

  @override
  Future<OwnerContact?> getContactById(int id) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'owner_contacts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return OwnerContactModel.fromMap(maps.first);
    }
    return null;
  }

  @override
  Future<int> updateContact(OwnerContact contact) async {
    final db = await _databaseHelper.database;
    final contactModel = OwnerContactModel.fromEntity(contact);
    
    final contactMap = contactModel.toMap();
    contactMap['updated_at'] = DateTime.now().toIso8601String();
    
    return await db.update(
      'owner_contacts',
      contactMap,
      where: 'id = ?',
      whereArgs: [contact.id],
    );
  }
}