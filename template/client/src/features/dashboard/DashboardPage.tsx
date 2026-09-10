import { useEffect, useState } from 'react';
import { Stack } from '@astryxdesign/core/Stack';
import { Heading } from '@astryxdesign/core/Heading';
import { Text } from '@astryxdesign/core/Text';
import { Card } from '@astryxdesign/core/Card';
import { Badge } from '@astryxdesign/core/Badge';
import { fetchHealth, itemsApi, type HealthStatus } from '../../core/api/client';
import { authEnabled } from '../../config/environment';

export function DashboardPage() {
  const [health, setHealth] = useState<HealthStatus | null>(null);
  const [itemCount, setItemCount] = useState<number | null>(null);
  const [reachable, setReachable] = useState(true);

  useEffect(() => {
    void (async () => {
      try {
        setHealth(await fetchHealth());
        setItemCount((await itemsApi.list()).length);
        setReachable(true);
      } catch {
        setReachable(false);
      }
    })();
  }, []);

  return (
    <Stack direction="vertical" gap={6}>
      <Stack direction="vertical" gap={1}>
        <Heading level={1}>Dashboard</Heading>
        <Text color="secondary">Service status at a glance.</Text>
      </Stack>

      <Stack direction="horizontal" gap={4}>
        <Card padding={4} width={240}>
          <Stack direction="vertical" gap={2}>
            <Text size="sm" color="secondary">API</Text>
            <Badge
              variant={reachable ? 'success' : 'error'}
              label={reachable ? (health?.status ?? 'healthy') : 'unreachable'}
            />
            {health && (
              <Text size="sm" color="secondary">
                checked {new Date(health.timestamp).toLocaleTimeString()}
              </Text>
            )}
          </Stack>
        </Card>

        <Card padding={4} width={240}>
          <Stack direction="vertical" gap={2}>
            <Text size="sm" color="secondary">Items</Text>
            <Heading level={2}>{itemCount ?? '—'}</Heading>
          </Stack>
        </Card>

        <Card padding={4} width={240}>
          <Stack direction="vertical" gap={2}>
            <Text size="sm" color="secondary">Authentication</Text>
            <Badge
              variant={authEnabled ? 'success' : 'neutral'}
              label={authEnabled ? 'Andy Auth' : 'disabled'}
            />
            <Text size="sm" color="secondary">
              {authEnabled
                ? 'Bearer tokens attached to every request.'
                : 'No issuer configured; the API allows anonymous access.'}
            </Text>
          </Stack>
        </Card>
      </Stack>
    </Stack>
  );
}
