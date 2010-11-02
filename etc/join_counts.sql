SELECT document.*, ann_cnt.cnt
FROM document NATURAL JOIN (SELECT text_id, COUNT(annotation_id) as cnt
FROM document NATURAL JOIN text LEFT JOIN annotation using(text_id)
GROUP BY text_id) as ann_cnt
