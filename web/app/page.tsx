import { copy } from "@/copy";
import { DownloadForm } from "./download-form";
import { LaunchVideo } from "./launch-video";

export default function Home() {
  return (
    <main className="max-w-[34rem] px-10 py-12">
      <p className="mb-8 text-sm">
        <a href={copy.repoUrl} className="text-[#00e] underline">
          {copy.repoLabel}
        </a>
      </p>
      <h1 className="text-[2rem] font-bold leading-tight">{copy.headline}</h1>
      <p className="mt-2 text-[1.05rem] text-[#777]">{copy.subtitle}</p>
      <p className="mt-6 text-[15px] leading-7">{copy.body}</p>
      <div className="mt-6 space-y-1 text-[15px] leading-7">
        {copy.features.map((line) => (
          <p key={line}>{line}</p>
        ))}
      </div>
      <DownloadForm />
      {copy.video ? <LaunchVideo src={copy.video} /> : null}
    </main>
  );
}
