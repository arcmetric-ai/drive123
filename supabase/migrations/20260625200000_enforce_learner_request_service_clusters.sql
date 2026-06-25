create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.drive_tutor_normalize_region_name(input text)
returns text
language sql
immutable
as $$
  select nullif(lower(regexp_replace(trim(coalesce(input, '')), '[[:space:]]+', ' ', 'g')), '');
$$;

create or replace function private.drive_tutor_cluster_for_region(input text)
returns text
language sql
immutable
as $$
  select case private.drive_tutor_normalize_region_name(input)
    when 'kwc' then 'kwc'
    when 'kitchener' then 'kwc'
    when 'waterloo' then 'kwc'
    when 'cambridge' then 'kwc'
    when 'guelph-orangeville' then 'guelph_orangeville'
    when 'guelph' then 'guelph_orangeville'
    when 'orangeville' then 'guelph_orangeville'
    when 'hamilton-burlington-brantford' then 'hamilton_burlington_brantford'
    when 'hamilton' then 'hamilton_burlington_brantford'
    when 'burlington' then 'hamilton_burlington_brantford'
    when 'brantford' then 'hamilton_burlington_brantford'
    when 'niagara region' then 'niagara_region'
    when 'st. catharines' then 'niagara_region'
    when 'st catharines' then 'niagara_region'
    when 'niagara falls' then 'niagara_region'
    when 'london-woodstock' then 'london_woodstock'
    when 'london' then 'london_woodstock'
    when 'woodstock' then 'london_woodstock'
    when 'windsor-chatham-sarnia' then 'windsor_chatham_sarnia'
    when 'windsor' then 'windsor_chatham_sarnia'
    when 'chatham' then 'windsor_chatham_sarnia'
    when 'sarnia' then 'windsor_chatham_sarnia'
    when 'barrie-innisfil' then 'barrie_innisfil'
    when 'barrie' then 'barrie_innisfil'
    when 'innisfil' then 'barrie_innisfil'
    when 'gta west' then 'gta_west'
    when 'mississauga' then 'gta_west'
    when 'brampton' then 'gta_west'
    when 'oakville' then 'gta_west'
    when 'gta central' then 'gta_central'
    when 'toronto' then 'gta_central'
    when 'etobicoke' then 'gta_central'
    when 'downsview' then 'gta_central'
    when 'port union' then 'gta_central'
    when 'gta east (durham region)' then 'gta_east_durham'
    when 'gta east' then 'gta_east_durham'
    when 'durham region' then 'gta_east_durham'
    when 'ajax' then 'gta_east_durham'
    when 'oshawa' then 'gta_east_durham'
    when 'newmarket region' then 'newmarket_region'
    when 'newmarket' then 'newmarket_region'
    when 'aurora' then 'newmarket_region'
    when 'richmond hill' then 'newmarket_region'
    when 'vaughan' then 'newmarket_region'
    when 'markham' then 'newmarket_region'
    when 'eastern ontario corridor' then 'eastern_ontario_corridor'
    when 'ottawa' then 'eastern_ontario_corridor'
    when 'kanata' then 'eastern_ontario_corridor'
    when 'kingston' then 'eastern_ontario_corridor'
    else null
  end;
$$;

create or replace function private.drive_tutor_neighbor_clusters(cluster_id text)
returns text[]
language sql
immutable
as $$
  select case cluster_id
    when 'kwc' then array['guelph_orangeville', 'hamilton_burlington_brantford', 'london_woodstock']
    when 'guelph_orangeville' then array['kwc', 'hamilton_burlington_brantford', 'gta_west', 'newmarket_region']
    when 'hamilton_burlington_brantford' then array['kwc', 'guelph_orangeville', 'london_woodstock', 'niagara_region', 'gta_west']
    when 'niagara_region' then array['hamilton_burlington_brantford']
    when 'london_woodstock' then array['kwc', 'hamilton_burlington_brantford', 'windsor_chatham_sarnia']
    when 'windsor_chatham_sarnia' then array['london_woodstock']
    when 'barrie_innisfil' then array['newmarket_region']
    when 'gta_west' then array['gta_central', 'hamilton_burlington_brantford', 'newmarket_region', 'guelph_orangeville']
    when 'gta_central' then array['gta_west', 'gta_east_durham', 'newmarket_region']
    when 'gta_east_durham' then array['gta_central', 'newmarket_region', 'eastern_ontario_corridor']
    when 'newmarket_region' then array['gta_central', 'gta_west', 'gta_east_durham', 'barrie_innisfil', 'guelph_orangeville']
    when 'eastern_ontario_corridor' then array['gta_east_durham']
    else array[]::text[]
  end;
$$;

create or replace function private.drive_tutor_clusters_are_requestable(
  learner_region text,
  instructor_region text
)
returns boolean
language sql
immutable
as $$
  select
    private.drive_tutor_cluster_for_region(learner_region) is not null
    and private.drive_tutor_cluster_for_region(instructor_region) is not null
    and (
      private.drive_tutor_cluster_for_region(instructor_region) =
        private.drive_tutor_cluster_for_region(learner_region)
      or private.drive_tutor_cluster_for_region(instructor_region) = any(
        private.drive_tutor_neighbor_clusters(
          private.drive_tutor_cluster_for_region(learner_region)
        )
      )
    );
$$;

create or replace function private.drive_tutor_extract_regions(value jsonb)
returns text[]
language plpgsql
immutable
as $$
declare
  item jsonb;
  regions text[] := array[]::text[];
  candidate text;
begin
  if value is null or value = 'null'::jsonb then
    return regions;
  end if;

  if jsonb_typeof(value) = 'array' then
    for item in select jsonb_array_elements(value)
    loop
      regions := regions || private.drive_tutor_extract_regions(item);
    end loop;
    return regions;
  end if;

  if jsonb_typeof(value) = 'string' then
    candidate := value #>> '{}';
    if private.drive_tutor_normalize_region_name(candidate) is not null then
      regions := array_append(regions, candidate);
    end if;
    return regions;
  end if;

  if jsonb_typeof(value) = 'object' then
    foreach candidate in array array[
      value ->> 'city',
      value ->> 'service_area_city',
      value ->> 'serviceAreaCity',
      value ->> 'areaName',
      value ->> 'area',
      value ->> 'label',
      value ->> 'name'
    ]
    loop
      if private.drive_tutor_normalize_region_name(candidate) is not null then
        regions := array_append(regions, candidate);
      end if;
    end loop;
  end if;

  return regions;
end;
$$;

create or replace function private.enforce_learner_request_service_cluster()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  learner_region text;
  instructor_profile_region text;
  instructor_locations jsonb;
  instructor_regions text[] := array[]::text[];
  instructor_region text;
  is_allowed boolean := false;
begin
  select p.city
    into learner_region
  from public.profiles p
  where p.id = new.learner_id;

  learner_region := coalesce(
    nullif(trim(coalesce(learner_region, '')), ''),
    nullif(trim(coalesce(new.requested_city, '')), '')
  );

  select p.city, to_jsonb(ip.preferred_locations)
    into instructor_profile_region, instructor_locations
  from public.instructor_profiles ip
  left join public.profiles p on p.id = ip.profile_id
  where ip.profile_id = new.instructor_id;

  if private.drive_tutor_normalize_region_name(instructor_profile_region) is not null then
    instructor_regions := array_append(instructor_regions, instructor_profile_region);
  end if;
  instructor_regions := instructor_regions ||
    private.drive_tutor_extract_regions(instructor_locations);

  foreach instructor_region in array instructor_regions
  loop
    if private.drive_tutor_clusters_are_requestable(learner_region, instructor_region) then
      is_allowed := true;
      exit;
    end if;
  end loop;

  if not is_allowed then
    raise exception
      'Your location is outside instructor service area, please request an other instructor within your zone or area/city'
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

drop trigger if exists learner_request_service_cluster_guard
  on public.learner_requests;

create trigger learner_request_service_cluster_guard
  before insert or update of learner_id, instructor_id, requested_city
  on public.learner_requests
  for each row
  execute function private.enforce_learner_request_service_cluster();

revoke all on function private.drive_tutor_normalize_region_name(text)
  from public, anon, authenticated;
revoke all on function private.drive_tutor_cluster_for_region(text)
  from public, anon, authenticated;
revoke all on function private.drive_tutor_neighbor_clusters(text)
  from public, anon, authenticated;
revoke all on function private.drive_tutor_clusters_are_requestable(text, text)
  from public, anon, authenticated;
revoke all on function private.drive_tutor_extract_regions(jsonb)
  from public, anon, authenticated;
revoke all on function private.enforce_learner_request_service_cluster()
  from public, anon, authenticated;
