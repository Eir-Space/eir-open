import Image from 'next/image';
import Link from 'next/link';

const navItems = [
  { href: '/submit', label: 'Submit' },
  {
    href: 'https://github.com/Eir-Space/eir-open/tree/main/skills',
    label: 'Skills Repo',
    external: true,
  },
  {
    href: 'https://github.com/Eir-Space/eir-open/tree/main/apps/skills-eir-cli',
    label: 'CLI',
    external: true,
  },
];

function NavLink({ item }) {
  if (item.external) {
    return (
      <a href={item.href} target="_blank" rel="noreferrer" className="navLink">
        {item.label}
      </a>
    );
  }

  return (
    <Link href={item.href} className="navLink">
      {item.label}
    </Link>
  );
}

export function SiteChrome({ children }) {
  return (
    <div className="siteShell">
      <header className="topBar">
        <div className="frame topBarInner">
          <Link href="/" className="brandLockup">
            <Image
              src="/brand/icon-dark.svg"
              alt="Eir icon"
              width={46}
              height={46}
              className="brandIcon"
              priority
            />
            <span>
              <Image
                src="/brand/logo-colored.png"
                alt="Eir Space"
                width={148}
                height={30}
                className="brandWordmark"
                priority
              />
              <small>Eir skill registry</small>
            </span>
          </Link>

          <nav className="topNav" aria-label="Primary">
            {navItems.map((item) => (
              <NavLink key={item.label} item={item} />
            ))}
          </nav>
        </div>
      </header>

      <div className="siteContent">{children}</div>

      <footer className="siteFooter">
        <div className="frame siteFooterInner">
          <div>
            <Image
              src="/brand/logo-colored.png"
              alt="Eir Space"
              width={180}
              height={48}
              className="footerLogo"
            />
            <p className="eyebrow">Medical agent registry</p>
            <p className="footerCopy">
              Build medical agents with skills that add context, safer defaults, and better next
              actions.
            </p>
          </div>
          <div className="footerLinks">
            <a
              href="https://github.com/Eir-Space/eir-open/tree/main/apps/skills-eir-space"
              target="_blank"
              rel="noreferrer"
            >
              App source
            </a>
            <a href="https://github.com/Eir-Space/eir-open/tree/main/skills" target="_blank" rel="noreferrer">
              Skills repo
            </a>
          </div>
        </div>
      </footer>
    </div>
  );
}
