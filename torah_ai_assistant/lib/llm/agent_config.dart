abstract class LlmProvider {
  Future<String> call(List<Map<String, String>> messages);
}

class AgentConfig {
  final String groqApiKey;
  final String model;
  final int maxTokens;
  final double temperature;
  final Duration timeout;

  AgentConfig({
    required this.groqApiKey,
    this.model = 'llama-3.3-70b-versatile',
    this.maxTokens = 1000,
    this.temperature = 0.7,
    this.timeout = const Duration(seconds: 30),
  });
}