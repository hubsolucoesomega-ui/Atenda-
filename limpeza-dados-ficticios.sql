DELETE FROM closing_reports WHERE author_id IN (SELECT id FROM users WHERE email <> 'ana@atenda.com.br');
DELETE FROM closing_reports WHERE reviewer_id IN (SELECT id FROM users WHERE email <> 'ana@atenda.com.br');
DELETE FROM employees;
DELETE FROM users WHERE email <> 'ana@atenda.com.br';
DELETE FROM clients;
