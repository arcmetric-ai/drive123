import PolicyLayout from '@/components/PolicyLayout'
import type { Metadata } from 'next'
export const metadata: Metadata = { title: 'Privacy Policy — Drive Tutor' }
export default function PrivacyPolicy() {
  return (
    <PolicyLayout badge="🔐 Legal Document" title="Privacy Policy" updated="January 1, 2025"
      toc={[{id:'pp-1',label:'Information We Collect'},{id:'pp-2',label:'How We Use Your Information'},{id:'pp-3',label:'Information Sharing & Disclosure'},{id:'pp-4',label:'Data Storage & Security'},{id:'pp-5',label:"Your Rights & Choices"},{id:'pp-6',label:"Children's Privacy"},{id:'pp-7',label:'Changes to This Policy'},{id:'pp-8',label:'Contact Us'}]}
      nextPage={{label:'Terms & Conditions',href:'/terms-and-conditions'}}>
      <div className="policy-highlight">Drive Tutor Inc. ("Drive Tutor", "we", "us", or "our") is committed to protecting your privacy. This Privacy Policy describes how we collect, use, share, and protect your personal information when you use our mobile application and related services.</div>
      <section id="pp-1"><h2>1. Information We Collect</h2>
        <h3>Information You Provide</h3>
        <ul><li><strong>Account information:</strong> name, email address, phone number, date of birth</li><li><strong>Profile information:</strong> profile photo, driving licence details (for instructors)</li><li><strong>Payment information:</strong> processed securely through our payment provider</li><li><strong>Booking data:</strong> lesson dates, times, locations, and notes</li><li><strong>Communications:</strong> messages sent through the in-app messaging system</li><li><strong>Documents:</strong> driving credentials uploaded by instructors for verification</li></ul>
        <h3>Information Collected Automatically</h3>
        <ul><li><strong>Device information:</strong> device type, operating system, unique device identifiers</li><li><strong>Usage data:</strong> features used, time spent in the app, pages visited</li><li><strong>Location data:</strong> approximate location when you grant permission (to find nearby instructors)</li><li><strong>Log data:</strong> IP address, app crash reports, system activity</li></ul>
      </section>
      <section id="pp-2"><h2>2. How We Use Your Information</h2>
        <ul><li>To create and manage your Drive Tutor account</li><li>To facilitate bookings between learners and instructors</li><li>To process payments and send receipts</li><li>To verify instructor credentials and maintain platform safety</li><li>To send booking confirmations, reminders, and service notifications</li><li>To improve and develop our platform features</li><li>To comply with legal obligations under Ontario and Canadian law</li><li>To respond to support enquiries</li></ul>
        <div className="policy-highlight">We do not sell your personal data to third parties. We do not use your data for advertising without your explicit consent.</div>
      </section>
      <section id="pp-3"><h2>3. Information Sharing & Disclosure</h2>
        <ul><li><strong>Between users:</strong> Learner and instructor profile information is shared as necessary to facilitate bookings.</li><li><strong>Service providers:</strong> We share data with trusted third parties who help us operate our platform, including payment processors, cloud hosting, and analytics services. These parties are contractually bound to protect your data.</li><li><strong>Legal compliance:</strong> We may disclose information if required by law or valid legal process.</li><li><strong>Business transfers:</strong> In the event of a merger or acquisition, user data may be transferred as part of that transaction.</li></ul>
      </section>
      <section id="pp-4"><h2>4. Data Storage & Security</h2>
        <p>Your data is stored on secure cloud infrastructure with industry-standard encryption in transit (TLS) and at rest. Access to personal data is restricted to authorised personnel only. We conduct regular security assessments of our systems.</p>
        <p>We retain your personal information for as long as your account is active. When you delete your account, we delete or anonymise your personal data within 30 days, except where legally required to retain it longer.</p>
      </section>
      <section id="pp-5"><h2>5. Your Rights & Choices</h2>
        <p>Under PIPEDA and applicable Ontario privacy law, you have the right to:</p>
        <ul><li>Access the personal information we hold about you</li><li>Request correction of inaccurate information</li><li>Request deletion of your personal information</li><li>Withdraw consent to data processing at any time</li><li>Lodge a complaint with the Office of the Privacy Commissioner of Canada</li></ul>
        <p>To exercise any of these rights, contact us at <a href="mailto:info@drivetutor.ca">info@drivetutor.ca</a>.</p>
      </section>
      <section id="pp-6"><h2>6. Children&apos;s Privacy</h2><p>Drive Tutor is not directed at individuals under the age of 16. We do not knowingly collect personal information from children under 16. If you believe we have inadvertently collected such information, please contact us immediately.</p></section>
      <section id="pp-7"><h2>7. Changes to This Policy</h2><p>We may update this Privacy Policy from time to time. We will notify you of material changes via email or in-app notification. Your continued use of Drive Tutor after changes take effect constitutes your acceptance of the revised policy.</p></section>
      <section id="pp-8"><h2>8. Contact Us</h2><p>Questions about this Privacy Policy? Contact us at <a href="mailto:info@drivetutor.ca">info@drivetutor.ca</a> or <a href="mailto:info@drivetutor.ca">info@drivetutor.ca</a>.</p></section>
    </PolicyLayout>
  )
}
