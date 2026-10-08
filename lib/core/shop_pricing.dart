/// Informational retail price only. Order totals always use ProductData.price.
/// Integer arithmetic gives half-up rounding to kopecks, including on web.
double shopSalePrice(double purchasePrice, double markupPercent) {
  final cents = BigInt.from((purchasePrice * 100).round());
  final percentHundredths = BigInt.from((markupPercent * 100).round());
  final scale = BigInt.from(10000);
  final result =
      (cents * (scale + percentHundredths) + BigInt.from(5000)) ~/ scale;
  return result.toDouble() / 100;
}
