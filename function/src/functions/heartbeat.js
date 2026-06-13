import { app } from '@azure/functions';

const getConfiguredFoundryProjectEndpoint = () => {
  return process.env.AZURE_EXISTING_AIPROJECT_ENDPOINT || null;
};

const getConfiguredAgentReference = () => {
  const configuredAgentId = process.env.AZURE_EXISTING_AGENT_ID || '';
  const configuredAgentName = process.env.AZURE_FOUNDRY_AGENT_NAME || '';
  const configuredAgentVersion = process.env.AZURE_FOUNDRY_AGENT_VERSION || '';

  if (configuredAgentName && configuredAgentVersion) {
    return {
      configured: true,
      source: 'split',
      name: configuredAgentName,
      version: configuredAgentVersion,
      reference: `${configuredAgentName}:${configuredAgentVersion}`,
      message: 'Foundry agent is configured via AZURE_FOUNDRY_AGENT_NAME and AZURE_FOUNDRY_AGENT_VERSION.',
    };
  }

  if (configuredAgentId) {
    const separatorIndex = configuredAgentId.lastIndexOf(':');
    if (separatorIndex > 0 && separatorIndex < configuredAgentId.length - 1) {
      return {
        configured: true,
        source: 'combined',
        name: configuredAgentId.slice(0, separatorIndex),
        version: configuredAgentId.slice(separatorIndex + 1),
        reference: configuredAgentId,
        message: 'Foundry agent is configured via AZURE_EXISTING_AGENT_ID.',
      };
    }

    return {
      configured: false,
      source: 'combined',
      message: 'AZURE_EXISTING_AGENT_ID must be in name:version format.',
    };
  }

  return {
    configured: false,
    message:
      'Foundry agent is not configured. Set AZURE_EXISTING_AGENT_ID (name:version) or set AZURE_FOUNDRY_AGENT_NAME and AZURE_FOUNDRY_AGENT_VERSION.',
  };
};

const checkFoundryProjectConnectivity = async (endpoint) => {
  if (!endpoint) {
    return {
      configured: false,
      reachable: false,
      message: 'Foundry project endpoint is not configured. Set AZURE_EXISTING_AIPROJECT_ENDPOINT.',
    };
  }

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 5000);

    const response = await fetch(endpoint, {
      method: 'GET',
      signal: controller.signal,
    });

    clearTimeout(timeoutId);

    const reachable = response.status >= 200 && response.status < 500;

    return {
      configured: true,
      endpoint,
      reachable,
      httpStatus: response.status,
      message: reachable
        ? 'Foundry project endpoint is reachable.'
        : `Foundry project endpoint returned an unexpected status: ${response.status}`,
    };
  } catch (error) {
    return {
      configured: true,
      endpoint,
      reachable: false,
      message: `Failed to reach Foundry project endpoint: ${error.message}`,
    };
  }
};

app.http('heartbeat', {
  methods: ['GET'],
  authLevel: 'anonymous',
  route: 'heartbeat',
  handler: async () => {
    const now = new Date();
    const endpoint = getConfiguredFoundryProjectEndpoint();
    const project = await checkFoundryProjectConnectivity(endpoint);
    const agent = getConfiguredAgentReference();
    const readyForStyleCheckRun = Boolean(project.reachable && agent.configured);

    return {
      status: readyForStyleCheckRun ? 200 : 503,
      jsonBody: {
        status: readyForStyleCheckRun ? 'ok' : 'degraded',
        heartbeatAtUtc: now.toISOString(),
        heartbeatEpochMs: now.getTime(),
        foundry: {
          readyForStyleCheckRun,
          project,
          agent,
        },
      },
    };
  },
});
