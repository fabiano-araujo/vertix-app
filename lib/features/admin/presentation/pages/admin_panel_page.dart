import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/admin_service.dart';
import '../../../../core/services/auth_service.dart';

/// Admin Panel Page
/// For AI Series Generation and Management
class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  final AdminService _adminService = AdminService();
  final AuthService _authService = AuthService();

  final _formKey = GlobalKey<FormState>();
  final _themeController = TextEditingController();

  String _selectedGenre = 'Acao';
  int _episodeCount = 5;
  int _duration = 60;
  String _targetAudience = 'Geral';

  List<GenerationJob> _jobs = [];
  bool _isLoading = false;
  bool _isGenerating = false;

  final List<String> _genres = [
    'Acao',
    'Drama',
    'Comedia',
    'Romance',
    'Terror',
    'Suspense',
    'Ficcao Cientifica',
    'Fantasia',
    'Documentario',
  ];

  final List<String> _audiences = [
    'Geral',
    'Infantil',
    'Adolescente',
    'Adulto',
  ];

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _loadJobs();
  }

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    final isAuth = await _authService.isAuthenticated();
    if (!isAuth || !_authService.isAdmin) {
      if (mounted) {
        context.go('/');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Acesso nao autorizado')),
        );
      }
    }
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);

    final response = await _adminService.getJobs();

    setState(() {
      _jobs = response.data;
      _isLoading = false;
    });
  }

  Future<void> _generateSeries() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isGenerating = true);

    final response = await _adminService.generateSeries(
      theme: _themeController.text.trim(),
      genre: _selectedGenre,
      episodeCount: _episodeCount,
      duration: _duration,
      targetAudience: _targetAudience,
    );

    setState(() => _isGenerating = false);

    if (response.success) {
      _themeController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geracao iniciada com sucesso!'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadJobs();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message ?? 'Erro ao iniciar geracao'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Admin Panel'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadJobs,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Generation Form
            _buildGenerationForm(),

            const SizedBox(height: 32),

            // Jobs List
            _buildJobsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerationForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(50)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Gerar Serie com IA',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Crie uma nova serie usando inteligencia artificial',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),

            // Theme Input
            TextFormField(
              controller: _themeController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Tema da Serie',
                hintText: 'Ex: Um detetive que resolve crimes com humor',
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Digite o tema da serie';
                }
                if (value.length < 10) {
                  return 'Descreva melhor o tema (minimo 10 caracteres)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Genre Dropdown
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedGenre,
                    decoration: InputDecoration(
                      labelText: 'Genero',
                      filled: true,
                      fillColor: AppColors.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    dropdownColor: AppColors.surface,
                    items: _genres.map((genre) {
                      return DropdownMenuItem(
                        value: genre,
                        child: Text(genre),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedGenre = value!);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _targetAudience,
                    decoration: InputDecoration(
                      labelText: 'Publico',
                      filled: true,
                      fillColor: AppColors.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    dropdownColor: AppColors.surface,
                    items: _audiences.map((audience) {
                      return DropdownMenuItem(
                        value: audience,
                        child: Text(audience),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _targetAudience = value!);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Episode Count
            Text(
              'Numero de Episodios: $_episodeCount',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            Slider(
              value: _episodeCount.toDouble(),
              min: 1,
              max: 20,
              divisions: 19,
              activeColor: AppColors.primary,
              inactiveColor: AppColors.surfaceLighter,
              onChanged: (value) {
                setState(() => _episodeCount = value.toInt());
              },
            ),
            const SizedBox(height: 16),

            // Duration
            Text(
              'Duracao por Episodio: ${_duration}s',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            Slider(
              value: _duration.toDouble(),
              min: 30,
              max: 180,
              divisions: 15,
              activeColor: AppColors.primary,
              inactiveColor: AppColors.surfaceLighter,
              onChanged: (value) {
                setState(() => _duration = value.toInt());
              },
            ),
            const SizedBox(height: 24),

            // Generate Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateSeries,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _isGenerating ? 'Gerando...' : 'Gerar Serie com IA',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Geracoes Recentes',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            TextButton(
              onPressed: _loadJobs,
              child: const Text('Atualizar'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          )
        else if (_jobs.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 48,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma geracao ainda',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _jobs.length,
            itemBuilder: (context, index) => _buildJobCard(_jobs[index]),
          ),
      ],
    );
  }

  Widget _buildJobCard(GenerationJob job) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Status Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getStatusColor(job.status).withAlpha(50),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getStatusIcon(job.status),
              color: _getStatusColor(job.status),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.inputData?['theme'] ?? 'Serie ${job.id}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildChip(job.inputData?['genre'] ?? 'N/A'),
                    const SizedBox(width: 8),
                    _buildChip('${job.inputData?['episodeCount'] ?? 0} eps'),
                  ],
                ),
              ],
            ),
          ),

          // Status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(job.status).withAlpha(50),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getStatusText(job.status),
                  style: TextStyle(
                    color: _getStatusColor(job.status),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (job.isCompleted && job.seriesId != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.push('/series/${job.seriesId}'),
                  child: const Text('Ver Serie'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'COMPLETED':
        return AppColors.success;
      case 'FAILED':
        return AppColors.error;
      case 'PROCESSING':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'COMPLETED':
        return Icons.check_circle;
      case 'FAILED':
        return Icons.error;
      case 'PROCESSING':
        return Icons.hourglass_empty;
      default:
        return Icons.schedule;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'COMPLETED':
        return 'Concluido';
      case 'FAILED':
        return 'Falhou';
      case 'PROCESSING':
        return 'Processando';
      default:
        return 'Pendente';
    }
  }
}
