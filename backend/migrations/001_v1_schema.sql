-- ============================================================================
-- eSOuQ V1 Initial Schema Migration
-- Migration: 001_v1_schema.sql
-- Target Database: PostgreSQL 13+ (compatible with PostgreSQL 18)
-- Description: Core schema foundation for eSOuQ V1 e-commerce system.
-- Includes multi-store catalog isolation, customer/staff/rider/admin accounts,
-- products (available state, no inventory tracking), store-scoped carts & orders,
-- composite FK store isolation, price & loyalty snapshotting, and idempotent
-- order-completion loyalty crediting.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. Extensions
-- ----------------------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ----------------------------------------------------------------------------
-- 1. Helper Functions & Triggers
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- 2. Custom ENUM Types
-- ----------------------------------------------------------------------------

CREATE TYPE user_role AS ENUM (
    'customer',
    'store_staff',
    'store_manager',
    'delivery_rider',
    'super_admin'
);

CREATE TYPE order_status AS ENUM (
    'pending',
    'accepted',
    'preparing',
    'out_for_delivery',
    'completed',
    'cancelled',
    'rejected'
);

CREATE TYPE fulfillment_type AS ENUM (
    'delivery',
    'pickup'
);

CREATE TYPE loyalty_transaction_type AS ENUM (
    'order_completion'
);

-- ----------------------------------------------------------------------------
-- 3. Supermarkets / Stores
-- ----------------------------------------------------------------------------

CREATE TABLE stores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(150) NOT NULL,
    area VARCHAR(100) NOT NULL,
    address TEXT,
    phone_number VARCHAR(20),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Exactly one ACTIVE store per area (case-insensitive), allowing inactive historical stores
CREATE UNIQUE INDEX uq_stores_active_area ON stores (LOWER(area)) WHERE is_active = TRUE;
CREATE INDEX idx_stores_area ON stores(area);
CREATE INDEX idx_stores_is_active ON stores(is_active);

CREATE TRIGGER trg_stores_updated_at
BEFORE UPDATE ON stores
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ----------------------------------------------------------------------------
-- 4. Users (Customers, Store Staff, Store Managers, Delivery Riders, Super Admin)
-- ----------------------------------------------------------------------------

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE,
    password_hash TEXT,
    full_name VARCHAR(150) NOT NULL,
    role user_role NOT NULL DEFAULT 'customer',
    store_id UUID REFERENCES stores(id) ON DELETE SET NULL,
    address TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_staff_manager_store
        CHECK (role NOT IN ('store_staff', 'store_manager') OR store_id IS NOT NULL),
    CONSTRAINT chk_password_required_unless_admin
        CHECK (role = 'super_admin' OR password_hash IS NOT NULL)
);

CREATE INDEX idx_users_phone ON users(phone_number);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_store_id ON users(store_id);

CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ----------------------------------------------------------------------------
-- 5. Products (Store-scoped catalog, available/unavailable state, no stock count)
-- ----------------------------------------------------------------------------

CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    category VARCHAR(100),
    image_url TEXT,
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    loyalty_points_per_unit INTEGER NOT NULL DEFAULT 0 CHECK (loyalty_points_per_unit >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Composite unique key to support composite FK store isolation in cart/order items
    CONSTRAINT uq_products_id_store UNIQUE (id, store_id)
);

CREATE INDEX idx_products_store_id ON products(store_id);
CREATE INDEX idx_products_store_available ON products(store_id, is_available);

CREATE TRIGGER trg_products_updated_at
BEFORE UPDATE ON products
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ----------------------------------------------------------------------------
-- 6. Carts & Cart Items (Store-scoped active cart per customer)
-- ----------------------------------------------------------------------------

CREATE TABLE carts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_user_store_cart UNIQUE (user_id, store_id),
    -- Composite unique key to support composite FK store isolation in cart items
    CONSTRAINT uq_carts_id_store UNIQUE (id, store_id)
);

CREATE INDEX idx_carts_user_id ON carts(user_id);
CREATE INDEX idx_carts_store_id ON carts(store_id);

CREATE TRIGGER trg_carts_updated_at
BEFORE UPDATE ON carts
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TABLE cart_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id UUID NOT NULL,
    product_id UUID NOT NULL,
    store_id UUID NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_cart_product UNIQUE (cart_id, product_id),

    -- Database-level store isolation: cart and product MUST belong to the exact same store
    CONSTRAINT fk_cart_items_cart FOREIGN KEY (cart_id, store_id)
        REFERENCES carts(id, store_id) ON DELETE CASCADE,
    CONSTRAINT fk_cart_items_product FOREIGN KEY (product_id, store_id)
        REFERENCES products(id, store_id) ON DELETE CASCADE
);

CREATE INDEX idx_cart_items_cart_id ON cart_items(cart_id);
CREATE INDEX idx_cart_items_store_id ON cart_items(store_id);

CREATE TRIGGER trg_cart_items_updated_at
BEFORE UPDATE ON cart_items
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ----------------------------------------------------------------------------
-- 7. Orders & Order Items (Preserves price & loyalty snapshots for historical accuracy)
-- ----------------------------------------------------------------------------

CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_number VARCHAR(50) UNIQUE NOT NULL,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE RESTRICT,
    rider_id UUID REFERENCES users(id) ON DELETE SET NULL,
    status order_status NOT NULL DEFAULT 'pending',
    fulfillment_type fulfillment_type NOT NULL DEFAULT 'delivery',
    delivery_address TEXT,
    subtotal NUMERIC(10, 2) NOT NULL CHECK (subtotal >= 0),
    delivery_fee NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (delivery_fee >= 0),
    total_amount NUMERIC(10, 2) NOT NULL CHECK (total_amount >= 0),
    rejection_reason TEXT,
    points_earned INTEGER NOT NULL DEFAULT 0 CHECK (points_earned >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_delivery_requires_address
        CHECK (fulfillment_type = 'pickup' OR delivery_address IS NOT NULL),
    -- Composite unique key to support composite FK store isolation in order items
    CONSTRAINT uq_orders_id_store UNIQUE (id, store_id)
);

CREATE INDEX idx_orders_store_status ON orders(store_id, status);
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_rider_id ON orders(rider_id);

CREATE TRIGGER trg_orders_updated_at
BEFORE UPDATE ON orders
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL,
    product_id UUID NOT NULL,
    store_id UUID NOT NULL,
    product_name VARCHAR(200) NOT NULL,
    unit_price NUMERIC(10, 2) NOT NULL CHECK (unit_price >= 0),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    loyalty_points_per_unit INTEGER NOT NULL DEFAULT 0 CHECK (loyalty_points_per_unit >= 0),
    subtotal_price NUMERIC(10, 2) NOT NULL CHECK (subtotal_price >= 0),
    subtotal_points INTEGER NOT NULL DEFAULT 0 CHECK (subtotal_points >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Database-level store isolation: order and product MUST belong to the exact same store
    CONSTRAINT fk_order_items_order FOREIGN KEY (order_id, store_id)
        REFERENCES orders(id, store_id) ON DELETE CASCADE,
    CONSTRAINT fk_order_items_product FOREIGN KEY (product_id, store_id)
        REFERENCES products(id, store_id) ON DELETE RESTRICT
);

CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_store_id ON order_items(store_id);

-- ----------------------------------------------------------------------------
-- 8. Customer Loyalty Wallets & Idempotent Transaction Ledger
-- ----------------------------------------------------------------------------

CREATE TABLE customer_loyalty_wallets (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    total_points INTEGER NOT NULL DEFAULT 0 CHECK (total_points >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER trg_customer_loyalty_wallets_updated_at
BEFORE UPDATE ON customer_loyalty_wallets
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TABLE loyalty_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    points INTEGER NOT NULL CHECK (points > 0),
    transaction_type loyalty_transaction_type NOT NULL DEFAULT 'order_completion',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Idempotency constraint: guarantees points for a completed order cannot be awarded twice
    CONSTRAINT uq_order_loyalty_transaction UNIQUE (order_id, transaction_type)
);

CREATE INDEX idx_loyalty_transactions_user_id ON loyalty_transactions(user_id);
CREATE INDEX idx_loyalty_transactions_order_id ON loyalty_transactions(order_id);
