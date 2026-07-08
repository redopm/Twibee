import 'package:flutter/material.dart';
import 'privacy_radio_screen.dart';

final List<PrivacyOption> _standardOptions = [
  PrivacyOption(label: 'Everyone', value: 'Everyone'),
  PrivacyOption(label: 'My contacts', value: 'My contacts'),
  PrivacyOption(label: 'My contacts except...', value: 'My contacts except...', isExceptOption: true),
  PrivacyOption(label: 'Nobody', value: 'Nobody'),
];

class PrivacyProfilePictureScreen extends StatelessWidget {
  const PrivacyProfilePictureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PrivacyRadioScreen(
      title: 'Profile picture',
      sectionHeader: 'Who can see my profile picture',
      settingKey: 'privacy_profile_photo',
      excludedListKey: 'privacy_profile_photo_excluded',
      options: _standardOptions,
    );
  }
}

class PrivacyAboutScreen extends StatelessWidget {
  const PrivacyAboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PrivacyRadioScreen(
      title: 'About',
      sectionHeader: 'Who can see my About',
      settingKey: 'privacy_about',
      excludedListKey: 'privacy_about_excluded',
      options: _standardOptions,
    );
  }
}

class PrivacyLinksScreen extends StatelessWidget {
  const PrivacyLinksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PrivacyRadioScreen(
      title: 'Links',
      sectionHeader: 'Who can see the links on my profile',
      settingKey: 'privacy_links',
      excludedListKey: 'privacy_links_excluded',
      options: _standardOptions,
    );
  }
}

class PrivacyGroupsScreen extends StatelessWidget {
  const PrivacyGroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PrivacyRadioScreen(
      title: 'Groups',
      sectionHeader: 'Who can add me to groups',
      settingKey: 'privacy_groups',
      excludedListKey: 'privacy_groups_excluded',
      options: [
        PrivacyOption(label: 'Everyone', value: 'Everyone'),
        PrivacyOption(label: 'My contacts', value: 'My contacts'),
        PrivacyOption(label: 'My contacts except...', value: 'My contacts except...', isExceptOption: true),
      ],
      footerText: 'Admins who can\'t add you to a group will have the option of inviting you privately instead.\n\nThis setting does not apply to community announcement groups. If you\'re added to a community, you\'ll always be added to a community announcement group.',
    );
  }
}

