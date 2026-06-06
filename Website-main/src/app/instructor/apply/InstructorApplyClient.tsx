'use client'

import { useEffect, useState } from 'react'
import type { FormEvent } from 'react'
import type { Session } from '@supabase/supabase-js'
import { isSupabaseConfigured, supabase } from '@/lib/supabase'

const AGREEMENT_VERSION = '2026-06-05'

type FileKey =
  | 'identityLicense'
  | 'identitySelfie'
  | 'instructorLicense'
  | 'insurance'
  | 'backgroundCheck'
  | 'municipalLicense'

type ApplicationFiles = Record<FileKey, File | null>

const emptyFiles: ApplicationFiles = {
  identityLicense: null,
  identitySelfie: null,
  instructorLicense: null,
  insurance: null,
  backgroundCheck: null,
  municipalLicense: null,
}

function clean(value: string) {
  return value.trim()
}

function extensionFor(file: File) {
  const fallback = file.type.includes('pdf') ? 'pdf' : 'jpg'
  return file.name.split('.').pop()?.toLowerCase() || fallback
}

export default function InstructorApplyClient() {
  const [session, setSession] = useState<Session | null>(null)
  const [authMode, setAuthMode] = useState<'signin' | 'signup'>('signup')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [authLoading, setAuthLoading] = useState(true)
  const [submitting, setSubmitting] = useState(false)
  const [message, setMessage] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  const [firstName, setFirstName] = useState('')
  const [lastName, setLastName] = useState('')
  const [phone, setPhone] = useState('')
  const [years, setYears] = useState('')
  const [bio, setBio] = useState('')
  const [files, setFiles] = useState<ApplicationFiles>(emptyFiles)
  const [accepted, setAccepted] = useState({
    terms: false,
    privacy: false,
    dataConsent: false,
    verification: false,
  })

  useEffect(() => {
    let mounted = true
    supabase.auth.getSession().then(({ data }) => {
      if (!mounted) return
      setSession(data.session)
      setAuthLoading(false)
    })
    const { data: listener } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession)
      setAuthLoading(false)
    })
    return () => {
      mounted = false
      listener.subscription.unsubscribe()
    }
  }, [])

  const handleAuth = async (event: FormEvent) => {
    event.preventDefault()
    setError(null)
    setMessage(null)
    setAuthLoading(true)
    try {
      if (authMode === 'signup') {
        const { data, error: signUpError } = await supabase.auth.signUp({
          email: clean(email),
          password,
          options: {
            data: { role: 'instructor' },
            emailRedirectTo: 'https://www.drivetutor.ca/auth-redirect',
          },
        })
        if (signUpError) throw signUpError
        if (!data.session) {
          setMessage('Check your email to confirm your account, then return here to finish the application.')
        }
      } else {
        const { error: signInError } = await supabase.auth.signInWithPassword({
          email: clean(email),
          password,
        })
        if (signInError) throw signInError
      }
    } catch (authError) {
      setError(authError instanceof Error ? authError.message : 'Unable to continue.')
    } finally {
      setAuthLoading(false)
    }
  }

  const setFile = (key: FileKey, value: File | null) => {
    setFiles(current => ({ ...current, [key]: value }))
  }

  const uploadFile = async (bucket: string, userId: string, prefix: string, file: File) => {
    const path = `${userId}/${prefix}-${Date.now()}.${extensionFor(file)}`
    const { error: uploadError } = await supabase.storage.from(bucket).upload(path, file, {
      upsert: true,
      contentType: file.type || undefined,
    })
    if (uploadError) throw uploadError
    return path
  }

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault()
    const user = session?.user
    if (!user) {
      setError('Sign in before submitting your application.')
      return
    }
    if (!accepted.terms || !accepted.privacy || !accepted.dataConsent || !accepted.verification) {
      setError('Accept all required terms and consent statements before submitting.')
      return
    }
    const requiredFiles: FileKey[] = [
      'identityLicense',
      'identitySelfie',
      'instructorLicense',
      'insurance',
      'backgroundCheck',
    ]
    if (requiredFiles.some(key => files[key] == null)) {
      setError('Upload all required identity and instructor credential documents.')
      return
    }

    setSubmitting(true)
    setError(null)
    setMessage(null)
    try {
      const now = new Date().toISOString()
      const identityLicensePath = await uploadFile('identity-verification', user.id, 'license', files.identityLicense!)
      const identitySelfiePath = await uploadFile('identity-verification', user.id, 'selfie', files.identitySelfie!)
      const instructorLicensePath = await uploadFile('instructor-credentials', user.id, 'instructor_license', files.instructorLicense!)
      const insurancePath = await uploadFile('instructor-credentials', user.id, 'insurance_document', files.insurance!)
      const backgroundPath = await uploadFile('instructor-credentials', user.id, 'background_check', files.backgroundCheck!)
      const municipalPath = files.municipalLicense
        ? await uploadFile('instructor-credentials', user.id, 'municipal_license', files.municipalLicense)
        : null

      const { error: profileError } = await supabase.from('profiles').upsert({
        id: user.id,
        email: user.email,
        role: 'instructor',
        first_name: clean(firstName),
        last_name: clean(lastName),
        phone: clean(phone) || null,
        verification_status: 'pending',
        verification_submitted_at: now,
        verification_review_started_at: null,
        verification_approved_at: null,
        identity_license_path: identityLicensePath,
        identity_selfie_path: identitySelfiePath,
        onboarding_stage: 'verification_pending',
        is_verified: false,
      }, { onConflict: 'id' })
      if (profileError) throw profileError

      const parsedYears = Number.parseInt(years, 10)
      const { error: instructorError } = await supabase.from('instructor_profiles').upsert({
        profile_id: user.id,
        bio: clean(bio) || null,
        years_of_experience: Number.isFinite(parsedYears) ? parsedYears : null,
        instructor_license_path: instructorLicensePath,
        insurance_document_path: insurancePath,
        background_check_path: backgroundPath,
        municipal_license_path: municipalPath,
        credentials_status: 'pending',
        credentials_submitted_at: now,
        credentials_review_started_at: null,
        credentials_approved_at: null,
      }, { onConflict: 'profile_id' })
      if (instructorError) throw instructorError

      const agreements = [
        'terms-and-conditions',
        'privacy-policy',
        'data-consent-policy',
        'instructor-verification-consent',
      ].map(agreementKey => ({
        profile_id: user.id,
        agreement_key: agreementKey,
        agreement_version: AGREEMENT_VERSION,
        metadata: { source: 'website_instructor_application' },
      }))
      const { error: agreementError } = await supabase.from('user_agreements').insert(agreements)
      if (agreementError) throw agreementError

      setMessage('Application submitted. Drive Tutor will review your identity and instructor credentials before activation.')
    } catch (submitError) {
      setError(submitError instanceof Error ? submitError.message : 'Unable to submit application.')
    } finally {
      setSubmitting(false)
    }
  }

  if (!isSupabaseConfigured) {
    return <div className="policy-highlight">Website Supabase environment variables are not configured yet.</div>
  }

  return (
    <div style={{ display: 'grid', gap: 24 }}>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 16 }}>
        {[
          { step: '1', title: 'Create or sign in', desc: 'Use the same account you will use in the mobile app.' },
          { step: '2', title: 'Submit credentials', desc: 'Upload identity and instructor credential documents.' },
          { step: '3', title: 'Wait for review', desc: 'Drive Tutor reviews your application before learner access.' },
          { step: '4', title: 'Use the app after approval', desc: 'After approval and activation, sign into the mobile app to manage learners and lessons.' },
        ].map(item => (
          <div key={item.step} className="contact-card">
            <div className="contact-card-icon">{item.step}</div>
            <h3>{item.title}</h3>
            <p>{item.desc}</p>
          </div>
        ))}
      </div>

      {!session && (
        <div className="contact-card">
          <h3>{authMode === 'signup' ? 'Create instructor account' : 'Sign in to continue'}</h3>
          <form onSubmit={handleAuth} style={{ display: 'grid', gap: 14, marginTop: 16 }}>
            <input className="form-input" type="email" autoComplete="email" placeholder="Email address" value={email} onChange={event => setEmail(event.target.value)} required />
            <input className="form-input" type="password" autoComplete={authMode === 'signup' ? 'new-password' : 'current-password'} placeholder="Password" value={password} onChange={event => setPassword(event.target.value)} minLength={8} required />
            <button className="policy-nav-btn primary" type="submit" disabled={authLoading}>
              {authLoading ? 'Please wait...' : authMode === 'signup' ? 'Create Account' : 'Sign In'}
            </button>
          </form>
          <button type="button" className="nav-link" style={{ marginTop: 12 }} onClick={() => setAuthMode(authMode === 'signup' ? 'signin' : 'signup')}>
            {authMode === 'signup' ? 'Already have an account? Sign in' : 'Need an account? Create one'}
          </button>
        </div>
      )}

      {session && (
        <form onSubmit={handleSubmit} className="contact-card" style={{ display: 'grid', gap: 16 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, flexWrap: 'wrap' }}>
            <div>
              <h3>Instructor application</h3>
              <p>Signed in as {session.user.email}</p>
            </div>
            <button type="button" className="policy-nav-btn" onClick={() => supabase.auth.signOut()}>Sign Out</button>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 12 }}>
            <input className="form-input" autoComplete="given-name" placeholder="First name" value={firstName} onChange={event => setFirstName(event.target.value)} required />
            <input className="form-input" autoComplete="family-name" placeholder="Last name" value={lastName} onChange={event => setLastName(event.target.value)} required />
            <input className="form-input" autoComplete="tel" inputMode="tel" placeholder="Phone number" value={phone} onChange={event => setPhone(event.target.value)} required />
            <input className="form-input" type="number" min="0" placeholder="Years of experience" value={years} onChange={event => setYears(event.target.value)} />
          </div>
          <textarea className="form-input" rows={4} placeholder="Brief instructor bio and service area" value={bio} onChange={event => setBio(event.target.value)} />

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: 12 }}>
            <FileField label="Government ID or licence photo" required capture="environment" onChange={file => setFile('identityLicense', file)} />
            <FileField label="Selfie for verification" required capture="user" onChange={file => setFile('identitySelfie', file)} />
            <FileField label="Instructor licence" required capture="environment" onChange={file => setFile('instructorLicense', file)} />
            <FileField label="Insurance document" required onChange={file => setFile('insurance', file)} />
            <FileField label="Background check" required onChange={file => setFile('backgroundCheck', file)} />
            <FileField label="Municipal licence, if applicable" capture="environment" onChange={file => setFile('municipalLicense', file)} />
          </div>

          <ConsentBox label="I agree to the Drive Tutor Terms and Conditions." checked={accepted.terms} onChange={value => setAccepted(current => ({ ...current, terms: value }))} />
          <ConsentBox label="I have read and agree to the Privacy Policy." checked={accepted.privacy} onChange={value => setAccepted(current => ({ ...current, privacy: value }))} />
          <ConsentBox label="I consent to Drive Tutor processing my documents for verification." checked={accepted.dataConsent} onChange={value => setAccepted(current => ({ ...current, dataConsent: value }))} />
          <ConsentBox label="I confirm the information and documents I submit are accurate." checked={accepted.verification} onChange={value => setAccepted(current => ({ ...current, verification: value }))} />

          <button className="policy-nav-btn primary" type="submit" disabled={submitting}>
            {submitting ? 'Submitting...' : 'Submit Application'}
          </button>
        </form>
      )}

      {message && <div className="policy-highlight">{message}</div>}
      {error && <div className="policy-highlight" style={{ borderColor: '#DC2626', color: '#991B1B' }}>{error}</div>}
    </div>
  )
}

function FileField({
  label,
  required,
  capture,
  onChange,
}: {
  label: string
  required?: boolean
  capture?: 'user' | 'environment'
  onChange: (file: File | null) => void
}) {
  return (
    <label style={{ display: 'grid', gap: 6, fontSize: 13, fontWeight: 700, color: 'var(--fg)' }}>
      {label}{required ? ' *' : ''}
      <input className="form-input" type="file" accept="image/*,.pdf" capture={capture} required={required} onChange={event => onChange(event.target.files?.[0] ?? null)} />
      <span style={{ color: 'var(--muted)', fontSize: 12, fontWeight: 500, lineHeight: 1.45 }}>
        On mobile, use the camera or choose an existing file.
      </span>
    </label>
  )
}

function ConsentBox({ label, checked, onChange }: { label: string; checked: boolean; onChange: (value: boolean) => void }) {
  return (
    <label style={{ display: 'flex', gap: 10, alignItems: 'flex-start', color: 'var(--fg)', fontSize: 14, lineHeight: 1.5 }}>
      <input type="checkbox" checked={checked} onChange={event => onChange(event.target.checked)} style={{ marginTop: 4 }} />
      <span>{label}</span>
    </label>
  )
}
