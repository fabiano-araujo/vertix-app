import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/feed_service.dart';
import '../../../../core/services/watchlist_service.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/models/episode_model.dart';
import '../../../../core/utils/logger.dart';
import '../../../home/presentation/widgets/series_carousel.dart';

/// My Vertix Page - User profile and library
/// Shows: Profile, Continue Watching, Likes, History, Downloads
class MyVertixPage extends StatefulWidget {
  const MyVertixPage({super.key});

  @override
  State<MyVertixPage> createState() => _MyVertixPageState();
}

class _MyVertixPageState extends State<MyVertixPage> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final FeedService _feedService = FeedService();
  final WatchlistService _watchlist = WatchlistService();

  UserModel? _user;
  List<EpisodeModel> _continueWatching = [];
  List<EpisodeModel> _likedEpisodes = [];
  List<EpisodeModel> _history = [];
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watchlist.revision.addListener(_onWatchlistChanged);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watchlist.revision.removeListener(_onWatchlistChanged);
    super.dispose();
  }

  void _onWatchlistChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAuthState();
    }
  }

  /// Verifica se o estado de autenticacao mudou
  Future<void> _checkAuthState() async {
    final isNowLoggedIn = await _authService.isAuthenticated();
    final currentUser = _authService.currentUser;

    // Recarrega se o estado mudou
    if (isNowLoggedIn != _isLoggedIn ||
        (isNowLoggedIn && _user?.id != currentUser?.id)) {
      Logger.i('MY_VERTIX', 'Estado de auth mudou, recarregando...');
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    _isLoggedIn = await _authService.isAuthenticated();
    await _watchlist.ensureLoaded();
    Logger.i('MY_VERTIX', 'isLoggedIn: $_isLoggedIn');

    if (_isLoggedIn) {
      // Primeiro tenta usar o usuario ja carregado do login
      _user = _authService.currentUser;
      Logger.i('MY_VERTIX', 'currentUser from cache: ${_user?.name}');
      Logger.i('MY_VERTIX', 'user.role: ${_user?.role}');
      Logger.i('MY_VERTIX', 'user.isAdmin: ${_user?.isAdmin}');

      // Se nao tiver, busca do servidor
      if (_user == null) {
        Logger.i('MY_VERTIX', 'Buscando perfil do servidor...');
        final profileResponse = await _authService.getProfile();
        if (profileResponse.success) {
          _user = profileResponse.user;
          Logger.s('MY_VERTIX', 'Perfil carregado: ${_user?.name}');
        } else {
          Logger.e('MY_VERTIX', 'Falha ao carregar perfil: ${profileResponse.message}');
        }
      }

      // Load user content
      try {
        final continueWatching = await _feedService.getContinueWatching(limit: 10);
        final liked = await _feedService.getLikedEpisodes(limit: 10);
        final history = await _feedService.getHistory(limit: 10);

        setState(() {
          _continueWatching = continueWatching.data;
          _likedEpisodes = liked.data;
          _history = history.data;
          _isLoading = false;
        });
      } catch (e) {
        Logger.e('MY_VERTIX', 'Erro ao carregar conteudo', e);
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    setState(() {
      _isLoggedIn = false;
      _user = null;
      _continueWatching = [];
      _likedEpisodes = [];
      _history = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              title: const Text('Minha Vertix'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => context.push('/search'),
                ),
                if (_isLoggedIn && _user?.isAdmin == true)
                  IconButton(
                    icon: const Icon(Icons.admin_panel_settings),
                    onPressed: () {
                      Logger.i('MY_VERTIX', '=== ADMIN BUTTON PRESSED ===');
                      Logger.i('MY_VERTIX', 'User: ${_user?.name}');
                      Logger.i('MY_VERTIX', 'Role: ${_user?.role}');
                      Logger.i('MY_VERTIX', 'isAdmin: ${_user?.isAdmin}');
                      Logger.i('MY_VERTIX', 'Navigating to /admin...');
                      context.push('/admin');
                    },
                    tooltip: 'Admin',
                  ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () {},
                ),
              ],
            ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  top: isDesktop ? Responsive.topNavHeight : 0,
                ),
                child: Column(
                  children: [
                    // Profile Section
                    _buildProfileSection(context),

                    const SizedBox(height: 24),

                    if (_watchlist.items.isNotEmpty)
                      SeriesCarousel(
                        title: 'Minha Lista',
                        icon: Icons.bookmark,
                        items: _watchlist.items
                            .map(
                              (series) => {
                                'id': series.id,
                                'title': series.title,
                                'coverUrl': series.coverUrl,
                                'genre': series.genre,
                              },
                            )
                            .toList(),
                        onItemTap: (id) => context.push('/series/$id'),
                      ),

                    if (!_isLoggedIn) ...[
                      _buildLoginPrompt(context),
                    ] else ...[
                      // Menu Options
                      _buildMenuSection(context),

                      const SizedBox(height: 24),

                      // Continue Watching Section
                      if (_continueWatching.isNotEmpty)
                        _buildContentSection(
                          context,
                          'Continue Assistindo',
                          Icons.play_circle_outline,
                          _continueWatching,
                        ),

                      // Liked Content Section
                      if (_likedEpisodes.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildContentSection(
                          context,
                          'Minhas Curtidas',
                          Icons.favorite,
                          _likedEpisodes,
                        ),
                      ],

                      // History Section
                      if (_history.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildContentSection(
                          context,
                          'Historico',
                          Icons.history,
                          _history,
                        ),
                      ],
                    ],

                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final avatar = GestureDetector(
      onTap: _isLoggedIn ? null : _goToLogin,
      child: Container(
        width: isDesktop ? 72 : 100,
        height: isDesktop ? 72 : 100,
        decoration: BoxDecoration(
          color: _isLoggedIn ? AppColors.primary : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(isDesktop ? 8 : 16),
        ),
        child: _user?.photo != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(isDesktop ? 8 : 16),
                child: CachedNetworkImage(
                  imageUrl: _user!.photo!,
                  fit: BoxFit.cover,
                ),
              )
            : Center(
                child: _isLoggedIn
                    ? Text(
                        _user?.initials ?? 'U',
                        style: TextStyle(
                          fontSize: isDesktop ? 26 : 40,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : const Icon(
                        Icons.person,
                        size: 48,
                        color: AppColors.textSecondary,
                      ),
              ),
      ),
    );

    final nameRow = Row(
      mainAxisSize: isDesktop ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (isDesktop)
          Expanded(
            child: Text(
              _isLoggedIn ? (_user?.displayName ?? 'Usuario') : 'Visitante',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          )
        else
          Text(
            _isLoggedIn ? (_user?.displayName ?? 'Usuario') : 'Visitante',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        if (_isLoggedIn)
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            onPressed: _logout,
            tooltip: 'Sair',
          ),
      ],
    );

    final badge = _isLoggedIn && _user?.isCreator == true
        ? Container(
            margin: EdgeInsets.only(top: isDesktop ? 6 : 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(50),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withAlpha(100)),
            ),
            child: Text(
              _user?.isAdmin == true ? 'Administrador' : 'Criador',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          )
        : const SizedBox.shrink();

    if (isDesktop) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          Responsive.horizontalPadding(context),
          28,
          Responsive.horizontalPadding(context),
          8,
        ),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Minha Vertix',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  nameRow,
                  badge,
                ],
              ),
            ),
            if (_isLoggedIn && _user?.isAdmin == true)
              IconButton(
                icon: const Icon(Icons.admin_panel_settings),
                onPressed: () => context.push('/admin'),
                tooltip: 'Admin',
              ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {},
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          avatar,
          const SizedBox(height: 16),
          nameRow,
          badge,
        ],
      ),
    );
  }

  Future<void> _goToLogin() async {
    await context.push('/login');
    // Recarrega apos voltar da tela de login
    _loadData();
  }

  Future<void> _goToRegister() async {
    await context.push('/register');
    // Recarrega apos voltar da tela de registro
    _loadData();
  }

  Widget _buildLoginPrompt(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.horizontalPadding(context),
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isDesktop ? 420 : double.infinity),
        child: Column(
          crossAxisAlignment: isDesktop
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            Text(
              'Faca login para acessar suas curtidas, historico e muito mais!',
              textAlign: isDesktop ? TextAlign.left : TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: isDesktop ? 220 : double.infinity,
              child: ElevatedButton(
                onPressed: _goToLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Entrar'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _goToRegister,
              child: const Text('Criar conta'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    final items = [
      (
        icon: Icons.notifications_outlined,
        title: 'Notificacoes',
        subtitle: 'Ver todos os avisos da sua conta.',
        trailing: 'Ver todos',
      ),
      (
        icon: Icons.download_outlined,
        title: 'Downloads',
        subtitle: 'Os filmes e series baixados ficam aqui.',
        trailing: null,
      ),
      (
        icon: Icons.history,
        title: 'Historico completo',
        subtitle: 'Retome o que voce ja assistiu.',
        trailing: null,
      ),
    ];

    if (Responsive.isDesktop(context)) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.horizontalPadding(context),
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                child: _buildDesktopMenuCard(
                  icon: items[i].icon,
                  title: items[i].title,
                  subtitle: items[i].subtitle,
                ),
              ),
            ],
          ],
        ),
      );
    }

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
        _buildMenuItem(
          context,
          icon: Icons.history,
          title: 'Historico completo',
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildDesktopMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceLighter),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
    List<EpisodeModel> episodes,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.horizontalPadding(context),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
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
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.horizontalPadding(context) - 4,
            ),
            itemCount: episodes.length,
            itemBuilder: (context, index) =>
                _buildContentCard(context, episodes[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildContentCard(BuildContext context, EpisodeModel episode) {
    return GestureDetector(
      onTap: () => context.push('/player/${episode.id}'),
      child: Container(
        width: 120,
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
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    episode.thumbnailUrl != null
                        ? CachedNetworkImage(
                            imageUrl: episode.thumbnailUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: AppColors.surfaceLight),
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.movie_outlined,
                              color: AppColors.textSecondary,
                            ),
                          )
                        : const Icon(
                            Icons.movie_outlined,
                            color: AppColors.textSecondary,
                          ),
                    // Progress bar
                    if (episode.watchProgress > 0)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: LinearProgressIndicator(
                          value: episode.watchProgress,
                          backgroundColor: Colors.black45,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                          minHeight: 3,
                        ),
                      ),
                    // Play icon
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Title
            Text(
              episode.title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // Series name
            if (episode.series != null)
              Text(
                episode.series!.title,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textTertiary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}
