import { Geist, Geist_Mono } from 'next/font/google';
import './globals.css';
import { SiteChrome } from '@/components/site-chrome';

const geistSans = Geist({
  subsets: ['latin'],
  variable: '--font-sans',
});

const geistMono = Geist_Mono({
  subsets: ['latin'],
  variable: '--font-mono',
});

export const metadata = {
  title: 'skills.eir.space',
  description:
    'A beautifully designed Eir Space registry for publishing, browsing, and submitting agent skills.',
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body className={`${geistSans.variable} ${geistMono.variable}`}>
        <SiteChrome>{children}</SiteChrome>
      </body>
    </html>
  );
}
