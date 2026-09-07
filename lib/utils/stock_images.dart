import 'dart:math';

// D-090: ambient background imagery, ported from Kansei
// (goal-executor/lib/utils/stock_images.dart) for the welcome screen's
// rotating backdrop. randomStockImage() is unused today but ported
// alongside the list since it's the same file Kansei draws it from.
const List<String> kStockImages = [
  'images/stock/stock_00.jpg',
  'images/stock/stock_01.jpg',
  'images/stock/stock_02.jpg',
  'images/stock/stock_03.jpg',
  'images/stock/stock_04.jpg',
  'images/stock/stock_05.jpg',
  'images/stock/stock_06.jpg',
  'images/stock/stock_07.jpg',
  'images/stock/stock_08.jpg',
  'images/stock/stock_09.jpg',
  'images/stock/stock_10.jpg',
  'images/stock/stock_11.jpg',
  'images/stock/stock_12.jpg',
  'images/stock/stock_13.jpg',
  'images/stock/stock_14.jpg',
  'images/stock/stock_15.jpg',
  'images/stock/stock_16.jpg',
  'images/stock/stock_17.jpg',
  'images/stock/stock_18.jpg',
  'images/stock/stock_19.jpg',
];

String randomStockImage([Random? rng]) {
  final r = rng ?? Random();
  return kStockImages[r.nextInt(kStockImages.length)];
}
