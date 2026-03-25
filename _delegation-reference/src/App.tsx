/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useEffect, useRef, useState, useCallback } from 'react';
import { SceneManager } from './three/SceneManager';
import { SceneContext } from './three/SceneContext';
import { useAgencyOrchestrator } from './hooks/useAgencyOrchestrator';
import { useAgencyStore } from './store/agencyStore';
import { useStore } from './store/useStore';
import { AGENT_SETS, getAgentSet } from './data/agents';
import { getActiveAgentSet } from './store/agencyStore';
import Header from './components/Header';
import InspectorPanel from './components/InspectorPanel';
import { ActionLogPanel } from './components/ActionLogPanel';
import { KanbanPanel } from './components/KanbanPanel';
import { FinalOutputModal } from './components/FinalOutputModal';
import SimulationView from './components/SimulationView';

// Expose stores to window for Swift bridge
// @ts-ignore
window.orchestraStore = useAgencyStore;
// @ts-ignore
window.orchestraUIStore = useStore;
// @ts-ignore
window.useAgencyStore = useAgencyStore;
// @ts-ignore
window.AGENT_SETS = AGENT_SETS;
// @ts-ignore
window.getActiveAgentSetForBridge = getActiveAgentSet;

// Helper to start chat with a specific agent (used by Swift bridge for popup "Open Chat")
// @ts-ignore
window.startChatWithAgent = (npcIndex: number) => {
  // Route through SceneManager for full 3D experience (camera, walk, face)
  if ((window as any).orchestraSceneManager) {
    (window as any).orchestraSceneManager.startChat(npcIndex);
  }
};

// Helper function for Swift bridge to get agent personality including custom agents
// @ts-ignore
window.getAgentPersonalityForBridge = (agentIndex: number) => {
  const agentSet = getActiveAgentSet();
  const agent = agentSet.agents.find((a: any) => a.index === agentIndex);
  if (agent) {
    return {
      agentIndex: agent.index,
      role: agent.role,
      department: agent.department,
      mission: agent.mission,
      personality: agent.personality,
      companyName: agentSet.companyName,
      companyId: agentSet.id
    };
  }
  return null;
};

/** Mounts inside SceneContext so useSceneManager() is available. */
function AgencyOrchestrator() {
  useAgencyOrchestrator();
  return null;
}

const App: React.FC = () => {
  const canvasRef = useRef<HTMLDivElement>(null);
  const managerRef = useRef<SceneManager | null>(null);
  const [sceneManager, setSceneManager] = useState<SceneManager | null>(null);
  const { isLogOpen, isKanbanOpen, setIsResizing } = useAgencyStore();

  const [isFullscreen, setIsFullscreen] = useState(false);
  const [kanbanHeight, setKanbanHeight] = useState(220);

  const startResizing = useCallback(() => {
    setIsResizing(true);
  }, [setIsResizing]);

  const stopResizing = useCallback(() => {
    setIsResizing(false);
  }, [setIsResizing]);

  const resize = useCallback((e: MouseEvent) => {
    if (useAgencyStore.getState().isResizing) {
      const windowHeight = window.innerHeight;
      const newHeight = windowHeight - e.clientY;
      const minHeight = windowHeight * 0.2;
      const maxHeight = windowHeight * 0.5;
      if (newHeight >= minHeight && newHeight <= maxHeight) {
        setKanbanHeight(newHeight);
      }
    }
  }, []);

  useEffect(() => {
    window.addEventListener('mousemove', resize);
    window.addEventListener('mouseup', stopResizing);
    return () => {
      window.removeEventListener('mousemove', resize);
      window.removeEventListener('mouseup', stopResizing);
    };
  }, [resize, stopResizing]);

  useEffect(() => {
    if (canvasRef.current && !managerRef.current) {
      const manager = new SceneManager(canvasRef.current);
      managerRef.current = manager;
      // @ts-ignore
      window.orchestraSceneManager = manager;
      setSceneManager(manager);
    }

    return () => {
      if (managerRef.current) {
        managerRef.current.dispose();
        managerRef.current = null;
        // @ts-ignore
        window.orchestraSceneManager = null;
        setSceneManager(null);
      }
    };
  }, []);

  return (
    <SceneContext.Provider value={sceneManager}>
      <AgencyOrchestrator />
      <div className="w-screen h-screen bg-white overflow-hidden flex flex-col">
        {/* Top: Header */}
        {!isFullscreen && <Header />}

        <div className="flex-1 flex flex-row min-h-0 min-w-0 overflow-hidden">
          {/* Left: Log panel */}
          {isLogOpen && !isFullscreen && <ActionLogPanel />}

          {/* Center: canvas + kanban drawer stacked */}
          <div className="relative flex-1 flex flex-col min-w-0 min-h-0 overflow-hidden bg-zinc-50">
            <SimulationView canvasRef={canvasRef} isFullscreen={isFullscreen} setIsFullscreen={setIsFullscreen} />

            {/* Resize Bar */}
            {isKanbanOpen && !isFullscreen && (
              <div
                className={`h-2 hover:h-2 bg-transparent hover:bg-zinc-200 border-t border-black/5 transition-colors cursor-row-resize z-30 flex items-center justify-center group shrink-0 ${useAgencyStore.getState().isResizing ? 'bg-zinc-300' : ''}`}
                onMouseDown={startResizing}
              >
                <div className="w-12 h-1 bg-zinc-300 rounded-full group-hover:bg-zinc-400" />
              </div>
            )}

            {isKanbanOpen && !isFullscreen && <KanbanPanel height={kanbanHeight} />}
          </div>

          {/* Right: Inspector sidebar */}
          {!isFullscreen && <InspectorPanel />}
        </div>

        {/* Final output — fixed viewport overlay */}
        <FinalOutputModal />
      </div>
    </SceneContext.Provider>
  );
};

export default App;

