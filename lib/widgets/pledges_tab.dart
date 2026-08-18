import 'package:flutter/material.dart';
import '../models/pledge_model.dart';
import 'pledges_card.dart';

class PledgesTab extends StatelessWidget {
  const PledgesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final pledges = [
      PledgeModel(
        supporter: 'John Doe',
        amount: '\$50',
        message: 'Always supporting the team! Let\'s go!',
        time: '1 hour ago',
      ),
      PledgeModel(
        supporter: 'Sarah Miller',
        amount: '\$100',
        message: 'Proud to be part of this community',
        time: '3 hours ago',
      ),
      PledgeModel(
        supporter: 'Mike Johnson',
        amount: '\$25',
        message: 'Every bit helps. Go team!',
        time: '6 hours ago',
      ),
      PledgeModel(
        supporter: 'Emma Wilson',
        amount: '\$75',
        message: 'Together we are stronger!',
        time: '8 hours ago',
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pledges.length,
      itemBuilder: (context, index) {
        return PledgeCard(pledge: pledges[index]);
      },
    );
  }
}
