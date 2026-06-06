import type { Metadata } from 'next'
import '../styles/globals.css'

export const metadata: Metadata = {
  title: 'Drive Tutor — Ontario\'s Driving Lesson Platform',
  description: "Ontario's driving lesson platform for learners and instructors. Book lessons, manage schedules, and stay organized with confidence.",
  keywords: 'driving lessons, Ontario, G1, G2, driving instructor, book driving lesson',
  icons: {
    icon: [
      { url: '/favicon.ico', type: 'image/x-icon' },
      { url: '/favicon.svg', type: 'image/svg+xml' },
      { url: '/icon.svg', type: 'image/svg+xml' },
    ],
    shortcut: '/favicon.ico',
    apple: '/logo-brand-blue.png',
  },
  openGraph: {
    title: 'Drive Tutor — Book Driving Lessons with Confidence',
    description: "Ontario's driving lesson platform for learners and instructors. Book lessons, manage schedules, and stay organized with confidence.",
    type: 'website',
  },
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800;900&display=swap" rel="stylesheet" />
      </head>
      <body>{children}</body>
    </html>
  )
}
