import React, { useState } from 'react';
import { useAgencyStore, getActiveAgentSet } from '../store/agencyStore';
import { ScrollText, RefreshCcw, Users, UserPlus, Pencil, Trash2 } from 'lucide-react';
import AgentSetPickerModal from './AgentSetPickerModal';
import AgentFormModal from './AgentFormModal';
import ResetModal from './ResetModal';
import { useSceneManager } from '../three/SceneContext';
import { abortAllCalls } from '../services/agencyService';
import { isBuiltInTeam } from '../data/agents';

const ProjectView: React.FC = () => {
  const {
    clientBrief,
    phase,
    actionLog,
    selectedAgentSetId,
    resetProject,
    customAgents,
    removeCustomAgent,
  } = useAgencyStore();
  const [isPickerOpen, setIsPickerOpen] = useState(false);
  const [isResetModalOpen, setIsResetModalOpen] = useState(false);
  const [isAgentFormOpen, setIsAgentFormOpen] = useState(false);
  const [editAgent, setEditAgent] = useState<{ index: number; agent: any } | null>(null);
  const scene = useSceneManager();

  const hasLogs = actionLog.length > 0;
  const activeSet = getActiveAgentSet();

  const handleResetConfirm = () => {
    // 1. Cancel all in-flight LLM calls
    abortAllCalls();
    // 2. Reset the 3D scene (teleport agents, clear chat)
    scene?.resetScene();
    // 3. Clear agency state
    resetProject();
    setIsResetModalOpen(false);
  };

  return (
    <div className="flex flex-col h-full overflow-y-auto p-6 bg-white/50">
      <div className="mb-6">
        <div className="flex items-center justify-between mb-2">
          <h2 className="text-xl font-black text-zinc-900 leading-tight">Project Info</h2>
          <div className="flex items-center gap-2">
            <div className={`px-2 py-0.5 rounded-md text-[9px] font-black uppercase tracking-widest flex items-center gap-1.5 ${
              phase === 'working' ? 'bg-blue-500 text-white' :
              phase === 'done' ? 'bg-green-500 text-white' :
              phase === 'briefing' ? 'bg-amber-500 text-white' :
              'bg-zinc-100 text-zinc-400'
            }`}>
              <div className={`w-1.5 h-1.5 rounded-full ${['working', 'briefing'].includes(phase) ? 'bg-white animate-pulse' : 'bg-white opacity-40'}`} />
              {phase}
            </div>
          </div>
        </div>
      </div>

      <div className="h-px bg-zinc-100 w-full mb-6" />

      {/* Reset Project Button */}
      {hasLogs && (
        <div className="mb-8 flex justify-end">
          <button
            onClick={() => setIsResetModalOpen(true)}
            className="flex items-center gap-1.5 px-3 py-1.5 bg-zinc-100/50 hover:bg-zinc-100 text-zinc-400 hover:text-red-500 rounded-lg transition-all active:scale-95 group border border-transparent hover:border-red-100"
          >
            <RefreshCcw size={12} className="transition-transform group-hover:rotate-180 duration-500" />
            <span className="text-[10px] font-black uppercase tracking-widest">Reset Project</span>
          </button>
        </div>
      )}

      {/* Brief */}
      <div className="mb-8">
        <p className="text-[10px] font-black uppercase tracking-widest text-zinc-400 mb-2 flex items-center gap-2">
          <ScrollText size={10} />
          Client Brief
        </p>
        <div className="bg-zinc-50 border border-zinc-100 rounded-xl p-4">
          <p className="text-xs text-zinc-600 leading-relaxed font-medium italic">
            {clientBrief || "No active brief. Talk to the Orchestrator to define your project."}
          </p>
        </div>
      </div>

      {/* Team Section */}
      <div className="mb-8">
        <div className="flex items-center justify-between mb-2">
          <p className="text-[10px] font-black uppercase tracking-widest text-zinc-400 flex items-center gap-2">
            <Users size={10} />
            Team ({activeSet.agents.length})
          </p>
          <button
            onClick={() => setIsAgentFormOpen(true)}
            className="flex items-center gap-1 px-2 py-1 bg-violet-100 hover:bg-violet-200 text-violet-600 rounded-lg transition-colors"
          >
            <UserPlus size={12} />
            <span className="text-[9px] font-black uppercase tracking-widest">Add</span>
          </button>
        </div>
        <div className="bg-zinc-50 border border-zinc-100 rounded-xl p-3 space-y-2">
          {activeSet.agents.map((agent) => {
            const isCustom = customAgents[selectedAgentSetId]?.some((a: any) => a.role === agent.role);
            return (
              <div key={agent.index} className="flex items-center justify-between py-1">
                <div className="flex items-center gap-2">
                  <div className="w-2 h-2 rounded-full" style={{ backgroundColor: agent.color }} />
                  <span className="text-xs font-medium text-zinc-700">{agent.role}</span>
                  {agent.isPlayer && (
                    <span className="text-[8px] font-black uppercase tracking-widest text-zinc-400 bg-zinc-200 px-1.5 py-0.5 rounded">
                      You
                    </span>
                  )}
                </div>
                {!agent.isPlayer && isCustom && (
                  <div className="flex items-center gap-1">
                    <button
                      onClick={() => {
                        const customIndex = customAgents[selectedAgentSetId]?.findIndex((a: any) => a.role === agent.role);
                        if (customIndex !== -1) {
                          setEditAgent({ index: agent.index, agent });
                        }
                      }}
                      className="p-1 hover:bg-violet-100 rounded transition-colors group"
                    >
                      <Pencil size={12} className="text-zinc-400 group-hover:text-violet-500" />
                    </button>
                    <button
                      onClick={() => {
                        const customIndex = customAgents[selectedAgentSetId]?.findIndex((a: any) => a.role === agent.role);
                        if (customIndex !== -1) {
                          removeCustomAgent(selectedAgentSetId, customIndex);
                        }
                      }}
                      className="p-1 hover:bg-red-100 rounded transition-colors group"
                    >
                      <Trash2 size={12} className="text-zinc-400 group-hover:text-red-500" />
                    </button>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>

      <AgentSetPickerModal
        isOpen={isPickerOpen}
        onClose={() => setIsPickerOpen(false)}
        hasActiveProject={hasLogs}
      />

      <ResetModal
        isOpen={isResetModalOpen}
        onClose={() => setIsResetModalOpen(false)}
        onConfirm={handleResetConfirm}
      />

      <AgentFormModal
        isOpen={isAgentFormOpen || editAgent !== null}
        onClose={() => {
          setIsAgentFormOpen(false);
          setEditAgent(null);
        }}
        editAgent={editAgent}
      />
    </div>
  );
};

export default ProjectView;
