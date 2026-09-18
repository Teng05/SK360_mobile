import 'package:flutter/material.dart';

import '../../services/mobile_api_service.dart';
import '../../ui/app_ui.dart';
import '../../widgets/president_components.dart';

// Leadership directory with search, filtering, and profile details.
class PresidentLeadershipScreen extends StatefulWidget {
  const PresidentLeadershipScreen({super.key});

  @override
  State<PresidentLeadershipScreen> createState() =>
      _PresidentLeadershipScreenState();
}

class _PresidentLeadershipScreenState extends State<PresidentLeadershipScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = false;
  String _selectedBarangayId = 'all';
  @override
  void initState() {
    super.initState();
    if (MobileApiService.syncedData == null) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final barangays = _barangays();
    final leaders = _filteredLeaders();
    final executives = leaders.where((leader) => leader.isExecutive).toList();
    final councilors = leaders.where((leader) => !leader.isExecutive).toList();

    return Scaffold(
      key: _scaffoldKey,
      drawer: const PresidentSideDrawer(),
      backgroundColor: AppColors.lightGrayBg,
      bottomNavigationBar: PresidentBottomNavBar(
        activeItem: null,
        onItemSelected: _handleNavSelection,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              PresidentHeader(
                leading: PresidentHeaderLeading.menu,
                onLeadingTap: () => _scaffoldKey.currentState?.openDrawer(),
                title: 'Leadership',
                subtitle: 'Barangay councils',
                trailing: [
                  if (_isChairman)
                    IconButton(
                      onPressed: _isLoading ? null : _showAddCouncilDialog,
                      icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
                    ),
                ],
              ),
              if (_isLoading) const LinearProgressIndicator(minHeight: 3),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: 'Barangays',
                        value: '${barangays.length}',
                        icon: Icons.location_city_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Executives',
                        value: '${executives.length}',
                        icon: Icons.verified_user_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Council',
                        value: '${councilors.length}',
                        icon: Icons.groups_outlined,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _isLocalOfficial
                    ? _LocalBarangayBadge(
                        barangayName: barangays.isEmpty
                            ? _currentBarangayName
                            : barangays.first.name,
                      )
                    : _BarangayFilter(
                        barangays: barangays,
                        selectedBarangayId: _selectedBarangayId,
                        onChanged: (value) {
                          setState(() => _selectedBarangayId = value ?? 'all');
                        },
                      ),
              ),
              const SizedBox(height: 12),
              _Section(
                title: 'Executive Officers',
                icon: Icons.verified_user_outlined,
                emptyText: 'No executive officers found.',
                leaders: executives,
              ),
              _Section(
                title: 'SK Councilors',
                icon: Icons.groups_outlined,
                emptyText: 'No SK councilors found.',
                leaders: councilors,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_BarangayOption> _barangays() {
    final rows =
        MobileApiService.syncedData?['barangays'] as List<dynamic>? ?? [];
    final currentBarangayId = _currentBarangayId;

    return rows.where((row) {
      if (!_isLocalOfficial || currentBarangayId.isEmpty) return true;
      final map = Map<String, dynamic>.from(row as Map);
      return '${map['barangay_id']}' == currentBarangayId;
    }).map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      return _BarangayOption(
        id: '${map['barangay_id']}',
        name: map['barangay_name']?.toString() ?? 'Unknown Barangay',
      );
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<_Leader> _filteredLeaders() {
    final barangayNames = {
      for (final barangay in _barangays()) barangay.id: barangay.name,
    };
    final rows =
        MobileApiService.syncedData?['leadership_profiles'] as List<dynamic>? ??
            [];
    final currentBarangayId = _currentBarangayId;

    final leaders = rows.map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      final barangayId = '${map['barangay_id']}';
      return _Leader(
        name: _firstValue(map, ['full_name', 'name'], 'Unnamed official'),
        position: _positionLabel(_firstValue(map, ['position'], 'SK Councilor')),
        barangayId: barangayId,
        barangay: barangayNames[barangayId] ?? 'Unknown Barangay',
        term: _termLabel(map),
        status: _firstValue(map, ['status'], 'current'),
        profilePictureUrl: map['profile_pic_url']?.toString(),
      );
    }).where((leader) {
      if (_isLocalOfficial && currentBarangayId.isNotEmpty) {
        return leader.barangayId == currentBarangayId;
      }

      return _selectedBarangayId == 'all' ||
          leader.barangayId == _selectedBarangayId;
    }).toList();

    leaders.sort((a, b) {
      final barangayCompare = a.barangay.compareTo(b.barangay);
      if (barangayCompare != 0) return barangayCompare;
      return a.position.compareTo(b.position);
    });

    return leaders;
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    try {
      await MobileApiService.sync();
    } on MobileApiException catch (exception) {
      if (mounted) _showMessage(exception.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleNavSelection(PresidentNavItem item) {
    if (item == PresidentNavItem.leadership) return;
    handleRoleNavSelection(context, item);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.primaryRed),
    );
  }

  Future<void> _showAddCouncilDialog() async {
    var name = '';
    var email = '';
    var phone = '';
    var term = '2023-2026';
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              final cleanName = name.trim();
              if (cleanName.isEmpty) {
                _showMessage('Enter council member name.');
                return;
              }

              setDialogState(() => isSaving = true);
              var saved = false;
              try {
                await MobileApiService.createCouncilMember(
                  name: cleanName,
                  email: email,
                  phone: phone,
                  term: term,
                );
                saved = true;
                if (!mounted) return;
                Navigator.pop(dialogContext);
                setState(() {});
                _showMessage('SK council member added.');
              } on MobileApiException catch (exception) {
                if (mounted) _showMessage(exception.message);
              } finally {
                if (!saved && mounted) {
                  setDialogState(() => isSaving = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Add SK Councilor'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: _decoration('Full name'),
                      textInputAction: TextInputAction.next,
                      onChanged: (value) => name = value,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: _decoration('Email'),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      onChanged: (value) => email = value,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: _decoration('Phone'),
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      onChanged: (value) => phone = value,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: _decoration('Term (default 2023-2026)'),
                      textInputAction: TextInputAction.done,
                      onChanged: (value) => term = value,
                      onSubmitted: (_) {
                        if (!isSaving) submit();
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isSaving ? 'Saving...' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool get _isChairman {
    final role = MobileApiService.currentUser?['role']?.toString() ?? '';
    return role == 'sk_chairman';
  }

  bool get _isLocalOfficial {
    final role = MobileApiService.currentUser?['role']?.toString() ?? '';
    return role == 'sk_chairman' || role == 'sk_secretary';
  }

  String get _currentBarangayId =>
      '${MobileApiService.currentUser?['barangay_id'] ?? ''}';

  String get _currentBarangayName =>
      MobileApiService.currentUser?['barangay_name']?.toString() ??
      'Your barangay';
}

class _LocalBarangayBadge extends StatelessWidget {
  final String barangayName;

  const _LocalBarangayBadge({required this.barangayName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderPink),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_city_outlined, color: AppColors.primaryRed),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Barangay $barangayName',
              style: const TextStyle(
                color: AppColors.darkGray,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarangayFilter extends StatelessWidget {
  final List<_BarangayOption> barangays;
  final String selectedBarangayId;
  final ValueChanged<String?> onChanged;

  const _BarangayFilter({
    required this.barangays,
    required this.selectedBarangayId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderPink),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: selectedBarangayId,
        decoration: _decoration('Select barangay'),
        items: [
          const DropdownMenuItem(value: 'all', child: Text('All barangays')),
          ...barangays.map(
            (barangay) => DropdownMenuItem(
              value: barangay.id,
              child: Text('Barangay ${barangay.name}'),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final String emptyText;
  final List<_Leader> leaders;

  const _Section({
    required this.title,
    required this.icon,
    required this.emptyText,
    required this.leaders,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderPink),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primaryRed),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.darkGray,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (leaders.isEmpty)
              Text(emptyText, style: const TextStyle(color: AppColors.lightText))
            else
              ...leaders.map(
                (leader) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: _LeaderCard(
                    leader: leader,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _LeaderDetailsPage(leader: leader),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LeaderCard extends StatelessWidget {
  final _Leader leader;
  final VoidCallback? onTap;

  const _LeaderCard({required this.leader, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.softPink,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
          CircleAvatar(
            backgroundColor:
                leader.isExecutive ? AppColors.primaryRed : const Color(0xFFFFC107),
            backgroundImage: leader.profilePictureUrl?.isNotEmpty == true
                ? NetworkImage(leader.profilePictureUrl!)
                : null,
            child: leader.profilePictureUrl?.isNotEmpty == true
                ? null
                : Text(leader.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leader.name,
                  style: const TextStyle(
                    color: AppColors.darkGray,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${leader.position} - Barangay ${leader.barangay}',
                  style: const TextStyle(color: AppColors.lightText, fontSize: 12),
                ),
                Text(
                  'Term: ${leader.term} - ${_readable(leader.status)}',
                  style: const TextStyle(color: AppColors.lightText, fontSize: 12),
                ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }
}

// Displays the selected official's complete leadership information.
class _LeaderDetailsPage extends StatelessWidget {
  final _Leader leader;

  const _LeaderDetailsPage({required this.leader});

  @override
  Widget build(BuildContext context) {
    final hasPicture = leader.profilePictureUrl?.isNotEmpty == true;
    return Scaffold(
      backgroundColor: AppColors.lightGrayBg,
      appBar: AppBar(
        title: const Text('Official profile'),
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: CircleAvatar(
              radius: 46,
              backgroundColor: leader.isExecutive
                  ? AppColors.primaryRed
                  : const Color(0xFFFFC107),
              backgroundImage: hasPicture
                  ? NetworkImage(leader.profilePictureUrl!)
                  : null,
              child: hasPicture
                  ? null
                  : Text(
                      leader.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              leader.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.darkGray,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _ProfileRow(label: 'Position', value: leader.position),
          _ProfileRow(label: 'Barangay', value: leader.barangay),
          _ProfileRow(label: 'Term', value: leader.term),
          _ProfileRow(label: 'Status', value: _readable(leader.status)),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderPink),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.lightText),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.darkGray,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderPink),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryRed, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.darkGray,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.lightText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _BarangayOption {
  final String id;
  final String name;

  const _BarangayOption({required this.id, required this.name});
}

class _Leader {
  final String name;
  final String position;
  final String barangayId;
  final String barangay;
  final String term;
  final String status;
  final String? profilePictureUrl;

  const _Leader({
    required this.name,
    required this.position,
    required this.barangayId,
    required this.barangay,
    required this.term,
    required this.status,
    this.profilePictureUrl,
  });

  bool get isExecutive {
    final value = position.toLowerCase();
    return value.contains('president') ||
        value.contains('chairman') ||
        value.contains('secretary') ||
        value.contains('treasurer');
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'NA';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

InputDecoration _decoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: AppColors.softPink,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}

String _firstValue(
  Map<String, dynamic> row,
  List<String> keys,
  String fallback,
) {
  for (final key in keys) {
    final value = row[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString();
    }
  }

  return fallback;
}

String _positionLabel(String value) {
  switch (value) {
    case 'sk_president':
      return 'SK President';
    case 'sk_chairman':
      return 'SK Chairman';
    case 'sk_secretary':
      return 'SK Secretary';
    default:
      return _readable(value);
  }
}

String _termLabel(Map<String, dynamic> row) {
  final explicit = _firstValue(row, ['term'], '');
  if (explicit.isNotEmpty) return explicit;

  final start = _yearFromDate(_firstValue(row, ['term_start'], ''));
  final end = _yearFromDate(_firstValue(row, ['term_end'], ''));
  if (start.isEmpty && end.isEmpty) return 'N/A';
  if (end.isEmpty) return '$start-present';

  return '$start-$end';
}

String _yearFromDate(String value) {
  if (value.length < 4) return '';
  return value.substring(0, 4);
}

String _readable(String value) {
  final words = value.replaceAll('_', ' ').trim().split(RegExp(r'\s+'));
  return words
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
}
