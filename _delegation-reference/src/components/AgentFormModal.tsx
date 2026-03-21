import React, { useState, useEffect } from 'react';
import { X, UserPlus, Pencil } from 'lucide-react';
import { useAgencyStore } from '../store/agencyStore';
import { AgentData, getAgentSet } from '../data/agents';

interface AgentFormModalProps {
  isOpen: boolean;
  onClose: () => void;
  editAgent?: { index: number; agent: AgentData } | null;
}

const COLORS = [
  '#F59E0B', // amber
  '#10B981', // emerald
  '#3B82F6', // blue
  '#8B5CF6', // violet
  '#EC4899', // pink
  '#06B6D4', // cyan
  '#EF4444', // red
  '#84CC16', // lime
];

const AgentFormModal: React.FC<AgentFormModalProps> = ({ isOpen, onClose, editAgent }) => {
  const { selectedAgentSetId, addCustomAgent, updateCustomAgent, customAgents, customTeams } = useAgencyStore();
  const [role, setRole] = useState('');
  const [department, setDepartment] = useState('');
  const [mission, setMission] = useState('');
  const [personality, setPersonality] = useState('');
  const [color, setColor] = useState(COLORS[0]);

  const isEditMode = !!editAgent;

  // Populate form when editing
  useEffect(() => {
    if (editAgent) {
      setRole(editAgent.agent.role);
      setDepartment(editAgent.agent.department);
      setMission(editAgent.agent.mission);
      setPersonality(editAgent.agent.personality);
      setColor(editAgent.agent.color);
    }
  }, [editAgent]);

  if (!isOpen) return null;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!role.trim() || !mission.trim()) return;

    const agentData: Omit<AgentData, 'index'> = {
      role: role.trim(),
      department: department.trim() || 'Team',
      mission: mission.trim(),
      personality: personality.trim() || 'Helpful and friendly.',
      expertise: [],
      isPlayer: false,
      color,
    };

    if (isEditMode && editAgent) {
      // Find the index in customAgents array
      const customForSet = useAgencyStore.getState().customAgents[selectedAgentSetId] || [];
      const customIndex = customForSet.findIndex(a => a.role === editAgent.agent.role);
      if (customIndex !== -1) {
        updateCustomAgent(selectedAgentSetId, customIndex, agentData);

        // Update CLAUDE.md file via bridge
        if (window.webkit?.messageHandlers?.orchestra) {
          window.webkit.messageHandlers.orchestra.postMessage({
            type: 'updateAgentPersonality',
            agentIndex: editAgent.index,
            role: role.trim(),
            department: department.trim() || 'Team',
            mission: mission.trim(),
            personality: personality.trim() || 'Helpful and friendly.',
            companyName: getAgentSet(selectedAgentSetId, customAgents, customTeams).companyName,
            companyId: selectedAgentSetId,
          });
        }
      }
    } else {
      addCustomAgent(selectedAgentSetId, agentData);
    }
    handleClose();
  };

  const handleClose = () => {
    setRole('');
    setDepartment('');
    setMission('');
    setPersonality('');
    setColor(COLORS[0]);
    onClose();
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md mx-4 overflow-hidden">
        {/* Header */}
        <div className="flex items-center justify-between p-4 border-b border-zinc-100">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-violet-500 flex items-center justify-center">
              {isEditMode ? <Pencil size={16} className="text-white" /> : <UserPlus size={16} className="text-white" />}
            </div>
            <h2 className="text-lg font-black text-zinc-900">{isEditMode ? 'Edit Agent' : 'Add New Agent'}</h2>
          </div>
          <button
            onClick={handleClose}
            className="w-8 h-8 rounded-lg bg-zinc-100 hover:bg-zinc-200 flex items-center justify-center transition-colors"
          >
            <X size={16} className="text-zinc-500" />
          </button>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="p-4 space-y-4">
          {/* Role */}
          <div>
            <label className="block text-[10px] font-black uppercase tracking-widest text-zinc-400 mb-1">
              Role Name *
            </label>
            <input
              type="text"
              value={role}
              onChange={(e) => setRole(e.target.value)}
              placeholder="e.g., Musician Melody"
              className="w-full px-3 py-2 rounded-lg border border-zinc-200 focus:border-violet-500 focus:ring-1 focus:ring-violet-500 outline-none text-sm"
              required
            />
          </div>

          {/* Department */}
          <div>
            <label className="block text-[10px] font-black uppercase tracking-widest text-zinc-400 mb-1">
              Department
            </label>
            <input
              type="text"
              value={department}
              onChange={(e) => setDepartment(e.target.value)}
              placeholder="e.g., Strings, Percussion"
              className="w-full px-3 py-2 rounded-lg border border-zinc-200 focus:border-violet-500 focus:ring-1 focus:ring-violet-500 outline-none text-sm"
            />
          </div>

          {/* Mission */}
          <div>
            <label className="block text-[10px] font-black uppercase tracking-widest text-zinc-400 mb-1">
              Mission *
            </label>
            <textarea
              value={mission}
              onChange={(e) => setMission(e.target.value)}
              placeholder="What does this agent help with?"
              rows={2}
              className="w-full px-3 py-2 rounded-lg border border-zinc-200 focus:border-violet-500 focus:ring-1 focus:ring-violet-500 outline-none text-sm resize-none"
              required
            />
          </div>

          {/* Personality */}
          <div>
            <label className="block text-[10px] font-black uppercase tracking-widest text-zinc-400 mb-1">
              Personality
            </label>
            <textarea
              value={personality}
              onChange={(e) => setPersonality(e.target.value)}
              placeholder="e.g., Creative, detail-oriented, friendly"
              rows={2}
              className="w-full px-3 py-2 rounded-lg border border-zinc-200 focus:border-violet-500 focus:ring-1 focus:ring-violet-500 outline-none text-sm resize-none"
            />
          </div>

          {/* Color Picker */}
          <div>
            <label className="block text-[10px] font-black uppercase tracking-widest text-zinc-400 mb-2">
              Color
            </label>
            <div className="flex gap-2 flex-wrap">
              {COLORS.map((c) => (
                <button
                  key={c}
                  type="button"
                  onClick={() => setColor(c)}
                  className={`w-8 h-8 rounded-lg transition-transform ${
                    color === c ? 'ring-2 ring-offset-2 ring-zinc-400 scale-110' : 'hover:scale-105'
                  }`}
                  style={{ backgroundColor: c }}
                />
              ))}
            </div>
          </div>

          {/* Submit */}
          <div className="pt-2">
            <button
              type="submit"
              disabled={!role.trim() || !mission.trim()}
              className="w-full py-3 bg-violet-500 hover:bg-violet-600 disabled:bg-zinc-200 disabled:text-zinc-400 text-white rounded-xl font-black text-sm uppercase tracking-widest transition-colors"
            >
              {isEditMode ? 'Save Changes' : 'Add Agent'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default AgentFormModal;
