import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// My Vertix Page - User profile and library
/// Shows: Profile, Continue Watching, Likes, History, Downloads
class MyVertixPage extends StatelessWidget {
  const MyVertixPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Minha Vertix'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Section
            _buildProfileSection(context),

            const SizedBox(height: 24),

            // Menu Options
            _buildMenuSection(context),

            const SizedBox(height: 24),

            // Liked Content Section
            _buildContentSection(
              context,
              'Series e filmes que voce curtiu',
              Icons.favorite,
            ),

            const SizedBox(height: 24),

            // My List Section
            _buildContentSection(
              context,
              'Minha lista',
              Icons.add,
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.warning,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                ':)',
                style: TextStyle(
                  fontSize: 40,
                  color: AppColors.background,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Name with dropdown
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Usuario',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    return Column(
      children: [
        _buildMenuItem(
          context,
          icon: Icons.notifications_outlined,
          title: 'Notificacoes',
          trailing: 'Ver todos',
          onTap: () {},
        ),
        _buildMenuItem(
          context,
          icon: Icons.download_outlined,
          title: 'Downloads',
          subtitle: 'Os filmes e series baixados ficam aqui.',
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    String? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.textPrimary),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            )
          : null,
      trailing: trailing != null
          ? Text(
              trailing,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            )
          : const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
            ),
      onTap: onTap,
    );
  }

  Widget _buildContentSection(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              TextButton(
                onPressed: () {},
                child: const Text('Ver todos'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Horizontal scroll of content
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: 5,
            itemBuilder: (context, index) => _buildContentCard(context, index),
          ),
        ),
      ],
    );
  }

  Widget _buildContentCard(BuildContext context, int index) {
    return Container(
      width: 110,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: NetworkImage(
                  'https://picsum.photos/200/300?random=${index + 20}',
                ),
                fit: BoxFit.cover,
              ),
            ),
            child: Stack(
              children: [
                // Share button
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.share,
                      size: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Title
          Text(
            'Titulo ${index + 1}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          // Subtitle
          const Text(
            'Compartil...',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
