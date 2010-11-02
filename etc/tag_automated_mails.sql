﻿INSERT INTO annotation (text_id, annotationtype_id, start_pos, end_pos, value, creator_id)
SELECT DISTINCT text_id, 12 AS annotationtype_id, -1 AS start_pos, -1 AS end_pos, '' AS value, 1 AS creator_id
FROM document
WHERE sender IN ('venturewire', 'navigator', 'abcnewsnow-editor', 'service', 'emaildelivery', 'postmaster', 'customercare', 'doctor', 'gift', 'enerfaxdaily', 'Dailyblessings 10', 'memberservices', 'ipayit', 'word', 'mailer-daemon', 'pma-marketplace', 'eserver', 'edirectnetwork', 'grs4ferc', 'powerprices', 'enerfax1', 'members', 'carrfuturesenergy', 'announcements', 'orders', 'energybulletin', 'gasnews', 'enerfax', 'storm-advisory', 'ethink', 'special', 'etradeservice', 'marketopshourahead', 'opinionjournal', 'tradersummary', 'djcustomclips', 'weather', 'specialoffers', 'bible-html', 'wincash', 'marketplace', 'people', 'technologydaily-alert', 'rfpservice', 'pennfuture', 'sweepsclub', 'khou-weatherwarn', 'breakingnews', 'Enron Mailsweeper Admin', 'updates', 'trnews', 'subscriptions', 'netsaaversv', 'ecdirect-daily', 'clickathome', 'mailbot', 'news', 'issuealert', 'Continental Airlines Inc', 'yahoo-delivers', 'yahoo-finance', 'refertofriend', 'alerts-breakingnews', 'wsmith' )
