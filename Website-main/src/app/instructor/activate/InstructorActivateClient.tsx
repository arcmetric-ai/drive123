'use client'

import { useEffect, useState } from 'react'
import type { FormEvent } from 'react'
import type { Session } from '@supabase/supabase-js'
import { isSupabaseConfigured, supabase } from '@/lib/supabase'

type BillingPlan = {
  plan_key: string
  display_name: string
  description: string | null
  amount_cents: number
  currency: string
  billing_interval: 'day' | 'month' | 'year'
  access_days: number
}

type Entitlement = {
  plan_key: string
  status: string
  access_expires_at: string
}

function priceLabel(plan: BillingPlan) {
  const amount = plan.amount_cents / 100
  const currency = plan.currency.toUpperCase() === 'CAD' ? 'CAD' : plan.currency.toUpperCase()
  return `$${amount.toLocaleString('en-CA', { maximumFractionDigits: 2 })} ${currency}`
}

function dailyRate(plan: BillingPlan) {
  const amount = plan.amount_cents / plan.access_days / 100
  return `$${amount.toLocaleString('en-CA', { maximumFractionDigits: 2 })}/day`
}

function isActive(entitlement: Entitlement | null) {
  if (!entitlement) return false
  return ['active', 'trialing'].includes(entitlement.status) && new Date(entitlement.access_expires_at).getTime() > Date.now()
}

export default function InstructorActivateClient() {
  const [session, setSession] = useState<Session | null>(null)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [plans, setPlans] = useState<BillingPlan[]>([])
  const [entitlement, setEntitlement] = useState<Entitlement | null>(null)
  const [loading, setLoading] = useState(true)
  const [checkoutPlan, setCheckoutPlan] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let mounted = true
    supabase.auth.getSession().then(({ data }) => {
      if (!mounted) return
      setSession(data.session)
      setLoading(false)
    })
    const { data: listener } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession)
      setLoading(false)
    })
    return () => {
      mounted = false
      listener.subscription.unsubscribe()
    }
  }, [])

  useEffect(() => {
    if (!session) return
    refreshBilling()
  }, [session])

  const refreshBilling = async () => {
    setError(null)
    const { data: planRows, error: plansError } = await supabase
      .from('instructor_billing_plans')
      .select('plan_key, display_name, description, amount_cents, currency, billing_interval, access_days')
      .eq('is_active', true)
      .order('amount_cents')
    if (plansError) {
      setError(plansError.message)
      return
    }
    setPlans((planRows ?? []) as BillingPlan[])

    const userId = session?.user.id
    if (!userId) return
    const { data: entitlementRow, error: entitlementError } = await supabase
      .from('instructor_billing_entitlements')
      .select('plan_key, status, access_expires_at')
      .eq('profile_id', userId)
      .maybeSingle()
    if (entitlementError) {
      setError(entitlementError.message)
      return
    }
    setEntitlement((entitlementRow as Entitlement | null) ?? null)
  }

  const handleSignIn = async (event: FormEvent) => {
    event.preventDefault()
    setError(null)
    setLoading(true)
    const { error: signInError } = await supabase.auth.signInWithPassword({ email: email.trim(), password })
    if (signInError) setError(signInError.message)
    setLoading(false)
  }

  const startCheckout = async (planKey: string) => {
    setCheckoutPlan(planKey)
    setError(null)
    try {
      const { data, error: invokeError } = await supabase.functions.invoke('create-instructor-checkout-session', {
        body: { planKey },
      })
      if (invokeError) throw invokeError
      const checkoutUrl = (data as { url?: string } | null)?.url
      if (!checkoutUrl) throw new Error('Checkout did not return a URL.')
      window.location.href = checkoutUrl
    } catch (checkoutError) {
      setError(checkoutError instanceof Error ? checkoutError.message : 'Unable to start checkout.')
    } finally {
      setCheckoutPlan(null)
    }
  }

  if (!isSupabaseConfigured) {
    return <div className="policy-highlight">Website Supabase environment variables are not configured yet.</div>
  }

  if (loading) {
    return <div className="policy-highlight">Loading instructor activation...</div>
  }

  if (!session) {
    return (
      <div className="contact-card">
        <h3>Sign in to activate</h3>
        <p>Use the same instructor account you used for your Drive Tutor application.</p>
        <form onSubmit={handleSignIn} style={{ display: 'grid', gap: 14, marginTop: 16 }}>
          <input className="form-input" type="email" autoComplete="email" placeholder="Email address" value={email} onChange={event => setEmail(event.target.value)} required />
          <input className="form-input" type="password" autoComplete="current-password" placeholder="Password" value={password} onChange={event => setPassword(event.target.value)} required />
          <button className="policy-nav-btn primary" type="submit">Sign In</button>
        </form>
        {error && <div className="policy-highlight" style={{ marginTop: 16, borderColor: '#DC2626', color: '#991B1B' }}>{error}</div>}
      </div>
    )
  }

  return (
    <div style={{ display: 'grid', gap: 24 }}>
      <div className="contact-card">
        <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, flexWrap: 'wrap' }}>
          <div>
            <h3>Signed in as {session.user.email}</h3>
            <p>{isActive(entitlement) ? `Your pass is active until ${new Date(entitlement!.access_expires_at).toLocaleString()}.` : 'Choose a pass to activate or reactivate instructor access.'}</p>
          </div>
          <button type="button" className="policy-nav-btn" onClick={() => supabase.auth.signOut()}>Sign Out</button>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(230px, 1fr))', gap: 16 }}>
        {plans.map(plan => (
          <div key={plan.plan_key} className="contact-card">
            <h3>{plan.display_name}</h3>
            <p style={{ fontSize: 28, fontWeight: 900, color: 'var(--primary)', margin: '10px 0 4px' }}>{priceLabel(plan)}</p>
            <p style={{ fontWeight: 700, color: 'var(--fg)' }}>{dailyRate(plan)}</p>
            <p>{plan.description ?? `${plan.access_days} days of instructor access.`}</p>
            <button className="policy-nav-btn primary" type="button" disabled={checkoutPlan != null} onClick={() => startCheckout(plan.plan_key)} style={{ marginTop: 12 }}>
              {checkoutPlan === plan.plan_key ? 'Opening Stripe...' : 'Continue to Stripe'}
            </button>
          </div>
        ))}
      </div>

      <button className="policy-nav-btn" type="button" onClick={refreshBilling}>Refresh Payment Status</button>
      {error && <div className="policy-highlight" style={{ borderColor: '#DC2626', color: '#991B1B' }}>{error}</div>}
    </div>
  )
}
