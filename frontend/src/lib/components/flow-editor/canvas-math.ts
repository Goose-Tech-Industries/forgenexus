import type { FlowNode, NodeTypeSchema } from '$lib/stores/plugins.svelte';

export const NODE_WIDTH = 200;
export const PORT_SPACING = 24;
export const HEADER_HEIGHT = 36;
export const PORT_OFFSET_Y = HEADER_HEIGHT + 16;
export const PORT_RADIUS = 6;
export const NODE_PADDING_BOTTOM = 12;

export function getNodeHeight(schema: NodeTypeSchema | null): number {
  if (!schema) return HEADER_HEIGHT + PORT_SPACING + NODE_PADDING_BOTTOM;
  const portRows = Math.max(schema.inputs.length, schema.outputs.length, 1);
  return HEADER_HEIGHT + 16 + portRows * PORT_SPACING + NODE_PADDING_BOTTOM;
}

export function getInputPortPosition(
  node: FlowNode,
  portIndex: number
): { x: number; y: number } {
  return {
    x: node.position_x,
    y: node.position_y + PORT_OFFSET_Y + portIndex * PORT_SPACING,
  };
}

export function getOutputPortPosition(
  node: FlowNode,
  portIndex: number
): { x: number; y: number } {
  return {
    x: node.position_x + NODE_WIDTH,
    y: node.position_y + PORT_OFFSET_Y + portIndex * PORT_SPACING,
  };
}

export function getPortPosition(
  node: FlowNode,
  side: 'input' | 'output',
  portIndex: number
): { x: number; y: number } {
  return side === 'input'
    ? getInputPortPosition(node, portIndex)
    : getOutputPortPosition(node, portIndex);
}

export function getPortIndexByName(
  schema: NodeTypeSchema,
  side: 'input' | 'output',
  portName: string
): number {
  const ports = side === 'input' ? schema.inputs : schema.outputs;
  const idx = ports.findIndex((p) => p.name === portName);
  return idx >= 0 ? idx : 0;
}

export function edgePath(
  sx: number, sy: number,
  tx: number, ty: number
): string {
  const dx = Math.abs(tx - sx);
  const offset = Math.max(60, dx * 0.4);
  return `M ${sx} ${sy} C ${sx + offset} ${sy}, ${tx - offset} ${ty}, ${tx} ${ty}`;
}

export function screenToCanvas(
  screenX: number,
  screenY: number,
  panX: number,
  panY: number,
  zoom: number,
  svgRect: DOMRect
): { x: number; y: number } {
  return {
    x: (screenX - svgRect.left - panX) / zoom,
    y: (screenY - svgRect.top - panY) / zoom,
  };
}

export function clampZoom(z: number): number {
  return Math.max(0.15, Math.min(3, z));
}

export function truncateText(text: string, maxChars: number): string {
  if (text.length <= maxChars) return text;
  return text.slice(0, maxChars - 1) + '\u2026';
}
