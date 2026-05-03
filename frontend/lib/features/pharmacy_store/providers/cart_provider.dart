import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pharmacy_store_models.dart';

class CartState {
  final String? pharmacyId;
  final String? pharmacyName;
  final double deliveryFee;
  final List<CartItem> items;

  const CartState({
    this.pharmacyId,
    this.pharmacyName,
    this.deliveryFee = 0,
    this.items = const [],
  });

  double get subtotal => items.fold(0, (sum, item) => sum + item.total);
  double get total => subtotal + deliveryFee;
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  CartState copyWith({
    String? pharmacyId,
    String? pharmacyName,
    double? deliveryFee,
    List<CartItem>? items,
  }) =>
      CartState(
        pharmacyId: pharmacyId ?? this.pharmacyId,
        pharmacyName: pharmacyName ?? this.pharmacyName,
        deliveryFee: deliveryFee ?? this.deliveryFee,
        items: items ?? this.items,
      );
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  void setPharmacy({
    required String pharmacyId,
    required String pharmacyName,
    required double deliveryFee,
  }) {
    if (state.pharmacyId != pharmacyId) {
      // Switching pharmacy clears cart
      state = CartState(
        pharmacyId: pharmacyId,
        pharmacyName: pharmacyName,
        deliveryFee: deliveryFee,
      );
    }
  }

  void addItem(PharmacyProduct product) {
    final items = [...state.items];
    final idx = items.indexWhere((e) => e.product.id == product.id);
    if (idx >= 0) {
      items[idx].quantity++;
    } else {
      items.add(CartItem(product: product));
    }
    state = state.copyWith(items: items);
  }

  void removeItem(int productId) {
    final items = state.items.where((e) => e.product.id != productId).toList();
    state = state.copyWith(items: items);
  }

  void updateQuantity(int productId, int quantity) {
    if (quantity < 1) {
      removeItem(productId);
      return;
    }
    final items = [...state.items];
    final idx = items.indexWhere((e) => e.product.id == productId);
    if (idx >= 0) {
      items[idx].quantity = quantity;
      state = state.copyWith(items: items);
    }
  }

  void clear() {
    state = CartState(
      pharmacyId: state.pharmacyId,
      pharmacyName: state.pharmacyName,
      deliveryFee: state.deliveryFee,
    );
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>(
  (ref) => CartNotifier(),
);
