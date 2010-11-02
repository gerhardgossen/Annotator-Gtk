INSERT INTO annotation (text_id, annotationtype_id, start_pos, end_pos, value, creator_id)
SELECT DISTINCT text_id, 12 AS annotationtype_id, -1 AS start_pos, -1 AS end_pos, '' AS value, 1 AS creator_id
FROM document
WHERE title LIKE 'A.Word.A.Day%'
