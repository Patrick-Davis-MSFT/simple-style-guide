import { app } from '@azure/functions';
import { DefaultAzureCredential } from '@azure/identity';
import { AIProjectClient } from '@azure/ai-projects';

const projectEndpoint = process.env.AZURE_EXISTING_AIPROJECT_ENDPOINT;
const configuredAgentId = process.env.AZURE_EXISTING_AGENT_ID;
const configuredAgentName = process.env.AZURE_FOUNDRY_AGENT_NAME;
const configuredAgentVersion = process.env.AZURE_FOUNDRY_AGENT_VERSION;
const configuredOpenAIApiVersion = (
  process.env.OPENAI_API_VERSION || process.env.AZURE_OPENAI_API_VERSION || '2025-05-15-preview'
).trim();

let projectClient;
let openAIClient;

async function getOpenAIClient() {
  if (!projectEndpoint) {
    throw new Error('Missing AZURE_EXISTING_AIPROJECT_ENDPOINT setting.');
  }

  if (!projectClient) {
    projectClient = new AIProjectClient(projectEndpoint, new DefaultAzureCredential());
  }

  if (!openAIClient) {
    if (typeof projectClient.getOpenAIClient === 'function') {
      openAIClient = await projectClient.getOpenAIClient();
    } else if (typeof projectClient.getAzureOpenAIClient === 'function') {
      openAIClient = await projectClient.getAzureOpenAIClient({
        apiVersion: configuredOpenAIApiVersion,
      });
    } else {
      throw new Error(
        'The installed @azure/ai-projects SDK does not expose getOpenAIClient/getAzureOpenAIClient. Upgrade @azure/ai-projects to 2.0.0-beta.1 or newer.',
      );
    }
  }

  return openAIClient;
}

function getAgentReference() {
  if (configuredAgentName && configuredAgentVersion) {
    return {
      type: 'agent_reference',
      name: configuredAgentName,
      version: configuredAgentVersion,
    };
  }

  if (configuredAgentId) {
    const separatorIndex = configuredAgentId.lastIndexOf(':');
    if (separatorIndex > 0 && separatorIndex < configuredAgentId.length - 1) {
      const name = configuredAgentId.slice(0, separatorIndex);
      const version = configuredAgentId.slice(separatorIndex + 1);
      return {
        type: 'agent_reference',
        name,
        version,
      };
    }
  }

  throw new Error(
    'Agent configuration is invalid. Set AZURE_EXISTING_AGENT_ID as name:version, or set AZURE_FOUNDRY_AGENT_NAME + AZURE_FOUNDRY_AGENT_VERSION.',
  );
}

function extractReplacements(text) {
  const trimmed = text.trim();

  let candidate = trimmed;
  if (candidate.startsWith('```')) {
    const firstNewline = candidate.indexOf('\n');
    if (firstNewline >= 0) {
      candidate = candidate.slice(firstNewline + 1);
    }
    if (candidate.endsWith('```')) {
      candidate = candidate.slice(0, -3);
    }
    candidate = candidate.trim();
  }

  const normalizeParsed = (value) => {
    if (Array.isArray(value)) {
      return value;
    }

    if (value && typeof value === 'object') {
      const replacements = value.replacements;
      if (Array.isArray(replacements)) {
        return replacements;
      }
      throw new Error('Model response JSON object must include a replacements array.');
    }

    throw new Error('Model response JSON payload must be an object or array.');
  };

  try {
    return normalizeParsed(JSON.parse(candidate));
  } catch {
    // Fall back to extracting JSON from mixed text when strict mode is not respected.
  }

  const objectStart = candidate.indexOf('{');
  const objectEnd = candidate.lastIndexOf('}');
  if (objectStart >= 0 && objectEnd > objectStart) {
    return normalizeParsed(JSON.parse(candidate.slice(objectStart, objectEnd + 1)));
  }

  const start = candidate.indexOf('[');
  const end = candidate.lastIndexOf(']');
  if (start >= 0 && end > start) {
    return normalizeParsed(JSON.parse(candidate.slice(start, end + 1)));
  }

  throw new Error('Model response did not contain a JSON object/array payload.');
}

function normalizeAgentResponse(items, originalText) {
  if (!Array.isArray(items)) {
    throw new Error('Agent response payload is not an array.');
  }

  return items.map((item) => {
    const normalizedOriginal = String(item?.ORIGINAL_TEXT ?? originalText ?? '');
    const normalizedNew = String(item?.NEW_TEXT ?? '');
    const normalizedReason = String(item?.REASON ?? '');

    return {
      ORIGINAL_TEXT: normalizedOriginal,
      NEW_TEXT: normalizedNew,
      REASON: normalizedReason,
    };
  });
}

async function runAgentStyleCheck(inputText) {
  const client = await getOpenAIClient();
  const agentReference = getAgentReference();

  const conversation = await client.conversations.create({
    items: [{ type: 'message', role: 'user', content: inputText }],
  });

  const responseBody = {
    agent_reference: agentReference,
  }

  const response = await client.responses.create(
    {
      conversation: conversation.id,
    },
    {
      body: responseBody,
    },
  );

  const outputText = String(response?.output_text ?? '').trim();

  if (!outputText) {
    throw new Error('Agent returned an empty text response.');
  }

  const parsed = extractReplacements(outputText);
  return normalizeAgentResponse(parsed, inputText);
}

app.http('style-check', {
  methods: ['POST'],
  authLevel: 'anonymous',
  route: 'style-check',
  handler: async (request, context) => {
    let body;
    try {
      body = await request.json();
    } catch {
      return {
        status: 400,
        jsonBody: {
          error: 'Invalid request body. Expected JSON with a non-empty text field.',
        },
      };
    }

    try {
      const inputText = String(body?.text ?? '').trim();

      if (!inputText) {
        return {
          status: 400,
          jsonBody: {
            error: 'Invalid request body. Expected JSON with a non-empty text field.',
          },
        };
      }

      const replacements = await runAgentStyleCheck(inputText);
      const issues = replacements.map((item, index) => ({
        ruleId: `foundry-agent-${index + 1}`,
        severity: 'info',
        message: item.ORIGINAL_TEXT,
        suggestion: `Change To:${item.NEW_TEXT}${item.REASON ? `\nReason: ${item.REASON}` : ''}`,
      }));

      context.log('Style check executed', {
        textLength: inputText.length,
        issueCount: issues.length,
      });

      return {
        status: 200,
        jsonBody: {
          analyzedAtUtc: new Date().toISOString(),
          issueCount: issues.length,
          issues,
          replacements,
        },
      };
    } catch (error) {
      context.error('Style check failed', error);
      return {
        status: 500,
        jsonBody: {
          error: error instanceof Error ? error.message : 'Style check failed.',
        },
      };
    }
  },
});
