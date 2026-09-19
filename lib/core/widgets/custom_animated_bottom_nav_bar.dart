import 'package:flutter/material.dart';
import 'package:skore_hodimlar/core/widgets/animated_rotating_ring.dart';

class CustomBottomNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isCenter;

  const CustomBottomNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.isCenter = false,
  });
}

class CustomAnimatedBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;
  final List<CustomBottomNavItem> items;

  const CustomAnimatedBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(left: 12, right: 12, bottom: 10, top: 4),
        height: 68,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: List.generate(items.length, (index) {
            final isSelected = selectedIndex == index;
            final item = items[index];

            return Expanded(
              child: GestureDetector(
                onTap: () => onItemTapped(index),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon Slot - Fixed 36x36 Box on exact same line
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: Center(
                        child: isSelected
                            ? AnimatedRotatingRing(
                                size: 36,
                                borderWidth: 2,
                                gradientColors: const [
                                  Color(0xFF0D6E6E),
                                  Color(0xFF139797),
                                  Color(0xFF26BBAA),
                                  Color(0xFF0D6E6E),
                                ],
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF0D6E6E),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    item.selectedIcon,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              )
                            : Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                child: Icon(
                                  item.icon,
                                  color: Colors.grey.shade500,
                                  size: 20,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Label Slot
                    SizedBox(
                      height: 14,
                      child: Center(
                        child: Text(
                          item.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? const Color(0xFF0D6E6E)
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
