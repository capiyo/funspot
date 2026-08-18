import 'package:flutter/material.dart';
import '../models/pledge_model.dart';

class PledgeCard extends StatelessWidget {
  final PledgeModel pledge;

  const PledgeCard({super.key, required this.pledge});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        border: Border.all(color: const Color(0xFF064E3B)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pledge.supporter,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF34D399),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pledge.time,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    pledge.amount,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '"${pledge.message}"',
              style: const TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Color(0xFFD1D5DB),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                Icon(Icons.favorite, size: 14, color: Color(0xFF10B981)),
                SizedBox(width: 4),
                Text(
                  'Thank you for your support!',
                  style: TextStyle(fontSize: 12, color: Color(0xFF10B981)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
