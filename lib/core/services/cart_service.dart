import 'package:flutter/foundation.dart';
import '../../models/offer.dart';

class CartService extends ChangeNotifier {
  final Map<String, Offer> _items = {};

  List<Offer> get items => _items.values.toList();

  double get totalAmount =>
      _items.values.fold(0, (sum, item) => sum + item.price);

  bool contains(String offerId) {
    return _items.containsKey(offerId);
  }

  void add(Offer offer) {
    if (!_items.containsKey(offer.id)) {
      _items[offer.id] = offer;
      notifyListeners();
    }
  }

  void remove(String offerId) {
    if (_items.containsKey(offerId)) {
      _items.remove(offerId);
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
