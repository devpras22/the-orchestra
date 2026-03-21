import React, { useState, useEffect } from 'react';
import { X, Building2, Pencil } from 'lucide-react';
import { useAgencyStore } from '../store/agencyStore';
import { AgentSet, COMPANY_TYPES, TEAM_COLORS, createDefaultPlayer } from '../data/agents';

interface TeamFormModalProps {
  isOpen: boolean;
  onClose: () => void;
  editTeam?: AgentSet | null;
}

const TeamFormModal: React.FC<TeamFormModalProps> = ({ isOpen, onClose, editTeam }) => {
  const { addCustomTeam, updateCustomTeam } = useAgencyStore();
  const [companyName, setCompanyName] = useState('');
  const [companyType, setCompanyType] = useState<string>(COMPANY_TYPES[0]);
  const [companyDescription, setCompanyDescription] = useState('');
  const [color, setColor] = useState(TEAM_COLORS[0]);

  const isEditMode = !!editTeam;

  // Populate form when editing
  useEffect(() => {
    if (editTeam) {
      setCompanyName(editTeam.companyName);
      setCompanyType(editTeam.companyType);
      setCompanyDescription(editTeam.companyDescription);
      setColor(editTeam.color);
    }
  }, [editTeam]);

  if (!isOpen) return null;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!companyName.trim()) return;

    if (isEditMode && editTeam) {
      // Update existing team
      updateCustomTeam(editTeam.id, {
        companyName: companyName.trim(),
        companyType,
        companyDescription: companyDescription.trim() || `A ${companyType.toLowerCase()} team.`,
        color,
      });
    } else {
      // Create new team
      const teamId = `custom_${Date.now()}`;
      const player = createDefaultPlayer(color);

      const newTeam: AgentSet = {
        id: teamId,
        companyName: companyName.trim(),
        companyType,
        companyDescription: companyDescription.trim() || `A ${companyType.toLowerCase()} team.`,
        color,
        agents: [player], // Start with just the player
      };

      console.log('[TeamFormModal] Creating new team:', newTeam);
      addCustomTeam(newTeam);
    }
    handleClose();
  };

  const handleClose = () => {
    setCompanyName('');
    setCompanyType(COMPANY_TYPES[0]);
    setCompanyDescription('');
    setColor(TEAM_COLORS[0]);
    onClose();
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-[200]">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md mx-4 overflow-hidden">
        {/* Header */}
        <div className="flex items-center justify-between p-4 border-b border-zinc-100">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-violet-500 flex items-center justify-center">
              {isEditMode ? <Pencil size={16} className="text-white" /> : <Building2 size={16} className="text-white" />}
            </div>
            <h2 className="text-lg font-black text-zinc-900">{isEditMode ? 'Edit Team' : 'Create New Team'}</h2>
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
          {/* Team Name */}
          <div>
            <label className="block text-[10px] font-black uppercase tracking-widest text-zinc-400 mb-1">
              Team Name *
            </label>
            <input
              type="text"
              value={companyName}
              onChange={(e) => setCompanyName(e.target.value)}
              placeholder="e.g., My Space Team"
              className="w-full px-3 py-2 rounded-lg border border-zinc-200 focus:border-violet-500 focus:ring-1 focus:ring-violet-500 outline-none text-sm"
              required
            />
          </div>

          {/* Team Type */}
          <div>
            <label className="block text-[10px] font-black uppercase tracking-widest text-zinc-400 mb-1">
              Team Type *
            </label>
            <select
              value={companyType}
              onChange={(e) => setCompanyType(e.target.value)}
              className="w-full px-3 py-2 rounded-lg border border-zinc-200 focus:border-violet-500 focus:ring-1 focus:ring-violet-500 outline-none text-sm bg-white"
            >
              {COMPANY_TYPES.map((type) => (
                <option key={type} value={type}>{type}</option>
              ))}
            </select>
          </div>

          {/* Description */}
          <div>
            <label className="block text-[10px] font-black uppercase tracking-widest text-zinc-400 mb-1">
              Description
            </label>
            <textarea
              value={companyDescription}
              onChange={(e) => setCompanyDescription(e.target.value)}
              placeholder="What does this team do?"
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
              {TEAM_COLORS.map((c) => (
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
              disabled={!companyName.trim()}
              className="w-full py-3 bg-violet-500 hover:bg-violet-600 disabled:bg-zinc-200 disabled:text-zinc-400 text-white rounded-xl font-black text-sm uppercase tracking-widest transition-colors"
            >
              {isEditMode ? 'Save Changes' : 'Create Team'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default TeamFormModal;
