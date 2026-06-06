import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Email Confirmation - Drive Tutor',
}

export default function AuthRedirect() {
  return (
    <main
      style={{
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        minHeight: '100vh',
        textAlign: 'center',
        fontFamily: 'Arial, sans-serif',
        padding: 24,
      }}
    >
      <div>
        <h1>Email Confirmation Successful</h1>
        <p>You can now return to Drive Tutor and continue your account setup.</p>
      </div>
    </main>
  )
}
