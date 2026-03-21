import React, { useState } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { X, AlertTriangle, Users, Plus, Pencil, Trash2 } from 'lucide-react';
import { AgentSet, getAllAgentSets, isBuiltInTeam } from '../data/agents';
import { useAgencyStore } from '../store/agencyStore';
import { useSceneManager } from '../three/SceneContext';
import { abortAllCalls } from '../services/agencyService';
import ResetModal from './ResetModal';
import TeamFormModal from './TeamFormModal';

interface AgentSetPickerModalProps {
  isOpen: boolean;
  onClose: () => void;
  hasActiveProject?: boolean;
}

const AgentSetCard: React.FC<{
  set: AgentSet;
  isSelected: boolean;
  onSelect: () => void;
  onEdit?: () => void;
  onDelete?: () => void;
  canEdit: boolean;
}> = ({ set, isSelected, onSelect, onEdit, onDelete, canEdit }) => {
  const npcAgents = set.agents.filter((a) => !a.isPlayer);
  const accent = set.color;

  const handleCardClick = () => {
    console.log('[AgentSetCard] Clicked on team:', set.id, set.companyName);
    onSelect();
  };

  return (
    <div
      onClick={handleCardClick}
      className={`relative w-full text-left rounded-2xl border-2 p-4 transition-all duration-200 cursor-pointer ${
        isSelected
          ? 'bg-zinc-50 shadow-lg'
          : 'border-zinc-100 bg-white hover:border-zinc-200 hover:shadow-sm'
      }`}
      style={isSelected ? { borderColor: accent } : {}}
    >
      {/* Top row: agent count indicator + name + type + actions */}
      <div className="flex items-start justify-between gap-2 mb-3">
        <div className="flex items-center gap-2.5">
          <div
            className="h-5 px-1.5 rounded-lg shrink-0 shadow-sm flex items-center justify-center gap-1.5"
            style={{ backgroundColor: accent }}
          >
            <Users size={10} className="text-white opacity-90" strokeWidth={3} />
            <span className="text-[10px] font-black text-white leading-none">
              {set.agents.length - 1}
            </span>
          </div>
          <div>
            <p className="text-xs font-black text-zinc-900 leading-tight">{set.companyName}</p>
            <p className="text-[9px] font-bold text-zinc-400 uppercase tracking-widest leading-none mt-0.5">
              {set.companyType}
            </p>
          </div>
        </div>
        <div className="flex items-center gap-1">
          {/* Edit/Delete buttons for custom teams */}
          {canEdit && (
            <>
              {onEdit && (
                <button
                  onClick={(e) => { e.stopPropagation(); onEdit(); }}
                  className="p-1.5 hover:bg-violet-100 rounded-lg transition-colors group"
                >
                  <Pencil size={12} className="text-zinc-400 group-hover:text-violet-500" />
                </button>
              )}
              {onDelete && (
                <button
                  onClick={(e) => { e.stopPropagation(); onDelete(); }}
                  className="p-1.5 hover:bg-red-100 rounded-lg transition-colors group"
                >
                  <Trash2 size={12} className="text-zinc-400 group-hover:text-red-500" />
                </button>
              )}
            </>
          )}
          <div
            className={`w-4 h-4 rounded-full border-2 shrink-0 transition-all ${
              isSelected ? '' : 'border-zinc-200 bg-white'
            }`}
            style={isSelected ? { borderColor: accent, backgroundColor: accent } : {}}
          />
        </div>
      </div>

      {/* Description */}
      <p className="text-[10px] text-zinc-500 leading-relaxed mb-3">{set.companyDescription}</p>

      {/* Agent role chips */}
      <div className="flex flex-wrap gap-1">
        {npcAgents.map((agent) => (
          <span
            key={agent.index}
            className="flex items-center gap-1 px-2 py-0.5 rounded-full border text-[9px] font-bold uppercase tracking-wide"
            style={{ borderColor: `${agent.color}40`, color: agent.color, backgroundColor: `${agent.color}10` }}
          >
            <span
              className="w-1.5 h-1.5 rounded-full shrink-0"
              style={{ backgroundColor: agent.color }}
            />
            {agent.role}
          </span>
        ))}
      </div>
    </div>
  );
};

const AgentSetPickerModal: React.FC<AgentSetPickerModalProps> = ({
  isOpen,
  onClose,
  hasActiveProject = false,
}) => {
  const { selectedAgentSetId, setAgentSet, customAgents, customTeams, deleteCustomTeam } = useAgencyStore();
  const [pendingSetId, setPendingSetId] = useState<string>(selectedAgentSetId);
  const [isResetConfirmOpen, setIsResetConfirmOpen] = useState(false);
  const [isCreateTeamOpen, setIsCreateTeamOpen] = useState(false);
  const [editTeam, setEditTeam] = useState<AgentSet | null>(null);
  const [deleteConfirmTeam, setDeleteConfirmTeam] = useState<AgentSet | null>(null);
  const scene = useSceneManager();

  // Build merged agent sets with custom teams and custom agents
  const allAgentSets = getAllAgentSets(customAgents, customTeams);
  const selectedSet = allAgentSets.find((s) => s.id === pendingSetId) ?? allAgentSets[0];
  const isChangingSet = pendingSetId !== selectedAgentSetId;

  // Debug logging
  console.log('[AgentSetPickerModal] customTeams:', customTeams);
  console.log('[AgentSetPickerModal] allAgentSets:', allAgentSets.map(s => s.id));
  console.log('[AgentSetPickerModal] pendingSetId:', pendingSetId, 'selectedAgentSetId:', selectedAgentSetId);

  const handleConfirm = () => {
    console.log('[AgentSetPickerModal] handleConfirm called, isChangingSet:', isChangingSet, 'hasActiveProject:', hasActiveProject);
    if (isChangingSet && hasActiveProject) {
      setIsResetConfirmOpen(true);
      return;
    }
    executeSwitch();
  };

  const executeSwitch = () => {
    console.log('[AgentSetPickerModal] executeSwitch called, pendingSetId:', pendingSetId);
    // 0. Notify native app to close all tmux sessions
    if (window.webkit?.messageHandlers?.orchestra) {
      window.webkit.messageHandlers.orchestra.postMessage({ type: 'switchCompany' });
    }
    // 1. Cancel all in-flight LLM calls
    abortAllCalls();
    // 2. Reset the 3D scene (teleport agents, clear chat)
    scene?.resetScene();
    // 3. Switch agent set + reset project state in one atomic update
    setAgentSet(pendingSetId);
    setIsResetConfirmOpen(false);
    onClose();
  };

  return (
    <AnimatePresence>
      {isOpen && (
        <>
          <div className="fixed inset-0 z-[100] flex items-center justify-center p-4">
            {/* Backdrop */}
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={onClose}
              className="absolute inset-0 bg-zinc-950/60 backdrop-blur-sm"
            />

            {/* Panel */}
            <motion.div
              initial={{ opacity: 0, scale: 0.95, y: 20 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.95, y: 20 }}
              className="relative w-full max-w-2xl bg-white rounded-[32px] shadow-2xl overflow-hidden border border-zinc-100 max-h-[90vh] flex flex-col"
            >
            {/* Header */}
            <div className="px-8 pt-8 pb-6 shrink-0">
              <div className="flex items-start justify-between mb-4">
                <div className="w-12 h-12 rounded-2xl bg-zinc-900 flex items-center justify-center text-white">
                  <Users size={22} />
                </div>
                <button
                  onClick={onClose}
                  className="p-2 hover:bg-zinc-100 rounded-full text-zinc-400 transition-colors cursor-pointer"
                >
                  <X size={20} />
                </button>
              </div>

              <h3 className="text-2xl font-black text-zinc-900 mb-1 leading-tight">Choose Your Team</h3>
              <p className="text-sm text-zinc-500 leading-relaxed">
                Pick the team you want to work with. This will reset any active project.
              </p>

              {/* Warning banner if project is active */}
              {hasActiveProject && (
                <div className="mt-4 flex items-center gap-2.5 px-4 py-3 bg-amber-50 border border-amber-100 rounded-xl">
                  <AlertTriangle size={14} className="text-amber-500 shrink-0" />
                  <p className="text-[11px] font-medium text-amber-700">
                    Switching teams will clear the current brief, all tasks, logs, and conversation histories.
                  </p>
                </div>
              )}
            </div>

            {/* Cards grid */}
            <div className="px-8 overflow-y-auto flex-1">
              <div className="flex flex-col gap-3 pb-6">
                {/* Create New Team button */}
                <button
                  onClick={() => setIsCreateTeamOpen(true)}
                  className="w-full p-4 rounded-2xl border-2 border-dashed border-zinc-200 hover:border-violet-300 hover:bg-violet-50/50 transition-all flex items-center justify-center gap-2 text-zinc-400 hover:text-violet-500"
                >
                  <Plus size={16} />
                  <span className="text-xs font-black uppercase tracking-widest">Create New Team</span>
                </button>

                {allAgentSets.map((set) => {
                  const canEdit = !isBuiltInTeam(set.id);
                  return (
                    <AgentSetCard
                      key={set.id}
                      set={set}
                      isSelected={pendingSetId === set.id}
                      onSelect={() => setPendingSetId(set.id)}
                      canEdit={canEdit}
                      onEdit={canEdit ? () => setEditTeam(set) : undefined}
                      onDelete={canEdit ? () => setDeleteConfirmTeam(set) : undefined}
                    />
                  );
                })}
              </div>
            </div>

            {/* Footer */}
            <div className="px-8 pb-8 shrink-0 border-t border-zinc-100 pt-5">
              <button
                onClick={handleConfirm}
                className="w-full py-4 text-white rounded-2xl font-black text-xs uppercase tracking-widest transition-all active:scale-[0.98] flex items-center justify-center gap-2 cursor-pointer"
                style={{ backgroundColor: selectedSet.color }}
              >
                <Users size={14} />
                {isChangingSet
                  ? `Switch to ${selectedSet.companyName}`
                  : `Start with ${selectedSet.companyName}`}
              </button>
            </div>
          </motion.div>
        </div>

        <ResetModal
          isOpen={isResetConfirmOpen}
          onClose={() => setIsResetConfirmOpen(false)}
          onConfirm={executeSwitch}
        />

        <TeamFormModal
          isOpen={isCreateTeamOpen || editTeam !== null}
          onClose={() => {
            setIsCreateTeamOpen(false);
            setEditTeam(null);
          }}
          editTeam={editTeam}
        />

        {/* Delete confirmation */}
        {deleteConfirmTeam && (
          <div className="fixed inset-0 z-[200] flex items-center justify-center p-4">
            <div className="absolute inset-0 bg-black/50" onClick={() => setDeleteConfirmTeam(null)} />
            <div className="relative bg-white rounded-2xl shadow-2xl w-full max-w-sm p-6">
              <div className="flex items-center gap-3 mb-4">
                <div className="w-10 h-10 rounded-xl bg-red-100 flex items-center justify-center">
                  <Trash2 size={20} className="text-red-500" />
                </div>
                <div>
                  <h3 className="text-lg font-black text-zinc-900">Delete Team?</h3>
                  <p className="text-xs text-zinc-500">This cannot be undone.</p>
                </div>
              </div>
              <p className="text-sm text-zinc-600 mb-6">
                Delete <strong>{deleteConfirmTeam.companyName}</strong>? All agents in this team will be removed too.
              </p>
              <div className="flex gap-2">
                <button
                  onClick={() => setDeleteConfirmTeam(null)}
                  className="flex-1 py-2.5 bg-zinc-100 hover:bg-zinc-200 text-zinc-700 rounded-xl font-bold text-sm transition-colors"
                >
                  Cancel
                </button>
                <button
                  onClick={() => {
                    // If deleting currently selected team, need to switch first
                    if (deleteConfirmTeam.id === selectedAgentSetId) {
                      // Notify native app to close all tmux sessions
                      if (window.webkit?.messageHandlers?.orchestra) {
                        window.webkit.messageHandlers.orchestra.postMessage({ type: 'switchCompany' });
                      }
                      abortAllCalls();
                      scene?.resetScene();
                    }
                    deleteCustomTeam(deleteConfirmTeam.id);
                    setDeleteConfirmTeam(null);
                    setPendingSetId(useAgencyStore.getState().selectedAgentSetId);
                  }}
                  className="flex-1 py-2.5 bg-red-500 hover:bg-red-600 text-white rounded-xl font-bold text-sm transition-colors"
                >
                  Delete
                </button>
              </div>
            </div>
          </div>
        )}
        </>
      )}
    </AnimatePresence>
  );
};

export default AgentSetPickerModal;
