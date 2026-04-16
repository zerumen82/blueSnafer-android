/// Exploit generado por modelos TFLite
class GeneratedExploit {
  final String vulnerabilityType;
  final String exploitCode;
  final String targetPlatform;
  final String generationMethod;
  final String complexityLevel;
  final double estimatedSuccessRate;
  final List<String> requiredResources;
  final DateTime timestamp;

  GeneratedExploit({
    required this.vulnerabilityType,
    required this.exploitCode,
    required this.targetPlatform,
    required this.generationMethod,
    required this.complexityLevel,
    required this.estimatedSuccessRate,
    required this.requiredResources,
    required this.timestamp,
  });
}

/// Clases de resultado de análisis TFLite
class PinBypassPrediction {
  final bool isVulnerable;
  final double confidence;
  final double threshold;
  final List<String> outputClasses;
  final Map<String, dynamic>? adaptiveFactors;

  PinBypassPrediction({
    required this.isVulnerable,
    required this.confidence,
    required this.threshold,
    required this.outputClasses,
    this.adaptiveFactors,
  });
}

class AttackSuccessPrediction {
  final List<double> attackSuccessProbabilities;
  final List<String> attackTypes;
  final double overallSuccessScore;
  final Map<String, double>? adaptiveWeights;
  final double? modelConfidence;
  final List<String>? recommendedAttacks;

  AttackSuccessPrediction({
    required this.attackSuccessProbabilities,
    required this.attackTypes,
    required this.overallSuccessScore,
    this.adaptiveWeights,
    this.modelConfidence,
    this.recommendedAttacks,
  });
}

class DeviceClassification {
  final String deviceCategory;
  final List<double> categoryProbabilities;
  final List<String> categories;
  final double confidence;

  DeviceClassification({
    required this.deviceCategory,
    required this.categoryProbabilities,
    required this.categories,
    required this.confidence,
  });
}

class CountermeasureDetection {
  final List<String> detectedCountermeasures;
  final List<double> countermeasureProbabilities;
  final List<String> countermeasures;
  final double overallSecurityLevel;

  CountermeasureDetection({
    required this.detectedCountermeasures,
    required this.countermeasureProbabilities,
    required this.countermeasures,
    required this.overallSecurityLevel,
  });
}

class JavaVulnerabilityAnalysis {
  final List<double> vulnerabilityScores;
  final List<String> vulnerabilityTypes;
  final List<String> highRiskVulnerabilities;
  final double overallRiskScore;
  final double threshold;

  JavaVulnerabilityAnalysis({
    required this.vulnerabilityScores,
    required this.vulnerabilityTypes,
    required this.highRiskVulnerabilities,
    required this.overallRiskScore,
    required this.threshold,
  });
}

class JavaExploitGeneration {
  final String exploitCode;
  final String vulnerabilityType;
  final String targetSystem;
  final double generationScore;
  final List<String> vulnerabilityTypes;

  JavaExploitGeneration({
    required this.exploitCode,
    required this.vulnerabilityType,
    required this.targetSystem,
    required this.generationScore,
    required this.vulnerabilityTypes,
  });
}
