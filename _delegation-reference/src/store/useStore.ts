
import { create } from 'zustand';
import { CharacterState } from '../types';
import { useAgencyStore, getActiveAgentSet } from './agencyStore';

export const useStore = create<CharacterState>()(
  (set) => ({
    isThinking: false,
    instanceCount: getActiveAgentSet().agents.length,

    selectedNpcIndex: null,
    selectedPosition: null,
    hoveredNpcIndex: null,
    hoveredPoiId: null,
    hoveredPoiLabel: null,
    hoverPosition: null,
    npcScreenPositions: {},
    isChatting: false,
    isTyping: false,
    chatMessages: [],
    inspectorTab: 'info',

    isBYOKOpen: false,
    byokError: null,
    setBYOKOpen: (open: boolean, error: string | null = null) =>
      set({ isBYOKOpen: open, byokError: error }),

    llmConfig: (() => {
      try {
        const saved = localStorage.getItem('byok-config');
        if (saved) return JSON.parse(saved);
      } catch {}
      return {
        provider: 'gemini',
        apiKey: '',
        model: 'gemini-3-flash-preview'
      };
    })(),

    setThinking: (isThinking: boolean) => set({ isThinking }),
    setIsTyping: (isTyping: boolean) => set({ isTyping }),
    setInspectorTab: (tab: 'info' | 'chat') => set({ inspectorTab: tab }),
    setInstanceCount: (count: number) => set({ instanceCount: count }),

    setSelectedNpc: (index: number | null) => set({
      selectedNpcIndex: index,
      selectedPosition: null,
    }),
    setSelectedPosition: (pos: { x: number; y: number } | null) => set({ selectedPosition: pos }),
    setHoveredNpc: (index: number | null, pos: { x: number; y: number } | null) => set({
      hoveredNpcIndex: index,
      hoverPosition: pos,
      hoveredPoiId: null,
      hoveredPoiLabel: null,
    }),
    setHoveredPoi: (id: string | null, label: string | null, pos: { x: number; y: number } | null) => set({
      hoveredPoiId: id,
      hoveredPoiLabel: label,
      hoverPosition: pos,
      hoveredNpcIndex: null,
    }),
    setLlmConfig: (config) => set((s) => ({ llmConfig: { ...s.llmConfig, ...config } })),
  })
);

// Keep instanceCount in sync whenever the active agent set OR custom agents change
useAgencyStore.subscribe((state, prevState) => {
  const agentSetChanged = state.selectedAgentSetId !== prevState.selectedAgentSetId;
  const customAgentsChanged = state.customAgents !== prevState.customAgents;

  if (agentSetChanged || customAgentsChanged) {
    useStore.getState().setInstanceCount(getActiveAgentSet().agents.length);
  }
});
