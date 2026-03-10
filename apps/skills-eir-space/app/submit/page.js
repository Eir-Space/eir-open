import Link from 'next/link';
import { SubmitForm } from '@/components/submit-form';

export const metadata = {
  title: 'Submit Skill | skills.eir.space',
};

export default function SubmitPage() {
  return (
    <main className="pageWrap">
      <section className="pageHero">
        <div>
          <p className="eyebrow accent">Submission Portal</p>
          <h1>Submit or update an Eir skill.</h1>
          <p className="lede">
            Bring a GitHub repo, point at the skill folder, and publish into the queue with trust
            labels, source URLs, and catalog metadata already wired in.
          </p>
        </div>
        <div className="heroActions compact">
          <Link href="/" className="button ghost">
            Back to Directory
          </Link>
        </div>
      </section>

      <section className="heroMiniGrid">
        <article className="miniPanel">
          <p className="eyebrow">Repo URL</p>
          <h3>Point to the source of truth.</h3>
          <p>Each submission ties back to a real GitHub repo and a real skill path.</p>
        </article>
        <article className="miniPanel">
          <p className="eyebrow">Trust metadata</p>
          <h3>Show how much confidence belongs on the listing.</h3>
          <p>Review status, moderation tier, linked files, and source links all travel with the skill.</p>
        </article>
        <article className="miniPanel">
          <p className="eyebrow">Clinical workflows</p>
          <h3>Target repeatable, reviewable healthcare tasks.</h3>
          <p>Strong skills usually reduce chart hunting, improve handoffs, or catch omissions before they reach a patient.</p>
        </article>
      </section>

      <SubmitForm />
    </main>
  );
}
