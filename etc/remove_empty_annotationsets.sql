DELETE FROM annotationset WHERE annotationset_id IN (SELECT set.annotationset_id
FROM annotationset as set LEFT JOIN annotationtype as ty USING (annotationset_id)
GROUP BY annotationset_id
HAVING COUNT(ty.annotationset_id) = 0)