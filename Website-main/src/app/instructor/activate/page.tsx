import Link from 'next/link'
import Navbar from '@/components/Nav'
import Footer from '@/components/Footer'
import InstructorActivateClient from './InstructorActivateClient'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Activate Instructor Account - Drive Tutor',
  description: 'Activate or reactivate your Drive Tutor instructor account.',
}

export default function InstructorActivate() {
  return (
    <>
      <Navbar />
      <main className="policy-page">
        <div className="policy-inner" style={{ maxWidth: 980 }}>
          <div className="policy-breadcrumb">
            <Link href="/">Home</Link>
            <span className="sep">/</span>
            <span style={{ color: 'var(--fg)', fontWeight: 600 }}>Activate Instructor Account</span>
          </div>

          <div className="policy-header">
            <div className="policy-badge">Instructor Activation</div>
            <h1 className="policy-title">Activate your instructor account</h1>
            <p style={{ color: 'var(--muted)', fontSize: 15, lineHeight: 1.7, marginTop: 12 }}>
              Approved instructors can choose a pass to unlock instructor tools in the Drive Tutor app.
              Access is granted only after Stripe confirms payment through our secure webhook.
              Payment opens in Stripe Checkout, then returns you here to confirm activation.
            </p>
          </div>

          <InstructorActivateClient />

          <div className="policy-nav-row">
            <Link href="/instructor/apply" className="policy-nav-btn">Apply First</Link>
            <Link href="/contact" className="policy-nav-btn primary">Need Help?</Link>
          </div>
        </div>
      </main>
      <Footer />
    </>
  )
}
