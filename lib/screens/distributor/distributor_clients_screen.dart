import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/data_repository.dart';
import '../../services/pagination_controller.dart';
import '../../widgets/common/paginated_list_view.dart';
import '../../widgets/common/premium_icon_badge.dart';

class DistributorClientsScreen extends StatefulWidget {
  const DistributorClientsScreen({super.key});

  @override
  State<DistributorClientsScreen> createState() => _DistributorClientsScreenState();
}

class _DistributorClientsScreenState extends State<DistributorClientsScreen> {
  final DataRepository _repo = DataRepository();
  late final PaginationController<Client> _controller;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Поиск идёт на сервере — иначе фильтр видел бы только текущую страницу.
    _controller = PaginationController<Client>(
      fetchPage: (page) => _repo.distributorClients(
        page: page,
        search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      ),
    );
    _searchCtrl.addListener(_controller.refreshDebounced);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        title: const Text('КЛИЕНТЫ РЕГИОНА', style: TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.w900)),
      ),
      body: Column(
        children: [
          _buildSearch(),
          Expanded(
            child: PaginatedListView<Client>(
              controller: _controller,
              emptyMessage: 'КЛИЕНТЫ НЕ НАЙДЕНЫ',
              itemBuilder: (context, client, _) => ClientListCard(client: client),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Container(
      color: const Color(0xFF171717),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'ПОИСК ПО НАЗВАНИЮ ИЛИ ИНН',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12, fontWeight: FontWeight.bold),
          prefixIcon: const Icon(Icons.search, color: Color(0xFFF01D2C)),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: const OutlineInputBorder(borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }
}

class ClientListCard extends StatelessWidget {
  final Client client;
  const ClientListCard({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            client.name.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF171717)),
          ),
          subtitle: Row(
            children: [
              Text('ИНН ${client.inn}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              _statusBadge(client.status),
            ],
          ),
          leading: const PremiumIconBadge(
            icon: Icons.business_outlined,
            size: 40,
            iconSize: 20,
          ),
          children: [
            const Divider(height: 1, color: Color(0xFF171717)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('ГОРОД', client.city),
                  _infoRow('РЕГИОН', client.region),
                  _infoRow('КОНТАКТ', client.contact),
                  _infoRow('ТЕЛЕФОН', client.phone),
                  _infoRow('ЗАКУПКИ', '${client.totalPurchases.toStringAsFixed(0)} ₽'),

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(ClientStatus status) {
    Color color = Colors.grey;
    String label = 'НОВЫЙ';
    
    switch (status) {
      case ClientStatus.active:
        color = const Color(0xFF25D366);
        label = 'АКТИВЕН';
      case ClientStatus.underReview:
        color = Colors.orange;
        label = 'ПРОВЕРКА';
      case ClientStatus.blocked:
        color = const Color(0xFFF01D2C);
        label = 'БЛОК';
      default:
        color = Colors.grey;
        label = 'НОВЫЙ';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(2)),
      child: Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900)),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textHint)),
          Text(value.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF171717))),
        ],
      ),
    );
  }

}
