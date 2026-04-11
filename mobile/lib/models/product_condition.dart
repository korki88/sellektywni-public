enum ProductCondition {
  newItem,
  outlet,
  used,
}

extension ProductConditionX on ProductCondition {
  String get label => switch (this) {
        ProductCondition.newItem => 'Nowe',
        ProductCondition.outlet => 'Outlet',
        ProductCondition.used => 'Używane',
      };
}
