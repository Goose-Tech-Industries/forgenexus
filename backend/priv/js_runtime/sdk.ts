// ForgeNexus JS Plugin SDK
// This file is prepended to every plugin execution.
// It provides the ForgeNexus global object with trigger data, settings, and API methods.

const _inputJson = Deno.args[0];
if (!_inputJson) {
  console.log(JSON.stringify({ output: {}, logs: ["ERROR: No input provided"], commands: [] }));
  Deno.exit(1);
}

let _input: { trigger: any; settings: Record<string, any>; permissions: string[] };
try {
  _input = JSON.parse(_inputJson);
} catch {
  console.log(JSON.stringify({ output: {}, logs: ["ERROR: Invalid input JSON"], commands: [] }));
  Deno.exit(1);
}

const _logs: string[] = [];
const _commands: any[] = [];
let _output: Record<string, any> = {};
const _maxLogs = 100;
const _maxLogLength = 1000;

const ForgeNexus = {
  trigger: _input.trigger || { type: "manual", data: {} },
  settings: _input.settings || {},

  log(message: string): void {
    if (_logs.length < _maxLogs) {
      _logs.push(String(message).slice(0, _maxLogLength));
    }
  },

  output(data: Record<string, any>): void {
    _output = data;
  },

  api: {
    async createPost(forumId: string, threadId: string, body: string): Promise<void> {
      _commands.push({ type: "create_post", args: { forum_id: forumId, thread_id: threadId, body } });
    },

    async createThread(forumId: string, title: string, body: string): Promise<void> {
      _commands.push({ type: "create_thread", args: { forum_id: forumId, title, body } });
    },

    async sendDm(userId: string, subject: string, body: string): Promise<void> {
      _commands.push({ type: "send_dm", args: { user_id: userId, subject, body } });
    },

    async sendNotification(userId: string, message: string): Promise<void> {
      _commands.push({ type: "send_notification", args: { user_id: userId, message } });
    },

    async setUserData(key: string, value: any): Promise<void> {
      _commands.push({ type: "set_user_data", args: { key, value } });
    },

    async getUserData(key: string): Promise<any> {
      _commands.push({ type: "get_user_data", args: { key } });
      return null;
    },

    async setGlobalData(key: string, value: any): Promise<void> {
      _commands.push({ type: "set_global_data", args: { key, value } });
    },

    async getGlobalData(key: string): Promise<any> {
      _commands.push({ type: "get_global_data", args: { key } });
      return null;
    },

    async queryTable(tableSlug: string, filters?: Record<string, any>): Promise<any[]> {
      _commands.push({ type: "query_table", args: { table_slug: tableSlug, filters } });
      return [];
    },

    async insertRow(tableSlug: string, data: Record<string, any>): Promise<void> {
      _commands.push({ type: "insert_row", args: { table_slug: tableSlug, data } });
    },

    async updateRow(tableSlug: string, rowId: string, data: Record<string, any>): Promise<void> {
      _commands.push({ type: "update_row", args: { table_slug: tableSlug, row_id: rowId, data } });
    },

    async deleteRow(tableSlug: string, rowId: string): Promise<void> {
      _commands.push({ type: "delete_row", args: { table_slug: tableSlug, row_id: rowId } });
    },

    async emitEvent(eventName: string, payload: Record<string, any>): Promise<void> {
      _commands.push({ type: "emit_event", args: { event_name: eventName, payload } });
    },

    async awardPoints(userId: string, points: number): Promise<void> {
      _commands.push({ type: "award_points", args: { user_id: userId, points } });
    },

    async setCustomTitle(userId: string, title: string): Promise<void> {
      _commands.push({ type: "set_custom_title", args: { user_id: userId, title } });
    },

    async httpRequest(url: string, options?: { method?: string; headers?: Record<string, string>; body?: string }): Promise<any> {
      _commands.push({ type: "http_request", args: { url, ...options } });
      return null;
    },
  },
};

// Make ForgeNexus available globally
(globalThis as any).ForgeNexus = ForgeNexus;

// --- Plugin code is inserted below this line ---
