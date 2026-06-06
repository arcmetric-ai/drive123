import Link from 'next/link'
import Nav from './Nav'
import Footer from './Footer'

interface TocItem { id: string; label: string }
interface Props {
  badge: string
  title: string
  updated: string
  toc: TocItem[]
  children: React.ReactNode
  prevPage?: { label: string; href: string }
  nextPage?: { label: string; href: string }
}

export default function PolicyLayout({ badge, title, updated, toc, children, prevPage, nextPage }: Props) {
  return (
    <>
      <Nav />
      <main className="policy-page">
        <div className="policy-inner">
          <div className="policy-breadcrumb">
            <Link href="/">Home</Link>
            <span className="sep">/</span>
            <span style={{color:'var(--fg)',fontWeight:600}}>{title}</span>
          </div>
          <div className="policy-header">
            <div className="policy-badge">{badge}</div>
            <h1 className="policy-title">{title}</h1>
            <div className="policy-meta">
              <span className="policy-date"><strong>Last Updated:</strong> {updated}</span>
              <span className="policy-date"><strong>Effective:</strong> {updated}</span>
            </div>
          </div>
          {toc.length > 0 && (
            <div className="policy-toc">
              <div className="policy-toc-title">Table of Contents</div>
              <ol className="policy-toc-list">
                {toc.map(item => (
                  <li key={item.id}><a href={`#${item.id}`}>{item.label}</a></li>
                ))}
              </ol>
            </div>
          )}
          <div className="policy-body">{children}</div>
          <div className="policy-contact-box">
            <h3>Questions about this policy?</h3>
            <p>Email us at <a href="mailto:info@drivetutor.ca">info@drivetutor.ca</a></p>
          </div>
          <div className="policy-nav-row">
            {prevPage ? <Link href={prevPage.href} className="policy-nav-btn">← {prevPage.label}</Link> : <span />}
            <Link href="/" className="policy-nav-btn primary">Back to Home →</Link>
            {nextPage && <Link href={nextPage.href} className="policy-nav-btn">{nextPage.label} →</Link>}
          </div>
        </div>
      </main>
      <Footer />
    </>
  )
}
