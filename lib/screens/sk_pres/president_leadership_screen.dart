import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/mobile_api_service.dart';
import '../../ui/app_ui.dart';
import '../../widgets/president_components.dart';

class PresidentLeadershipScreen extends StatefulWidget {
  const PresidentLeadershipScreen({super.key});

  @override
  State<PresidentLeadershipScreen> createState() =>
      _PresidentLeadershipScreenState();
}

class _PresidentLeadershipScreenState extends State<PresidentLeadershipScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = false;
  String? _loadError;
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
    final hasSecretary = leaders.any(
      (leader) => leader.position.toLowerCase().contains('secretary'),
    );

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
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              PresidentHeader(
                leading: PresidentHeaderLeading.menu,
                onLeadingTap: () => _scaffoldKey.currentState?.openDrawer(),
                title: 'Leadership',
                subtitle: 'Barangay councils',
                trailing: [
                  if (_isChairman)
                    PopupMenuButton<String>(
                      enabled: !_isLoading,
                      tooltip: 'Add leadership member',
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      onSelected: (value) {
                        if (value == 'councilor') _showAddCouncilDialog();
                        if (value == 'secretary') _showAddSecretaryDialog();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'councilor',
                          child: ListTile(
                            leading: Icon(Icons.groups_outlined),
                            title: Text('Add SK Councilor'),
                          ),
                        ),
                        if (!hasSecretary)
                          const PopupMenuItem(
                            value: 'secretary',
                            child: ListTile(
                              leading: Icon(Icons.manage_accounts_outlined),
                              title: Text('Create Secretary Account'),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              if (_isLoading) const AppLoadingIndicator(),
              if (_loadError != null)
                AppEmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Unable to refresh',
                  message:
                      'Check your connection and try again. Previously loaded records may still be shown.',
                  onAction: _refresh,
                ),
              const AppPageIntro(
                eyebrow: 'SK council directory',
                title: 'Leadership',
                subtitle:
                    'Executive officers and SK councilors serving each '
                    'barangay.',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: AppMetricGrid(
                  columns: 3,
                  children: [
                    _SummaryCard(
                      label: 'Barangays',
                      value: '${barangays.length}',
                      icon: Icons.location_city_outlined,
                      color: AppColors.info,
                    ),
                    _SummaryCard(
                      label: 'Executives',
                      value: '${executives.length}',
                      icon: Icons.verified_user_outlined,
                      color: AppColors.primaryRed,
                    ),
                    _SummaryCard(
                      label: 'Council',
                      value: '${councilors.length}',
                      icon: Icons.groups_outlined,
                      color: AppColors.highlight,
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
                onView: _showLeaderProfile,
              ),
              _Section(
                title: 'SK Councilors',
                icon: Icons.groups_outlined,
                emptyText: 'No SK councilors found.',
                leaders: councilors,
                onView: _showLeaderProfile,
                onEdit: _isChairman ? _showEditCouncilDialog : null,
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

    return rows
        .where((row) {
          if (!_isLocalOfficial || currentBarangayId.isEmpty) return true;
          final map = Map<String, dynamic>.from(row as Map);
          return '${map['barangay_id']}' == currentBarangayId;
        })
        .map((row) {
          final map = Map<String, dynamic>.from(row as Map);
          return _BarangayOption(
            id: '${map['barangay_id']}',
            name: map['barangay_name']?.toString() ?? 'Unknown Barangay',
          );
        })
        .toList()
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

    final leaders = rows
        .map((row) {
          final map = Map<String, dynamic>.from(row as Map);
          final barangayId = '${map['barangay_id']}';
          return _Leader(
            id: int.tryParse('${map['leadership_id']}'),
            name: _firstValue(map, ['full_name', 'name'], 'Unnamed official'),
            position: _positionLabel(
              _firstValue(map, ['position'], 'SK Councilor'),
            ),
            barangayId: barangayId,
            barangay: barangayNames[barangayId] ?? 'Unknown Barangay',
            term: _termLabel(map),
            status: _firstValue(map, ['status'], 'current'),
            profilePictureUrl: map['profile_pic_url']?.toString(),
            email: map['email']?.toString() ?? '',
            phone: map['phone']?.toString() ?? '',
            isVerified: '${map['is_verified'] ?? '1'}' == '1',
            isCouncilRecord: map['user_id'] == null,
          );
        })
        .where((leader) {
          if (_isLocalOfficial && currentBarangayId.isNotEmpty) {
            return leader.barangayId == currentBarangayId;
          }

          return _selectedBarangayId == 'all' ||
              leader.barangayId == _selectedBarangayId;
        })
        .toList();

    leaders.sort((a, b) {
      final barangayCompare = a.barangay.compareTo(b.barangay);
      if (barangayCompare != 0) return barangayCompare;
      return a.position.compareTo(b.position);
    });

    return leaders;
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      await MobileApiService.sync();
    } on MobileApiException catch (exception) {
      if (mounted) setState(() => _loadError = exception.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleNavSelection(PresidentNavItem item) {
    if (item == PresidentNavItem.leadership) return;
    handleRoleNavSelection(context, item);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showAddCouncilDialog() async {
    var name = '';
    var email = '';
    var phone = '';
    var term = '2023-2026';
    bool isSaving = false;
    File? profilePicture;

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
                  profilePicture: profilePicture,
                );
                saved = true;
                if (!mounted || !dialogContext.mounted) return;
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
              icon: const AppIconTile(icon: Icons.person_add_alt_1_outlined),
              title: const Text('Add SK Councilor'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CouncilPhotoPicker(
                      file: profilePicture,
                      onPick: () async {
                        final image = await _pickCouncilPhoto();
                        if (image != null && dialogContext.mounted) {
                          setDialogState(() => profilePicture = image);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
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
                FilledButton(
                  onPressed: isSaving ? null : submit,
                  child: Text(isSaving ? 'Saving...' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditCouncilDialog(_Leader leader) async {
    if (leader.id == null || !leader.isCouncilRecord) return;
    var name = leader.name;
    var email = leader.email;
    var phone = leader.phone;
    var term = leader.term;
    var isSaving = false;
    File? profilePicture;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> submit() async {
            if (name.trim().isEmpty) {
              _showMessage('Enter council member name.');
              return;
            }
            setDialogState(() => isSaving = true);
            try {
              await MobileApiService.updateCouncilMember(
                councilId: leader.id!,
                name: name.trim(),
                email: email,
                phone: phone,
                term: term,
                profilePicture: profilePicture,
              );
              if (!mounted || !dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              setState(() {});
              _showMessage('SK council member updated.');
            } on MobileApiException catch (exception) {
              if (mounted) _showMessage(exception.message);
              if (dialogContext.mounted) setDialogState(() => isSaving = false);
            }
          }

          return AlertDialog(
            icon: const AppIconTile(icon: Icons.manage_accounts_outlined),
            title: const Text('Edit SK Councilor'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CouncilPhotoPicker(
                    file: profilePicture,
                    networkUrl: leader.profilePictureUrl,
                    onPick: () async {
                      final image = await _pickCouncilPhoto();
                      if (image != null && dialogContext.mounted) {
                        setDialogState(() => profilePicture = image);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    initialValue: name,
                    decoration: _decoration('Full name'),
                    onChanged: (value) => name = value,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    initialValue: email,
                    decoration: _decoration('Email'),
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (value) => email = value,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    initialValue: phone,
                    decoration: _decoration('Phone'),
                    keyboardType: TextInputType.phone,
                    onChanged: (value) => phone = value,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    initialValue: term,
                    decoration: _decoration('Term'),
                    onChanged: (value) => term = value,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSaving ? null : submit,
                child: Text(isSaving ? 'Saving...' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAddSecretaryDialog() async {
    var firstName = '';
    var lastName = '';
    var email = '';
    var phone = '';
    var isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> submit() async {
            if (firstName.trim().isEmpty ||
                lastName.trim().isEmpty ||
                email.trim().isEmpty) {
              _showMessage('Complete the Secretary name and email.');
              return;
            }
            setDialogState(() => isSaving = true);
            try {
              final response = await MobileApiService.createSecretaryAccount(
                firstName: firstName,
                lastName: lastName,
                email: email,
                phone: phone,
              );
              if (!mounted || !dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              setState(() {});
              _showMessage(
                response['message']?.toString() ?? 'Secretary account created.',
              );
            } on MobileApiException catch (exception) {
              if (mounted) _showMessage(exception.message);
              if (dialogContext.mounted) setDialogState(() => isSaving = false);
            }
          }

          return AlertDialog(
            icon: const AppIconTile(icon: Icons.manage_accounts_outlined),
            title: const Text('Create Secretary Account'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: _decoration('First name'),
                    onChanged: (value) => firstName = value,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: _decoration('Last name'),
                    onChanged: (value) => lastName = value,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: _decoration('Email'),
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (value) => email = value,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: _decoration('Phone (optional)'),
                    keyboardType: TextInputType.phone,
                    onChanged: (value) => phone = value,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'A password setup link will be emailed to the Secretary. The account stays inactive until setup is completed.',
                    style: TextStyle(color: AppColors.lightText, fontSize: 12),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSaving ? null : submit,
                child: Text(isSaving ? 'Creating...' : 'Create Account'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLeaderProfile(_Leader leader) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            children: [
              CircleAvatar(
                radius: 54,
                backgroundColor: AppColors.softPink,
                backgroundImage: leader.profilePictureUrl?.isNotEmpty == true
                    ? NetworkImage(leader.profilePictureUrl!)
                    : null,
                child: leader.profilePictureUrl?.isNotEmpty == true
                    ? null
                    : Text(
                        leader.initials,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryRed,
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              Text(
                leader.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              AppStatusBadge(
                label: leader.position,
                color: AppColors.primaryRed,
              ),
              const SizedBox(height: 22),
              _ProfileDetail(
                icon: Icons.location_city_outlined,
                label: 'Barangay',
                value: leader.barangay,
              ),
              _ProfileDetail(
                icon: Icons.event_repeat_outlined,
                label: 'Term',
                value: leader.term,
              ),
              _ProfileDetail(
                icon: Icons.flag_outlined,
                label: 'Status',
                value: _readable(leader.status),
              ),
              _ProfileDetail(
                icon: Icons.email_outlined,
                label: 'Email',
                value: leader.email,
              ),
              _ProfileDetail(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: leader.phone,
              ),
              if (!leader.isCouncilRecord)
                _ProfileDetail(
                  icon: leader.isVerified
                      ? Icons.verified_user_outlined
                      : Icons.pending_outlined,
                  label: 'Account',
                  value: leader.isVerified
                      ? 'Verified'
                      : 'Pending account setup',
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<File?> _pickCouncilPhoto() async {
    final selected = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
      maxWidth: 2000,
      maxHeight: 2000,
    );
    if (selected == null) return null;

    final cropped = await ImageCropper().cropImage(
      sourcePath: selected.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 88,
      maxWidth: 1200,
      maxHeight: 1200,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Adjust councilor photo',
          toolbarColor: AppColors.primaryRed,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppColors.primaryRed,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Adjust councilor photo',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );

    return cropped == null ? null : File(cropped.path);
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
      decoration: AppDecorations.surface(color: AppColors.softPink),
      child: Row(
        children: [
          const AppIconTile(icon: Icons.location_city_outlined, size: 19),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Barangay $barangayName',
              style: Theme.of(context).textTheme.titleSmall,
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
      decoration: AppDecorations.surface(),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: selectedBarangayId,
        decoration: _decoration('Select barangay').copyWith(
          prefixIcon: const Icon(
            Icons.location_city_outlined,
            color: AppColors.primaryRed,
          ),
        ),
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
  final ValueChanged<_Leader>? onEdit;
  final ValueChanged<_Leader>? onView;

  const _Section({
    required this.title,
    required this.icon,
    required this.emptyText,
    required this.leaders,
    this.onEdit,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeading(
            icon: icon,
            title: title,
            action: AppStatusBadge(
              label: '${leaders.length}',
              color: AppColors.info,
            ),
          ),
          const SizedBox(height: 12),
          if (leaders.isEmpty)
            AppEmptyState(
              icon: icon,
              title: emptyText,
              message: 'Council profiles will appear here when available.',
            )
          else
            Column(
              children: [
                for (final leader in leaders)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _LeaderCard(
                      leader: leader,
                      onEdit: onEdit,
                      onView: onView,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _LeaderCard extends StatelessWidget {
  final _Leader leader;
  final ValueChanged<_Leader>? onEdit;
  final ValueChanged<_Leader>? onView;

  const _LeaderCard({required this.leader, this.onEdit, this.onView});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = leader.profilePictureUrl?.isNotEmpty == true;
    final accent = leader.isExecutive ? AppColors.primaryRed : AppColors.info;
    final current = leader.status.toLowerCase() == 'current';
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpace.radius),
      onTap: onView == null ? null : () => onView!(leader),
      child: AppAccentCard(
        accent: leader.isExecutive ? AppColors.primaryRed : AppColors.border,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: leader.isExecutive
                      ? AppColors.gold
                      : accent.withValues(alpha: .3),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: accent.withValues(alpha: .1),
                backgroundImage: hasPhoto
                    ? NetworkImage(leader.profilePictureUrl!)
                    : null,
                child: hasPhoto
                    ? null
                    : Text(
                        leader.initials,
                        style: TextStyle(
                          color: accent,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    leader.position.toUpperCase(),
                    style: TextStyle(
                      color: leader.isExecutive
                          ? AppColors.actionRed
                          : AppColors.info,
                      fontSize: 11.5,
                      letterSpacing: .6,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    leader.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AppMeta(
                    icon: Icons.location_city_outlined,
                    label: 'Barangay ${leader.barangay}',
                    color: AppColors.primaryRed,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      AppStatusBadge(
                        label: 'Term ${leader.term}',
                        color: AppColors.info,
                        icon: Icons.event_repeat_outlined,
                      ),
                      AppStatusBadge(
                        label: _readable(leader.status),
                        color: current ? AppColors.success : AppColors.muted,
                        dot: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onEdit != null && leader.isCouncilRecord)
              IconButton(
                tooltip: 'Edit councilor',
                onPressed: () => onEdit!(leader),
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileDetail extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.inset(),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryRed, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 2),
                Text(
                  value.trim().isEmpty ? 'Not provided' : value,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
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
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppStatistic(label: label, value: value, icon: icon, color: color);
  }
}

class _CouncilPhotoPicker extends StatelessWidget {
  final File? file;
  final String? networkUrl;
  final VoidCallback onPick;

  const _CouncilPhotoPicker({
    required this.file,
    required this.onPick,
    this.networkUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hasNetworkImage = networkUrl?.isNotEmpty == true;
    return Column(
      children: [
        CircleAvatar(
          radius: 42,
          backgroundColor: AppColors.softPink,
          backgroundImage: file != null
              ? FileImage(file!)
              : hasNetworkImage
              ? NetworkImage(networkUrl!) as ImageProvider
              : null,
          child: file == null && !hasNetworkImage
              ? const Icon(
                  Icons.person_outline,
                  size: 40,
                  color: AppColors.primaryRed,
                )
              : null,
        ),
        TextButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(
            file == null && !hasNetworkImage ? 'Add picture' : 'Change picture',
          ),
        ),
      ],
    );
  }
}

class _BarangayOption {
  final String id;
  final String name;

  const _BarangayOption({required this.id, required this.name});
}

class _Leader {
  final int? id;
  final String name;
  final String position;
  final String barangayId;
  final String barangay;
  final String term;
  final String status;
  final String? profilePictureUrl;
  final String email;
  final String phone;
  final bool isCouncilRecord;
  final bool isVerified;

  const _Leader({
    this.id,
    required this.name,
    required this.position,
    required this.barangayId,
    required this.barangay,
    required this.term,
    required this.status,
    this.profilePictureUrl,
    this.email = '',
    this.phone = '',
    this.isCouncilRecord = false,
    this.isVerified = true,
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
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
