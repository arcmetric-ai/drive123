# Instructor Billing Implementation

## Products

| Plan | Stripe mode | Price | Access window |
| --- | --- | ---: | --- |
| Monthly Subscription | subscription | $360.00 | 30 days |
| Annual Subscription | subscription | $3,600.00 | 365 days |

The annual option is positioned as the same instructor subscription paid annually, with two months free compared with paying monthly for 12 months.

The database seeds these plan keys:

- `monthly_pass`
- `yearly_pass`

## Supabase Secrets

Set these secrets before deploying the Edge Functions:

```sh
supabase secrets set STRIPE_SECRET_KEY=sk_live_...
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_...
supabase secrets set STRIPE_PRICE_MONTHLY_PASS=price_...
supabase secrets set STRIPE_PRICE_YEARLY_PASS=price_...
supabase secrets set STRIPE_CHECKOUT_SUCCESS_URL=https://www.drivetutor.ca/auth-redirect
supabase secrets set STRIPE_CHECKOUT_CANCEL_URL=https://www.drivetutor.ca/auth-redirect
```

Use test-mode keys and test-mode Price IDs first. Switch to live keys only after a complete paid checkout and webhook test.

## Stripe Webhook

Deploy `stripe-webhook` and configure Stripe to send these events:

- `checkout.session.completed`
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `invoice.payment_failed`

Webhook URL format:

```text
https://<project-ref>.functions.supabase.co/stripe-webhook
```

## Access Control

Instructor access is blocked in two places:

- Flutter route resolution sends approved instructors without active billing to `/instructor-billing`.
- Supabase RLS adds a restrictive billing gate on instructor operational tables so a modified client cannot bypass the app screen and directly use instructor data endpoints.

Billing entitlement writes are service-role only. The client can read its own entitlement and active plan rows, but cannot create or modify entitlement records.

## Pending Product Decisions

- Confirm the exact Stripe Price IDs for monthly and annual recurring subscriptions.
- Confirm whether monthly and annual options have identical features or differentiated feature codes beyond `instructor_access`.
- Confirm cancellation/refund terms for App Store and Play Store metadata.
