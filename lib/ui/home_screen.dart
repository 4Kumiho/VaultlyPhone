import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/analytics.dart';
import '../core/app_data.dart';
import '../core/models.dart';
import '../core/money.dart';
import 'accounts_tab.dart';
import 'more_tab.dart';
import 'tags_tab.dart';
import 'vault_tab.dart';
import 'widgets.dart';

/// App dell'utente connesso: quattro sezioni con la barra di navigazione in basso.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onLogout});
  final VoidCallback onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // All'accesso: avviso se ci sono tetti di spesa superati o quasi.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) warnAboutBudgets(context, context.read<AppData>());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          const AccountsTab(),
          const TagsTab(),
          const VaultTab(),
          MoreTab(onLogout: widget.onLogout),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Conti'),
          NavigationDestination(icon: Icon(Icons.sell_outlined), selectedIcon: Icon(Icons.sell), label: 'Etichette'),
          NavigationDestination(icon: Icon(Icons.lock_outline), selectedIcon: Icon(Icons.lock), label: 'Password'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Altro'),
        ],
      ),
    );
  }
}

/// Avvisa se le etichette con tetto (tutte, o solo `onlyTags`) sono all'80% o oltre.
void warnAboutBudgets(BuildContext context, AppData data, {List<String>? onlyTags}) {
  final over = <String>[];
  final near = <String>[];
  for (final tag in data.tags) {
    if (tag.budget == null) continue;
    if (onlyTags != null && !onlyTags.any((t) => t.toLowerCase() == tag.name.toLowerCase())) continue;
    final s = data.budgetStatus(tag);
    if (s.finished || s.upcoming) continue;
    final c = currencyFor(tag.currency);
    final line = '"${tag.name}" ${Money.format(s.spent, c)} su ${Money.format(s.budget, c)}';
    if (s.level == BudgetLevel.over) over.add(line);
    if (s.level == BudgetLevel.warning) near.add(line);
  }
  if (over.isNotEmpty) {
    showToast(context, 'Tetto di spesa superato: ${over.join(', ')}', tone: 'danger');
  } else if (near.isNotEmpty) {
    showToast(context, 'Quasi al tetto di spesa: ${near.join(', ')}', tone: 'warning');
  }
}
