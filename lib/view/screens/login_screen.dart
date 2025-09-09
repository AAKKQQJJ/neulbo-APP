import 'package:flutter/material.dart';
import '../../widgets/oauth_button.dart';
import '../../models/oauth_button_config.dart';
import '../../const/login_constants.dart';

class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage(LoginConstants.backgroundImagePath),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 80),
                _buildHeader(),
                const Expanded(child: SizedBox()),
                _buildLoginButtons(),
                const SizedBox(height: 24),
                _buildFooter(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      children: [
        Text(
          LoginConstants.appTitle,
          style: LoginConstants.titleStyle,
        ),
        SizedBox(height: 20),
        Text(
          LoginConstants.subtitleOne,
          style: LoginConstants.subtitleStyle,
        ),
        SizedBox(height: 4),
        Text(
          LoginConstants.subtitleTwo,
          style: LoginConstants.subtitleStyle,
        ),
      ],
    );
  }

  Widget _buildLoginButtons() {
    return Column(
      children: OAuthButtonConfig.defaultConfigs
          .map((config) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OAuthButton(config: config),
              ))
          .toList(),
    );
  }

  Widget _buildFooter() {
    return const Column(
      children: [
        Text(
          LoginConstants.browseWithoutLoginText,
          style: LoginConstants.footerPrimaryStyle,
        ),
        SizedBox(height: 16),
        Text(
          LoginConstants.termsText,
          style: LoginConstants.footerSecondaryStyle,
        ),
      ],
    );
  }
}
