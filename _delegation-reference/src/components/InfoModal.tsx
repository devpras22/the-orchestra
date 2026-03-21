
import React from 'react';
import { motion, AnimatePresence } from 'motion/react';

interface InfoModalProps {
  onClose: () => void;
}

const InfoModal: React.FC<InfoModalProps> = ({ onClose }) => {
  return (
    <AnimatePresence mode="wait">
      <div className="fixed inset-0 z-100 flex items-center justify-center p-6 pointer-events-auto overflow-hidden">
        <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            className="absolute inset-0 bg-white/60 backdrop-blur-xl"
          />
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 20 }}
            className="relative w-full max-w-xl bg-white rounded-[40px] shadow-[0_32px_64px_-12px_rgba(0,0,0,0.1)] p-8 md:p-10 border border-zinc-100"
          >
            <div className="max-w-md mx-auto">
              <h2 className="text-3xl font-black text-zinc-900 leading-[1.1] mb-6 tracking-tight text-center">
                The Orchestra: A Kid-Friendly AI Assistant App with Animated Agents
              </h2>

              <div className="space-y-4 text-zinc-500 text-sm leading-relaxed font-medium">
                <p>
                  Managing AI agents is a skill of the future — and The Orchestra is a training ground.
                </p>
                <p>
                  Kids don't just watch AI work; they learn to <strong>direct</strong> it. They give instructions, define roles, and coordinate a team of AI assistants in real-time.
                </p>
                <p>
                  With 3D animated characters that walk, talk, and collaborate, children see not just the result, but the thinking behind it.
                </p>
                <p className="text-zinc-400 italic">
                  It's where prompt engineering meets team management — a new kind of literacy for the AI age.
                </p>
              </div>

              <div className="mt-8 flex flex-col items-center gap-8">
                <button
                  onClick={onClose}
                  className="px-8 py-3 bg-zinc-900 text-white rounded-full text-[11px] font-black uppercase tracking-[0.2em] hover:bg-black transition-all active:scale-95 cursor-pointer"
                >
                  Close
                </button>

                <p className="text-[9px] font-bold text-zinc-300 uppercase tracking-[0.15em] text-center leading-loose">
                  A project by{' '}
                  <a href="https://x.com/PrasDevadoss" target="_blank" rel="noopener noreferrer" className="text-zinc-400 hover:text-zinc-900 transition-colors">Pras</a>
                </p>
              </div>
            </div>
          </motion.div>
        </div>
    </AnimatePresence>
  );
};

export default InfoModal;
