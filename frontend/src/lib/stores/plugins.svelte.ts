import { api } from '$lib/api/client';

interface MiniUser { id: string; username: string; slug: string; avatar_url: string | null; }

export interface Flow {
  id: string; name: string; description: string | null; slug: string;
  status: string; tier: string; version: number;
  trigger_type: string; trigger_config: Record<string, any>; settings: Record<string, any>;
  error_message: string | null; last_executed_at: string | null; execution_count: number;
  inserted_at: string; updated_at: string; created_by: MiniUser | null;
  node_count?: number; edge_count?: number;
  nodes?: FlowNode[]; edges?: FlowEdge[];
}

export interface FlowNode {
  id: string; flow_id: string; type: string; category: string;
  label: string | null; config: Record<string, any>;
  position_x: number; position_y: number; position: number;
}

export interface FlowEdge {
  id: string; flow_id: string;
  source_node_id: string; target_node_id: string;
  source_port: string; target_port: string;
  condition: string | null; position: number;
}

export interface FlowExecution {
  id: string; flow_id: string; status: string; trigger_type: string;
  trigger_data: Record<string, any>; result: Record<string, any>;
  node_trace: Record<string, any>[]; started_at: string; finished_at: string | null;
  duration_ms: number | null; nodes_executed: number;
  db_operations: number; http_requests: number;
}

export interface DataTable {
  id: string; name: string; slug: string; description: string | null;
  scope: string; max_rows: number; inserted_at: string;
  columns: DataColumn[];
}

export interface DataColumn {
  id: string; name: string; slug: string; data_type: string;
  default_value: string | null; is_required: boolean;
  is_indexed: boolean; is_unique: boolean; position: number;
}

export interface DataRow {
  id: string; table_id: string; scope_id: string | null;
  data: Record<string, any>; version: number;
  inserted_at: string; updated_at: string;
}

export interface JsPlugin {
  id: string; name: string; slug: string; description: string | null;
  version: string; status: string; code: string;
  manifest: { hooks: string[]; permissions: string[]; settings_schema: any[]; allowed_domains?: string[] };
  settings: Record<string, any>;
  error_message: string | null; last_executed_at: string | null; execution_count: number;
  inserted_at: string; updated_at: string; created_by: MiniUser | null;
}

export interface JsPluginExecution {
  id: string; js_plugin_id: string; status: string; trigger_type: string;
  trigger_data: Record<string, any>; result: Record<string, any>;
  logs: string[]; started_at: string; finished_at: string | null;
  duration_ms: number | null; inserted_at: string;
}

export interface NodeTypeSchema {
  type: string; category: string; label: string; description: string;
  inputs: { name: string; type: string; required: boolean }[];
  outputs: { name: string; type: string }[];
  config_fields: { name: string; type: string; options?: string[]; default?: any; description?: string }[];
}

let flows = $state<Flow[]>([]);
let dataTables = $state<DataTable[]>([]);
let executions = $state<FlowExecution[]>([]);
let nodeTypes = $state<NodeTypeSchema[]>([]);
let jsPlugins = $state<JsPlugin[]>([]);
let jsPluginExecutions = $state<JsPluginExecution[]>([]);
let loading = $state(false);

export const plugins = {
  get flows() { return flows; },
  get dataTables() { return dataTables; },
  get executions() { return executions; },
  get nodeTypes() { return nodeTypes; },
  get jsPlugins() { return jsPlugins; },
  get jsPluginExecutions() { return jsPluginExecutions; },
  get loading() { return loading; },

  async loadFlows(params?: Record<string, string>) {
    loading = true;
    try { const d = await api.getFlows(params); flows = d.flows; } finally { loading = false; }
  },

  async loadFlow(id: string): Promise<Flow> {
    const d = await api.getFlow(id);
    return d.flow;
  },

  async createFlow(data: Record<string, any>) {
    const d = await api.createFlow(data);
    flows = [d.flow, ...flows];
    return d.flow;
  },

  async updateFlow(id: string, data: Record<string, any>) {
    const d = await api.updateFlow(id, data);
    flows = flows.map(f => f.id === id ? d.flow : f);
    return d.flow;
  },

  async deleteFlow(id: string) {
    await api.deleteFlow(id);
    flows = flows.filter(f => f.id !== id);
  },

  async activateFlow(id: string) {
    const d = await api.activateFlow(id);
    flows = flows.map(f => f.id === id ? d.flow : f);
    return d.flow;
  },

  async deactivateFlow(id: string) {
    const d = await api.deactivateFlow(id);
    flows = flows.map(f => f.id === id ? d.flow : f);
    return d.flow;
  },

  async executeFlow(id: string, params?: Record<string, any>) {
    return await api.executeFlow(id, params);
  },

  async loadNodeTypes() {
    const d = await api.getNodeTypes();
    nodeTypes = d.node_types;
    return d.node_types;
  },

  async loadExecutions(params?: Record<string, string>) {
    loading = true;
    try { const d = await api.getExecutions(params); executions = d.executions; } finally { loading = false; }
  },

  async loadDataTables(params?: Record<string, string>) {
    loading = true;
    try { const d = await api.getDataTables(params); dataTables = d.tables; } finally { loading = false; }
  },

  async loadDataTable(id: string): Promise<DataTable> {
    const d = await api.getDataTable(id);
    return d.table;
  },

  async createDataTable(data: Record<string, any>) {
    const d = await api.createDataTable(data);
    dataTables = [d.table, ...dataTables];
    return d.table;
  },

  async deleteDataTable(id: string) {
    await api.deleteDataTable(id);
    dataTables = dataTables.filter(t => t.id !== id);
  },

  // JS Plugins (Tier 2)

  async loadJsPlugins(params?: Record<string, string>) {
    loading = true;
    try { const d = await api.getJsPlugins(params); jsPlugins = d.plugins; } finally { loading = false; }
  },

  async loadJsPlugin(id: string): Promise<JsPlugin> {
    const d = await api.getJsPlugin(id);
    return d.plugin;
  },

  async createJsPlugin(data: Record<string, any>) {
    const d = await api.createJsPlugin(data);
    jsPlugins = [d.plugin, ...jsPlugins];
    return d.plugin;
  },

  async updateJsPlugin(id: string, data: Record<string, any>) {
    const d = await api.updateJsPlugin(id, data);
    jsPlugins = jsPlugins.map(p => p.id === id ? d.plugin : p);
    return d.plugin;
  },

  async deleteJsPlugin(id: string) {
    await api.deleteJsPlugin(id);
    jsPlugins = jsPlugins.filter(p => p.id !== id);
  },

  async activateJsPlugin(id: string) {
    const d = await api.activateJsPlugin(id);
    jsPlugins = jsPlugins.map(p => p.id === id ? d.plugin : p);
    return d.plugin;
  },

  async deactivateJsPlugin(id: string) {
    const d = await api.deactivateJsPlugin(id);
    jsPlugins = jsPlugins.map(p => p.id === id ? d.plugin : p);
    return d.plugin;
  },

  async executeJsPlugin(id: string) {
    return await api.executeJsPlugin(id);
  },

  async loadJsPluginExecutions(pluginId: string, params?: Record<string, string>) {
    loading = true;
    try {
      const d = await api.getJsPluginExecutions(pluginId, params);
      jsPluginExecutions = d.executions;
    } finally { loading = false; }
  },
};
