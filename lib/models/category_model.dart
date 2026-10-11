import 'package:flutter/material.dart';

class CategoryModel {
  final String id;
  final String name;
  final int? itemCount;
  final IconData? icon;

  const CategoryModel({
    required this.id,
    required this.name,
    this.itemCount,
    this.icon,
  });
}
