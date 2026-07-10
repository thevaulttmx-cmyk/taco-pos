import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'database_service.dart';

// Opciones rápidas SIN costo, comunes en un puesto de tacos.
const List<String> quickNoteOptions = [
  'Sin cebolla',
  'Sin cilantro',
  'Con nopales',
  'Con papas',
  'Sin salsa',
  'Con todo',
];

class CustomizationResult {
  final String notes;
  final double extraPrice;
  CustomizationResult({required this.notes, required this.extraPrice});
}

/// Muestra un diálogo para agregar notas y extras con costo a un producto.
/// Devuelve las notas finales + el precio extra a sumar, o null si canceló.
Future<CustomizationResult?> showItemNotesDialog(
  BuildContext context, {
  String? initialNotes,
  required String productName,
}) async {
  final currencyFmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  final selectedQuickNotes = <String>{};
  final selectedExtras = <Extra>{};
  final textController = TextEditingController();
  var extras = await DatabaseService.instance.getExtras();

  if (initialNotes != null && initialNotes.trim().isNotEmpty) {
    final parts = initialNotes.split(',').map((e) => e.trim()).toList();
    for (final part in parts) {
      if (quickNoteOptions.contains(part)) selectedQuickNotes.add(part);
    }
  }

  if (!context.mounted) return null;

  return showDialog<CustomizationResult>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          Future<void> addNewExtra() async {
            final nameController = TextEditingController();
            final priceController = TextEditingController();
            final saved = await showDialog<bool>(
              context: ctx,
              builder: (ctx2) => AlertDialog(
                title: const Text('Nuevo extra con costo'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Nombre (ej. Con queso)'),
                    ),
                    TextField(
                      controller: priceController,
                      decoration: const InputDecoration(labelText: 'Costo adicional'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx2, false), child: const Text('Cancelar')),
                  FilledButton(onPressed: () => Navigator.pop(ctx2, true), child: const Text('Guardar')),
                ],
              ),
            );
            if (saved == true) {
              final name = nameController.text.trim();
              final price = double.tryParse(priceController.text.replaceAll(',', '.'));
              if (name.isEmpty || price == null) return;
              await DatabaseService.instance.insertExtra(Extra(name: name, price: price));
              extras = await DatabaseService.instance.getExtras();
              setState(() {});
            }
          }

          return AlertDialog(
            title: Text('Personalizar: $productName'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (extras.isNotEmpty) ...[
                      Text('Extras con costo', style: Theme.of(ctx).textTheme.titleSmall),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: extras.map((extra) {
                          final isSelected = selectedExtras.any((e) => e.id == extra.id);
                          return FilterChip(
                            label: Text('${extra.name} (+${currencyFmt.format(extra.price)})'),
                            selected: isSelected,
                            selectedColor: Theme.of(ctx).colorScheme.secondary.withOpacity(0.3),
                            onSelected: (value) {
                              setState(() {
                                if (value) {
                                  selectedExtras.add(extra);
                                } else {
                                  selectedExtras.removeWhere((e) => e.id == extra.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: addNewExtra,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Agregar extra nuevo'),
                        ),
                      ),
                      const Divider(height: 20),
                    ] else
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: addNewExtra,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Agregar extra con costo'),
                        ),
                      ),
                    Text('Sin costo', style: Theme.of(ctx).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: quickNoteOptions.map((option) {
                        final isSelected = selectedQuickNotes.contains(option);
                        return FilterChip(
                          label: Text(option),
                          selected: isSelected,
                          onSelected: (value) {
                            setState(() {
                              if (value) {
                                selectedQuickNotes.add(option);
                              } else {
                                selectedQuickNotes.remove(option);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: textController,
                      decoration: const InputDecoration(
                        labelText: 'Otra indicación (opcional)',
                        hintText: 'Ej. bien dorado',
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              FilledButton(
                onPressed: () {
                  final parts = <String>[
                    ...selectedExtras.map((e) => '${e.name} (+${currencyFmt.format(e.price)})'),
                    ...selectedQuickNotes,
                  ];
                  if (textController.text.trim().isNotEmpty) {
                    parts.add(textController.text.trim());
                  }
                  final extraPrice = selectedExtras.fold<double>(0, (sum, e) => sum + e.price);
                  Navigator.pop(ctx, CustomizationResult(notes: parts.join(', '), extraPrice: extraPrice));
                },
                child: const Text('Agregar'),
              ),
            ],
          );
        },
      );
    },
  );
}
