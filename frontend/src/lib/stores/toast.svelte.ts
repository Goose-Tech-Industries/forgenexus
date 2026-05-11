let nextId = 0;

interface Toast {
  id: number;
  message: string;
  type: 'success' | 'error' | 'info' | 'warning';
  duration: number;
  createdAt: number;
}

const MAX_TOASTS = 5;

let toasts = $state<Toast[]>([]);

function addToast(message: string, type: Toast['type'], duration?: number) {
  const defaultDuration = type === 'error' ? 6000 : 4000;
  const toast: Toast = {
    id: nextId++,
    message,
    type,
    duration: duration ?? defaultDuration,
    createdAt: Date.now()
  };

  toasts = [...toasts, toast];

  // Enforce max visible
  if (toasts.length > MAX_TOASTS) {
    toasts = toasts.slice(toasts.length - MAX_TOASTS);
  }

  // Auto-remove after duration
  setTimeout(() => {
    dismiss(toast.id);
  }, toast.duration);
}

function dismiss(id: number) {
  toasts = toasts.filter(t => t.id !== id);
}

export const toast = {
  get toasts() { return toasts; },
  success(message: string, duration?: number) { addToast(message, 'success', duration); },
  error(message: string, duration?: number) { addToast(message, 'error', duration); },
  info(message: string, duration?: number) { addToast(message, 'info', duration); },
  warning(message: string, duration?: number) { addToast(message, 'warning', duration); },
  dismiss
};
