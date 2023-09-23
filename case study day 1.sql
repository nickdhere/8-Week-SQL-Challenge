-- Create the database schema
CREATE DATABASE dannys_diner;
USE dannys_diner;

-- Create the sales table
CREATE TABLE sales (
  customer_id VARCHAR(1),
  order_date DATE,
  product_id INT
);

-- Insert data into the sales table
INSERT INTO sales
  (customer_id, order_date, product_id)
VALUES
  ('A', '2021-01-01', 1),
  ('A', '2021-01-01', 2),
  ('A', '2021-01-07', 2),
  ('A', '2021-01-10', 3),
  ('A', '2021-01-11', 3),
  ('A', '2021-01-11', 3),
  ('B', '2021-01-01', 2),
  ('B', '2021-01-02', 2),
  ('B', '2021-01-04', 1),
  ('B', '2021-01-11', 1),
  ('B', '2021-01-16', 3),
  ('B', '2021-02-01', 3),
  ('C', '2021-01-01', 3),
  ('C', '2021-01-01', 3),
  ('C', '2021-01-07', 3);

-- Create the menu table
CREATE TABLE menu (
  product_id INT,
  product_name VARCHAR(5),
  price INT
);

-- Insert data into the menu table
INSERT INTO menu
  (product_id, product_name, price)
VALUES
  (1, 'sushi', 10),
  (2, 'curry', 15),
  (3, 'ramen', 12);

-- Create the members table
CREATE TABLE members (
  customer_id VARCHAR(1),
  join_date DATE
);

-- Insert data into the members table
INSERT INTO members
  (customer_id, join_date)
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');

SELECT * FROM members;
SELECT * FROM sales;
SELECT * FROM menu;


-- What is the total amount each customer spent at the restaurant?
SELECT s.customer_id, SUM(m.price) Amount
FROM sales s
LEFT JOIN menu m
ON s.product_id = m.product_id
GROUP BY 1;


-- How many days has each customer visited the restaurant?
SELECT customer_id, COUNT(DISTINCT order_date) No_of_days
FROM sales
GROUP BY 1;


-- What was the first item from the menu purchased by each customer?
WITH cte AS(
SELECT s.customer_id, ROW_NUMBER() OVER(PARTITION BY customer_id) rn, m.product_name
FROM sales s 
LEFT JOIN menu m
ON s.product_id = m.product_id
)
SELECT customer_id, product_name
FROM cte
WHERE rn = 1;


-- What is the most purchased item on the menu and how many times was it purchased by all customers? 
WITH most_purchased_id AS(
SELECT product_id, COUNT(*) no_of_times_bought
FROM sales
GROUP BY 1
ORDER BY 2 DESC
LIMIT 1
)
SELECT product_name, no_of_times_bought
FROM menu m
JOIN most_purchased_id mp
ON m.product_id = mp.product_id;


-- Which item was the most popular for each customer?
WITH cte AS(
SELECT s.customer_id, s.product_id, m.product_name 
FROM sales s
LEFT JOIN menu m
ON s.product_id = m.product_id
), cte1 AS(
SELECT customer_id, product_name, COUNT(*) order_count, DENSE_RANK() OVER(PARTITION BY customer_id ORDER BY COUNT(*) DESC) dr
FROM cte
GROUP BY 1,2
)
SELECT customer_id, product_name, order_count
FROM cte1
WHERE dr = 1;


-- Which item was purchased first by the customer after they became a member?
WITH cte AS(
SELECT s.customer_id, me.join_date, s.order_date, m.product_name
FROM members me
RIGHT JOIN sales s
ON s.customer_id = me.customer_id
LEFT JOIN menu m
ON m.product_id = s.product_id
), cte1 AS(
SELECT customer_id, product_name, order_date, ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY order_date) rn
FROM cte
WHERE join_date < order_date
)
SELECT customer_id, product_name
FROM cte1
WHERE rn = 1;


-- Which item was purchased just before the customer became a member?
WITH cte AS(
SELECT m.product_name, s.order_date, me.join_date, s.customer_id
FROM members me
RIGHT JOIN sales s
ON s.customer_id = me.customer_id
LEFT JOIN menu m
ON m.product_id = s.product_id
), cte1 AS(
SELECT * , ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY order_date DESC) rn FROM cte
WHERE order_date < join_date
)
SELECT customer_id, product_name
FROM cte1
WHERE rn = 1;


-- What is the total items and amount spent for each member before they became a member?
SELECT s.customer_id, COUNT(s.customer_id) order_quantity, SUM(m.price) total_amount
FROM members me
RIGHT JOIN sales s
ON s.customer_id = me.customer_id
LEFT JOIN menu m
ON m.product_id = s.product_id
WHERE s.order_date < me.join_date
GROUP BY 1;


/*If each $1 spent equates to 10 points and sushi has a 2x points multiplier -
     how many points would each customer have?*/
WITH tokens AS(
SELECT customer_id, 
CASE WHEN m.product_name != 'sushi' THEN price*10 ELSE price*20 END Tokens
FROM sales s
LEFT JOIN menu m
ON m.product_id = s.product_id
)
SELECT customer_id, SUM(Tokens) total_tokens
FROM tokens
GROUP BY 1;


/*In the first week after a customer joins the program (including their join date) 
they earn 2x points on all items, not just sushi - how many points do customer A and B 
have at the end of January?*/
WITH cte AS(
SELECT s.customer_id, s.order_date, m.price, m.product_name, me.join_date, DATE(me.join_date +6) first_week 
FROM members me
RIGHT JOIN sales s
ON s.customer_id = me.customer_id
LEFT JOIN menu m
ON m.product_id = s.product_id
WHERE s.order_date < '2021-01-31'
AND s.order_date >= me.join_date
), cte1 AS(
SELECT customer_id, 
CASE 
	WHEN product_name = 'sushi' THEN price*20 
    WHEN order_date BETWEEN join_date AND first_week +1 THEN price*20
    ELSE price*10
    END tokens
FROM cte
)
SELECT customer_id, SUM(tokens) total_tokens
FROM cte1
GROUP BY 1;



/* Join All The Things
Recreate the table with: customer_id, order_date, product_name, price, member (Y/N)*/
SELECT s.customer_id, s.order_date, m.product_name, m.price,
CASE WHEN s.order_date >= me.join_date THEN 'Y' ELSE 'N' END Members
FROM members me
RIGHT JOIN sales s
ON s.customer_id = me.customer_id
LEFT JOIN menu m
ON m.product_id = s.product_id;


/* Rank All The Things
Danny also requires further information about the ranking of customer products, 
but he purposely does not need the ranking for non-member purchases so he expects null ranking values
 for the records when customers are not yet part of the loyalty program.*/
WITH cte AS
(
SELECT s.customer_id, s.order_date, m.product_name, m.price,
CASE WHEN s.order_date >= me.join_date THEN 'Y' ELSE 'N' END Members
FROM members me
RIGHT JOIN sales s
ON s.customer_id = me.customer_id
LEFT JOIN menu m
ON m.product_id = s.product_id
)
SELECT *, 
CASE 
	WHEN Members = 'Y' THEN DENSE_RANK() OVER(PARTITION BY customer_id, Members ORDER BY order_date) ELSE NULL END Ranking
FROM cte;
    
    
    
    



