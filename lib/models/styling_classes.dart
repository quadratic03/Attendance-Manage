import 'package:flutter/material.dart';

class ItemStyling {
  final Color backgroundColor;
  final Color sectionHeaderBackground;
  final Color listItemBorder;
  final Color cardBackground;

  ItemStyling({
    required this.backgroundColor,
    required this.sectionHeaderBackground,
    required this.listItemBorder,
    required this.cardBackground,
  });
}

class LearnersItemStyling extends ItemStyling {
  LearnersItemStyling({
    required Color backgroundColor,
    required Color sectionHeaderBackground,
    required Color listItemBorder,
    required Color cardBackground,
  }) : super(
          backgroundColor: backgroundColor,
          sectionHeaderBackground: sectionHeaderBackground,
          listItemBorder: listItemBorder,
          cardBackground: cardBackground,
        );
}

class ReportsItemStyling extends ItemStyling {
  ReportsItemStyling({
    required Color sectionHeaderBackground,
    required Color cardBackground,
    Color backgroundColor = Colors.white,
    Color listItemBorder = Colors.grey,
  }) : super(
          backgroundColor: backgroundColor,
          sectionHeaderBackground: sectionHeaderBackground,
          listItemBorder: listItemBorder,
          cardBackground: cardBackground,
        );
}