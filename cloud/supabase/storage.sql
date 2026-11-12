-- Run in Supabase SQL Editor. Keeps the existing bucket PRIVATE.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('collectible-images', 'collectible-images', false, 5242880,
        array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "MONO users manage their own images" on storage.objects;
create policy "MONO users manage their own images"
on storage.objects for all to anon, authenticated
using (
  bucket_id = 'collectible-images'
  and auth.jwt()->>'iss' = 'https://securetoken.google.com/mono-6d8ad'
  and auth.jwt()->>'aud' = 'mono-6d8ad'
  and (storage.foldername(name))[1] = auth.jwt()->>'sub'
)
with check (
  bucket_id = 'collectible-images'
  and auth.jwt()->>'iss' = 'https://securetoken.google.com/mono-6d8ad'
  and auth.jwt()->>'aud' = 'mono-6d8ad'
  and (storage.foldername(name))[1] = auth.jwt()->>'sub'
);
-- No custom Firebase role is required: these policies explicitly validate the JWT
-- even for the anon database role. An unauthenticated API key has no matching sub/iss.
-- Keep Firebase third-party auth enabled in Supabase Authentication settings.
