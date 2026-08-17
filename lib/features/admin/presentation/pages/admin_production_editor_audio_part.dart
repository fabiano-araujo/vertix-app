part of 'admin_production_editor_page.dart';

extension _AdminProductionEditorAudioExtension
    on _AdminProductionEditorPageState {
  Widget _buildAudio() {
    final episode = _episode!;
    return ListView(
      key: const PageStorageKey('production-audio'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
      children: [
        _panel(
          title: 'Pos-producao de audio',
          icon: Icons.graphic_eq,
          trailing: _pill(
            episode.musicStatus,
            _statusColor(episode.musicStatus),
          ),
          child: const Text(
            'A musica final fica fora do Seedance. Dialogo, musica, ambiente e efeitos permanecem em faixas independentes para mixagem e substituicao.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final music = _buildMusicConfiguration(episode);
            final mixer = _buildAudioMixer(episode);
            if (constraints.maxWidth < 820) {
              return Column(
                children: [music, const SizedBox(height: 12), mixer],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: music),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: mixer),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _panel(
          title: 'Faixas do episodio',
          icon: Icons.multitrack_audio_outlined,
          trailing: OutlinedButton.icon(
            onPressed: () => setState(() => _sectionIndex = 4),
            icon: const Icon(Icons.view_timeline_outlined, size: 18),
            label: const Text('Abrir timeline'),
          ),
          child: Column(
            children: [
              _buildStemCard(
                icon: Icons.record_voice_over_outlined,
                color: const Color(0xFF8B5CF6),
                title: 'Dialogo',
                subtitle: 'Vozes e timecodes definidos em cada take',
                status: 'EDITAVEL',
                waveformSeed: 3,
              ),
              const SizedBox(height: 9),
              _buildStemCard(
                icon: Icons.music_note,
                color: const Color(0xFFEC4899),
                title: 'Musica',
                subtitle: episode.externalMusic
                    ? '${episode.musicProvider} • arquivo independente'
                    : 'Faixa musical desativada',
                status: episode.musicStatus,
                waveformSeed: 7,
              ),
              const SizedBox(height: 9),
              _buildStemCard(
                icon: Icons.air,
                color: const Color(0xFF14B8A6),
                title: 'Ambiente',
                subtitle: 'Room tone e ambiencia continua entre cortes',
                status: 'PRONTO',
                waveformSeed: 11,
              ),
              const SizedBox(height: 9),
              _buildStemCard(
                icon: Icons.bolt,
                color: const Color(0xFFF97316),
                title: 'Efeitos / SFX',
                subtitle: 'Eventos pontuais alinhados aos takes',
                status: 'EDITAVEL',
                waveformSeed: 17,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMusicConfiguration(ProductionEpisodeItem episode) {
    const providers = [
      'API de musica (a definir)',
      'API externa',
      'Suno',
      'ElevenLabs Music',
      'Arquivo proprio',
    ];
    final provider = providers.contains(episode.musicProvider)
        ? episode.musicProvider
        : providers.first;
    final generating = episode.musicStatus == 'GENERATING';
    return _panel(
      title: 'Gerador de musica externo',
      icon: Icons.library_music_outlined,
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: episode.externalMusic,
            onChanged: (value) {
              _replaceEpisode(episode.copyWith(externalMusic: value));
            },
            title: const Text(
              'Manter musica fora do Seedance',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Permite trocar, regenerar e mixar sem refazer o video.',
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: provider,
            decoration: const InputDecoration(
              labelText: 'Provedor / origem',
              prefixIcon: Icon(Icons.cloud_outlined),
            ),
            items: providers
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: episode.externalMusic
                ? (value) {
                    if (value != null) {
                      _replaceEpisode(episode.copyWith(musicProvider: value));
                    }
                  }
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: episode.musicPrompt,
            enabled: episode.externalMusic,
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: 'Prompt da trilha musical',
              alignLabelWithHint: true,
              helperText:
                  'Inclua duracao, arco emocional, instrumentos, pontos de virada e "sem voz".',
            ),
            onChanged: (value) {
              _replaceEpisode(episode.copyWith(musicPrompt: value));
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: !episode.externalMusic || generating
                  ? null
                  : _simulateMusic,
              icon: generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                generating
                    ? 'Simulando geracao...'
                    : episode.musicStatus == 'COMPLETED'
                    ? 'Gerar outra versao'
                    : 'Simular faixa musical',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioMixer(ProductionEpisodeItem episode) {
    return _panel(
      title: 'Mixer',
      icon: Icons.tune,
      trailing: _pill('MASTER -6 dB'),
      child: Column(
        children: [
          _buildMixerChannel(
            icon: Icons.record_voice_over_outlined,
            color: const Color(0xFF8B5CF6),
            label: 'Dialogo',
            value: episode.dialogueVolume,
            onChanged: (value) {
              _replaceEpisode(episode.copyWith(dialogueVolume: value));
            },
          ),
          _buildMixerChannel(
            icon: Icons.music_note,
            color: const Color(0xFFEC4899),
            label: 'Musica',
            value: episode.musicVolume,
            onChanged: episode.externalMusic
                ? (value) {
                    _replaceEpisode(episode.copyWith(musicVolume: value));
                  }
                : null,
          ),
          _buildMixerChannel(
            icon: Icons.air,
            color: const Color(0xFF14B8A6),
            label: 'Ambiente',
            value: episode.ambienceVolume,
            onChanged: (value) {
              _replaceEpisode(episode.copyWith(ambienceVolume: value));
            },
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceLighter),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: AppColors.success,
                  size: 20,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Ducking de musica durante falas e continuidade de room tone habilitados.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMixerChannel({
    required IconData icon,
    required Color color,
    required String label,
    required double value,
    required ValueChanged<double>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(35),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(0.0, 1.0),
              activeColor: color,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '${(value * 100).round()}%',
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStemCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String status,
    required int waveformSeed,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLighter),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(35),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 11),
          SizedBox(
            width: 165,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 38,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(52, (index) {
                  final raw = ((index + waveformSeed) * 37) % 29;
                  final height = 7.0 + raw;
                  return Expanded(
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        height: height,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: color.withAlpha(145),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _pill(status, _statusColor(status)),
        ],
      ),
    );
  }

  Future<void> _simulateMusic() async {
    final episode = _episode;
    if (episode == null || episode.musicStatus == 'GENERATING') return;
    _replaceEpisode(episode.copyWith(musicStatus: 'GENERATING'));
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted || _episode == null) return;
    _replaceEpisode(_episode!.copyWith(musicStatus: 'COMPLETED'));
    await _saveProject(notify: false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Faixa musical externa simulada e adicionada a timeline'),
      ),
    );
  }
}
