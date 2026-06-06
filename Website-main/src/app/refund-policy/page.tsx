import PolicyLayout from '@/components/PolicyLayout'
import type { Metadata } from 'next'
export const metadata: Metadata = { title: 'Refund & Cancellation Policy — Drive Tutor' }
export default function Page() {
  return (
    <PolicyLayout badge="💳 Legal Document" title="Refund & Cancellation Policy" updated="January 1, 2025" toc={[]}>
      <div className="policy-highlight">This policy is effective as of January 1, 2025. For questions, contact us at info@drivetutor.ca.</div>
      <section>
        <h2>Overview</h2>
        <p>This page contains Drive Tutor&apos;s Refund & Cancellation Policy. Full policy content will be added here. Contact us at <a href="mailto:info@drivetutor.ca">info@drivetutor.ca</a> with any questions.</p>
      </section>
    </PolicyLayout>
  )
}
