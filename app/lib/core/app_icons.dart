import 'package:flutter/material.dart';

/// The backend only accepts these icon keys; each maps to a built-in icon.
/// No images are used anywhere in the app.
class AppIcons {
  AppIcons._();

  static const Map<String, IconData> all = {
    // income sources
    'salary': Icons.work_rounded,
    'freelance': Icons.laptop_mac_rounded,
    'business': Icons.storefront_rounded,
    'gift': Icons.card_giftcard_rounded,
    'investment': Icons.trending_up_rounded,
    'refund': Icons.replay_rounded,
    'rental': Icons.key_rounded,
    'bonus': Icons.stars_rounded,
    'sale': Icons.sell_rounded,
    // expenses
    'food': Icons.restaurant_rounded,
    'groceries': Icons.local_grocery_store_rounded,
    'coffee': Icons.local_cafe_rounded,
    'transport': Icons.directions_bus_rounded,
    'fuel': Icons.local_gas_station_rounded,
    'car': Icons.directions_car_rounded,
    'home': Icons.home_rounded,
    'bills': Icons.receipt_long_rounded,
    'phone': Icons.smartphone_rounded,
    'internet': Icons.wifi_rounded,
    'shopping': Icons.shopping_bag_rounded,
    'clothes': Icons.checkroom_rounded,
    'health': Icons.medical_services_rounded,
    'education': Icons.school_rounded,
    'entertainment': Icons.sports_esports_rounded,
    'sport': Icons.fitness_center_rounded,
    'travel': Icons.flight_rounded,
    'family': Icons.family_restroom_rounded,
    'pets': Icons.pets_rounded,
    'charity': Icons.volunteer_activism_rounded,
    'beauty': Icons.spa_rounded,
    'tools': Icons.build_rounded,
    'subscription': Icons.autorenew_rounded,
    // wallets
    'cash': Icons.payments_rounded,
    'card': Icons.credit_card_rounded,
    'bank': Icons.account_balance_rounded,
    'mobile': Icons.phone_android_rounded,
    'savings': Icons.savings_rounded,
    // generic
    'other': Icons.category_rounded,
  };

  static const incomeKeys = [
    'salary', 'freelance', 'business', 'gift', 'investment', 'refund', 'rental', 'bonus', 'sale', 'other',
  ];

  static const expenseKeys = [
    'food', 'groceries', 'coffee', 'transport', 'fuel', 'car', 'home', 'bills', 'phone', 'internet',
    'shopping', 'clothes', 'health', 'education', 'entertainment', 'sport', 'travel', 'family', 'pets',
    'charity', 'beauty', 'tools', 'subscription', 'gift', 'other',
  ];

  static const walletKeys = ['cash', 'card', 'bank', 'mobile', 'savings'];

  static IconData of(String key) => all[key] ?? Icons.category_rounded;
}
