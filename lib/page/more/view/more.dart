import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/more/more.dart';

@RoutePage()
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 768),
            child: ListView(
              children: [
                const SizedBox(height: 24),
                _buildHeader(context),
                const SettingsWidget(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    // TODO: hack do I really need this unchanable breeze with its icon
    // or migrate this behavior to like haka_comic's change application icon
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset('asset/image/app-icon.png', width: 88, height: 88),
        ),
        const SizedBox(height: 12),
        Text(
          'Breeze',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
