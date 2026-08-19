class SeasonBeatEngine {
  final int durationSeconds;
  final String hook;
  final String friction;
  final String spike;
  final String button;
  final String freezeFrameCheck;
  final String peakCutRule;

  const SeasonBeatEngine({
    required this.durationSeconds,
    required this.hook,
    required this.friction,
    required this.spike,
    required this.button,
    required this.freezeFrameCheck,
    required this.peakCutRule,
  });

  Map<String, dynamic> toJson() => {
    'duration_seconds': durationSeconds,
    'hook': hook,
    'friction': friction,
    'spike': spike,
    'button': button,
    'freeze_frame_check': freezeFrameCheck,
    'peak_cut_rule': peakCutRule,
  };
}

class SeasonRetentionProfile {
  final String distributionProfile;
  final int episodeCount;
  final int firstEpisodeDurationSeconds;
  final int otherEpisodeDurationSeconds;
  final int freeEpisodeCount;
  final int? paywallEpisode;
  final int? payoffAfterPaywallEpisode;
  final String primaryConversion;
  final String acquisitionClipSeconds;
  final String centralQuestionPayoffWindow;
  final SeasonBeatEngine beatEngineFirst;
  final SeasonBeatEngine beatEngineOther;

  const SeasonRetentionProfile({
    required this.distributionProfile,
    required this.episodeCount,
    required this.firstEpisodeDurationSeconds,
    required this.otherEpisodeDurationSeconds,
    required this.freeEpisodeCount,
    required this.paywallEpisode,
    required this.payoffAfterPaywallEpisode,
    required this.primaryConversion,
    required this.acquisitionClipSeconds,
    required this.centralQuestionPayoffWindow,
    required this.beatEngineFirst,
    required this.beatEngineOther,
  });

  Map<String, dynamic> toJson() => {
    'distribution_profile': distributionProfile,
    'episode_count': episodeCount,
    'first_episode_duration_seconds': firstEpisodeDurationSeconds,
    'other_episode_duration_seconds': otherEpisodeDurationSeconds,
    'free_episode_count': freeEpisodeCount,
    'paywall_episode': paywallEpisode,
    'payoff_after_paywall_episode': payoffAfterPaywallEpisode,
    'primary_conversion': primaryConversion,
    'acquisition_clip_seconds': acquisitionClipSeconds,
    'central_question_payoff_window': centralQuestionPayoffWindow,
    'beat_engine_first': beatEngineFirst.toJson(),
    'beat_engine_other': beatEngineOther.toJson(),
  };
}

class SeasonBlockPlan {
  final String id;
  int start;
  int end;
  String episodes;
  final String role;
  final String conversionRole;
  final List<String> mustNotResolve;

  SeasonBlockPlan({
    required this.id,
    required this.start,
    required this.end,
    required this.episodes,
    required this.role,
    required this.conversionRole,
    required this.mustNotResolve,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'start': start,
    'end': end,
    'episodes': episodes,
    'role': role,
    'conversion_role': conversionRole,
    'must_not_resolve': mustNotResolve,
  };
}

class SeasonArchitecture {
  const SeasonArchitecture._();

  static SeasonBeatEngine beatEngineForDuration(int seconds) {
    final duration = seconds < 20 ? 20 : seconds;
    final hookEnd = (duration * 0.2).round().clamp(8, 15);
    final buttonLen = (duration * 0.1).round().clamp(5, 10);
    final buttonStart = duration - buttonLen;
    final frictionEnd =
        (hookEnd + (buttonStart - hookEnd) * 0.55).round();
    return SeasonBeatEngine(
      durationSeconds: duration,
      hook: '0-${hookEnd}s',
      friction: '$hookEnd-${frictionEnd}s',
      spike: '$frictionEnd-${buttonStart}s',
      button: '$buttonStart-${duration}s',
      freezeFrameCheck: '3s',
      peakCutRule:
          'Cortar 2 segundos antes do que parece seguro, na pergunta sem resposta, nunca na explicação.',
    );
  }

  static int ceilingStart(int episodeCount) {
    final n = episodeCount < 1 ? 1 : episodeCount;
    if (n <= 8) return n < 1 ? 1 : n - 1 < 1 ? 1 : n - 1;
    if (n <= 20) return n - 3 < 1 ? 1 : n - 3;
    final start = (n * 0.82).round();
    return start < 1 ? 1 : start;
  }

  static SeasonRetentionProfile buildRetentionProfile({
    required int episodeCount,
    int firstDuration = 120,
    int otherDuration = 60,
    String distributionProfile = 'app_native',
    int? freeEpisodeCount,
    int? paywallPosition,
  }) {
    final n = episodeCount < 1 ? 1 : episodeCount;
    final first = firstDuration < 1 ? 120 : firstDuration;
    final other = otherDuration < 1 ? 60 : otherDuration;
    final distribution = distributionProfile.trim().isEmpty
        ? 'app_native'
        : distributionProfile.trim();
    final social = distribution == 'social_serialized';

    var freeCount = n;
    if (freeEpisodeCount != null && freeEpisodeCount > 0) {
      freeCount = freeEpisodeCount < n ? freeEpisodeCount : n;
    } else if (social || n <= 3) {
      freeCount = n;
    } else if (n <= 8) {
      final computed = (n * 0.4).floor();
      freeCount = computed < 2 ? 2 : computed;
    } else if (n <= 20) {
      freeCount = 5;
    } else {
      freeCount = 8;
    }

    int? paywall;
    if (social || n <= 3) {
      paywall = null;
    } else if (paywallPosition != null && paywallPosition > 0) {
      paywall = paywallPosition < n ? paywallPosition : n;
    } else {
      paywall = freeCount < n ? freeCount : n;
    }
    if (paywall != null && freeCount > paywall) freeCount = paywall;

    final wall = paywall;
    final payoffAfter = wall == null
        ? null
        : () {
            final gap = n - wall;
            final step = gap < 1 ? 1 : (gap > 2 ? 2 : gap);
            final value = wall + step;
            return value < n ? value : n;
          }();

    return SeasonRetentionProfile(
      distributionProfile: distribution,
      episodeCount: n,
      firstEpisodeDurationSeconds: first,
      otherEpisodeDurationSeconds: other,
      freeEpisodeCount: paywall == null ? n : freeCount,
      paywallEpisode: paywall,
      payoffAfterPaywallEpisode: payoffAfter,
      primaryConversion: social ? 'next_view' : 'unlock',
      acquisitionClipSeconds: '5-12s',
      centralQuestionPayoffWindow: '${ceilingStart(n)}-$n',
      beatEngineFirst: beatEngineForDuration(first),
      beatEngineOther: beatEngineForDuration(other),
    );
  }

  static SeasonBlockPlan _block(
    String id,
    int start,
    int end,
    String role,
    String conversionRole,
    List<String> mustNot,
  ) => SeasonBlockPlan(
    id: id,
    start: start,
    end: end,
    episodes: start == end ? '$start' : '$start-$end',
    role: role,
    conversionRole: conversionRole,
    mustNotResolve: mustNot,
  );

  static List<SeasonBlockPlan> plannedSeasonBlocks(
    int episodeCount,
    int? paywallEpisode,
  ) {
    final n = episodeCount < 1 ? 1 : episodeCount;
    if (n == 1) {
      return [
        _block(
          'standalone',
          1,
          1,
          'complete_microstory_open_loop',
          'acquisition_clip',
          const ['season_mythology'],
        ),
      ];
    }

    final paywall =
        paywallEpisode != null && paywallEpisode > 0 && paywallEpisode <= n
        ? paywallEpisode
        : null;
    final blocks = <SeasonBlockPlan>[];
    final ceilingFloor = [n <= 8 ? 2 : 3, ceilingStart(n)].reduce(
      (a, b) => a > b ? a : b,
    );
    final remainingAfterPaywall = paywall == null ? n : n - paywall;

    if (paywall != null && paywall > 1) {
      blocks.add(
        _block(
          'premise_hook',
          1,
          paywall - 1,
          'detonate_premise_prove_fantasy',
          'free_funnel',
          const ['central_question', 'antagonist_defeat'],
        ),
      );
      blocks.add(
        _block(
          'conversion',
          paywall,
          paywall,
          'paywall_question',
          'paywall_cliffhanger',
          const ['central_question', 'paywall_answer', 'antagonist_defeat'],
        ),
      );
    } else {
      final rawFunnel = paywall ?? (n * 0.15).round();
      final funnelEnd = rawFunnel < 1 ? 1 : (rawFunnel > n ? n : rawFunnel);
      blocks.add(
        _block(
          'premise_hook',
          1,
          funnelEnd,
          'detonate_premise_prove_fantasy',
          paywall == 1 ? 'paywall_cliffhanger' : 'acquisition_clip',
          const ['central_question', 'antagonist_defeat'],
        ),
      );
    }

    var cursor = blocks.last.end + 1;
    if (cursor > n) return blocks;

    final shortPaidTail = paywall != null && remainingAfterPaywall <= 3;
    if (paywall != null && !shortPaidTail && cursor <= n) {
      final paidCap = paywall + 2;
      final paidEnd = [
        n,
        paidCap,
        ceilingFloor - 1,
      ].reduce((a, b) => a < b ? a : b);
      if (paidEnd >= cursor) {
        blocks.add(
          _block(
            'paid_payoff',
            cursor,
            paidEnd,
            'pay_then_open_larger_problem',
            'post_paywall_payoff',
            const ['central_question', 'antagonist_defeat'],
          ),
        );
        cursor = paidEnd + 1;
      }
    }
    if (cursor > n) return blocks;

    final climaxStart = cursor > ceilingFloor ? cursor : ceilingFloor;
    if (n >= 40 && cursor < climaxStart) {
      final darkCandidate = (n * 0.45).round() + 1;
      final darkStart = cursor > darkCandidate ? cursor : darkCandidate;
      if (darkStart - 1 >= cursor) {
        blocks.add(
          _block(
            'escalation',
            cursor,
            darkStart - 1,
            'complication_almost_moments',
            'binge_midgame',
            const ['central_question', 'antagonist_defeat'],
          ),
        );
        cursor = darkStart;
      }
      if (cursor <= climaxStart - 1) {
        blocks.add(
          _block(
            'dark_middle',
            cursor,
            climaxStart - 1,
            'farthest_from_resolution',
            'sunk_cost',
            const ['central_question'],
          ),
        );
        cursor = climaxStart;
      }
    } else if (cursor <= climaxStart - 1) {
      blocks.add(
        _block(
          'escalation',
          cursor,
          climaxStart - 1,
          shortPaidTail
              ? 'pay_then_open_larger_problem'
              : 'rising_cost_and_counterplay',
          shortPaidTail ? 'post_paywall_payoff' : 'binge_midgame',
          const ['central_question', 'antagonist_defeat'],
        ),
      );
      cursor = climaxStart;
    }

    if (cursor <= n) {
      blocks.add(
        _block(
          'ceiling',
          cursor,
          n,
          'earned_payoff_renewal_hook',
          shortPaidTail ? 'post_paywall_payoff' : 'season_payoff',
          const [],
        ),
      );
    }

    return normalizeSeasonBlocks(blocks, n);
  }

  static List<SeasonBlockPlan> normalizeSeasonBlocks(
    List<SeasonBlockPlan> blocks,
    int episodeCount,
  ) {
    final n = episodeCount < 1 ? 1 : episodeCount;
    final sorted = [...blocks]
      ..sort((a, b) {
        final start = a.start.compareTo(b.start);
        return start != 0 ? start : a.end.compareTo(b.end);
      });
    final out = <SeasonBlockPlan>[];
    var next = 1;
    for (final item in sorted) {
      if (item.end < next) continue;
      final start = item.start > next ? item.start : next;
      if (start > next && out.isNotEmpty) {
        out.last.end = start - 1;
        out.last.episodes = out.last.start == start - 1
            ? '${out.last.start}'
            : '${out.last.start}-${start - 1}';
      } else if (start > next) {
        out.add(
          _block(
            'escalation',
            next,
            start - 1,
            'rising_cost_and_counterplay',
            'binge_midgame',
            const ['central_question', 'antagonist_defeat'],
          ),
        );
      }
      item.start = start;
      item.episodes = start == item.end ? '$start' : '$start-${item.end}';
      out.add(item);
      next = item.end + 1;
    }
    if (next <= n) {
      if (out.isNotEmpty) {
        out.last.end = n;
        out.last.episodes = out.last.start == n
            ? '$n'
            : '${out.last.start}-$n';
      } else {
        out.add(
          _block(
            'ceiling',
            1,
            n,
            'earned_payoff_renewal_hook',
            'season_payoff',
            const [],
          ),
        );
      }
    }
    return out;
  }

  static SeasonBlockPlan? blockForEpisode(
    List<SeasonBlockPlan> blocks,
    int episodeNumber,
  ) {
    for (final block in blocks) {
      if (episodeNumber >= block.start && episodeNumber <= block.end) {
        return block;
      }
    }
    return null;
  }

  static const pressureTypes = [
    'identity',
    'deadline',
    'evidence',
    'intimacy',
    'status',
    'freedom',
  ];

  static String pressureTypeFor(int episodeNumber) =>
      pressureTypes[(episodeNumber - 1) % pressureTypes.length];

  static List<Map<String, dynamic>> defaultReservedReveals({
    required String centralQuestion,
    required String opposingForce,
    required SeasonRetentionProfile profile,
    required List<SeasonBlockPlan> blocks,
  }) {
    final ceiling =
        blockForEpisode(blocks, profile.episodeCount) ?? blocks.last;
    final lateStart =
        blocks
            .where((item) => item.id == 'dark_middle' || item.id == 'escalation')
            .map((item) => item.start)
            .fold<int?>(null, (best, start) {
              if (best == null || start < best) return start;
              return best;
            }) ??
        ceiling.start;
    final paywallPayoff = profile.payoffAfterPaywallEpisode ?? ceiling.start;
    return [
      {
        'id': 'central_question',
        'fact': centralQuestion,
        'earliest_episode': ceiling.start,
        'payoff_episode': profile.episodeCount,
        'why_late':
            'A pergunta central só pode ser paga no bloco final, senão a temporada acaba cedo.',
      },
      {
        'id': 'antagonist_defeat',
        'fact': 'A derrota definitiva de $opposingForce',
        'earliest_episode': lateStart,
        'payoff_episode': profile.episodeCount,
        'why_late':
            'A força oposta precisa vencer de verdade no meio da temporada.',
      },
      {
        'id': 'paywall_answer',
        'fact': 'A resposta da pergunta que o paywall deixa em aberto',
        'earliest_episode': paywallPayoff,
        'payoff_episode': paywallPayoff,
        'why_late':
            'O episódio do paywall só pode fazer a pergunta; o pagamento vem 1-2 episódios depois.',
      },
    ];
  }

  static Map<String, dynamic> spineSlot({
    required int episodeNumber,
    required SeasonBlockPlan block,
    required List<Map<String, dynamic>> reservedReveals,
  }) {
    final locked = reservedReveals
        .where((item) {
          final earliest = (item['earliest_episode'] as num?)?.toInt() ?? 999;
          return earliest > episodeNumber;
        })
        .map((item) => item['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    return {
      'episode': episodeNumber,
      'block_id': block.id,
      'function': block.role,
      'dominant_question':
          'Qual escolha irreversível o EP$episodeNumber força agora?',
      'promise_paid': block.conversionRole == 'post_paywall_payoff'
          ? 'paywall_promise'
          : null,
      'promise_opened': block.conversionRole == 'paywall_cliffhanger'
          ? 'paywall_promise'
          : null,
      'reserved_ids_locked': locked,
      'pressure_type': pressureTypeFor(episodeNumber),
      'relationship_shift':
          'O vínculo central muda por uma decisão visível, não por mal-entendido adiado.',
      'conversion_role': block.conversionRole,
      'must_not': block.mustNotResolve.join(', '),
    };
  }

  static bool episodeRequiresUnlock(int episodeNumber, int freeEpisodeCount) =>
      episodeNumber > freeEpisodeCount;

  static Map<String, dynamic> architectureBible({
    required SeasonRetentionProfile profile,
    required List<SeasonBlockPlan> blocks,
    required List<Map<String, dynamic>> reservedReveals,
    required List<Map<String, dynamic>> spine,
    String acquisitionClip = '',
  }) => {
    ...profile.toJson(),
    'acquisition_clip': acquisitionClip,
    'status': 'LOCKED_FOR_OUTLINE',
    'blocks': blocks.map((item) => item.toJson()).toList(),
    'reserved_reveal_count': reservedReveals.length,
  };

  static const defaultOutlineBatchSize = 5;

  static Map<String, dynamic> outlineBatchRange({
    required int fromEpisode,
    required int targetEpisodeCount,
    int batchSize = defaultOutlineBatchSize,
  }) {
    final target = targetEpisodeCount < 1 ? 1 : targetEpisodeCount;
    final size = batchSize < 1
        ? defaultOutlineBatchSize
        : (batchSize > 20 ? 20 : batchSize);
    final from = fromEpisode < 1
        ? 1
        : (fromEpisode > target ? target : fromEpisode);
    final through = (from + size - 1) > target ? target : (from + size - 1);
    final remaining = target - through;
    return {
      'fromEpisode': from,
      'throughEpisode': through,
      'targetEpisodeCount': target,
      'remaining': remaining < 0 ? 0 : remaining,
      'canContinue': remaining > 0,
      'nextFromEpisode': remaining > 0 ? through + 1 : null,
      'batchSize': size,
      'isFullSeason': from == 1 && through == target,
    };
  }

  static int? nextOutlineEpisode({
    required Iterable<int> outlinedNumbers,
    required int targetEpisodeCount,
  }) {
    if (targetEpisodeCount < 1) return null;
    final numbers = outlinedNumbers.toSet();
    var next = 1;
    while (next <= targetEpisodeCount && numbers.contains(next)) {
      next += 1;
    }
    return next > targetEpisodeCount ? null : next;
  }

  static final placeholderTitlePattern = RegExp(
    r'^gerando epis[oó]dio',
    caseSensitive: false,
  );

  static bool isPlaceholderTitle(String title) {
    final value = title.trim();
    if (value.isEmpty) return true;
    return placeholderTitlePattern.hasMatch(value) ||
        RegExp(r'^epis[oó]dio\s*\d+$', caseSensitive: false).hasMatch(value);
  }

  static bool isReadyOutline({
    required String status,
    required String title,
    required String summary,
  }) {
    if (status == 'GENERATING') return false;
    if (summary.trim().isEmpty) return false;
    if (isPlaceholderTitle(title)) return false;
    return true;
  }

  static bool hasLockedSeasonArchitecture(Map<String, dynamic> bible) {
    final architecture = bible['season_architecture'];
    if (architecture is! Map) return false;
    final blocks = architecture['blocks'];
    return blocks is List && blocks.isNotEmpty;
  }
}
