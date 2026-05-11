export const CATEGORY_COLORS: Record<string, string> = {
  // Core
  trigger:         '#f97316',
  logic:           '#3b82f6',
  math:            '#a855f7',
  data:            '#22c55e',
  action:          '#ef4444',
  text:            '#06b6d4',
  ui:              '#ec4899',
  // Moderation & Safety
  moderation:      '#dc2626',
  automod:         '#b91c1c',
  // Community Management
  user_management: '#8b5cf6',
  notification:    '#f59e0b',
  verification:    '#14b8a6',
  content:         '#0ea5e9',
  ticket:          '#6366f1',
  poll:            '#8b5cf6',
  approval:        '#7c3aed',
  // Economy & Commerce
  economy:         '#eab308',
  gambling:        '#d97706',
  inventory:       '#84cc16',
  collection:      '#10b981',
  // Gamification
  stats:           '#06b6d4',
  achievement:     '#f59e0b',
  reputation:      '#a3e635',
  tournament:      '#e11d48',
  quest:           '#7c3aed',
  pet:             '#f472b6',
  // Scheduling & Integration
  scheduling:      '#0891b2',
  integration:     '#64748b',
  // Analytics & Profile
  analytics:       '#0d9488',
  profile:         '#c084fc',
};

export function categoryColor(category: string): string {
  return CATEGORY_COLORS[category] ?? '#6b7280';
}

export function categoryBg(category: string): string {
  const c = categoryColor(category);
  return c + '20';
}
