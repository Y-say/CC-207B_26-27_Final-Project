-- PRC on Profile is read-only; owners manage licenses via Employees only.

revoke execute on function public.update_my_prc_license(text, date) from authenticated;