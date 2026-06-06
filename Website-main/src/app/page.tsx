'use client'
import { useEffect, useRef, useState } from 'react'
import Link from 'next/link'
import Navbar from '@/components/Nav'
import Footer from '@/components/Footer'
import { UserCheck, Calendar, LayoutDashboard, BarChart3 } from 'lucide-react'

type TileItem = { color: string; delay: number; duration: number }
const TILE_COLORS = [
  'rgba(5,74,218,0.18)',
  'rgba(79,70,229,0.14)',
  'rgba(99,102,241,0.11)',
  'rgba(139,92,246,0.09)',
  'rgba(59,130,246,0.16)',
  'rgba(96,165,250,0.12)',
  'rgba(167,139,250,0.10)',
]

const features = [
  { ico: '📅', title: 'Easy Booking', desc: 'Send lesson requests and get scheduled based on your availability, no back-and-forth calls.' },
  { ico: '🛡️', title: 'Verified Instructors', desc: 'Every instructor is verified before they can accept bookings. Safety first, always.' },
  { ico: '🗓️', title: 'Lesson Management', desc: 'Upcoming lessons, history, and rescheduling — all tracked automatically.' },
  { ico: '🔒', title: 'Secure & Private', desc: 'Your data is protected. Personal information is handled with care.' },
]
const screenshots = [
  { bg: 'linear-gradient(145deg,#EFF6FF,#DBEAFE)', src: '/screenshots/Ins_dash.png',  alt: 'Instructor Dashboard' },
  { bg: 'linear-gradient(145deg,#F0FDF4,#DCFCE7)', src: '/screenshots/Sch_view1.png', alt: 'Schedule View 1' },
  { bg: 'linear-gradient(145deg,#FFF7ED,#FED7AA)', src: '/screenshots/Sch_view2.png', alt: 'Schedule View 2' },
  { bg: 'linear-gradient(145deg,#F5F3FF,#EDE9FE)', src: '/screenshots/Learn_Man.png', alt: 'Learner Management' },
  { bg: 'linear-gradient(145deg,#FFF1F2,#FFE4E6)', src: '/screenshots/Pend_req.png',  alt: 'Pending Requests' },
]
const legalCards = [
  { ico: '🔐', title: 'Privacy Policy', desc: 'How we collect, use, and protect your personal data.', href: '/privacy-policy' },
  { ico: '📜', title: 'Terms & Conditions', desc: 'The rules and guidelines for using Drive Tutor.', href: '/terms-and-conditions' },
  { ico: '✅', title: 'Data Consent Policy', desc: 'Your rights around data consent and processing.', href: '/data-consent-policy' },
  { ico: '💳', title: 'Refund Policy', desc: 'Our cancellation and refund guidelines.', href: '/refund-policy' },
  { ico: '🍪', title: 'Cookie Policy', desc: 'How we use cookies and tracking technologies.', href: '/cookie-policy' },
  { ico: '🗑️', title: 'Account Deletion', desc: 'How to request deletion of your account and data.', href: '/account-deletion' },
  { ico: '🤝', title: 'Community Guidelines', desc: 'Standards for respectful use of the platform.', href: '/community-guidelines' },
  { ico: '🛡️', title: 'Instructor Verification', desc: 'How we vet and verify all instructors.', href: '/instructor-verification' },
  { ico: '🦺', title: 'Safety Policy', desc: 'Our commitment to the safety of all users.', href: '/safety-policy' },
  { ico: '💬', title: 'Contact & Support', desc: 'Get in touch with the Drive Tutor team.', href: '/contact' },
]

export default function Home() {
  const sectionsRef = useRef<string[]>(['#hero','#about','#screenshots','#features','#download','#legal'])

  useEffect(() => {
    const btns = document.querySelectorAll('.pn-btn')
    const handler = () => {
      let cur = 0
      sectionsRef.current.forEach((id, i) => {
        const el = document.querySelector(id)
        if (el && window.scrollY >= (el as HTMLElement).offsetTop - 180) cur = i
      })
      btns.forEach((b, i) => b.classList.toggle('active', i === cur))
    }
    window.addEventListener('scroll', handler, { passive: true })
    return () => window.removeEventListener('scroll', handler)
  }, [])

  const [tiles, setTiles] = useState<TileItem[]>([])
  useEffect(() => {
    setTiles(Array.from({ length: 220 }, () => ({
      color: TILE_COLORS[Math.floor(Math.random() * TILE_COLORS.length)],
      delay: +(Math.random() * 5).toFixed(2),
      duration: +(2.5 + Math.random() * 3).toFixed(2),
    })))
  }, [])

  const scrollTo = (id: string, btn: HTMLButtonElement) => {
    document.querySelector(id)?.scrollIntoView({ behavior: 'smooth' })
    document.querySelectorAll('.pn-btn').forEach(b => b.classList.remove('active'))
    btn.classList.add('active')
  }

  return (
    <>
      <Navbar />

      {/* HERO */}
      <section id="hero" style={{ minHeight: '640px', position: 'relative', overflow: 'hidden', background: '#ffffff' }}>
        {/* Animated tile grid */}
        <div className="hero-tile-grid">
          {tiles.map((t, i) => (
            <div
              key={i}
              className="hero-tile"
              style={{ background: t.color, animationDuration: `${t.duration}s`, animationDelay: `${t.delay}s` }}
            />
          ))}
        </div>

        {/* Background video */}
        <div className="hero-video-wrap">
          <video autoPlay loop muted playsInline className="hero-video">
            <source src="https://d8j0ntlcm91z4.cloudfront.net/user_38xzZboKViGWJOttwIXH07lWA1P/hf_20260302_085640_276ea93b-d7da-4418-a09b-2aa5b490e838.mp4" type="video/mp4" />
          </video>
          <div className="hero-overlay" />
        </div>

        {/* Content */}
        <div className="hero-content-new">
          <h1 className="hero-headline-new hero-animate" style={{ animationDelay: '0.1s' }}>
            <span className="hero-line-1">Stay focused on driving.</span>
            <span className="hero-line-2"><em className="hero-serif">We&apos;ll handle the rest.</em></span>
          </h1>

          <p className="hero-subtext-new hero-animate" style={{ animationDelay: '0.25s' }}>
            Book lessons, manage schedules, and learn with confidence through a platform built for Ontario drivers.
          </p>

          <div className="hero-pill-btns hero-animate" style={{ animationDelay: '0.4s' }}>
            <button type="button" onClick={() => document.querySelector('#download')?.scrollIntoView({ behavior: 'smooth' })} className="hero-pill-btn hero-pill-btn-primary">
              I&apos;m a Learner
            </button>
            <Link href="/instructor/apply" className="hero-pill-btn hero-pill-btn-secondary">
              I&apos;m an Instructor
            </Link>
          </div>

          <p className="hero-trust-line hero-animate" style={{ animationDelay: '0.52s' }}>
            Ontario&apos;s driving lesson platform
          </p>
        </div>
      </section>

      {/* HOW IT WORKS */}
      <section id="how-it-works" style={{ padding: 'clamp(64px,8vw,96px) clamp(16px,2.5vw,24px)', background: 'var(--secondary)' }}>
        <div className="page-container">
          <div style={{ textAlign: 'center', marginBottom: 56 }}>
            <h2>How Drive Tutor Works</h2>
            <p style={{ color: 'var(--muted)', fontSize: 16, marginTop: 10, maxWidth: 480, marginLeft: 'auto', marginRight: 'auto' }}>Simple steps to manage your lessons without the hassle</p>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 20, marginBottom: 48 }}>
            {[
              { step: '1', Icon: UserCheck,       title: 'Get matched with learners',       desc: 'Learners request lessons based on your location and availability.' },
              { step: '2', Icon: Calendar,         title: 'Accept and schedule',             desc: 'Approve learners and schedule lessons using your built-in planner.' },
              { step: '3', Icon: LayoutDashboard,  title: 'Manage everything in one place',  desc: 'Track lesson notes, progress, and schedules without manual work.' },
              { step: '4', Icon: BarChart3,         title: 'Stay organized and in control',   desc: 'View your daily, weekly, and monthly schedule at a glance.' },
            ].map(({ step, Icon, title, desc }) => (
              <div key={step} className="feat-card">
                <div className="hiw-icon-wrap">
                  <Icon size={22} strokeWidth={1.6} />
                </div>
                <div className="hiw-step-label">Step {step}</div>
                <div className="feat-title">{title}</div>
                <div className="feat-desc">{desc}</div>
              </div>
            ))}
          </div>
          <div style={{ textAlign: 'center' }}>
            <Link href="/instructor/apply" className="btn-primary">
              Apply as Instructor
            </Link>
          </div>
        </div>
      </section>

      {/* WHY DRIVE TUTOR */}
      <section id="why-drive-tutor" style={{ padding: 'clamp(64px,8vw,96px) clamp(16px,2.5vw,24px)', background: 'var(--bg)' }}>
        <div className="page-container">
          <div style={{ textAlign: 'center', marginBottom: 56 }}>
            <h2>Why learners and instructors trust Drive Tutor</h2>
            <p style={{ color: 'var(--muted)', fontSize: 16, marginTop: 10, maxWidth: 520, marginLeft: 'auto', marginRight: 'auto' }}>Built around verified instructors, organized lesson management, and a safer learning experience.</p>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))', gap: 20, marginBottom: 48 }}>
            {[
              { ico: '✅', title: 'Verified Ontario instructors', desc: 'Every instructor on Drive Tutor is reviewed to help learners connect with legitimate, provincially certified professionals.' },
              { ico: '📋', title: 'Organized lesson tracking', desc: 'Keep lesson notes, progress, and schedules in one place so nothing gets lost between classes.' },
              { ico: '🛡️', title: 'Built for a safer experience', desc: 'Drive Tutor is designed to reduce confusion, improve visibility, and give learners more confidence in who they are booking with.' },
            ].map(c => (
              <div key={c.title} className="feat-card">
                <div className="feat-icon">{c.ico}</div>
                <div className="feat-title">{c.title}</div>
                <div className="feat-desc">{c.desc}</div>
              </div>
            ))}
          </div>
          <div style={{ textAlign: 'center' }}>
            <Link href="/instructor/apply" className="btn-primary">
              Apply as Instructor
            </Link>
          </div>
        </div>
      </section>

      {/* ABOUT */}
      <section id="about" style={{ padding: 'clamp(64px,8vw,96px) clamp(16px,2.5vw,24px)', background: 'var(--bg)' }}>
        <div className="about-inner">
          <div className="about-tag-row">
            <div className="section-tag"><span>About Drive Tutor</span></div>
          </div>
          <div>
            <h2>Ontario&apos;s driving lesson platform</h2>
            <div className="about-text">
              <p>Drive Tutor is a mobile-first platform that connects people learning to drive with licensed instructors across Ontario.</p>
              <p>Whether you&apos;re preparing for your G1, G2, or G, or you&apos;re an instructor looking to manage bookings more efficiently, Drive Tutor brings both sides together in one trusted app.</p>
              <p>Built specifically for Ontario, Drive Tutor is designed around the G1 → G2 → G licensing journey — helping learners stay organized and instructors stay in control.</p>
            </div>
          </div>
          <div className="about-cards">
            {[
              { ico: '🎯', title: 'For Learners', desc: 'Browse verified instructors, check availability, and book in minutes. Track your full journey from G1 to G.' },
              { ico: '🏫', title: 'For Instructors', desc: 'Manage your schedule, student roster, and incoming bookings — without the overhead of admin work.' },
              { ico: '✅', title: 'Verified & Trusted', desc: 'All instructors undergo background checks and credential verification before they can accept bookings.' },
            ].map(c => (
              <div key={c.title} className="about-card">
                <div className="about-icon">{c.ico}</div>
                <div><div className="about-card-title">{c.title}</div><div className="about-card-desc">{c.desc}</div></div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* SCREENSHOTS */}
      <section id="screenshots" style={{ padding: 'clamp(64px,8vw,96px) clamp(16px,2.5vw,24px)', background: 'var(--secondary)' }}>
        <div className="screenshots-inner">
          <div className="screenshots-head">
            <h2>See the app in action</h2>
            <p>Clean, intuitive screens built for learners and instructors alike.</p>
          </div>
          <div className="app-screens-row">
            {screenshots.map(s => (
              <div key={s.alt} className="app-screen-item">
                <div style={{ width: '100%', aspectRatio: '9/19.5', borderRadius: '38px', border: '2px solid var(--border)', background: s.bg, overflow: 'hidden', boxShadow: '0 8px 40px rgba(0,0,0,0.09)', position: 'relative', transition: 'transform 0.3s, box-shadow 0.3s' }}>
                  <div style={{ position: 'absolute', top: 13, left: '50%', transform: 'translateX(-50%)', width: 58, height: 6, background: 'rgba(17,24,39,0.11)', borderRadius: 3 }} />
                  {s.src && <img src={s.src} alt={s.alt} style={{ width: '100%', height: '100%', objectFit: 'contain', display: 'block' }} />}
                </div>
                <span style={{ fontSize: 13, color: 'var(--muted)', fontWeight: 500 }}>{s.alt}</span>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* FEATURES */}
      <section id="features" style={{ padding: 'clamp(64px,8vw,96px) clamp(16px,2.5vw,24px)', background: 'var(--bg)' }}>
        <div className="features-inner">
          <div className="features-head">
            <div className="section-tag" style={{ margin: '0 auto 16px' }}><span>Features</span></div>
            <h2>Everything you need, nothing you don&apos;t</h2>
            <p>Built for learners and instructors alike — simple, fast, always available.</p>
          </div>
          <div className="features-grid">
            {features.map(f => (
              <div key={f.title} className="feat-card">
                <div className="feat-icon">{f.ico}</div>
                <div className="feat-title">{f.title}</div>
                <div className="feat-desc">{f.desc}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* DOWNLOAD */}
      <section id="download" style={{ padding: 'clamp(64px,8vw,96px) clamp(16px,2.5vw,24px)', background: 'var(--secondary)' }}>
        <div className="download-inner">
          <div style={{ textAlign: 'center', marginBottom: '28px' }}>
            <div className="section-tag" style={{ display: 'inline-flex' }}><span>Get the App</span></div>
          </div>
          <div className="dl-card">

            <h2>Start your driving journey today</h2>
            <p>Download Drive Tutor on iOS or Android and book your first lesson in minutes.</p>
            <div className="dl-btns">
              <a href="#" className="dl-btn dl-btn-white">
                <div style={{ width: 40, height: 40, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                  <img src="/store-badges/appstore.png" alt="App Store" style={{ maxWidth: '100%', maxHeight: '100%', objectFit: 'contain', display: 'block' }} />
                </div>
                <div style={{ textAlign: 'center' }}>
                  <div className="store-label-sm">Coming Soon</div>
                  <div style={{ fontWeight: 700, fontSize: 15, lineHeight: 1.2, marginTop: 2 }}>App Store</div>
                </div>
              </a>
              <a href="#" className="dl-btn dl-btn-border">
                <div style={{ width: 40, height: 40, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                  <img src="/store-badges/playstore.png" alt="Google Play" style={{ maxWidth: '100%', maxHeight: '100%', objectFit: 'contain', display: 'block' }} />
                </div>
                <div style={{ textAlign: 'center' }}>
                  <div className="store-label-sm">Coming Soon</div>
                  <div style={{ fontWeight: 700, fontSize: 15, lineHeight: 1.2, marginTop: 2 }}>Google Play</div>
                </div>
              </a>
            </div>
            <p className="dl-note">Free to download · iOS &amp; Android · Ontario, Canada</p>
          </div>
        </div>
      </section>

      {/* LEGAL */}
      <section id="legal" style={{ padding: 'clamp(64px,8vw,96px) clamp(16px,2.5vw,24px)', background: 'var(--bg)' }}>
        <div className="legal-inner">
          <div className="legal-head">
            <div className="section-tag" style={{ margin: '0 auto 16px' }}><span>Legal & Compliance</span></div>
            <h2>Transparency &amp; Trust</h2>
            <p>All our policies are public, accessible, and written in plain language.</p>
          </div>
          <div className="legal-grid">
            {legalCards.map(c => (
              <Link key={c.href} href={c.href} className="legal-card">
                <div className="legal-icon-box">{c.ico}</div>
                <div style={{ flex: 1 }}>
                  <div className="legal-card-title">{c.title}</div>
                  <div className="legal-card-desc">{c.desc}</div>
                </div>
                <span className="legal-arrow">→</span>
              </Link>
            ))}
          </div>
        </div>
      </section>

      <Footer />
    </>
  )
}
