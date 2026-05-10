-- SQL Script to Fix Duplicate User Records
-- 
-- This script addresses the issue where users have duplicate records:
-- 1. One record with company_id but empty permissionsMap
-- 2. Another record with null company_id but correct permissionsMap
--
-- The script will merge permissions and remove duplicates

-- Step 1: Identify duplicate users
SELECT 
    email, 
    COUNT(*) as duplicate_count,
    GROUP_CONCAT(id, ', ') as user_ids,
    GROUP_CONCAT(CASE WHEN company_id IS NOT NULL THEN id ELSE NULL END, ', ') as records_with_company,
    GROUP_CONCAT(CASE WHEN permissions LIKE '%permissionsMap%' AND permissions != '{}' THEN id ELSE NULL END, ', ') as records_with_permissions
FROM users 
WHERE email IS NOT NULL AND email != ''
GROUP BY email 
HAVING COUNT(*) > 1;

-- Step 2: Update records with company_id to include permissions from the duplicate record
-- This updates the record that has company_id but empty permissions
UPDATE users 
SET permissions = (
    SELECT permissions 
    FROM users u2 
    WHERE u2.email = users.email 
        AND u2.company_id IS NULL 
        AND u2.permissions LIKE '%permissionsMap%' 
        AND u2.permissions != '{}'
    LIMIT 1
),
updated_at = datetime('now')
WHERE email IN (
    SELECT email 
    FROM users 
    WHERE email IS NOT NULL AND email != ''
    GROUP BY email 
    HAVING COUNT(*) > 1
) 
AND company_id IS NOT NULL
AND (permissions IS NULL OR permissions = '{}' OR permissions NOT LIKE '%permissionsMap%');

-- Step 3: Remove duplicate records that have NULL company_id (after merging permissions)
DELETE FROM users 
WHERE id IN (
    SELECT id 
    FROM users 
    WHERE email IN (
        SELECT email 
        FROM users 
        WHERE email IS NOT NULL AND email != ''
        GROUP BY email 
        HAVING COUNT(*) > 1
    ) 
    AND company_id IS NULL
) 
AND EXISTS (
    SELECT 1 
    FROM users u2 
    WHERE u2.email = users.email 
        AND u2.company_id IS NOT NULL
);

-- Step 4: Verify the fix - Show remaining duplicates (should be empty)
SELECT 
    email, 
    COUNT(*) as remaining_count
FROM users 
WHERE email IS NOT NULL AND email != ''
GROUP BY email 
HAVING COUNT(*) > 1;

-- Step 5: Show specific user (asad@gmail.com) records after fix
SELECT 
    id, 
    email, 
    company_id, 
    CASE 
        WHEN permissions LIKE '%permissionsMap%' AND permissions != '{}' THEN 'Has Permissions'
        ELSE 'No Permissions'
    END as permission_status,
    length(permissions) as permissions_length,
    updated_at
FROM users 
WHERE email = 'asad@gmail.com'
ORDER BY updated_at DESC;
