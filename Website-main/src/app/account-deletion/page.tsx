import PolicyLayout from '@/components/PolicyLayout'
import type { Metadata } from 'next'
export const metadata: Metadata = { title: 'Account Deletion — Drive Tutor' }
export default function AccountDeletion() {
  return (
    <PolicyLayout badge="🗑️ Account" title="Account Deletion Policy" updated="January 1, 2025"
      toc={[{id:'ad-1',label:'How to Delete Your Account'},{id:'ad-2',label:'What Happens After Deletion'},{id:'ad-3',label:'Data Retained After Deletion'},{id:'ad-4',label:'Reactivation'}]}
      prevPage={{label:'Safety Policy',href:'/safety-policy'}}>
      <div className="policy-highlight">Account deletion is permanent. Once completed, your data cannot be recovered. Please read this policy carefully before submitting a deletion request.</div>
      <section id="ad-1">
        <h2>1. How to Delete Your Account</h2>
        <p>You can request account deletion at any time through one of these methods:</p>
        <div style={{marginTop:16}}>
          {[
            {n:1,t:'In-App Request',d:'Go to Settings → Account → Delete Account within the Drive Tutor app.'},
            {n:2,t:'Email Request',d:'Send an email to info@drivetutor.ca with the subject line "Account Deletion Request" and your registered email address.'},
            {n:3,t:'Confirmation',d:'We will confirm your request within 2 business days and begin the deletion process.'},
          ].map(s=>(
            <div key={s.n} style={{display:'flex',gap:20,padding:'22px',background:'var(--secondary)',borderRadius:'var(--r)',marginBottom:4}}>
              <div style={{width:36,height:36,borderRadius:'50%',background:'var(--primary)',color:'#fff',fontWeight:800,display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>{s.n}</div>
              <div><div style={{fontSize:14,fontWeight:700,color:'var(--fg)',marginBottom:4}}>{s.t}</div><div style={{fontSize:13,color:'var(--muted)',lineHeight:1.65}}>{s.d}</div></div>
            </div>
          ))}
        </div>
      </section>
      <section id="ad-2">
        <h2>2. What Happens After Deletion</h2>
        <div className="deletion-warning"><span style={{fontSize:20}}>⚠️</span><p><strong>This action is permanent.</strong> Once your account is deleted, all your profile data, lesson history, and messages will be permanently removed and cannot be recovered. Any upcoming lessons will be cancelled and refunded in accordance with our Refund Policy.</p></div>
        <ul><li>Your profile will be immediately deactivated and hidden from other users</li><li>All personal data (name, email, phone, profile photo) will be deleted within 30 days</li><li>Your booking history will be anonymised</li><li>Any pending or upcoming lessons will be cancelled and refunded where applicable</li></ul>
      </section>
      <section id="ad-3">
        <h2>3. Data Retained After Deletion</h2>
        <p>Some information may be retained after deletion for legal and compliance purposes:</p>
        <ul><li>Financial records (booking transactions) for up to 7 years as required by Canadian tax law</li><li>Safety incident records, if any exist, as required by law</li><li>Anonymised, aggregated usage data that cannot be linked back to you</li></ul>
        <div className="policy-highlight">We only retain the minimum data required by law. All retained data is anonymised wherever possible.</div>
      </section>
      <section id="ad-4">
        <h2>4. Reactivation</h2>
        <p>Once your account deletion is complete, it cannot be undone. If you wish to use Drive Tutor again in the future, you will need to create a new account. Historical booking data will not be transferable to a new account.</p>
      </section>
    </PolicyLayout>
  )
}
