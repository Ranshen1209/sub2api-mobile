export type StatusPeriod = '90m' | '24h' | '7d' | '30d';

export type StatusCounts = {
  available: number;
  degraded: number;
  unavailable: number;
  missing: number;
  slow_latency: number;
  rate_limit: number;
  server_error: number;
  client_error: number;
  auth_error: number;
  invalid_request: number;
  network_error: number;
  response_timeout: number;
  content_mismatch: number;
};

export type StatusTimePoint = {
  time: string;
  timestamp: number;
  status: number;
  latency: number;
  availability: number;
  status_counts: StatusCounts;
};

export type CurrentStatus = {
  status: number;
  latency: number;
  timestamp: number;
};

export type StatusLayer = {
  model: string;
  request_model: string;
  layer_order: number;
  current_status: CurrentStatus | null;
  timeline: StatusTimePoint[];
};

export type StatusGroup = {
  provider: string;
  provider_name?: string;
  provider_slug: string;
  provider_url: string;
  service: string;
  service_name?: string;
  category: string;
  sponsor: string;
  sponsor_url: string;
  sponsor_level?: string;
  channel: string;
  channel_name?: string;
  board: string;
  probe_url?: string;
  template_name?: string;
  interval_ms: number;
  slow_latency_ms: number;
  current_status: number;
  layers: StatusLayer[];
};

export type StatusResponse = {
  data: unknown[];
  groups: StatusGroup[];
  meta: {
    period: string;
    count: number;
    board_counts: { hot: number; secondary: number; cold: number };
    [key: string]: unknown;
  };
};
