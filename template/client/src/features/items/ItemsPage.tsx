import { useCallback, useEffect, useState } from 'react';
import { Stack } from '@astryxdesign/core/Stack';
import { Heading } from '@astryxdesign/core/Heading';
import { Text } from '@astryxdesign/core/Text';
import { Button } from '@astryxdesign/core/Button';
import { TextInput } from '@astryxdesign/core/TextInput';
import { Card } from '@astryxdesign/core/Card';
import { Badge } from '@astryxdesign/core/Badge';
import { Banner } from '@astryxdesign/core/Banner';
import { itemsApi, type Item } from '../../core/api/client';

export function ItemsPage() {
  const [items, setItems] = useState<Item[]>([]);
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [editingId, setEditingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    try {
      setItems(await itemsApi.list());
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'failed to load items');
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const reset = () => {
    setEditingId(null);
    setName('');
    setDescription('');
  };

  async function submit() {
    if (name.trim().length === 0) {
      setError('Name is required.');
      return;
    }
    setBusy(true);
    try {
      const body = { name: name.trim(), description: description.trim() || undefined };
      if (editingId) await itemsApi.update(editingId, body);
      else await itemsApi.create(body);
      reset();
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'save failed');
    } finally {
      setBusy(false);
    }
  }

  async function remove(id: string) {
    setBusy(true);
    try {
      await itemsApi.remove(id);
      if (editingId === id) reset();
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'delete failed');
    } finally {
      setBusy(false);
    }
  }

  function edit(item: Item) {
    setEditingId(item.id);
    setName(item.name);
    setDescription(item.description ?? '');
  }

  return (
    <Stack direction="vertical" gap={6}>
      <Stack direction="vertical" gap={1}>
        <Heading level={1}>Items</Heading>
        <Text color="secondary">
          Create, edit and delete items through the service API.
        </Text>
      </Stack>

      {error && (
        <Banner
          status="error"
          title="Something went wrong"
          description={error}
          isDismissable
          onDismiss={() => setError(null)}
        />
      )}

      <Card padding={4}>
        <Stack direction="vertical" gap={4}>
          <Heading level={2}>{editingId ? 'Edit item' : 'New item'}</Heading>
          <TextInput
            label="Name"
            value={name}
            onChange={setName}
            isRequired
            placeholder="2024 Jeep Wrangler Willys"
          />
          <TextInput
            label="Description"
            value={description}
            onChange={setDescription}
            isOptional
            placeholder="Optional detail"
          />
          <Stack direction="horizontal" gap={2}>
            <Button
              label={editingId ? 'Save changes' : 'Create item'}
              variant="primary"
              isLoading={busy}
              clickAction={submit}
            />
            {editingId && <Button label="Cancel" variant="ghost" clickAction={reset} />}
          </Stack>
        </Stack>
      </Card>

      <Stack direction="vertical" gap={3}>
        <Heading level={2}>{items.length} item{items.length === 1 ? '' : 's'}</Heading>

        {items.length === 0 && <Text color="secondary">Nothing here yet.</Text>}

        {items.map((item) => (
          <Card key={item.id} padding={4}>
            <Stack direction="horizontal" justify="between" align="center" gap={4}>
              <Stack direction="vertical" gap={1}>
                <Stack direction="horizontal" gap={2} align="center">
                  <Text weight="bold">{item.name}</Text>
                  <Badge label={item.status} />
                </Stack>
                {item.description && <Text color="secondary">{item.description}</Text>}
                <Text size="sm" color="secondary">
                  created {new Date(item.createdAt).toLocaleString()} by {item.createdBy}
                </Text>
              </Stack>
              <Stack direction="horizontal" gap={2}>
                <Button label="Edit" variant="secondary" clickAction={() => edit(item)} />
                <Button
                  label="Delete"
                  variant="destructive"
                  isDisabled={busy}
                  clickAction={() => remove(item.id)}
                />
              </Stack>
            </Stack>
          </Card>
        ))}
      </Stack>
    </Stack>
  );
}
