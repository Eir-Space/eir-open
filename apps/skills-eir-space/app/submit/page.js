import Link from "next/link";
import { SubmitForm } from "@/components/submit-form";

export const metadata = {
  title: "Submit Health Skill | skills.eir.space"
};

export default function SubmitPage() {
  return (
    <main className="pageWrap">
      <section className="subpageHero">
        <div>
          <p className="eyebrow accent">Submission Portal</p>
          <h1>Submit or Update a Health Skill</h1>
          <p className="lede">
            Public submissions are welcome. Skills publish into the registry with clear trust badges and moderation tier labels, then can be upgraded through verification and review.
          </p>
        </div>
        <div className="heroActions">
          <Link href="/" className="button ghost">
            Back to Directory
          </Link>
        </div>
      </section>

      <SubmitForm />
    </main>
  );
}
