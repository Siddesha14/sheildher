import 'dart:convert';

import 'package:flutter/services.dart';

class DistressIntentResult {
  const DistressIntentResult({
    required this.isDistressIntent,
    required this.score,
    required this.matchedSignals,
    required this.transcript,
  });

  final bool isDistressIntent;
  final double score;
  final List<String> matchedSignals;
  final String transcript;
}

class DistressIntentDetector {
  bool _isInitialized = false;
  double _distressThreshold = 0.88;
  double _strongCommandThreshold = 0.72;
  Map<String, double> _nonDistressLogProb = {};
  Map<String, double> _distressLogProb = {};
  double _nonDistressPrior = -0.6931471806;
  double _distressPrior = -0.6931471806;
  double _unknownNonDistressLogProb = -6.2;
  double _unknownDistressLogProb = -6.2;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final raw = await rootBundle.loadString('assets/models/en_distress_intent_model.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final tokenLogProb = data['token_log_prob'] as Map<String, dynamic>;
    final classLogPrior = data['class_log_prior'] as Map<String, dynamic>;
    final unknownTokenLogProb = data['unknown_token_log_prob'] as Map<String, dynamic>;
    final thresholds = data['thresholds'] as Map<String, dynamic>;

    _nonDistressPrior = (classLogPrior['non_distress'] as num).toDouble();
    _distressPrior = (classLogPrior['distress'] as num).toDouble();
    _unknownNonDistressLogProb = (unknownTokenLogProb['non_distress'] as num).toDouble();
    _unknownDistressLogProb = (unknownTokenLogProb['distress'] as num).toDouble();
    _distressThreshold = (thresholds['distress_probability'] as num).toDouble();
    _strongCommandThreshold = (thresholds['strong_command_probability'] as num).toDouble();

    _nonDistressLogProb = {};
    _distressLogProb = {};
    tokenLogProb.forEach((token, probs) {
      final p = probs as Map<String, dynamic>;
      _nonDistressLogProb[token] = (p['non_distress'] as num).toDouble();
      _distressLogProb[token] = (p['distress'] as num).toDouble();
    });

    _isInitialized = true;
  }

  DistressIntentResult detect({
    required String transcript,
    required double speechConfidence,
  }) {
    if (!_isInitialized) {
      return DistressIntentResult(
        isDistressIntent: false,
        score: 0,
        matchedSignals: const ['model_not_initialized'],
        transcript: transcript,
      );
    }

    final text = _normalize(transcript);
    if (text.isEmpty) {
      return const DistressIntentResult(
        isDistressIntent: false,
        score: 0,
        matchedSignals: [],
        transcript: '',
      );
    }

    // Strong intent templates (high precision).
    final strongPatterns = <RegExp>[
      RegExp(r'\b(call|contact|dial)\s+(the\s+)?(police|cops|emergency)\b'),
      RegExp(r'\b(send|trigger|activate)\s+(an?\s+)?sos\b'),
      RegExp(r'\bhelp\s+me\b'),
      RegExp(r'\bsave\s+me\b'),
      RegExp(r"\b(i am|im|i'm)\s+in\s+(danger|trouble)\b"),
      RegExp(r'\b(please\s+)?call\s+for\s+help\b'),
    ];

    final negativeSafetyPatterns = <RegExp>[
      RegExp(r"\b(no|not|don't)\s+need\s+help\b"),
      RegExp(r'\bjust\s+kidding\b'),
      RegExp(r'\btest(ing)?\s+(sos|alarm|emergency)\b'),
      RegExp(r'\bfalse\s+alarm\b'),
    ];

    final matchedSignals = <String>[];
    var score = 0.0;
    var hasStrongIntent = false;

    for (final pattern in strongPatterns) {
      if (pattern.hasMatch(text)) {
        hasStrongIntent = true;
        matchedSignals.add('strong_pattern');
      }
    }

    final tokens = text.split(' ').where((t) => t.isNotEmpty).toList();
    var distressLogScore = _distressPrior;
    var nonDistressLogScore = _nonDistressPrior;
    for (final token in tokens) {
      distressLogScore += _distressLogProb[token] ?? _unknownDistressLogProb;
      nonDistressLogScore += _nonDistressLogProb[token] ?? _unknownNonDistressLogProb;
    }

    final distressProbability = _sigmoid(distressLogScore - nonDistressLogScore);
    score = distressProbability;

    for (final pattern in negativeSafetyPatterns) {
      if (pattern.hasMatch(text)) {
        matchedSignals.add('negative_pattern');
        score *= 0.25;
      }
    }

    // Blend in ASR confidence for precision-first behavior.
    final normalizedConfidence = speechConfidence < 0 ? 0.5 : speechConfidence.clamp(0.0, 1.0);
    final calibratedScore = (score * 0.85) + (normalizedConfidence * 0.15);

    if (hasStrongIntent) {
      matchedSignals.add('strong_intent_command');
    }
    matchedSignals.add('distress_probability:${calibratedScore.toStringAsFixed(3)}');
    matchedSignals.add('speech_confidence:${normalizedConfidence.toStringAsFixed(3)}');

    final highPrecisionHit =
        hasStrongIntent && calibratedScore >= _strongCommandThreshold && normalizedConfidence >= 0.35;
    final modelHit = calibratedScore >= _distressThreshold && normalizedConfidence >= 0.45;
    final isDistressIntent = highPrecisionHit || modelHit;

    return DistressIntentResult(
      isDistressIntent: isDistressIntent,
      score: calibratedScore,
      matchedSignals: matchedSignals,
      transcript: transcript,
    );
  }

  double _sigmoid(double x) {
    if (x >= 0) {
      final z = _exp(-x);
      return 1 / (1 + z);
    }
    final z = _exp(x);
    return z / (1 + z);
  }

  double _exp(double x) {
    const terms = 18;
    var sum = 1.0;
    var term = 1.0;
    for (var n = 1; n <= terms; n++) {
      term *= x / n;
      sum += term;
    }
    return sum;
  }

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9\s']"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
