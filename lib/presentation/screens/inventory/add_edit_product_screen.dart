import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../providers/product_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/currency_provider.dart';
import '../../../domain/entities/product.dart';
import '../../../domain/entities/category.dart';
import '../../../core/constants/app_constants.dart';
import '../barcode_scanner_screen.dart';

class AddEditProductScreen extends StatefulWidget {
  final Product? product;
  final String? barcode;

  const AddEditProductScreen({super.key, this.product, this.barcode});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _stockController = TextEditingController();

  int? _selectedCategoryId;
  String? _imagePath;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    // Delay initialization to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCategories();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _barcodeController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  void _initializeForm() {
    if (_isEditing) {
      final product = widget.product!;
      _nameController.text = product.name;
      _descriptionController.text = product.description ?? '';
      _costPriceController.text = product.costPrice.toString();
      _sellingPriceController.text = product.sellingPrice.toString();
      _barcodeController.text = product.barcode ?? '';
      _stockController.text = product.stockQuantity.toString();
      _selectedCategoryId = product.categoryId;
      _imagePath = product.imagePath;
    } else if (widget.barcode != null) {
      // Pre-fill barcode if provided from scanner
      _barcodeController.text = widget.barcode!;
    }
  }

  Future<void> _loadCategories() async {
    final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
    await categoryProvider.loadCategories();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Product' : 'Add Product'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _showDeleteConfirmation,
              tooltip: 'Delete Product',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product Image Section
              _buildImageSection(theme),
              const SizedBox(height: AppConstants.spacingLarge),

              // Basic Information
              _buildBasicInfoSection(theme),
              const SizedBox(height: AppConstants.spacingLarge),

              // Pricing Information
              _buildPricingSection(theme),
              const SizedBox(height: AppConstants.spacingLarge),

              // Stock Information
              _buildStockSection(theme),
              const SizedBox(height: AppConstants.spacingLarge),

              // Additional Information
              _buildAdditionalInfoSection(theme),
              const SizedBox(height: AppConstants.spacingXLarge),

              // Action Buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Product Image',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.5),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                          child: Image.file(
                            _imageFile!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildImagePlaceholder(theme);
                            },
                          ),
                        )
                      : _imagePath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
                              child: File(_imagePath!).existsSync()
                                  ? Image.file(
                                      File(_imagePath!),
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return _buildImagePlaceholder(theme);
                                      },
                                    )
                                  : Image.asset(
                                      _imagePath!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return _buildImagePlaceholder(theme);
                                      },
                                    ),
                            )
                          : _buildImagePlaceholder(theme),
                ),
              ),
            ),
            if (_imagePath != null || _imageFile != null) ...[
              const SizedBox(height: AppConstants.spacingMedium),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _imagePath = null;
                      _imageFile = null;
                    });
                  },
                  icon: const Icon(Icons.delete),
                  label: const Text('Remove Image'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_a_photo,
          size: 32,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: AppConstants.spacingSmall),
        Text(
          'Add Photo',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildBasicInfoSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Information',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Product Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory_2),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Product name is required';
                }
                if (value.trim().length < 2) {
                  return 'Product name must be at least 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            Consumer<CategoryProvider>(
              builder: (context, categoryProvider, child) {
                return DropdownButtonFormField<int>(
                  value: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Category *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: categoryProvider.categories.map((Category category) {
                    return DropdownMenuItem<int>(
                      value: category.id,
                      child: Text(category.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategoryId = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a category';
                    }
                    return null;
                  },
                );
              },
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pricing Information',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            Row(
              children: [
                Expanded(
                  child: Consumer<CurrencyProvider>(
                    builder: (context, currencyProvider, child) {
                      return TextFormField(
                        controller: _costPriceController,
                        decoration: InputDecoration(
                          labelText: 'Cost Price *',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.attach_money),
                          prefixText: '${currencyProvider.selectedCurrency.symbol} ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Cost price is required';
                          }
                          final price = double.tryParse(value);
                          if (price == null || price < 0) {
                            return 'Enter a valid price';
                          }
                          return null;
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: AppConstants.spacingMedium),
                Expanded(
                  child: Consumer<CurrencyProvider>(
                    builder: (context, currencyProvider, child) {
                      return TextFormField(
                        controller: _sellingPriceController,
                        decoration: InputDecoration(
                          labelText: 'Selling Price *',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.sell),
                          prefixText: '${currencyProvider.selectedCurrency.symbol} ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Selling price is required';
                          }
                          final price = double.tryParse(value);
                          if (price == null || price < 0) {
                            return 'Enter a valid price';
                          }
                          return null;
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            // Profit Calculation Display
            ValueListenableBuilder(
              valueListenable: _costPriceController,
              builder: (context, costValue, child) {
                return ValueListenableBuilder(
                  valueListenable: _sellingPriceController,
                  builder: (context, sellingValue, child) {
                    final costPrice = double.tryParse(costValue.text) ?? 0;
                    final sellingPrice = double.tryParse(sellingValue.text) ?? 0;
                    final profit = sellingPrice - costPrice;
                    final profitMargin = costPrice > 0 ? (profit / costPrice) * 100 : 0;

                    return Container(
                      padding: const EdgeInsets.all(AppConstants.paddingMedium),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Profit per Unit',
                                style: theme.textTheme.bodySmall,
                              ),
                              Consumer<CurrencyProvider>(
                                builder: (context, currencyProvider, child) {
                                  return Text(
                                    currencyProvider.formatPrice(profit),
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: profit >= 0 ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Profit Margin',
                                style: theme.textTheme.bodySmall,
                              ),
                              Text(
                                '${profitMargin.toStringAsFixed(1)}%',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: profitMargin >= 0 ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stock Information',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            TextFormField(
              controller: _stockController,
              decoration: const InputDecoration(
                labelText: 'Stock Quantity *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory),
                suffixText: 'units',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Stock quantity is required';
                }
                final stock = int.tryParse(value);
                if (stock == null || stock < 0) {
                  return 'Enter a valid stock quantity';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalInfoSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Additional Information',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            TextFormField(
              controller: _barcodeController,
              decoration: InputDecoration(
                labelText: 'Barcode',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.qr_code),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _scanBarcode,
                  tooltip: 'Scan Barcode',
                ),
              ),
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  // Basic barcode validation (you can make this more specific)
                  if (value.length < 8) {
                    return 'Barcode must be at least 8 characters';
                  }
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: _isLoading ? null : _saveProduct,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingMedium),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditing ? 'Update Product' : 'Add Product'),
        ),
        const SizedBox(height: AppConstants.spacingMedium),
        OutlinedButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: AppConstants.paddingMedium),
          ),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        // Save image to app directory
        final String savedImagePath = await _saveImageToAppDirectory(image);
        
        setState(() {
          _imageFile = File(image.path);
          _imagePath = savedImagePath; // Store the permanent path
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String> _saveImageToAppDirectory(XFile image) async {
    try {
      // Get app documents directory
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final Directory imagesDir = Directory('${appDocDir.path}/product_images');
      
      // Create images directory if it doesn't exist
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      
      // Generate unique filename
      final String fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String savedPath = '${imagesDir.path}/$fileName';
      
      // Copy image to app directory
      final File imageFile = File(image.path);
      await imageFile.copy(savedPath);
      
      return savedPath;
    } catch (e) {
      throw Exception('Failed to save image: $e');
    }
  }

  void _scanBarcode() async {
    try {
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => const BarcodeScannerScreen(),
        ),
      );
      
      if (result != null && result.isNotEmpty) {
        setState(() {
          _barcodeController.text = result;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening barcode scanner: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);

      // Check if product name already exists (for new products or when name changed)
      if (!_isEditing || _nameController.text.trim() != widget.product!.name) {
        final nameExists = await productProvider.checkProductNameExists(_nameController.text.trim());
        if (nameExists) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('A product with this name already exists')),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // Check if barcode already exists (if barcode is provided)
      if (_barcodeController.text.trim().isNotEmpty) {
        if (!_isEditing || _barcodeController.text.trim() != (widget.product!.barcode ?? '')) {
          final barcodeExists = await productProvider.checkBarcodeExists(_barcodeController.text.trim());
          if (barcodeExists) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('A product with this barcode already exists')),
            );
            setState(() {
              _isLoading = false;
            });
            return;
          }
        }
      }

      final product = Product(
        id: _isEditing ? widget.product!.id : null,
        name: _nameController.text.trim(),
        imagePath: _imagePath,
        categoryId: _selectedCategoryId!,
        costPrice: double.parse(_costPriceController.text),
        sellingPrice: double.parse(_sellingPriceController.text),
        barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
        stockQuantity: int.parse(_stockController.text),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        createdAt: _isEditing ? widget.product!.createdAt : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (_isEditing) {
        await productProvider.updateProduct(product);
      } else {
        await productProvider.addProduct(product);
      }

      if (productProvider.error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Product updated successfully' : 'Product added successfully'),
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${productProvider.error}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${widget.product!.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              setState(() {
                _isLoading = true;
              });

              final productProvider = Provider.of<ProductProvider>(context, listen: false);
              await productProvider.deleteProduct(widget.product!.id!);
              
              if (productProvider.error == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Product deleted successfully')),
                );
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${productProvider.error}')),
                );
                setState(() {
                  _isLoading = false;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
