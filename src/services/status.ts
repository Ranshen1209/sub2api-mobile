import type { StatusGroup, StatusPeriod, StatusResponse } from '@/src/types/status';

const STATUS_BASE_URL = 'https://status.sakrylle.com';

export async function getServiceStatus(period: StatusPeriod = '24h'): Promise<StatusGroup[]> {
  const url = `${STATUS_BASE_URL}/api/status?period=${period}&board=hot`;

  const response = await fetch(url, {
    headers: {
      'Accept': 'application/json',
      'Accept-Encoding': 'gzip',
    },
  });

  if (!response.ok) {
    throw new Error(`STATUS_FETCH_FAILED: ${response.status}`);
  }

  const json: unknown = await response.json();

  if (!json || typeof json !== 'object' || !('groups' in json)) {
    throw new Error('STATUS_INVALID_RESPONSE');
  }

  return (json as StatusResponse).groups;
}
