-- Development seed (Phase V1): tiny coherent dataset for workflow testing.
-- Idempotent: safe to re-run (e.g. after `supabase db reset`).
--
-- Scope (V4 Phase V):
--   raw materials: Harina 000, Sal, Levadura
--   brands: Lealtad, Dos Anclas, Calsa
--   brand links: Harina 000 -> Lealtad, Sal -> Dos Anclas, Levadura -> Calsa
--   products: Baguette (morning), Pan Mignon (night)
--   one simple test recipe with an active version (Baguette)
-- No full real bakery dataset, no customer personal data.

-- Raw materials (case-insensitive unique name).
insert into public.raw_materials (name, default_unit)
select v.name, v.default_unit
from (values ('Harina 000', 'kg'), ('Sal', 'kg'), ('Levadura', 'kg')) as v(name, default_unit)
where not exists (select 1 from public.raw_materials r where lower(r.name) = lower(v.name));

-- Brands.
insert into public.brands (name)
select v.name
from (values ('Lealtad'), ('Dos Anclas'), ('Calsa')) as v(name)
where not exists (select 1 from public.brands b where b.name = v.name);

-- Allowed brand per raw material (canonical one-to-one mapping).
insert into public.raw_material_brands (raw_material_id, brand_id)
select rm.id, br.id
from public.raw_materials rm
join public.brands br
  on (rm.name, br.name) in (
    ('Harina 000', 'Lealtad'),
    ('Sal', 'Dos Anclas'),
    ('Levadura', 'Calsa')
  )
where not exists (
  select 1
  from public.raw_material_brands l
  where l.raw_material_id = rm.id and l.brand_id = br.id
);

-- Products (default shift is a default only; history is copied later).
insert into public.products (name, default_unit, default_shift_code)
select v.name, v.default_unit, v.shift
from (values ('Baguette', 'unidad', 'morning'), ('Pan Mignon', 'unidad', 'night')) as v(name, default_unit, shift)
where not exists (select 1 from public.products p where p.name = v.name);

-- Simple test recipe: Baguette (produces the Baguette product).
insert into public.recipes (name)
select 'Baguette'
where not exists (select 1 from public.recipes r where r.name = 'Baguette');

insert into public.recipe_versions (recipe_id, version_number, status, effective_from)
select r.id, 1, 'active', current_date
from public.recipes r
where r.name = 'Baguette'
  and not exists (
    select 1 from public.recipe_versions v where v.recipe_id = r.id and v.version_number = 1
  );

insert into public.recipe_ingredients (recipe_version_id, raw_material_id, quantity, unit, sort_order)
select v.recipe_version_id, rm.id, v.quantity, v.unit, v.sort_order
from (
  select rv.id as recipe_version_id,
         i.raw_material_name,
         i.quantity,
         i.unit,
         i.sort_order
  from public.recipe_versions rv
  join public.recipes r on r.id = rv.recipe_id
  cross join lateral (
    values
      ('Harina 000', 1.0, 'kg', 1),
      ('Sal', 0.02, 'kg', 2),
      ('Levadura', 0.03, 'kg', 3)
  ) as i(raw_material_name, quantity, unit, sort_order)
  where r.name = 'Baguette' and rv.version_number = 1
) v
join public.raw_materials rm on rm.name = v.raw_material_name
where not exists (
  select 1
  from public.recipe_ingredients ri
  where ri.recipe_version_id = v.recipe_version_id and ri.raw_material_id = rm.id
);

insert into public.recipe_products (recipe_id, product_id, sort_order)
select r.id, p.id, 1
from public.recipes r
join public.products p on p.name = 'Baguette'
where r.name = 'Baguette'
  and not exists (
    select 1 from public.recipe_products rp where rp.recipe_id = r.id and rp.product_id = p.id
  );
