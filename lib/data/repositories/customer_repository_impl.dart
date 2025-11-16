import '../../domain/entities/customer.dart';
import '../../domain/repositories/customer_repository.dart';
import '../datasources/database_helper.dart';
import '../models/customer_model.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  final DatabaseHelper _databaseHelper;

  CustomerRepositoryImpl(this._databaseHelper);

  @override
  Future<List<Customer>> getAllCustomers() async {
    final db = await _databaseHelper.database;
    final maps = await db.query('customers', orderBy: 'name COLLATE NOCASE');
    return maps.map((m) => CustomerModel.fromMap(m)).toList();
  }

  @override
  Future<Customer?> getCustomerById(int id) async {
    final db = await _databaseHelper.database;
    final maps = await db.query('customers', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return CustomerModel.fromMap(maps.first);
  }

  @override
  Future<int> insertCustomer(Customer customer) async {
    final db = await _databaseHelper.database;
    final model = CustomerModel.fromEntity(customer);
    final map = model.toMap();
    map.remove('id');
    map['created_at'] = DateTime.now().toIso8601String();
    map['updated_at'] = DateTime.now().toIso8601String();
    return await db.insert('customers', map);
  }

  @override
  Future<int> updateCustomer(Customer customer) async {
    final db = await _databaseHelper.database;
    final model = CustomerModel.fromEntity(customer);
    final map = model.toMap();
    map['updated_at'] = DateTime.now().toIso8601String();
    return await db.update('customers', map, where: 'id = ?', whereArgs: [customer.id]);
  }

  @override
  Future<int> deleteCustomer(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }
}
