import PolicyLayout from '@/components/PolicyLayout'
import type { Metadata } from 'next'
export const metadata: Metadata = { title: 'Terms & Conditions — Drive Tutor' }
export default function Terms() {
  return (
    <PolicyLayout badge="📜 Legal Document" title="Terms & Conditions" updated="January 1, 2025"
      toc={[{id:'tc-1',label:'Acceptance of Terms'},{id:'tc-2',label:'Description of Service'},{id:'tc-3',label:'User Accounts'},{id:'tc-4',label:'Instructor Terms'},{id:'tc-5',label:'Learner Terms'},{id:'tc-6',label:'Payments & Fees'},{id:'tc-7',label:'Prohibited Conduct'},{id:'tc-8',label:'Limitation of Liability'},{id:'tc-9',label:'Governing Law'},{id:'tc-10',label:'Changes to Terms'}]}
      prevPage={{label:'Privacy Policy',href:'/privacy-policy'}}
      nextPage={{label:'Data Consent',href:'/data-consent-policy'}}>
      <div className="policy-highlight">By downloading, installing, or using Drive Tutor, you agree to be bound by these Terms and Conditions. Please read them carefully.</div>
      <section id="tc-1"><h2>1. Acceptance of Terms</h2><p>These Terms constitute a legally binding agreement between you and Drive Tutor Inc. If you do not agree to these terms, please do not use our services.</p></section>
      <section id="tc-2"><h2>2. Description of Service</h2><p>Drive Tutor is a platform that connects learner drivers with professional driving instructors in Ontario, Canada. Drive Tutor acts as an intermediary marketplace and is not itself a driving instruction service.</p></section>
      <section id="tc-3"><h2>3. User Accounts</h2><ul><li>You must be at least 16 years old to create an account</li><li>You are responsible for maintaining the confidentiality of your account credentials</li><li>You must provide accurate and complete information when registering</li><li>You are responsible for all activity that occurs under your account</li><li>Drive Tutor reserves the right to suspend or terminate accounts that violate these terms</li></ul></section>
      <section id="tc-4"><h2>4. Instructor Terms</h2><p>Instructors using Drive Tutor agree to:</p><ul><li>Hold a valid Ontario driving instructor licence and all required certifications</li><li>Undergo and pass our background check process before accepting bookings</li><li>Maintain accurate availability information on the platform</li><li>Honour all confirmed bookings unless there is an emergency</li><li>Treat all learners professionally and respectfully at all times</li></ul></section>
      <section id="tc-5"><h2>5. Learner Terms</h2><ul><li>You must hold at least a valid Ontario G1 licence to book lessons</li><li>You must arrive on time for booked lessons</li><li>You must treat instructors professionally and respectfully</li><li>You must provide accurate information about your driving experience and licence status</li></ul></section>
      <section id="tc-6"><h2>6. Payments & Fees</h2><p>Lesson fees are set by individual instructors and displayed on their profiles. Drive Tutor may charge a platform service fee on transactions. All payments are processed securely through our payment provider. By booking a lesson, you authorise the associated charge to your payment method.</p></section>
      <section id="tc-7"><h2>7. Prohibited Conduct</h2><p>You agree not to:</p><ul><li>Use the platform for any unlawful purpose</li><li>Provide false or misleading information</li><li>Harass, abuse, or threaten other users</li><li>Circumvent platform fees by arranging payments off-platform</li><li>Attempt to reverse-engineer or interfere with platform functionality</li><li>Create fake reviews or manipulate ratings</li></ul></section>
      <section id="tc-8"><h2>8. Limitation of Liability</h2><p>To the maximum extent permitted by law, Drive Tutor shall not be liable for any indirect, incidental, special, or consequential damages arising from your use of the platform. Drive Tutor is a marketplace platform and is not responsible for the conduct of instructors or learners.</p></section>
      <section id="tc-9"><h2>9. Governing Law</h2><p>These Terms are governed by the laws of the Province of Ontario and the federal laws of Canada applicable therein. Any disputes shall be resolved in the courts of Ontario.</p></section>
      <section id="tc-10"><h2>10. Changes to Terms</h2><p>We may update these Terms from time to time. We will notify you of material changes via email or in-app notification. Your continued use of Drive Tutor after changes take effect constitutes your acceptance of the revised Terms.</p></section>
    </PolicyLayout>
  )
}
