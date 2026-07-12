import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:life_ops/theme/app_colors.dart';

class NavBar extends StatefulWidget implements PreferredSizeWidget {
  final Widget? title;
  final Widget? leading;
  final double elevation;
  final String currentScreen;

  const NavBar({
    Key? key,
    this.title,
    this.leading,
    this.elevation = 2.0,
    this.currentScreen = '',
  }) : super(key: key);

  @override
  NavBarState createState() => NavBarState(currentScreen, elevation, leading);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class NavBarState extends State<NavBar> {
  final String currentScreen;
  final double elevation;
  final Widget? leading;

  NavBarState(this.currentScreen, this.elevation, this.leading);

  @override
  Widget build(BuildContext context) {
    const String logo = 'images/svg/logo_green.svg';
    final Widget svgLogo = SvgPicture.asset(logo,
        height: 40,
        width: 40,
        fit: BoxFit.scaleDown,
        colorFilter: const ColorFilter.mode(AppColors.brandGreen, BlendMode.srcIn),
        semanticsLabel: 'Green Pyramid Logo');

    Widget? navBarLeading;

    if (leading == null) {
      navBarLeading = BackButton(
        color: Colors.white,
        onPressed: () => {Navigator.pop(context)},
      );
    } else {
      navBarLeading = leading;
    }

    return Material(
      elevation: elevation,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: AppColors.appBarGradient,
          ),
        ),
        child: AppBar(
          centerTitle: true,
          leading: navBarLeading,
          elevation: 0.0,
          title: svgLogo,
          backgroundColor: Colors.transparent,
        ),
      ),
    );
  }
}
