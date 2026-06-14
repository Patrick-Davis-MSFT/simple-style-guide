import { useEffect, useState } from 'react';
import {
  Badge,
  Button,
  Card,
  CardHeader,
  Field,
  Input,
  Spinner,
  Text,
  Textarea,
} from '@fluentui/react-components';

type Issue = {
  ruleId: string;
  severity: 'warning' | 'info' | 'success';
  message: string;
  suggestion: string;
};

type ApiResponse = {
  analyzedAtUtc: string;
  issueCount: number;
  issues: Issue[];
  replacements?: Replacement[];
};

type Replacement = {
  ORIGINAL_TEXT: string;
  NEW_TEXT: string;
  REASON: string;
};

type ReplacementApplySummary = {
  appliedCount: number;
  skippedCount: number;
};

type RuntimeConfig = {
  functionUrl?: string;
};

const configuredBaseUrl = (import.meta.env.VITE_FUNCTION_BASE_URL ?? '').trim();
const configuredApiUrl = (import.meta.env.FUNCTION_API_URL ?? '').trim();

const defaultFunctionUrl = configuredBaseUrl
  ? `${configuredBaseUrl.replace(/\/$/, '')}/api/style-check`
  : configuredApiUrl || '/api/style-check';
const deploymentTime =
  (globalThis as { __DEPLOYED_AT__?: string }).__DEPLOYED_AT__ ?? 'Unavailable';

const MAX_TEXT_LENGTH = 25000;
const MAX_WORD_SEARCH_LENGTH = 255;

function stripControlChars(value: string): string {
  let sanitized = '';

  for (const char of value) {
    const code = char.charCodeAt(0);
    const isAsciiControl =
      (code >= 0 && code <= 8) ||
      code === 11 ||
      code === 12 ||
      (code >= 14 && code <= 31) ||
      code === 127;

    if (!isAsciiControl) {
      sanitized += char;
    }
  }

  return sanitized;
}

function sanitizeWordText(raw: string): string {
  const withoutControls = stripControlChars(raw);

  return withoutControls
    .replace(/[\u2018\u2019]/g, "'")
    .replace(/[\u201C\u201D]/g, '"')
    .replace(/\u00A0/g, ' ')
    .replace(/\u00AD/g, '')
    .replace(/[\u200B-\u200D\uFEFF]/g, '')
    .replace(/\r\n/g, '\n')
    .replace(/\r/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function toWordNativeText(text: string): string {
  return text
    .replace(/'/g, '\u2019')
    .replace(/"/g, '\u201C');
}

export function App() {
  const [isWordHost, setIsWordHost] = useState(false);
  const [functionUrl, setFunctionUrl] = useState(defaultFunctionUrl);
  const [selectedText, setSelectedText] = useState('');
  const [issues, setIssues] = useState<Issue[]>([]);
  const [replacements, setReplacements] = useState<Replacement[]>([]);
  const [replacementNotice, setReplacementNotice] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    let isDisposed = false;

    const loadRuntimeConfig = async () => {
      try {
        const response = await fetch('/api/config', {
          method: 'GET',
          headers: {
            Accept: 'application/json',
          },
        });

        if (!response.ok) {
          return;
        }

        const config = (await response.json()) as RuntimeConfig;
        const runtimeFunctionUrl = (config.functionUrl ?? '').trim();

        if (!isDisposed && runtimeFunctionUrl) {
          setFunctionUrl(runtimeFunctionUrl);
        }
      } catch {
        // Keep compile-time/default fallback URL when runtime config is unavailable.
      }
    };

    void loadRuntimeConfig();

    return () => {
      isDisposed = true;
    };
  }, []);

  useEffect(() => {
    let isMounted = true;

    const detectHost = async () => {
      if (typeof Office === 'undefined' || typeof Office.onReady !== 'function') {
        return;
      }

      try {
        const info = await Office.onReady();
        const host = info?.host ?? Office?.context?.host;
        const wordHost = Office?.HostType?.Word ?? 'Word';

        if (isMounted) {
          setIsWordHost(host === wordHost);
        }
      } catch {
        if (isMounted) {
          setIsWordHost(false);
        }
      }
    };

    void detectHost();

    return () => {
      isMounted = false;
    };
  }, []);

  const buildCommentText = (replacement: Replacement, wasAutoUpdated: boolean) => {
    const lines = [
      'Text review result:',
      `Original text: ${replacement.ORIGINAL_TEXT}`,
      `New text: ${replacement.NEW_TEXT}`,
      `Reason: ${replacement.REASON}`,
    ];

    if (wasAutoUpdated) {
      lines.push('This text was automatically updated by the add-in because track changes is enabled.');
    }

    return lines.join('\n');
  };

  const applyReplacementsToDocument = async (replacements: Replacement[]): Promise<ReplacementApplySummary> => {
    const summary: ReplacementApplySummary = { appliedCount: 0, skippedCount: 0 };

    if (!replacements.length) {
      return summary;
    }

    if (typeof Office === 'undefined' || typeof Office.onReady !== 'function' || typeof Word === 'undefined') {
      return summary;
    }

    const info = await Office.onReady();
    const host = info?.host ?? Office?.context?.host;
    const wordHost = Office?.HostType?.Word ?? 'Word';

    if (host !== wordHost) {
      return summary;
    }

    await Word.run(async (context: any) => {
      const document = context.document;
      let isTrackChangesEnabled = false;

      try {
        (document as any).load('changeTrackingMode');
        await context.sync();

        const trackingMode = (document as any).changeTrackingMode;
        isTrackChangesEnabled =
          trackingMode === Word.ChangeTrackingMode.trackAll ||
          trackingMode === Word.ChangeTrackingMode.trackMineOnly;
      } catch {
        isTrackChangesEnabled = false;
      }

      const selection = context.document.getSelection();

      for (const replacement of replacements) {
        if (!replacement.ORIGINAL_TEXT?.trim()) {
          summary.skippedCount += 1;
          continue;
        }

        // Word search fails for overly long search strings; skip safely.
        if (replacement.ORIGINAL_TEXT.length > MAX_WORD_SEARCH_LENGTH) {
          summary.skippedCount += 1;
          continue;
        }

        try {
          let matches = selection.search(replacement.ORIGINAL_TEXT, {
            matchCase: false,
            matchWholeWord: false,
          });

          matches.load('items');
          await context.sync();

          if (matches.items.length === 0) {
            const nativeText = toWordNativeText(replacement.ORIGINAL_TEXT);
            matches = selection.search(nativeText, {
              matchCase: false,
              matchWholeWord: false,
            });
            matches.load('items');
            await context.sync();
          }

          for (const match of matches.items) {
            if (isTrackChangesEnabled) {
              const commentText = buildCommentText(replacement, true);
              const updatedRange = match.insertText(replacement.NEW_TEXT ?? '', Word.InsertLocation.replace);
              updatedRange.insertComment(commentText);
              summary.appliedCount += 1;
            } else {
              const commentText = buildCommentText(replacement, false);
              match.insertComment(commentText);
              summary.appliedCount += 1;
            }
          }

          if (matches.items.length > 0) {
            await context.sync();
          }
        } catch {
          summary.skippedCount += 1;
        }
      }
    });

    return summary;
  };

  const readSelection = async ({ clearError = true }: { clearError?: boolean } = {}) => {
    if (clearError) {
      setError('');
    }

    if (typeof Office === 'undefined' || typeof Office.onReady !== 'function') {
      setError('Office runtime is not available. Open this page from Word add-in context.');
      return '';
    }

    try {
      const info = await Office.onReady();
      const host = info?.host ?? Office?.context?.host;
      const wordHost = Office?.HostType?.Word ?? 'Word';

      if (host !== wordHost) {
        setError('Office runtime is not available. Open this page from Word add-in context.');
        return '';
      }

      const rawText = await new Promise<string>((resolve, reject) => {
        Office.context.document.getSelectedDataAsync(
          Office.CoercionType.Text,
          (result: any) => {
            if (result.status === Office.AsyncResultStatus.Succeeded) {
              resolve(result.value ?? '');
              return;
            }

            reject(new Error(result.error?.message ?? 'Unable to read selection from Word.'));
          },
        );
      });

      const text = sanitizeWordText(rawText);
      setSelectedText(text);
      return text;
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      setError(`Failed to read selection: ${message}`);
      return '';
    }
  };

  const getCurrentEntraAccessToken = async (): Promise<string> => {
    const officeRuntimeAuth = (globalThis as any)?.OfficeRuntime?.auth;
    const officeAuth = (globalThis as any)?.Office?.auth;
    const tokenOptions = {
      allowSignInPrompt: true,
      allowConsentPrompt: true,
    };

    if (typeof officeRuntimeAuth?.getAccessToken === 'function') {
      try {
        const token = await officeRuntimeAuth.getAccessToken(tokenOptions);
        if (token) {
          return token;
        }
      } catch {
        // Fall through to other token providers.
      }
    }

    if (typeof officeAuth?.getAccessToken === 'function') {
      try {
        const token = await officeAuth.getAccessToken(tokenOptions);
        if (token) {
          return token;
        }
      } catch {
        // Fall through to browser host token provider.
      }
    }

    try {
      const meResponse = await fetch('/.auth/me', {
        method: 'GET',
        credentials: 'include',
      });

      if (!meResponse.ok) {
        return '';
      }

      const identities = (await meResponse.json()) as Array<Record<string, unknown>>;

      if (!Array.isArray(identities) || identities.length === 0) {
        return '';
      }

      for (const identity of identities) {
        const provider = String(identity.provider_name ?? identity.provider ?? '').toLowerCase();
        const isEntraProvider =
          provider.includes('aad') ||
          provider.includes('entra') ||
          provider.includes('azureactivedirectory') ||
          provider.includes('microsoft');

        if (isEntraProvider) {
          const token = String(identity.id_token ?? identity.access_token ?? '');
          if (token) {
            return token;
          }
        }
      }

      for (const identity of identities) {
        const token = String(identity.id_token ?? identity.access_token ?? '');
        if (token) {
          return token;
        }
      }
    } catch {
      return '';
    }

    return '';
  };

  useEffect(() => {
    if (!isWordHost) {
      return;
    }

    if (typeof Office === 'undefined' || typeof Office.onReady !== 'function') {
      return;
    }

    let isDisposed = false;
    let selectionReadTimeout: ReturnType<typeof setTimeout> | undefined;
    const eventType = Office.EventType.DocumentSelectionChanged;
    const onSelectionChanged = () => {
      if (selectionReadTimeout) {
        clearTimeout(selectionReadTimeout);
      }

      selectionReadTimeout = setTimeout(() => {
        if (!isDisposed) {
          void readSelection({ clearError: false });
        }
      }, 200);
    };

    const registerSelectionHandler = async () => {
      try {
        await Office.onReady();

        if (isDisposed) {
          return;
        }

        Office.context.document.addHandlerAsync(eventType, onSelectionChanged, (result: any) => {
          if (result.status !== Office.AsyncResultStatus.Succeeded && !isDisposed) {
            setError(result.error?.message ?? 'Unable to subscribe to selection changes in Word.');
          }
        });

        void readSelection({ clearError: false });
      } catch {
        if (!isDisposed) {
          setError('Unable to subscribe to selection changes in Word.');
        }
      }
    };

    void registerSelectionHandler();

    return () => {
      isDisposed = true;

      if (selectionReadTimeout) {
        clearTimeout(selectionReadTimeout);
      }

      try {
        Office.context.document.removeHandlerAsync(eventType, { handler: onSelectionChanged });
      } catch {
        // no-op cleanup fallback
      }
    };
  }, [isWordHost]);

  const runStyleCheck = async () => {
    setLoading(true);
    setError('');
    setReplacementNotice('');
    setIssues([]);
    setReplacements([]);

    try {
      let textToAnalyze = selectedText;
      let accessToken = '';

      if (isWordHost) {
        textToAnalyze = await readSelection();
      }

      accessToken = await getCurrentEntraAccessToken();

      if (textToAnalyze.length > MAX_TEXT_LENGTH) {
        setError(
          `Selected text is too long (${textToAnalyze.length.toLocaleString()} characters, max ${MAX_TEXT_LENGTH.toLocaleString()}). Please select a smaller section.`,
        );
        setLoading(false);
        return;
      }

      const response = await fetch(functionUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {}),
        },
        body: JSON.stringify({ text: textToAnalyze }),
      });

      if (!response.ok) {
        throw new Error(`API returned HTTP ${response.status}`);
      }

      const body = (await response.json()) as ApiResponse;
      setIssues(body.issues);
      setReplacements(body.replacements ?? []);

      if (body.replacements?.length) {
        const summary = await applyReplacementsToDocument(body.replacements);
        if (summary.skippedCount > 0) {
          setReplacementNotice(
            `Applied ${summary.appliedCount} replacement(s); skipped ${summary.skippedCount} because Word search could not safely match the full text.`,
          );
        }
      }
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      setError(`Style check failed: ${message}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="page">
      <Card>
        <CardHeader header={<Text weight="semibold">Style Guide Foundry</Text>} />
        {!isWordHost && (
          <Field label="Function endpoint">
            <Input value={functionUrl} onChange={(_, data) => setFunctionUrl(data.value)} />
          </Field>
        )}
        <div className="actions">
          <Button appearance="primary" onClick={runStyleCheck} disabled={loading || !selectedText.trim()}>
            Run style check
          </Button>
        </div>
      </Card>

      {!isWordHost && (
        <Card>
          <CardHeader header={<Text weight="semibold">Selected text</Text>} />
          <Textarea
            resize="vertical"
            value={selectedText}
            onChange={(_, data) => setSelectedText(data.value)}
            rows={8}
          />
        </Card>
      )}

      <Card>
        <CardHeader header={<Text weight="semibold">Results</Text>} />
        {loading && <Spinner label="Analyzing..." />}
        {error && <Text className="error">{error}</Text>}
        {!error && replacementNotice && <Text>{replacementNotice}</Text>}
        {!loading && !error && issues.length === 0 && <Text>No results yet.</Text>}
        {!loading &&
          !error &&
          replacements.map((replacement, index) => (
            <div className="issue" key={`replacement-${index + 1}`}>
              <div className="issue-header">
                <Text weight="semibold">Change {index + 1}</Text>
                <Badge appearance="filled">info</Badge>
              </div>
              <Text weight="semibold">Original text</Text>
              <Text>{replacement.ORIGINAL_TEXT || '—'}</Text>
              <Text weight="semibold">New text</Text>
              <Text>{replacement.NEW_TEXT || '—'}</Text>
              <Text weight="semibold">Reason</Text>
              <Text>{replacement.REASON || 'No reason provided.'}</Text>
            </div>
          ))}
        {!loading &&
          !error &&
          replacements.length === 0 &&
          issues.map((issue) => (
            <div className="issue" key={`${issue.ruleId}-${issue.message}`}>
              <div className="issue-header">
                <Text weight="semibold">{issue.ruleId}</Text>
                <Badge appearance="filled">{issue.severity}</Badge>
              </div>
              <Text>{issue.message}</Text>
              <Text className="suggestion">{issue.suggestion}</Text>
            </div>
          ))}
      </Card>

      <Text size={200} className="deploy-time">
        Deployment time (UTC): {deploymentTime}
      </Text>
    </div>
  );
}
