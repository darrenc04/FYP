import 'package:flutter/material.dart';
import '../controller/profile_controller.dart';
import '../model/profile_user_data.dart';
import '../component/profile/profile_header.dart';
import '../component/profile/profile_info_tile.dart';
import '../component/edit_field_dialog.dart';
import '../component/change_password_dialog.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfileController _controller = ProfileController();
  ProfileUserData? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    setState(() => _isLoading = true);
    try {
      final userData = await _controller.fetchUserData();
      setState(() {
        _userData = userData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error fetching profile: $e')));
    }
  }

  Future<void> _updateField(String field, String value) async {
    final success = await _controller.updateUserField(field, value);
    if (success) {
      await _fetchUserData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Updated successfully')));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error updating field')));
    }
  }

  Future<void> _pickAndUploadImage() async {
    setState(() => _isLoading = true);
    final success = await _controller.pickAndUploadImage();
    if (success) {
      await _fetchUserData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile picture updated')));
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _showEditDialog(String title, String field, String currentValue) {
    showDialog(
      context: context,
      builder: (context) => EditFieldDialog(
        title: title,
        currentValue: currentValue,
        onSave: (value) => _updateField(field, value),
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) =>
          ChangePasswordDialog(onChangePassword: _controller.changePassword),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF2C3E50),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final data = _userData;
    if (data == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF2C3E50),
        body: Center(
          child: Text(
            'Error loading profile',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF2C3E50),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Personal Info',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ProfileHeader(
              profilePictureUrl: data.profilePicture,
              onEditPressed: _pickAndUploadImage,
            ),
            const SizedBox(height: 30),
            ProfileInfoTile(
              title: 'Full name',
              value: data.fullName,
              isEditable: true,
              onActionPressed: () => _showEditDialog(
                'Full name',
                'fullName',
                data.fullName == 'Not provided' ? '' : data.fullName,
              ),
            ),
            ProfileInfoTile(
              title: 'Email address',
              value: data.email,
              isEditable: false,
            ),
            ProfileInfoTile(
              title: 'Phone numbers',
              value: data.phoneNumber,
              isEditable: true,
              actionLabel: data.phoneNumber == 'Not provided' ? 'Add' : 'Edit',
              onActionPressed: () => _showEditDialog(
                'Phone numbers',
                'phoneNumber',
                data.phoneNumber == 'Not provided' ? '' : data.phoneNumber,
              ),
            ),
            ProfileInfoTile(
              title: 'ID Number',
              value: data.idNumber,
              isEditable: true,
              actionLabel: data.idNumber == 'Not provided' ? 'Add' : 'Edit',
              onActionPressed: () => _showEditDialog(
                'ID Number',
                'idNumber',
                data.idNumber == 'Not provided' ? '' : data.idNumber,
              ),
            ),
            ProfileInfoTile(
              title: 'Address',
              value: data.address,
              isEditable: true,
              actionLabel: data.address == 'Not provided' ? 'Add' : 'Edit',
              onActionPressed: () => _showEditDialog(
                'Address',
                'address',
                data.address == 'Not provided' ? '' : data.address,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white54),
                  foregroundColor: Colors.white,
                ),
                onPressed: _showChangePasswordDialog,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Change Password'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
