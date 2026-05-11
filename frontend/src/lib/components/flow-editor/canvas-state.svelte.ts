import type { Flow, FlowNode, FlowEdge, NodeTypeSchema } from '$lib/stores/plugins.svelte';

export interface DraftEdge {
  sourceNodeId: string;
  sourcePort: string;
  mouseX: number;
  mouseY: number;
}

export interface Viewport {
  panX: number;
  panY: number;
  zoom: number;
}

let nodes = $state<FlowNode[]>([]);
let edges = $state<FlowEdge[]>([]);
let nodeTypes = $state<NodeTypeSchema[]>([]);
let viewport = $state<Viewport>({ panX: 0, panY: 0, zoom: 1 });
let selectedNodeId = $state<string | null>(null);
let selectedEdgeId = $state<string | null>(null);
let draftEdge = $state<DraftEdge | null>(null);
let dirty = $state(false);
let flowId = $state('');
let flowName = $state('');
let flowStatus = $state('draft');

let selectedNode = $derived(nodes.find((n) => n.id === selectedNodeId) ?? null);
let selectedEdge = $derived(edges.find((e) => e.id === selectedEdgeId) ?? null);
let nodeTypeMap = $derived(new Map(nodeTypes.map((nt) => [nt.type, nt])));
let nodesByCategory = $derived(() => {
  const map = new Map<string, NodeTypeSchema[]>();
  for (const nt of nodeTypes) {
    const list = map.get(nt.category) || [];
    list.push(nt);
    map.set(nt.category, list);
  }
  return map;
});

function tempId(): string {
  return `temp_${crypto.randomUUID()}`;
}

export const canvasState = {
  get nodes() { return nodes; },
  get edges() { return edges; },
  get nodeTypes() { return nodeTypes; },
  get viewport() { return viewport; },
  get selectedNodeId() { return selectedNodeId; },
  get selectedEdgeId() { return selectedEdgeId; },
  get selectedNode() { return selectedNode; },
  get selectedEdge() { return selectedEdge; },
  get draftEdge() { return draftEdge; },
  get dirty() { return dirty; },
  get flowId() { return flowId; },
  get flowName() { return flowName; },
  get flowStatus() { return flowStatus; },
  get nodeTypeMap() { return nodeTypeMap; },
  get nodesByCategory() { return nodesByCategory(); },

  init(flow: Flow, types: NodeTypeSchema[]) {
    flowId = flow.id;
    flowName = flow.name;
    flowStatus = flow.status;
    nodes = (flow.nodes ?? []).map((n) => ({ ...n }));
    edges = (flow.edges ?? []).map((e) => ({ ...e }));
    nodeTypes = types;
    selectedNodeId = null;
    selectedEdgeId = null;
    draftEdge = null;
    dirty = false;
    // Center viewport on existing nodes
    if (nodes.length > 0) {
      const avgX = nodes.reduce((s, n) => s + n.position_x, 0) / nodes.length;
      const avgY = nodes.reduce((s, n) => s + n.position_y, 0) / nodes.length;
      viewport = { panX: -avgX + 400, panY: -avgY + 300, zoom: 1 };
    } else {
      viewport = { panX: 0, panY: 0, zoom: 1 };
    }
  },

  // Viewport
  pan(dx: number, dy: number) {
    viewport = { ...viewport, panX: viewport.panX + dx, panY: viewport.panY + dy };
  },

  zoomTo(newZoom: number, pivotX: number, pivotY: number) {
    const clamped = Math.max(0.15, Math.min(3, newZoom));
    const ratio = clamped / viewport.zoom;
    viewport = {
      panX: pivotX - (pivotX - viewport.panX) * ratio,
      panY: pivotY - (pivotY - viewport.panY) * ratio,
      zoom: clamped,
    };
  },

  // Node operations
  addNode(type: string, canvasX: number, canvasY: number): string {
    const schema = nodeTypeMap.get(type);
    const category = type.split('/')[0];
    const id = tempId();
    const node: FlowNode = {
      id,
      flow_id: flowId,
      type,
      category,
      label: schema?.label ?? type,
      config: {},
      position_x: canvasX,
      position_y: canvasY,
      position: nodes.length,
    };
    // Set default config from schema
    if (schema) {
      for (const field of schema.config_fields) {
        if (field.default !== undefined) {
          node.config[field.name] = field.default;
        }
      }
    }
    nodes = [...nodes, node];
    dirty = true;
    return id;
  },

  moveNode(id: string, x: number, y: number) {
    nodes = nodes.map((n) => (n.id === id ? { ...n, position_x: x, position_y: y } : n));
    dirty = true;
  },

  deleteNode(id: string) {
    nodes = nodes.filter((n) => n.id !== id);
    edges = edges.filter((e) => e.source_node_id !== id && e.target_node_id !== id);
    if (selectedNodeId === id) selectedNodeId = null;
    dirty = true;
  },

  updateNodeConfig(id: string, config: Record<string, any>) {
    nodes = nodes.map((n) => (n.id === id ? { ...n, config } : n));
    dirty = true;
  },

  updateNodeLabel(id: string, label: string) {
    nodes = nodes.map((n) => (n.id === id ? { ...n, label } : n));
    dirty = true;
  },

  // Selection
  selectNode(id: string | null) {
    selectedNodeId = id;
    selectedEdgeId = null;
  },

  selectEdge(id: string | null) {
    selectedEdgeId = id;
    selectedNodeId = null;
  },

  clearSelection() {
    selectedNodeId = null;
    selectedEdgeId = null;
  },

  // Edge operations
  startDraftEdge(nodeId: string, port: string, mouseX: number, mouseY: number) {
    draftEdge = { sourceNodeId: nodeId, sourcePort: port, mouseX, mouseY };
  },

  updateDraftEdge(mouseX: number, mouseY: number) {
    if (draftEdge) {
      draftEdge = { ...draftEdge, mouseX, mouseY };
    }
  },

  completeDraftEdge(targetNodeId: string, targetPort: string) {
    if (!draftEdge) return;
    if (draftEdge.sourceNodeId === targetNodeId) {
      draftEdge = null;
      return;
    }
    // Check for duplicate
    const exists = edges.some(
      (e) =>
        e.source_node_id === draftEdge!.sourceNodeId &&
        e.source_port === draftEdge!.sourcePort &&
        e.target_node_id === targetNodeId &&
        e.target_port === targetPort
    );
    if (!exists) {
      const edge: FlowEdge = {
        id: tempId(),
        flow_id: flowId,
        source_node_id: draftEdge.sourceNodeId,
        target_node_id: targetNodeId,
        source_port: draftEdge.sourcePort,
        target_port: targetPort,
        condition: null,
        position: edges.length,
      };
      edges = [...edges, edge];
      dirty = true;
    }
    draftEdge = null;
  },

  cancelDraftEdge() {
    draftEdge = null;
  },

  deleteEdge(id: string) {
    edges = edges.filter((e) => e.id !== id);
    if (selectedEdgeId === id) selectedEdgeId = null;
    dirty = true;
  },

  deleteSelected() {
    if (selectedNodeId) {
      this.deleteNode(selectedNodeId);
    } else if (selectedEdgeId) {
      this.deleteEdge(selectedEdgeId);
    }
  },

  // Serialization
  toSavePayload() {
    return {
      nodes: nodes.map((n) => ({
        id: n.id.startsWith('temp_') ? undefined : n.id,
        type: n.type,
        category: n.category,
        label: n.label,
        config: n.config,
        position_x: n.position_x,
        position_y: n.position_y,
      })),
      edges: edges.map((e) => ({
        id: e.id.startsWith('temp_') ? undefined : e.id,
        source_node_id: e.source_node_id,
        target_node_id: e.target_node_id,
        source_port: e.source_port,
        target_port: e.target_port,
        condition: e.condition,
      })),
    };
  },

  markClean() {
    dirty = false;
  },

  // Remap temp IDs after save
  remapIds(savedFlow: Flow) {
    const savedNodes = savedFlow.nodes ?? [];
    const savedEdges = savedFlow.edges ?? [];
    // Match by index (server returns in same order)
    const oldToNew = new Map<string, string>();
    for (let i = 0; i < nodes.length && i < savedNodes.length; i++) {
      if (nodes[i].id !== savedNodes[i].id) {
        oldToNew.set(nodes[i].id, savedNodes[i].id);
      }
    }
    // Update nodes
    nodes = savedNodes.map((n) => ({ ...n }));
    // Update edges with remapped IDs
    edges = savedEdges.map((e) => ({ ...e }));
    dirty = false;
  },
};
