import { useEffect, useState } from 'react';
import { Stack } from '@astryxdesign/core/Stack';
import { Heading } from '@astryxdesign/core/Heading';
import { Text } from '@astryxdesign/core/Text';
import { Card } from '@astryxdesign/core/Card';
import { helpApi, type HelpTopic } from '../../core/api/client';

export function HelpPage() {
  const [topics, setTopics] = useState<HelpTopic[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    void (async () => {
      try {
        setTopics(await helpApi.topics());
      } catch (e) {
        setError(e instanceof Error ? e.message : 'failed to load help topics');
      }
    })();
  }, []);

  return (
    <Stack direction="vertical" gap={6}>
      <Stack direction="vertical" gap={1}>
        <Heading level={1}>Help</Heading>
        <Text color="secondary">Topics served from the API's help content.</Text>
      </Stack>

      {error && <Text color="secondary">{error}</Text>}
      {!error && topics.length === 0 && <Text color="secondary">No topics published.</Text>}

      {topics.map((t) => (
        <Card key={t.slug} padding={4}>
          <Stack direction="vertical" gap={1}>
            <Text weight="bold">{t.title}</Text>
            {t.summary && <Text color="secondary">{t.summary}</Text>}
          </Stack>
        </Card>
      ))}
    </Stack>
  );
}
