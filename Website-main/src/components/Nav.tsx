'use client'
import { useState, useEffect } from 'react'
import Link from 'next/link'
import { usePathname } from 'next/navigation'

const policies = [
  { label: '🔐 Privacy Policy', href: '/privacy-policy' },
  { label: '📜 Terms & Conditions', href: '/terms-and-conditions' },
  { label: '✅ Data Consent Policy', href: '/data-consent-policy' },
  { label: '💳 Refund Policy', href: '/refund-policy' },
  { label: '🍪 Cookie Policy', href: '/cookie-policy' },
  { label: '🤝 Community Guidelines', href: '/community-guidelines' },
  { label: '🛡️ Instructor Verification', href: '/instructor-verification' },
  { label: '🦺 Safety Policy', href: '/safety-policy' },
  { label: '🗑️ Account Deletion', href: '/account-deletion' },
]

const scrollTo = (id: string) => {
  document.querySelector(id)?.scrollIntoView({ behavior: 'smooth' })
}

const scrollToTop = () => {
  window.scrollTo({ top: 0, behavior: 'smooth' })
}

export default function Nav() {
  const [mobileOpen, setMobileOpen] = useState(false)
  const [scrolled, setScrolled] = useState(false)

  useEffect(() => {
    const handler = () => setScrolled(window.scrollY > 20)
    window.addEventListener('scroll', handler, { passive: true })
    return () => window.removeEventListener('scroll', handler)
  }, [])
  const pathname = usePathname()
  const isHome = pathname === '/'

  useEffect(() => { setMobileOpen(false) }, [pathname])

  const closeMobile = () => setMobileOpen(false)

  return (
    <>
      <div className="accent-bar" />
      <nav>
        <Link href="/" className="nav-logo" onClick={closeMobile}>
          <img src="/logo-brand-blue.png" alt="DriveTutor" className="logo-mark" />
          <span className="logo-text">Drive<span>Tutor</span></span>
        </Link>

        <div className="nav-links">
          {isHome ? (
            <>
              <button className="nav-link" onClick={() => scrollTo('#hero')}>Home</button>
              <button className="nav-link" onClick={() => scrollTo('#about')}>About</button>
              <button className="nav-link" onClick={() => scrollTo('#screenshots')}>App</button>
              <button className="nav-link" onClick={() => scrollTo('#features')}>Features</button>
              <button className="nav-link" onClick={() => scrollTo('#download')}>Download</button>
              <button className="nav-link" onClick={() => scrollTo('#legal')}>Legal</button>
            </>
          ) : (
            <Link href="/" className="nav-link">← Home</Link>
          )}

          <div className="nav-dropdown">
            <button className="nav-link">Policies ▾</button>
            <div className="nav-dropdown-menu">
              {policies.map(p => (
                <Link key={p.href} href={p.href} className="nav-dropdown-item">{p.label}</Link>
              ))}
            </div>
          </div>

          <Link href="/contact" className={`nav-link${pathname === '/contact' ? ' active' : ''}`}>Contact</Link>
        </div>

        <div className="nav-spacer" />

        <Link href="/instructor/apply" className="nav-store-btn nav-btn-primary">
          Apply as Instructor
        </Link>

        <button className="hamburger" onClick={() => setMobileOpen(o => !o)} aria-label="Menu">
          <span /><span /><span />
        </button>
      </nav>

      <div className={`mobile-menu${mobileOpen ? ' open' : ''}`}>
        {isHome ? (
          <>
            <button className="mobile-nav-link" onClick={() => { scrollTo('#hero'); closeMobile() }}>🏠 Home</button>
            <button className="mobile-nav-link" onClick={() => { scrollTo('#about'); closeMobile() }}>ℹ️ About</button>
            <button className="mobile-nav-link" onClick={() => { scrollTo('#screenshots'); closeMobile() }}>📱 App</button>
            <button className="mobile-nav-link" onClick={() => { scrollTo('#features'); closeMobile() }}>⭐ Features</button>
            <button className="mobile-nav-link" onClick={() => { scrollTo('#download'); closeMobile() }}>⬇️ Download</button>
            <button className="mobile-nav-link" onClick={() => { scrollTo('#legal'); closeMobile() }}>⚖️ Legal</button>
          </>
        ) : (
          <Link href="/" className="mobile-nav-link" onClick={closeMobile}>🏠 Home</Link>
        )}
        <div className="mobile-divider" />
        {policies.map(p => (
          <Link key={p.href} href={p.href} className="mobile-nav-link" onClick={closeMobile}>{p.label}</Link>
        ))}
        <div className="mobile-divider" />
        <Link href="/contact" className="mobile-nav-link" onClick={closeMobile}>💬 Contact</Link>
        <div className="mobile-divider" />
        <Link href="/instructor/apply" className="mobile-nav-link" onClick={closeMobile}
          style={{ color: 'var(--primary)', fontWeight: 700 }}>
          Apply as Instructor
        </Link>
      </div>

      <button
        className={`scroll-top-btn${scrolled ? ' visible' : ''}`}
        onClick={scrollToTop}
        aria-label="Scroll to top"
      >
        ↑
      </button>
    </>
  )
}
