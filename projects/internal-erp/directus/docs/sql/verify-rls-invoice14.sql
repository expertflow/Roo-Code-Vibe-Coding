SELECT u.email, u.provider, r.id AS role_id, r.name AS role_name
FROM directus_users u
LEFT JOIN directus_roles r ON r.id = u.role
WHERE LOWER(TRIM(u.email)) IN ('apstuber@gmail.com', 'apstuber@expertflow.com');
