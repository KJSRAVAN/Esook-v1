import React, { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { getCart, updateQuantity, removeItem, clearCart } from '../../cart';
import { validateCoupon } from '../../api/coupons';
import { createOrder } from '../../api/orders';
import ErrorMessage from '../../components/ErrorMessage';

const Cart = () => {
  const [cart, setCart] = useState(null);
  const [couponCode, setCouponCode] = useState('');
  const [discount, setDiscount] = useState(0);
  const [fulfillment, setFulfillment] = useState('PICKUP');
  const [deliveryAddress, setDeliveryAddress] = useState('');
  const [notes, setNotes] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  useEffect(() => {
    setCart(getCart());
  }, []);

  const handleUpdateQty = (itemId, qty) => {
    updateQuantity(itemId, qty);
    setCart(getCart());
  };

  const handleRemove = (itemId) => {
    removeItem(itemId);
    setCart(getCart());
  };

  const applyCoupon = async () => {
    if (!couponCode) return;
    try {
      const subtotal = cart.items.reduce((sum, item) => sum + (item.price * item.quantity), 0);
      const res = await validateCoupon({ code: couponCode, subtotal });
      setDiscount(res.data.discount);
      setError('');
    } catch (err) {
      setDiscount(0);
      setError(err.response?.data?.message || 'Invalid coupon');
    }
  };

  const placeOrder = async () => {
    if (fulfillment === 'DELIVERY' && !deliveryAddress.trim()) {
      setError('Delivery address is required for delivery.');
      return;
    }
    
    setLoading(true);
    setError('');
    
    try {
      const orderData = {
        storeId: cart.storeId,
        items: cart.items.map(i => ({ itemId: i.itemId, quantity: i.quantity })),
        fulfillment,
        notes
      };
      if (fulfillment === 'DELIVERY') orderData.deliveryAddress = deliveryAddress;
      if (couponCode && discount > 0) orderData.couponCode = couponCode;
      
      await createOrder(orderData);
      clearCart();
      navigate('/orders');
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to place order');
      setLoading(false);
    }
  };

  if (!cart || !cart.storeId || cart.items.length === 0) {
    return (
      <div className="container" style={{ textAlign: 'center', marginTop: '50px' }}>
        <h2>Your cart is empty</h2>
        <Link to="/stores" className="btn btn-primary" style={{ display: 'inline-block', marginTop: '20px', textDecoration: 'none' }}>
          Browse Stores
        </Link>
      </div>
    );
  }

  const subtotal = cart.items.reduce((sum, item) => sum + (item.price * item.quantity), 0);
  const total = Math.max(0, subtotal - discount);

  return (
    <div className="container">
      <h2>Your Cart</h2>
      <ErrorMessage message={error} />
      
      <div className="card" style={{ marginBottom: '20px' }}>
        <table className="table">
          <thead>
            <tr>
              <th>Item</th>
              <th>Price</th>
              <th>Quantity</th>
              <th>Total</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {cart.items.map(item => (
              <tr key={item.itemId}>
                <td>{item.name}</td>
                <td>AED {Number(item.price).toFixed(2)}</td>
                <td>
                  <button onClick={() => handleUpdateQty(item.itemId, item.quantity - 1)}>-</button>
                  <span style={{ margin: '0 10px' }}>{item.quantity}</span>
                  <button onClick={() => handleUpdateQty(item.itemId, item.quantity + 1)}>+</button>
                </td>
                <td>AED {(item.price * item.quantity).toFixed(2)}</td>
                <td><button className="btn btn-danger" onClick={() => handleRemove(item.itemId)}>Remove</button></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="card">
        <div style={{ display: 'flex', gap: '40px', flexWrap: 'wrap' }}>
          <div style={{ flex: 1, minWidth: '300px' }}>
            <div className="form-group">
              <label>Fulfillment Method</label>
              <div style={{ display: 'flex', gap: '20px' }}>
                <label style={{ fontWeight: 'normal' }}>
                  <input type="radio" name="fulfillment" value="PICKUP" checked={fulfillment === 'PICKUP'} onChange={() => setFulfillment('PICKUP')} /> Pickup
                </label>
                <label style={{ fontWeight: 'normal' }}>
                  <input type="radio" name="fulfillment" value="DELIVERY" checked={fulfillment === 'DELIVERY'} onChange={() => setFulfillment('DELIVERY')} /> Delivery
                </label>
              </div>
            </div>
            
            {fulfillment === 'DELIVERY' && (
              <div className="form-group">
                <label>Delivery Address</label>
                <textarea className="input" rows="3" value={deliveryAddress} onChange={e => setDeliveryAddress(e.target.value)} required></textarea>
              </div>
            )}
            
            <div className="form-group">
              <label>Order Notes (Optional)</label>
              <textarea className="input" rows="2" value={notes} onChange={e => setNotes(e.target.value)}></textarea>
            </div>
            
            <div className="form-group" style={{ display: 'flex', gap: '10px' }}>
              <input type="text" className="input" placeholder="Coupon Code" value={couponCode} onChange={e => setCouponCode(e.target.value)} />
              <button className="btn btn-secondary" onClick={applyCoupon}>Apply</button>
            </div>
          </div>
          
          <div style={{ flex: 1, minWidth: '250px', background: '#f9fafb', padding: '20px', borderRadius: '8px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '10px' }}>
              <span>Subtotal:</span>
              <span>AED {subtotal.toFixed(2)}</span>
            </div>
            {discount > 0 && (
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '10px', color: '#16a34a' }}>
                <span>Discount:</span>
                <span>- AED {discount.toFixed(2)}</span>
              </div>
            )}
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '20px', fontWeight: 'bold', fontSize: '18px' }}>
              <span>Total:</span>
              <span>AED {total.toFixed(2)}</span>
            </div>
            <button className="btn btn-primary" style={{ width: '100%', padding: '12px', fontSize: '16px' }} onClick={placeOrder} disabled={loading}>
              {loading ? 'Processing...' : 'Place Order'}
            </button>
            <div style={{ marginTop: '15px', textAlign: 'center' }}>
              <Link to={`/store/${cart.storeId}`}>Continue Shopping</Link>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Cart;
