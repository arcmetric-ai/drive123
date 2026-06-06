import Link from 'next/link'
import Navbar from '@/components/Nav'
import Footer from '@/components/Footer'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Instructor Portal - Drive Tutor',
  description: 'Instructor account activation and app access for Drive Tutor.',
}

export default function InstructorDashboard() {
  return (
    <>
      <Navbar />
      <main className="policy-page">
        <div className="policy-inner" style={{ maxWidth: 860 }}>
          <div className="policy-breadcrumb">
            <Link href="/">Home</Link>
            <span className="sep">/</span>
            <span style={{ color: 'var(--fg)', fontWeight: 600 }}>Instructor Portal</span>
          </div>

          <div className="policy-header">
            <div className="policy-badge">Instructor Portal</div>
            <h1 className="policy-title">Instructor tools live in the app</h1>
            <p style={{ color: 'var(--muted)', fontSize: 15, lineHeight: 1.7, marginTop: 12 }}>
              The website is used for instructor application, credential review, activation, billing, and
              account-level support. Approved and active instructors use the Drive Tutor mobile app to manage
              learners, lesson requests, availability, and scheduled lessons.
            </p>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(230px, 1fr))', gap: 16 }}>
            <div className="contact-card">
              <h3>New instructor?</h3>
              <p>Apply, upload credentials, and wait for Drive Tutor review.</p>
              <Link href="/instructor/apply" className="policy-nav-btn primary">Apply as Instructor</Link>
            </div>
            <div className="contact-card">
              <h3>Already approved?</h3>
              <p>Activate or reactivate your instructor pass before using app tools.</p>
              <Link href="/instructor/activate" className="policy-nav-btn primary">Activate Account</Link>
            </div>
          </div>
        </div>
      </main>
      <Footer />
    </>
  )
}
