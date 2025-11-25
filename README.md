# NAMES: BENJAMIN NIYONGIRA
# ID: 27883

# 🛒 PL/SQL E-Commerce System

A comprehensive Oracle PL/SQL-based e-commerce management system demonstrating advanced database programming concepts including collections, packages, bulk operations, cursors, functions, and procedures.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Database Schema](#database-schema)
- [PL/SQL Concepts Demonstrated](#plsql-concepts-demonstrated)
- [Installation](#installation)
- [Usage](#usage)
- [Package Documentation](#package-documentation)
- [Examples](#examples)
- [Project Structure](#project-structure)
- [Contributing](#contributing)
- [License](#license)

## 🌟 Overview

This project implements a complete e-commerce backend system using Oracle PL/SQL. It handles customer management, product catalog, order processing, inventory management, and reporting through sophisticated database programming techniques.

## 🚀 Features

- **Order Management**: Complete order processing with validation
- **Inventory Control**: Real-time stock updates and logging
- **Pricing Engine**: Bulk price updates and calculations
- **Customer Analytics**: Order history and reporting
- **Bulk Operations**: High-performance data processing
- **Error Handling**: Comprehensive exception management

## 🗄️ Database Schema

### Tables
- **customers**: Customer information and registration
- **products**: Product catalog with pricing and stock
- **orders**: Order headers with status and totals
- **order_items**: Order line items with quantities
- **inventory_log**: Audit trail for stock changes

### Sequences
- `inventory_log_seq`: For inventory log primary keys

## 💻 PL/SQL Concepts Demonstrated

### ✅ Collections
- `TABLE` types for bulk operations
- `RECORD` types for structured data
- Associative arrays for key-value storage
- `BULK COLLECT` for efficient data retrieval

### ✅ Packages
- **ecommerce_pkg**: Main package with specification and body
- Encapsulated business logic and types
- Public and private program units

### ✅ Bulk Operations
- `FORALL` for high-performance DML
- `BULK COLLECT` for efficient data fetching
- Bulk price updates and stock modifications

### ✅ Cursors
- Explicit cursors for order processing
- Cursor FOR loops for data iteration
- REF CURSORS for flexible data return
- Parameterized cursors

### ✅ Functions
- Scalar functions for calculations
- Table functions returning collections
- Functions with complex return types
- Error-handling in functions

### ✅ GOTO Statements
- Controlled flow redirection (demonstration)
- Error handling scenarios
- Conditional branching

### ✅ Procedures
- Complex business logic procedures
- Parameter modes (IN, OUT)
- Exception handling
- Transaction management

## 📥 Installation

### Prerequisites
- Oracle Database 11g or higher
- SQL*Plus or SQL Developer
- Basic PL/SQL execution privileges

### Setup Instructions

1. **Clone or Download** the project files
2. **Connect** to your Oracle database:
   ```sql
   sqlplus username/password@database
   ```

3. **Execute** the complete script:
   ```sql
   @ecommerce_system.sql
   ```

4. **Verify** installation by checking created objects:
   ```sql
   SELECT object_name, object_type 
   FROM user_objects 
   WHERE object_name LIKE '%ECOMMERCE%' OR object_name IN ('CUSTOMERS','PRODUCTS','ORDERS','ORDER_ITEMS','INVENTORY_LOG');
   ```

## 🎯 Usage

### Basic Order Creation
```sql
DECLARE
    v_order_id NUMBER;
BEGIN
    ecommerce_pkg.create_order(
        p_customer_id => 1,
        p_product_ids => SYS.ODCINUMBERLIST(1, 2, 3),
        p_quantities => SYS.ODCINUMBERLIST(1, 2, 1),
        p_order_id => v_order_id
    );
    DBMS_OUTPUT.PUT_LINE('Created Order ID: ' || v_order_id);
END;
/
```

### Bulk Price Update
```sql
BEGIN
    ecommerce_pkg.bulk_update_prices('Electronics', 10); -- 10% increase
END;
/
```

### Customer Order Report
```sql
BEGIN
    display_customer_orders(1); -- Show all orders for customer 1
END;
/
```

## 📚 Package Documentation

### ecommerce_pkg Main Procedures

#### `create_order`
Creates a new order with multiple products using bulk operations.

**Parameters:**
- `p_customer_id`: Customer identifier
- `p_product_ids`: Collection of product IDs
- `p_quantities`: Collection of quantities
- `p_order_id`: Output parameter with created order ID

#### `bulk_update_prices`
Updates prices for all products in a category using bulk operations.

**Parameters:**
- `p_category`: Product category to update
- `p_percentage`: Percentage change (+/-)

#### `update_product_stock`
Updates product stock with GOTO demonstration for error handling.

**Parameters:**
- `p_product_id`: Product to update
- `p_quantity_change`: Quantity change (+/-)

### Key Functions

#### `calculate_order_total`
Returns the total amount for a specific order using cursor-based calculation.

#### `get_customer_orders`
Returns a collection of products ordered by a specific customer.

#### `get_top_selling_products`
Returns top 5 best-selling products using analytical queries.

## 🔧 Examples

### Example 1: Complete Order Lifecycle
```sql
SET SERVEROUTPUT ON;

DECLARE
    v_order_id NUMBER;
    v_total NUMBER;
BEGIN
    -- Create order
    ecommerce_pkg.create_order(1, SYS.ODCINUMBERLIST(1,2), SYS.ODCINUMBERLIST(1,3), v_order_id);
    
    -- Calculate total
    v_total := ecommerce_pkg.calculate_order_total(v_order_id);
    DBMS_OUTPUT.PUT_LINE('Order Total: $' || v_total);
    
    -- Process order
    ecommerce_pkg.process_daily_orders;
    
    -- Display report
    display_customer_orders(1);
END;
/
```

### Example 2: Inventory Management
```sql
BEGIN
    -- Add stock
    ecommerce_pkg.update_product_stock(1, 10);
    
    -- Try to over-remove stock (demonstrates GOTO)
    ecommerce_pkg.update_product_stock(1, -100);
END;
/
```

### Example 3: Analytical Queries
```sql
DECLARE
    v_products ecommerce_pkg.product_table;
BEGIN
    -- Get top selling products
    v_products := ecommerce_pkg.get_top_selling_products;
    
    FOR i IN 1..v_products.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE(v_products(i).name || ': $' || v_products(i).price);
    END LOOP;
END;
/
```

## 📁 Project Structure

```
plsql-ecommerce-system/
│
├── 📄 README.md                 
├── 🗃️ ecommerce_system.sql      
├──  screenshots    
             
```

### Database Objects Created
- **5 Tables**: customers, products, orders, order_items, inventory_log
- **1 Sequence**: inventory_log_seq
- **1 Package**: ecommerce_pkg (specification and body)
- **2 Standalone Program Units**: display_customer_orders procedure, get_product_price_list function

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for:

- Bug fixes
- New features
- Performance improvements
- Documentation enhancements

### Development Guidelines
1. Follow Oracle PL/SQL coding standards
2. Include comprehensive error handling
3. Add comments for complex logic
4. Test thoroughly before submitting

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

---

## 🏆 Advanced Features Highlight

### Performance Optimizations
- **Bulk Operations**: Reduced context switches between SQL and PL/SQL
- **Collection Processing**: Efficient in-memory data manipulation
- **Bulk Error Handling**: Comprehensive exception management in bulk operations

### Scalability Features
- **Modular Design**: Easy to extend and maintain
- **Transaction Safety**: Proper commit/rollback handling
- **Audit Trail**: Complete inventory change logging

### Real-World Readiness
- **Production-Grade Error Handling**
- **Comprehensive Input Validation**
- **Business Logic Encapsulation**
- **Reporting and Analytics Capabilities**

---

**⭐ Star this repository if you find it helpful for learning advanced PL/SQL concepts!**

For questions or support, please open an issue in the GitHub repository.
