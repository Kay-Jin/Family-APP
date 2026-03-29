-- Daily answer images: private bucket; mobile uses createSignedUrl (same pattern as family_album_images).

update storage.buckets
set public = false
where id = 'family_answer_images';
