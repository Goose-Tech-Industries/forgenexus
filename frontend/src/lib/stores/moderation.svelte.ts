import { api } from '$lib/api/client';

interface MiniUser {
  id: string;
  username: string;
  slug: string;
  avatar_url: string | null;
}

export interface Report {
  id: string;
  reason: string;
  description: string | null;
  status: string;
  priority: number;
  reportable_type: string;
  reportable_id: string;
  resolution_note: string | null;
  resolved_at: string | null;
  inserted_at: string;
  reporter: MiniUser;
  resolver: MiniUser | null;
  assigned_to: MiniUser | null;
}

export interface Ban {
  id: string;
  type: string;
  reason: string;
  expires_at: string | null;
  is_active: boolean;
  ip_address: string | null;
  inserted_at: string;
  user: MiniUser | null;
  banned_by: MiniUser | null;
}

export interface Warning {
  id: string;
  type: string;
  reason: string;
  points: number;
  expires_at: string | null;
  is_active: boolean;
  inserted_at: string;
  issued_by: MiniUser | null;
}

export interface ModNote {
  id: string;
  body: string;
  inserted_at: string;
  author: MiniUser;
}

export interface ModLog {
  id: string;
  action: string;
  reason: string | null;
  metadata: Record<string, any>;
  target_type: string;
  target_id: string;
  inserted_at: string;
  moderator: MiniUser;
}

export interface Appeal {
  id: string;
  type: string;
  target_id: string;
  reason: string;
  status: string;
  decision_note: string | null;
  decided_at: string | null;
  inserted_at: string;
  user?: MiniUser | null;
  reviewer?: MiniUser | null;
}

export interface WorkloadStats {
  assigned_reports: number;
  actions_30d: number;
  resolved_30d: number;
}

export interface QueueStats {
  open_count: number;
  oldest_report_at: string | null;
  avg_wait_seconds: number;
  pending_appeals: number;
}

export interface SuspiciousAccount {
  id: string;
  match_type: string;
  confidence: number;
  reviewed: boolean;
  reviewed_at: string | null;
  inserted_at: string;
  user: MiniUser | null;
  linked_user: MiniUser | null;
  reviewed_by: MiniUser | null;
}

export interface ContentPolicy {
  id: string;
  name: string;
  description: string | null;
  is_active: boolean;
  ai_moderation_enabled: boolean;
  rules: Record<string, any>;
  escalation_overrides: Record<string, any>;
  forum_id: string | null;
  category_id: string | null;
  inserted_at: string;
  updated_at: string;
}

export interface ImpersonationLog {
  id: string;
  reason: string;
  started_at: string;
  ended_at: string | null;
  inserted_at: string;
  admin: MiniUser | null;
  target_user: MiniUser | null;
}

let reports = $state<Report[]>([]);
let reportCounts = $state<Record<string, number>>({});
let bans = $state<Ban[]>([]);
let modLogs = $state<ModLog[]>([]);
let appeals = $state<Appeal[]>([]);
let suspiciousAccounts = $state<SuspiciousAccount[]>([]);
let policies = $state<ContentPolicy[]>([]);
let workload = $state<WorkloadStats | null>(null);
let queueStats = $state<QueueStats | null>(null);
let loading = $state(false);

export const moderation = {
  get reports() { return reports; },
  get reportCounts() { return reportCounts; },
  get bans() { return bans; },
  get modLogs() { return modLogs; },
  get appeals() { return appeals; },
  get suspiciousAccounts() { return suspiciousAccounts; },
  get policies() { return policies; },
  get workload() { return workload; },
  get queueStats() { return queueStats; },
  get loading() { return loading; },

  async loadReports(params?: { status?: string }) {
    loading = true;
    try {
      const data = await api.getReports(params);
      reports = data.reports;
      reportCounts = data.counts;
    } finally {
      loading = false;
    }
  },

  async loadBans(params?: { user_id?: string; active_only?: string }) {
    loading = true;
    try {
      const data = await api.getBans(params);
      bans = data.bans;
    } finally {
      loading = false;
    }
  },

  async loadModLogs(params?: { moderator_id?: string; action?: string }) {
    loading = true;
    try {
      const data = await api.getModLogs(params);
      modLogs = data.logs;
    } finally {
      loading = false;
    }
  },

  async assignReport(id: string, moderatorId?: string) {
    const data = await api.assignReport(id, moderatorId);
    reports = reports.map(r => r.id === id ? data.report : r);
    return data.report;
  },

  async resolveReport(id: string, note?: string) {
    const data = await api.resolveReport(id, note);
    reports = reports.map(r => r.id === id ? data.report : r);
    return data.report;
  },

  async dismissReport(id: string, note?: string) {
    const data = await api.dismissReport(id, note);
    reports = reports.map(r => r.id === id ? data.report : r);
    return data.report;
  },

  async banUser(data: { user_id: string; type: string; reason: string; expires_at?: string }) {
    const result = await api.createBan(data);
    return result.ban;
  },

  async revokeBan(id: string) {
    const result = await api.revokeBan(id);
    bans = bans.map(b => b.id === id ? result.ban : b);
    return result.ban;
  },

  async warnUser(data: { user_id: string; reason: string; type?: string; points?: number }) {
    const result = await api.createWarning(data);
    return result.warning;
  },

  async revokeWarning(id: string) {
    const result = await api.revokeWarning(id);
    return result.warning;
  },

  // Appeals
  async loadAppeals(params?: { status?: string }) {
    loading = true;
    try {
      const data = await api.getAppeals(params);
      appeals = data.appeals;
    } finally {
      loading = false;
    }
  },

  async reviewAppeal(id: string, decision: string, decisionNote?: string) {
    const data = await api.reviewAppeal(id, decision, decisionNote);
    appeals = appeals.map(a => a.id === id ? data.appeal : a);
    return data.appeal;
  },

  // Workload & Queue
  async loadWorkload(moderatorId?: string) {
    const data = await api.getWorkload(moderatorId);
    workload = data.workload;
    return data.workload;
  },

  async loadQueueStats() {
    const data = await api.getQueueStats();
    queueStats = data.queue;
    return data.queue;
  },

  async getSuggestedAssignment() {
    const data = await api.getSuggestedAssignment();
    return data.suggestion;
  },

  // Suspicious Accounts
  async loadSuspiciousAccounts(params?: { reviewed?: string }) {
    loading = true;
    try {
      const data = await api.getSuspiciousAccounts(params);
      suspiciousAccounts = data.suspicious_accounts;
    } finally {
      loading = false;
    }
  },

  async scanSuspicious(userId: string) {
    const data = await api.scanSuspicious(userId);
    return data;
  },

  async reviewSuspicious(id: string) {
    const data = await api.reviewSuspicious(id);
    suspiciousAccounts = suspiciousAccounts.map(sa => sa.id === id ? data.suspicious_account : sa);
    return data.suspicious_account;
  },

  // Impersonation
  async startImpersonation(targetUserId: string, reason: string) {
    const data = await api.startImpersonation(targetUserId, reason);
    return data.impersonation;
  },

  async endImpersonation() {
    const data = await api.endImpersonation();
    return data.impersonation;
  },

  async getActiveImpersonation() {
    const data = await api.getActiveImpersonation();
    return data.impersonation;
  },

  // Content Policies
  async loadPolicies(params?: { forum_id?: string; active_only?: string }) {
    loading = true;
    try {
      const data = await api.getPolicies(params);
      policies = data.policies;
    } finally {
      loading = false;
    }
  },

  async createPolicy(data: Record<string, any>) {
    const result = await api.createPolicy(data);
    policies = [result.policy, ...policies];
    return result.policy;
  },

  async updatePolicy(id: string, data: Record<string, any>) {
    const result = await api.updatePolicy(id, data);
    policies = policies.map(p => p.id === id ? result.policy : p);
    return result.policy;
  },

  async deletePolicy(id: string) {
    await api.deletePolicy(id);
    policies = policies.filter(p => p.id !== id);
  }
};
