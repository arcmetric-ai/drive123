import Link from 'next/link'
import Navbar from '@/components/Nav'
import Footer from '@/components/Footer'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Instructor Login - Drive Tutor',
  description: 'Sign in to activate your Drive Tutor instructor account.',
}

export default function InstructorLogin() {
  return (
    <>
      <Navbar />
      <main className="policy-page">
        <div className="policy-inner" style={{ maxWidth: 760 }}>
          <div className="policy-header">
            <div className="policy-badge">Instructor Login</div>
            <h1 className="policy-title">Continue to instructor activation</h1>
            <p style={{ color: 'var(--muted)', fontSize: 15, lineHeight: 1.7, marginTop: 12 }}>
              Instructor sign-in is handled on the activation page so we can check approval status and pass
              access before sending you to Stripe or back into the mobile app.
            </p>
          </div>
          <div className="policy-nav-row">
            <Link href="/instructor/apply" className="policy-nav-btn">Apply as Instructor</Link>
            <Link href="/instructor/activate" className="policy-nav-btn primary">Sign In to Activate</Link>
          </div>
        </div>
      </main>
      <Footer />
    </>
  )
}
