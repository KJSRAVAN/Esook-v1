import 'package:flutter/material.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../auth/domain/repositories/auth_repository.dart';

/// Account screen for the Rider portal.
class RiderAccountScreen extends StatefulWidget {
  final AuthRepository? authRepository;
  final UserModel? currentUser;
  final bool isOnline;
  final ValueChanged<bool>? onToggleOnline;

  const RiderAccountScreen({
    super.key,
    this.authRepository,
    this.currentUser,
    this.isOnline = true,
    this.onToggleOnline,
  });

  @override
  State<RiderAccountScreen> createState() => _RiderAccountScreenState();
}

class _RiderAccountScreenState extends State<RiderAccountScreen> {
  bool _isLoggingOut = false;

  Future<void> _handleLogout() async {
    if (widget.authRepository == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to sign out of the Driver Portal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoggingOut = true);

    await widget.authRepository!.logout();

    if (!mounted) return;

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Driver Profile',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Profile Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Avatar
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFED7AA), width: 2),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.delivery_dining_rounded,
                      size: 36,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                Text(
                  user?.name ?? 'Delivery Partner',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 4),

                if (user?.phone != null && user!.phone.isNotEmpty)
                  Text(
                    user.phone,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                const SizedBox(height: 10),

                // Driver badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: const Text(
                    'Delivery Rider',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFC2410C),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Online/Offline Status Control
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: widget.isOnline ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          widget.isOnline ? Icons.power_rounded : Icons.power_off_rounded,
                          color: widget.isOnline ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isOnline ? 'Duty: ONLINE' : 'Duty: OFFLINE',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: widget.isOnline ? const Color(0xFF15803D) : const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.isOnline ? 'Receiving pickup orders' : 'Not receiving orders',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  key: const Key('rider_duty_toggle_switch'),
                  value: widget.isOnline,
                  activeThumbColor: const Color(0xFF16A34A),
                  onChanged: (val) => widget.onToggleOnline?.call(val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. App Details
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B)),
                  title: const Text('App Version', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  trailing: const Text('2.0.0-dev', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ListTile(
                  leading: const Icon(Icons.verified_user_outlined, color: Color(0xFF64748B)),
                  title: const Text('Role', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  trailing: const Text('DRIVER', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFEA580C), fontSize: 13)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 4. Sign Out Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              key: const Key('rider_logout_btn'),
              onPressed: _isLoggingOut ? null : _handleLogout,
              icon: _isLoggingOut
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout_rounded, color: AppColors.error),
              label: Text(
                _isLoggingOut ? 'Signing out...' : 'Sign Out',
                style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 15),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFECACA)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
