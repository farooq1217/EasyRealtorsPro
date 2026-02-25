import 'package:flutter/material.dart';

/// Utility class to replace GoogleFonts with local Poppins fonts
class AppFonts {
  // Font family name
  static const String fontFamily = 'Poppins';

  // Text styles that mirror AppFonts.poppins() variations
  static TextStyle poppins({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextDecoration? decoration,
    TextDecorationStyle? decorationStyle,
    Color? decorationColor,
    double? decorationThickness,
    double? height,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.normal,
      color: color,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      decoration: decoration,
      decorationStyle: decorationStyle,
      decorationColor: decorationColor,
      decorationThickness: decorationThickness,
      height: height,
    );
  }

  // Common font styles
  static TextStyle get poppinsRegular => poppins(fontWeight: FontWeight.w400);
  static TextStyle get poppinsMedium => poppins(fontWeight: FontWeight.w500);
  static TextStyle get poppinsSemiBold => poppins(fontWeight: FontWeight.w600);
  static TextStyle get poppinsBold => poppins(fontWeight: FontWeight.w700);

  // Sized variations
  static TextStyle poppinsRegularSize(double fontSize) => 
      poppins(fontSize: fontSize, fontWeight: FontWeight.w400);
  
  static TextStyle poppinsMediumSize(double fontSize) => 
      poppins(fontSize: fontSize, fontWeight: FontWeight.w500);
  
  static TextStyle poppinsSemiBoldSize(double fontSize) => 
      poppins(fontSize: fontSize, fontWeight: FontWeight.w600);
  
  static TextStyle poppinsBoldSize(double fontSize) => 
      poppins(fontSize: fontSize, fontWeight: FontWeight.w700);

  // Common text styles with sizes
  static TextStyle get headline1 => poppins(fontSize: 32, fontWeight: FontWeight.w700);
  static TextStyle get headline2 => poppins(fontSize: 28, fontWeight: FontWeight.w600);
  static TextStyle get headline3 => poppins(fontSize: 24, fontWeight: FontWeight.w600);
  static TextStyle get headline4 => poppins(fontSize: 20, fontWeight: FontWeight.w500);
  static TextStyle get headline5 => poppins(fontSize: 18, fontWeight: FontWeight.w500);
  static TextStyle get headline6 => poppins(fontSize: 16, fontWeight: FontWeight.w500);
  
  static TextStyle get subtitle1 => poppins(fontSize: 16, fontWeight: FontWeight.w500);
  static TextStyle get subtitle2 => poppins(fontSize: 14, fontWeight: FontWeight.w500);
  
  static TextStyle get bodyText1 => poppins(fontSize: 16, fontWeight: FontWeight.w400);
  static TextStyle get bodyText2 => poppins(fontSize: 14, fontWeight: FontWeight.w400);
  
  static TextStyle get button => poppins(fontSize: 14, fontWeight: FontWeight.w500);
  static TextStyle get caption => poppins(fontSize: 12, fontWeight: FontWeight.w400);
  static TextStyle get overline => poppins(fontSize: 10, fontWeight: FontWeight.w400);
}

/// Extension to make it easier to replace AppFonts.poppins calls
extension PoppinsTextStyle on TextStyle {
  TextStyle get poppins => copyWith(fontFamily: 'Poppins');
}
