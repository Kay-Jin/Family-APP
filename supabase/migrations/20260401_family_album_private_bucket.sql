-- Album images: private bucket (no anonymous CDN URL). App uses createSignedUrl with current JWT.

update storage.buckets
set public = false
where id = 'family_album_images';
