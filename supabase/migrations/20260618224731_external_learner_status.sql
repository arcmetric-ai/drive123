alter table public.external_learners
  add column if not exists status text not null default 'active';

update public.external_learners
set status = 'active'
where status is null;

create index if not exists external_learners_instructor_status_idx
  on public.external_learners(instructor_id, status, created_at desc);
