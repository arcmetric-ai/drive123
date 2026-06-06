import Link from 'next/link'
import Navbar from '@/components/Nav'
import Footer from '@/components/Footer'
import InstructorApplyClient from './InstructorApplyClient'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Apply as an Instructor - Drive Tutor',
  description: 'Apply to become a verified Drive Tutor instructor in Ontario.',
}

export default function InstructorApply() {
  return (
    <>
      <Navbar />
      <main className="policy-page">
        <div className="policy-inner" style={{ maxWidth: 980 }}>
          <div className="policy-breadcrumb">
            <Link href="/">Home</Link>
            <span className="sep">/</span>
            <span style={{ color: 'var(--fg)', fontWeight: 600 }}>Instructor Application</span>
          </div>

          <div className="policy-header">
            <div className="policy-badge">Instructor Application</div>
            <h1 className="policy-title">Apply to teach with Drive Tutor</h1>
            <p style={{ color: 'var(--muted)', fontSize: 15, lineHeight: 1.7, marginTop: 12 }}>
              Instructor onboarding is moving to the Drive Tutor website. You will complete your application,
              upload credentials, wait for review, and activate your instructor account here before logging into
              the mobile app. The app tools begin after Drive Tutor accepts and activates your account.
            </p>
          </div>

          <InstructorApplyClient />

          <div className="policy-nav-row">
            <Link href="/" className="policy-nav-btn">Back to Home</Link>
            <Link href="/instructor/activate" className="policy-nav-btn primary">Already approved? Activate Account</Link>
          </div>
        </div>
      </main>
      <Footer />
    </>
  )
}
