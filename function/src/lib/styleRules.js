const passiveVoiceHint = /\b(was|were|is|are|been|being|be)\s+\w+ed\b/i;
const weakWords = ['very', 'really', 'just', 'thing', 'stuff'];

export function analyzeText(text) {
  const normalized = (text ?? '').trim();
  const issues = [];

  if (!normalized) {
    issues.push({
      ruleId: 'EMPTY_INPUT',
      severity: 'warning',
      message: 'No text provided. Paste content before running analysis.',
      suggestion: 'Add at least one sentence to analyze.',
    });
    return issues;
  }

  if (normalized.length > 2400) {
    issues.push({
      ruleId: 'TEXT_TOO_LONG',
      severity: 'info',
      message: 'Long selections are harder to revise in one pass.',
      suggestion: 'Analyze one section at a time (about 2-3 paragraphs).',
    });
  }

  if (passiveVoiceHint.test(normalized)) {
    issues.push({
      ruleId: 'PASSIVE_VOICE',
      severity: 'warning',
      message: 'Possible passive voice detected.',
      suggestion: 'Prefer active voice when clarity matters.',
    });
  }

  const matchedWeakWords = weakWords.filter((word) =>
    new RegExp(`\\b${word}\\b`, 'i').test(normalized),
  );

  if (matchedWeakWords.length > 0) {
    issues.push({
      ruleId: 'WEAK_WORDS',
      severity: 'info',
      message: `Found weak qualifiers: ${matchedWeakWords.join(', ')}.`,
      suggestion: 'Replace vague words with specific alternatives.',
    });
  }

  const sentenceCount = normalized.split(/[.!?]+/).filter(Boolean).length;
  const avgWordsPerSentence =
    sentenceCount === 0 ? 0 : normalized.split(/\s+/).filter(Boolean).length / sentenceCount;

  if (avgWordsPerSentence > 22) {
    issues.push({
      ruleId: 'LONG_SENTENCES',
      severity: 'warning',
      message: 'Average sentence length is high.',
      suggestion: 'Break long sentences into shorter units.',
    });
  }

  if (issues.length === 0) {
    issues.push({
      ruleId: 'NO_ISSUES',
      severity: 'success',
      message: 'No style issues detected by baseline rules.',
      suggestion: 'Looks good. Consider manual review for tone and audience fit.',
    });
  }

  return issues;
}
