-- Run this AFTER the original schema from the chat. It makes yearly case numbers safe.
create unique index if not exists cases_user_case_number_idx on public.cases(user_id, case_number);

create or replace function public.next_case_number()
returns text
language plpgsql
security invoker
set search_path = public
as $$
declare
  y text := to_char(current_date,'YYYY');
  n integer;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  select coalesce(max((substring(case_number from 6))::integer),0)+1
    into n
    from public.cases
   where user_id = auth.uid()
     and case_number like y || '-%';
  return y || '-' || lpad(n::text,3,'0');
end;
$$;

grant execute on function public.next_case_number() to authenticated;
