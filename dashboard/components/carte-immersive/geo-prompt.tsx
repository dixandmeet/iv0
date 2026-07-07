"use client";

type GeoPromptProps = {
  promptVisible: boolean;
  deniedNoticeVisible: boolean;
  city: string;
  onAllow: () => void;
  onDeny: () => void;
};

export function GeoPrompt({ promptVisible, deniedNoticeVisible, city, onAllow, onDeny }: GeoPromptProps) {
  if (promptVisible) {
    return (
      <div className="immersive-map-panel immersive-map-toast absolute left-1/2 top-[84px] z-[400] w-[min(360px,86vw)] -translate-x-1/2 rounded-[20px] p-4">
        <div className="flex items-center gap-3">
          <span className="text-xl">📍</span>
          <div className="flex-1">
            <div className="text-[14.5px] font-semibold">Autoriser la géolocalisation ?</div>
            <div className="mt-0.5 text-[13px] text-white/65">
              Aule centrera la carte sur votre position et affichera ce qui vous entoure.
            </div>
          </div>
        </div>
        <div className="mt-3.5 flex gap-2">
          <button
            type="button"
            onClick={onDeny}
            className="flex-1 rounded-xl border border-white/[.16] bg-transparent py-2.5 text-[13.5px] font-medium text-white/80"
          >
            Refuser
          </button>
          <button
            type="button"
            onClick={onAllow}
            className="flex-1 rounded-xl border-none bg-[#33bfa3] py-2.5 text-[13.5px] font-bold text-[#04211c]"
          >
            Autoriser
          </button>
        </div>
      </div>
    );
  }

  if (deniedNoticeVisible) {
    return (
      <div className="immersive-map-panel immersive-map-toast absolute left-1/2 top-[82px] z-[399] w-[min(420px,86vw)] -translate-x-1/2 rounded-full px-[18px] py-2.5 text-center text-[13px] text-white/85">
        Carte centrée sur {city} — autorisez votre position pour un suivi personnalisé.
      </div>
    );
  }

  return null;
}
