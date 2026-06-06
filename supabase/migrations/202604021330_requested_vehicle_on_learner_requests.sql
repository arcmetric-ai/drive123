alter table public.learner_requests
add column if not exists requested_vehicle_label text;

alter table public.learner_requests
add column if not exists requested_vehicle_type text;
