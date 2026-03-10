export function EirAppShell() {
  return (
    <main className="eir-page">
      <section className="eir-hero">
        <div>
          <p className="eir-kicker">skills.eir.space</p>
          <h1>Build something unmistakably Eir.</h1>
          <p>
            Warm surfaces, focused content, and the Eir Aura doing just enough work to make the
            product feel alive.
          </p>
        </div>

        <aside className="eir-feature">
          <strong>Design starter</strong>
          <ul>
            <li>Official tokens</li>
            <li>Brand assets</li>
            <li>Content-first app shell</li>
          </ul>
        </aside>
      </section>

      <section className="eir-stats">
        <article>Published skills</article>
        <article>Queued submissions</article>
        <article>Verified builders</article>
      </section>

      <section className="eir-content">
        <article className="eir-card">Use this section for filters, catalog cards, or forms.</article>
      </section>
    </main>
  );
}
