update public.instructor_billing_plans
set
  amount_cents = case plan_key
    when 'monthly_pass' then 36000
    when 'yearly_pass' then 360000
    else amount_cents
  end,
  display_name = case plan_key
    when 'monthly_pass' then 'Monthly Subscription'
    when 'yearly_pass' then 'Annual Subscription'
    else display_name
  end,
  description = case plan_key
    when 'monthly_pass' then 'Recurring monthly instructor access.'
    when 'yearly_pass' then 'Recurring annual instructor access with two months free.'
    else description
  end,
  updated_at = now()
where plan_key in ('monthly_pass', 'yearly_pass');

update public.instructor_billing_plans
set
  is_active = false,
  updated_at = now()
where plan_key = 'day_pass';
