import "./globals.css";

export const metadata = {
  title: "skills.eir.space",
  description: "A curated health skill directory for agents"
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
