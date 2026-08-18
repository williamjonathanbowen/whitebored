"use client";

import { useEffect, useRef } from "react";

export function LaunchVideo({ src }: { src: string }) {
  const ref = useRef<HTMLVideoElement>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    el.muted = true;
    el.defaultMuted = true;
    el.loop = true;
    const play = () => {
      el.play().catch(() => {});
    };
    play();
    el.addEventListener("pause", play);
    el.addEventListener("ended", play);
    return () => {
      el.removeEventListener("pause", play);
      el.removeEventListener("ended", play);
    };
  }, []);

  return (
    <video
      ref={ref}
      src={src}
      className="mt-12 w-full"
      autoPlay
      muted
      loop
      playsInline
      preload="auto"
    />
  );
}
