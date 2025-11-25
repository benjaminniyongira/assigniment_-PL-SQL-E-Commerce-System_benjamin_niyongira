-- =============================================
-- COMPLETE E-COMMERCE PL/SQL PROJECT
-- =============================================

-- Clean up existing objects
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE inventory_log CASCADE CONSTRAINTS';
    EXECUTE IMMEDIATE 'DROP TABLE order_items CASCADE CONSTRAINTS';
    EXECUTE IMMEDIATE 'DROP TABLE orders CASCADE CONSTRAINTS';
    EXECUTE IMMEDIATE 'DROP TABLE products CASCADE CONSTRAINTS';
    EXECUTE IMMEDIATE 'DROP TABLE customers CASCADE CONSTRAINTS';
    EXECUTE IMMEDIATE 'DROP PACKAGE ecommerce_pkg';
    EXECUTE IMMEDIATE 'DROP PROCEDURE display_customer_orders';
    EXECUTE IMMEDIATE 'DROP FUNCTION get_product_price_list';
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END;
/

-- Create sequence for inventory log
CREATE SEQUENCE inventory_log_seq START WITH 1 INCREMENT BY 1;

-- Create tables for e-commerce system
CREATE TABLE customers (
    customer_id NUMBER PRIMARY KEY,
    name VARCHAR2(100),
    email VARCHAR2(100),
    phone VARCHAR2(20),
    registration_date DATE
);

CREATE TABLE products (
    product_id NUMBER PRIMARY KEY,
    name VARCHAR2(100),
    description VARCHAR2(500),
    price NUMBER(10,2),
    stock_quantity NUMBER,
    category VARCHAR2(50)
);

CREATE TABLE orders (
    order_id NUMBER PRIMARY KEY,
    customer_id NUMBER,
    order_date DATE,
    total_amount NUMBER(10,2),
    status VARCHAR2(20),
    CONSTRAINT fk_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE order_items (
    order_item_id NUMBER PRIMARY KEY,
    order_id NUMBER,
    product_id NUMBER,
    quantity NUMBER,
    unit_price NUMBER(10,2),
    CONSTRAINT fk_order FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT fk_product FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE inventory_log (
    log_id NUMBER PRIMARY KEY,
    product_id NUMBER,
    old_stock NUMBER,
    new_stock NUMBER,
    change_date DATE,
    reason VARCHAR2(100)
);

-- Insert sample data
INSERT INTO customers VALUES (1, 'John Doe', 'john@email.com', '123-456-7890', SYSDATE);
INSERT INTO customers VALUES (2, 'Jane Smith', 'jane@email.com', '123-456-7891', SYSDATE);
INSERT INTO customers VALUES (3, 'Bob Johnson', 'bob@email.com', '123-456-7892', SYSDATE);

INSERT INTO products VALUES (1, 'Laptop', 'High-performance laptop', 999.99, 50, 'Electronics');
INSERT INTO products VALUES (2, 'Mouse', 'Wireless mouse', 29.99, 100, 'Electronics');
INSERT INTO products VALUES (3, 'Keyboard', 'Mechanical keyboard', 79.99, 75, 'Electronics');
INSERT INTO products VALUES (4, 'Book', 'Programming guide', 39.99, 200, 'Books');
INSERT INTO products VALUES (5, 'Headphones', 'Noise-cancelling headphones', 199.99, 30, 'Electronics');

COMMIT;

-- Create the E-commerce Package Specification
CREATE OR REPLACE PACKAGE ecommerce_pkg IS
    -- Type definitions for collections
    TYPE product_rec IS RECORD (
        product_id products.product_id%TYPE,
        name products.name%TYPE,
        price products.price%TYPE,
        stock products.stock_quantity%TYPE
    );
    
    TYPE product_table IS TABLE OF product_rec;
    TYPE product_assoc_array IS TABLE OF products.price%TYPE INDEX BY PLS_INTEGER;
    
    -- Procedures
    PROCEDURE create_order(
        p_customer_id IN orders.customer_id%TYPE,
        p_product_ids IN SYS.ODCINUMBERLIST,
        p_quantities IN SYS.ODCINUMBERLIST,
        p_order_id OUT orders.order_id%TYPE
    );
    
    PROCEDURE update_product_stock(
        p_product_id IN products.product_id%TYPE,
        p_quantity_change IN NUMBER
    );
    
    PROCEDURE bulk_update_prices(
        p_category IN products.category%TYPE,
        p_percentage IN NUMBER
    );
    
    PROCEDURE process_daily_orders;
    
    -- Functions
    FUNCTION calculate_order_total(p_order_id IN orders.order_id%TYPE) RETURN NUMBER;
    FUNCTION get_customer_orders(p_customer_id IN customers.customer_id%TYPE) RETURN product_table;
    FUNCTION get_product_info(p_product_id IN products.product_id%TYPE) RETURN product_rec;
    FUNCTION get_top_selling_products RETURN product_table;
    
    -- Exception
    insufficient_stock EXCEPTION;
    PRAGMA EXCEPTION_INIT(insufficient_stock, -20001);
    
END ecommerce_pkg;
/

-- Create the E-commerce Package Body
CREATE OR REPLACE PACKAGE BODY ecommerce_pkg IS
    
    -- Procedure to create a new order using BULK operations
    PROCEDURE create_order(
        p_customer_id IN orders.customer_id%TYPE,
        p_product_ids IN SYS.ODCINUMBERLIST,
        p_quantities IN SYS.ODCINUMBERLIST,
        p_order_id OUT orders.order_id%TYPE
    ) IS
        v_order_id orders.order_id%TYPE;
        v_total_amount orders.total_amount%TYPE := 0;
        
        -- Using collections for bulk processing
        TYPE price_table IS TABLE OF products.price%TYPE;
        TYPE stock_table IS TABLE OF products.stock_quantity%TYPE;
        v_prices price_table;
        v_stocks stock_table;
        v_product_names products.name%TYPE;
        
        -- Cursor declaration
        CURSOR product_cursor IS
            SELECT product_id, price, stock_quantity, name
            FROM products
            WHERE product_id IN (SELECT column_value FROM TABLE(p_product_ids));
            
    BEGIN
        -- Validate input collections
        IF p_product_ids IS NULL OR p_quantities IS NULL OR p_product_ids.COUNT != p_quantities.COUNT THEN
            DBMS_OUTPUT.PUT_LINE('Error: Invalid product IDs or quantities');
            RETURN;
        END IF;
        
        -- Get next order ID
        SELECT NVL(MAX(order_id), 0) + 1 INTO v_order_id FROM orders;
        p_order_id := v_order_id;
        
        -- Bulk collect product information using collections
        OPEN product_cursor;
        FETCH product_cursor BULK COLLECT INTO v_prices, v_stocks;
        CLOSE product_cursor;
        
        -- Validate stock and calculate total using collections
        FOR i IN 1..p_product_ids.COUNT LOOP
            IF p_quantities(i) > v_stocks(i) THEN
                DBMS_OUTPUT.PUT_LINE('Insufficient stock for product ID: ' || p_product_ids(i));
                RAISE insufficient_stock;
            END IF;
            
            v_total_amount := v_total_amount + (v_prices(i) * p_quantities(i));
        END LOOP;
        
        -- Create order header
        INSERT INTO orders (order_id, customer_id, order_date, total_amount, status)
        VALUES (v_order_id, p_customer_id, SYSDATE, v_total_amount, 'PENDING');
        
        -- Bulk insert order items using FORALL (BULK operation)
        FORALL i IN 1..p_product_ids.COUNT
            INSERT INTO order_items (order_item_id, order_id, product_id, quantity, unit_price)
            VALUES ((SELECT NVL(MAX(order_item_id), 0) FROM order_items) + i, v_order_id, p_product_ids(i), p_quantities(i), v_prices(i));
        
        -- Update stock quantities using BULK operations
        FORALL i IN 1..p_product_ids.COUNT
            UPDATE products 
            SET stock_quantity = stock_quantity - p_quantities(i)
            WHERE product_id = p_product_ids(i);
            
        -- Log inventory changes
        FOR i IN 1..p_product_ids.COUNT LOOP
            INSERT INTO inventory_log (log_id, product_id, old_stock, new_stock, change_date, reason)
            VALUES (inventory_log_seq.NEXTVAL, p_product_ids(i), v_stocks(i), v_stocks(i) - p_quantities(i), SYSDATE, 'Order ' || v_order_id);
        END LOOP;
            
        COMMIT;
        
        DBMS_OUTPUT.PUT_LINE('Order ' || v_order_id || ' created successfully. Total: $' || v_total_amount);
        
    EXCEPTION
        WHEN insufficient_stock THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('Error: Insufficient stock for one or more products');
            RAISE;
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('Error creating order: ' || SQLERRM);
            RAISE;
    END create_order;
    
    -- Procedure with GOTO statement (demonstrating usage, though generally not recommended)
    PROCEDURE update_product_stock(
        p_product_id IN products.product_id%TYPE,
        p_quantity_change IN NUMBER
    ) IS
        v_current_stock products.stock_quantity%TYPE;
        v_new_stock products.stock_quantity%TYPE;
        v_product_name products.name%TYPE;
    BEGIN
        -- Get current stock and product name
        BEGIN
            SELECT stock_quantity, name INTO v_current_stock, v_product_name
            FROM products 
            WHERE product_id = p_product_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                DBMS_OUTPUT.PUT_LINE('Error: Product ID ' || p_product_id || ' not found');
                RETURN;
        END;
        
        v_new_stock := v_current_stock + p_quantity_change;
        
        -- Using GOTO for demonstration (not recommended in practice)
        IF v_new_stock < 0 THEN
            GOTO negative_stock;
        END IF;
        
        -- Update stock
        UPDATE products 
        SET stock_quantity = v_new_stock 
        WHERE product_id = p_product_id;
        
        -- Log the change
        INSERT INTO inventory_log (log_id, product_id, old_stock, new_stock, change_date, reason)
        VALUES (inventory_log_seq.NEXTVAL, p_product_id, v_current_stock, v_new_stock, SYSDATE, 'Manual adjustment');
        
        COMMIT;
        
        DBMS_OUTPUT.PUT_LINE('Stock updated for ' || v_product_name || ': ' || v_current_stock || ' -> ' || v_new_stock);
        RETURN;
        
        <<negative_stock>>
        DBMS_OUTPUT.PUT_LINE('Error: Stock cannot be negative for ' || v_product_name);
        DBMS_OUTPUT.PUT_LINE('Current stock: ' || v_current_stock || ', Attempted change: ' || p_quantity_change);
        
    END update_product_stock;
    
    -- Procedure using BULK operations for price updates
    PROCEDURE bulk_update_prices(
        p_category IN products.category%TYPE,
        p_percentage IN NUMBER
    ) IS
        TYPE product_id_table IS TABLE OF products.product_id%TYPE;
        TYPE price_table IS TABLE OF products.price%TYPE;
        TYPE name_table IS TABLE OF products.name%TYPE;
        
        v_product_ids product_id_table;
        v_old_prices price_table;
        v_new_prices price_table;
        v_product_names name_table;
        
        CURSOR product_cur IS
            SELECT product_id, price, name
            FROM products
            WHERE category = p_category
            FOR UPDATE;
    BEGIN
        -- Bulk collect product data using BULK COLLECT
        OPEN product_cur;
        FETCH product_cur BULK COLLECT INTO v_product_ids, v_old_prices, v_product_names;
        CLOSE product_cur;
        
        IF v_product_ids.COUNT = 0 THEN
            DBMS_OUTPUT.PUT_LINE('No products found in category: ' || p_category);
            RETURN;
        END IF;
        
        -- Calculate new prices using collection
        FOR i IN 1..v_product_ids.COUNT LOOP
            v_new_prices(i) := v_old_prices(i) * (1 + p_percentage/100);
            DBMS_OUTPUT.PUT_LINE('Updating ' || v_product_names(i) || ': $' || v_old_prices(i) || ' -> $' || ROUND(v_new_prices(i), 2));
        END LOOP;
        
        -- Bulk update prices using FORALL
        FORALL i IN 1..v_product_ids.COUNT
            UPDATE products 
            SET price = v_new_prices(i)
            WHERE product_id = v_product_ids(i);
            
        COMMIT;
        
        DBMS_OUTPUT.PUT_LINE('Successfully updated ' || SQL%ROWCOUNT || ' products in category: ' || p_category);
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('Error in bulk update: ' || SQLERRM);
            RAISE;
    END bulk_update_prices;
    
    -- Additional procedure using cursor for order processing
    PROCEDURE process_daily_orders IS
        CURSOR pending_orders_cur IS
            SELECT order_id, customer_id, total_amount
            FROM orders
            WHERE status = 'PENDING'
            ORDER BY order_date;
            
        v_processed_count NUMBER := 0;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('Processing pending orders...');
        
        FOR order_rec IN pending_orders_cur LOOP
            BEGIN
                -- Update order status to PROCESSED
                UPDATE orders SET status = 'PROCESSED' WHERE order_id = order_rec.order_id;
                v_processed_count := v_processed_count + 1;
                
                DBMS_OUTPUT.PUT_LINE('Processed order ' || order_rec.order_id || ' for customer ' || order_rec.customer_id || ', Amount: $' || order_rec.total_amount);
                
            EXCEPTION
                WHEN OTHERS THEN
                    DBMS_OUTPUT.PUT_LINE('Error processing order ' || order_rec.order_id || ': ' || SQLERRM);
            END;
        END LOOP;
        
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Total orders processed: ' || v_processed_count);
        
    END process_daily_orders;
    
    -- Function to calculate order total using cursor
    FUNCTION calculate_order_total(p_order_id IN orders.order_id%TYPE) RETURN NUMBER IS
        v_total NUMBER := 0;
        
        CURSOR order_items_cur IS
            SELECT quantity, unit_price
            FROM order_items
            WHERE order_id = p_order_id;
    BEGIN
        FOR item IN order_items_cur LOOP
            v_total := v_total + (item.quantity * item.unit_price);
        END LOOP;
        
        RETURN v_total;
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END calculate_order_total;
    
    -- Function returning collection of customer orders
    FUNCTION get_customer_orders(p_customer_id IN customers.customer_id%TYPE) RETURN product_table IS
        v_products product_table;
        
        CURSOR customer_orders_cur IS
            SELECT p.product_id, p.name, p.price, p.stock_quantity
            FROM products p
            JOIN order_items oi ON p.product_id = oi.product_id
            JOIN orders o ON oi.order_id = o.order_id
            WHERE o.customer_id = p_customer_id;
    BEGIN
        OPEN customer_orders_cur;
        FETCH customer_orders_cur BULK COLLECT INTO v_products;
        CLOSE customer_orders_cur;
        
        RETURN v_products;
    END get_customer_orders;
    
    -- Function returning product record
    FUNCTION get_product_info(p_product_id IN products.product_id%TYPE) RETURN product_rec IS
        v_product product_rec;
    BEGIN
        SELECT product_id, name, price, stock_quantity
        INTO v_product
        FROM products
        WHERE product_id = p_product_id;
        
        RETURN v_product;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END get_product_info;
    
    -- Function to get top selling products using collections
    FUNCTION get_top_selling_products RETURN product_table IS
        v_products product_table;
    BEGIN
        SELECT p.product_id, p.name, p.price, p.stock_quantity
        BULK COLLECT INTO v_products
        FROM products p
        JOIN (
            SELECT product_id, SUM(quantity) as total_sold
            FROM order_items
            GROUP BY product_id
            ORDER BY total_sold DESC
        ) oi ON p.product_id = oi.product_id
        WHERE ROWNUM <= 5;
        
        RETURN v_products;
    END get_top_selling_products;

END ecommerce_pkg;
/

-- Standalone procedure using explicit cursor
CREATE OR REPLACE PROCEDURE display_customer_orders(p_customer_id IN NUMBER) IS
    CURSOR order_cursor IS
        SELECT o.order_id, o.order_date, o.total_amount, o.status
        FROM orders o
        WHERE o.customer_id = p_customer_id
        ORDER BY o.order_date DESC;
        
    v_order_count NUMBER := 0;
    v_customer_name customers.name%TYPE;
BEGIN
    -- Get customer name
    SELECT name INTO v_customer_name FROM customers WHERE customer_id = p_customer_id;
    
    DBMS_OUTPUT.PUT_LINE('Orders for customer: ' || v_customer_name || ' (ID: ' || p_customer_id || ')');
    DBMS_OUTPUT.PUT_LINE('=========================================');
    
    FOR order_rec IN order_cursor LOOP
        v_order_count := v_order_count + 1;
        DBMS_OUTPUT.PUT_LINE('Order ID: ' || order_rec.order_id);
        DBMS_OUTPUT.PUT_LINE('Date: ' || TO_CHAR(order_rec.order_date, 'DD-MON-YYYY'));
        DBMS_OUTPUT.PUT_LINE('Total: $' || order_rec.total_amount);
        DBMS_OUTPUT.PUT_LINE('Status: ' || order_rec.status);
        DBMS_OUTPUT.PUT_LINE('---');
    END LOOP;
    
    IF v_order_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No orders found for this customer.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Total orders: ' || v_order_count);
    END IF;
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Customer ID ' || p_customer_id || ' not found.');
END display_customer_orders;
/

-- Function using associative array and ref cursor
CREATE OR REPLACE FUNCTION get_product_price_list RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
BEGIN
    OPEN v_cursor FOR
        SELECT product_id, name, price, category
        FROM products
        ORDER BY category, product_id;
        
    RETURN v_cursor;
END get_product_price_list;
/

-- Demonstration script to test all features
SET SERVEROUTPUT ON;

DECLARE
    v_order_id NUMBER;
    v_total NUMBER;
    v_products ecommerce_pkg.product_table;
    v_product ecommerce_pkg.product_rec;
    v_price_cursor SYS_REFCURSOR;
    v_pid products.product_id%TYPE;
    v_pname products.name%TYPE;
    v_price products.price%TYPE;
    v_category products.category%TYPE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== E-COMMERCE PL/SQL SYSTEM DEMONSTRATION ===');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Test 1: Create order using collections and bulk operations
    DBMS_OUTPUT.PUT_LINE('1. CREATING NEW ORDER (Collections & Bulk Operations)');
    DBMS_OUTPUT.PUT_LINE('---------------------------------------------------');
    ecommerce_pkg.create_order(
        p_customer_id => 1,
        p_product_ids => SYS.ODCINUMBERLIST(1, 2, 3), -- Laptop, Mouse, Keyboard
        p_quantities => SYS.ODCINUMBERLIST(1, 2, 1),
        p_order_id => v_order_id
    );
    
    -- Test 2: Calculate order total using function with cursor
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('2. CALCULATING ORDER TOTAL (Function with Cursor)');
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------');
    v_total := ecommerce_pkg.calculate_order_total(v_order_id);
    DBMS_OUTPUT.PUT_LINE('Order ' || v_order_id || ' total: $' || v_total);
    
    -- Test 3: Get customer orders as collection
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('3. CUSTOMER ORDERS COLLECTION (BULK COLLECT)');
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------');
    v_products := ecommerce_pkg.get_customer_orders(1);
    
    IF v_products.COUNT > 0 THEN
        FOR i IN 1..v_products.COUNT LOOP
            DBMS_OUTPUT.PUT_LINE('Product: ' || v_products(i).name || ', Price: $' || v_products(i).price || ', Stock: ' || v_products(i).stock);
        END LOOP;
    ELSE
        DBMS_OUTPUT.PUT_LINE('No products found for customer.');
    END IF;
    
    -- Test 4: Update product stock with GOTO demonstration
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('4. UPDATING PRODUCT STOCK (GOTO Demonstration)');
    DBMS_OUTPUT.PUT_LINE('---------------------------------------------');
    ecommerce_pkg.update_product_stock(1, 5); -- Add 5 laptops to stock
    ecommerce_pkg.update_product_stock(1, -60); -- Try to remove too many (demonstrates GOTO)
    
    -- Test 5: Bulk update prices
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('5. BULK PRICE UPDATE (FORALL & BULK COLLECT)');
    DBMS_OUTPUT.PUT_LINE('-------------------------------------------');
    ecommerce_pkg.bulk_update_prices('Electronics', 10); -- Increase by 10%
    
    -- Test 6: Get product info using function
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('6. PRODUCT INFORMATION (Function returning Record)');
    DBMS_OUTPUT.PUT_LINE('-------------------------------------------------');
    v_product := ecommerce_pkg.get_product_info(1);
    IF v_product.product_id IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('Product: ' || v_product.name || ', Price: $' || v_product.price || ', Stock: ' || v_product.stock);
    END IF;
    
    -- Test 7: Display customer orders using standalone procedure with cursor
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('7. CUSTOMER ORDER REPORT (Standalone Procedure with Cursor)');
    DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------');
    display_customer_orders(1);
    
    -- Test 8: Process daily orders
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('8. DAILY ORDER PROCESSING (Procedure with Cursor)');
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------');
    ecommerce_pkg.process_daily_orders;
    
    -- Test 9: Get product price list using ref cursor
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('9. PRODUCT PRICE LIST (Ref Cursor)');
    DBMS_OUTPUT.PUT_LINE('----------------------------------');
    v_price_cursor := get_product_price_list;
    
    LOOP
        FETCH v_price_cursor INTO v_pid, v_pname, v_price, v_category;
        EXIT WHEN v_price_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(v_category || ': ' || v_pname || ' - $' || v_price);
    END LOOP;
    CLOSE v_price_cursor;
    
    -- Test 10: Get top selling products using collection
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('10. TOP SELLING PRODUCTS (Collection Function)');
    DBMS_OUTPUT.PUT_LINE('----------------------------------------------');
    v_products := ecommerce_pkg.get_top_selling_products;
    
    IF v_products.COUNT > 0 THEN
        FOR i IN 1..v_products.COUNT LOOP
            DBMS_OUTPUT.PUT_LINE('Top Product: ' || v_products(i).name || ' - $' || v_products(i).price);
        END LOOP;
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== DEMONSTRATION COMPLETE ===');
    
EXCEPTION
    WHEN ecommerce_pkg.insufficient_stock THEN
        DBMS_OUTPUT.PUT_LINE('Insufficient stock error handled gracefully');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Unexpected error: ' || SQLERRM);
END;
/