// ─────────────────────────────────────────────────────────────
//  Constants
// ─────────────────────────────────────────────────────────────
export const PLAYER_INDEX = 0;
export const NPC_START_INDEX = 1;
export const DEFAULT_AGENT_SET_ID = 'the-orchestra';

// ─────────────────────────────────────────────────────────────
//  Agent data types
// ─────────────────────────────────────────────────────────────
export interface AgentData {
  index: number;
  department: string;
  role: string;
  expertise: string[];
  mission: string;
  personality: string;
  isPlayer: boolean;
  color: string;
}

export interface AgentSet {
  id: string;
  companyName: string;
  companyType: string;
  companyDescription: string;
  color: string;
  agents: AgentData[];
}

// ─────────────────────────────────────────────────────────────
//  Agent Sets
// ─────────────────────────────────────────────────────────────
export const AGENT_SETS: AgentSet[] = [
  // ── 1. Idea Lab ───────────────────────────────────────────
  {
    id: 'idea-lab',
    companyName: 'Idea Lab',
    companyType: 'Creative Studio',
    companyDescription: 'A place where you turn your ideas into something real.',
    color: '#3B82F6',
    agents: [
      {
        index: 0,
        department: 'Hero',
        role: 'Superhero',
        expertise: ['Imagination', 'Bravery', 'Big Ideas'],
        mission: 'Share your amazing idea and watch it come to life!',
        personality: 'Brave, creative, and ready to save the day.',
        isPlayer: true,
        color: '#3B82F6',
      },
      {
        index: 1,
        department: 'Support',
        role: 'Sidekick',
        expertise: ['Building', 'Helping', 'Problem Solving'],
        mission: 'Help the superhero turn their idea into reality.',
        personality: 'Loyal, helpful, and always ready to assist.',
        isPlayer: false,
        color: '#10B981',
      },
    ],
  },

  // ── 2. StorySpark Studios ───────────────────────────────────────────
  {
    id: 'story-spark-studios',
    companyName: 'StorySpark Studios',
    companyType: 'Story & Comic Studio',
    companyDescription: 'A creative team that builds stories, comics, and adventures together.',
    color: '#10B981',
    agents: [
      {
        index: 0,
        department: 'Human',
        role: 'You',
        expertise: ['Imagination', 'Creativity', 'Story Ideas'],
        mission: 'Share your story idea and watch it come to life!',
        personality: 'Imaginative and creative.',
        isPlayer: true,
        color: '#10B981',
      },
      {
        index: 1,
        department: 'Writing',
        role: 'Story Writer',
        expertise: ['Plot', 'Dialogue', 'Pacing', 'Story Structure'],
        mission: 'Craft the engaging narrative with memorable characters and exciting plot twists.',
        personality: 'Creative, imaginative, and loves a good plot twist.',
        isPlayer: false,
        color: '#F59E0B',
      },
      {
        index: 2,
        department: 'Characters',
        role: 'Character Creator',
        expertise: ['Character Development', 'Backstory', 'Personality', 'Visual Design'],
        mission: 'Create memorable characters with unique personalities and compelling backstories.',
        personality: 'Creative, empathetic, and detail-oriented.',
        isPlayer: false,
        color: '#06B6D4',
      },
      {
        index: 3,
        department: 'Editing',
        role: 'Editor',
        expertise: ['Grammar', 'Pacing', 'Clarity', 'Flow'],
        mission: 'Polish the story, fix plot holes, and ensure narrative flows smoothly.',
        personality: 'Detail-oriented, constructive, and focused on quality.',
        isPlayer: false,
        color: '#6366F1',
      },
      {
        index: 4,
        department: 'Art',
        role: 'Illustrator',
        expertise: ['Visual Scenes', 'Character Design', 'Panel Layout'],
        mission: 'Create visual scenes that bring characters and world to life.',
        personality: 'Artistic, visual, and loves drawing characters.',
        isPlayer: false,
        color: '#EC4899',
      },
    ],
  },

  // ── 3. The Orchestra ────────────────────────────────────────
  {
    id: 'the-orchestra',
    companyName: 'The Orchestra',
    companyType: 'AI Studio',
    companyDescription: 'You are the conductor. You lead your AI musicians. Turn your idea into something real by directing your musicians.',
    color: '#8B5CF6',
    agents: [
      {
        index: 0,
        department: 'Conductor',
        role: 'You',
        expertise: ['Directing', 'Creativity', 'Ideas'],
        mission: 'Lead your musicians and turn your idea into reality.',
        personality: 'Creative and visionary.',
        isPlayer: true,
        color: '#8B5CF6',
      },
      {
        index: 1,
        department: 'Strings',
        role: 'Musician Nova',
        expertise: ['Writing', 'Building', 'Creating'],
        mission: 'Bring the conductors vision to life through code and creativity.',
        personality: 'Talented and expressive.',
        isPlayer: false,
        color: '#F59E0B',
      },
      {
        index: 2,
        department: 'Percussion',
        role: 'Musician Echo',
        expertise: ['Supporting', 'Debugging', 'Refining'],
        mission: 'Support the performance and refine the details.',
        personality: 'Rhythmic and reliable.',
        isPlayer: false,
        color: '#06B6D4',
      },
    ],
  },
];

// ─────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────

// Predefined company types for the dropdown
export const COMPANY_TYPES = [
  'AI Studio',
  'Creative Studio',
  'Game Studio',
  'Science Lab',
  'Story Studio',
  'Music Studio',
  'Art Studio',
  'Tech Lab',
] as const;

// Colors for team color picker
export const TEAM_COLORS = [
  '#8B5CF6', // violet (default)
  '#3B82F6', // blue
  '#10B981', // emerald
  '#F59E0B', // amber
  '#EC4899', // pink
  '#06B6D4', // cyan
  '#EF4444', // red
  '#84CC16', // lime
];

// Create a default player agent for new teams
export function createDefaultPlayer(teamColor: string): AgentData {
  return {
    index: 0,
    department: 'Leader',
    role: 'You',
    expertise: ['Creativity', 'Ideas', 'Direction'],
    mission: 'Lead your team and bring your ideas to life.',
    personality: 'Creative and visionary.',
    isPlayer: true,
    color: teamColor,
  };
}

// Get a single agent set (built-in or custom) with merged custom agents
export function getAgentSet(id: string, customAgents: Record<string, AgentData[]> = {}, customTeams: Record<string, AgentSet> = {}): AgentSet {
  // First check if it's a custom team
  const customTeam = customTeams[id];
  const baseSet = customTeam ?? AGENT_SETS.find((s) => s.id === id) ?? AGENT_SETS[0];
  const customForSet = customAgents[id] || [];

  if (customForSet.length === 0) {
    return baseSet;
  }

  // Merge custom agents with base set
  // Custom agents get indices starting after the last base agent
  const maxBaseIndex = Math.max(...baseSet.agents.map(a => a.index));
  const indexedCustomAgents = customForSet.map((agent, i) => ({
    ...agent,
    index: maxBaseIndex + 1 + i,
  }));

  return {
    ...baseSet,
    agents: [...baseSet.agents, ...indexedCustomAgents],
  };
}

// Get all agent sets (built-in + custom) with merged custom agents
export function getAllAgentSets(customAgents: Record<string, AgentData[]> = {}, customTeams: Record<string, AgentSet> = {}): AgentSet[] {
  const builtInSets = AGENT_SETS.map(set => getAgentSet(set.id, customAgents, customTeams));
  const customSetsList = Object.values(customTeams).map(team => getAgentSet(team.id, customAgents, customTeams));
  return [...builtInSets, ...customSetsList];
}

// Check if a team ID is a built-in team (cannot be edited/deleted)
export function isBuiltInTeam(id: string): boolean {
  return AGENT_SETS.some(s => s.id === id);
}

export function getAgent(index: number, agents: AgentData[]): AgentData | undefined {
  return agents.find((a) => a.index === index);
}
