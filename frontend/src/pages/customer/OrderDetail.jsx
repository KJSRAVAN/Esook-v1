import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { getOrder } from '../../api/orders';
import LoadingSpinner from '../../components/LoadingSpinner';
import ErrorMessage from '../../components/ErrorMessage';

const getStatusBadge = (status) => {
  const map = {
    'PENDING_PAYMENT': 'badge-pending',
    'ACCEPTED': 'badge-accepted',
    'REJECTED': 'badge-rejected',
    'READY': 'badge-ready',
    'DELIVERED': 'badge-delivered'
  };
  return `badge ${map[status] || 'badge-delivered'}`;
};

const OrderDetail = () => {
  const { orderId } = useParams();
  const [order, setOrder] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    fetchOrder();
  }, [orderId]);

  const fetchOrder = async () => {
    try {
      const res = await getOrder(orderId);
      setOrder(res.data);
      setLoading(false);
    } catch (err) {
      setError('Failed to load order details');
      setLoading(false);
    }
  };

  if (loading) return <LoadingSpinner />;
  if (!order) return <div className="container"><ErrorMessage message={error} /></div>;

  return (
    <div className="container">
      <div style={{ marginBottom: '20px' }}>
        <Link to="/orders">&larr; Back to Orders</Link>
      </div>
      
      <div className="card" style={{ marginBottom: '20px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
          <h2 style={{ margin: 0 }}>Order #{order.id.slice(0, 8)}</h2>
          <span className={getStatusBadge(order.status)} style={{ fontSize: '14px', padding: '6px 12px' }}>
            {order.status.replace('_', ' ')}
          </span>
        </div>
        
        <div style={{ display: 'flex', gap: '40px', flexWrap: 'wrap', marginBottom: '20px' }}>
          <div>
            <strong>Store:</strong> {order.store?.name}
          </div>
          <div>
            <strong>Date:</strong> {new Date(order.createdAt).toLocaleString()}
          </div>
          <div>
            <strong>Fulfillment:</strong> {order.fulfillment}
          </div>
          {order.fulfillment === 'DELIVERY' && (
            <div>
              <strong>Address:</strong> {order.deliveryAddress}
            </div>
          )}
        </div>
        {order.notes && (
          <div style={{ marginBottom: '20px' }}>
            <strong>Notes:</strong> {order.notes}
          </div>
        )}
      </div>

      <div className="card">
        <h3>Items</h3>
        <table className="table">
          <thead>
            <tr>
              <th>Item</th>
              <th>Price</th>
              <th>Qty</th>
              <th>Total</th>
            </tr>
          </thead>
          <tbody>
            {order.items?.map(item => (
              <tr key={item.id}>
                <td>{item.itemName}</td>
                <td>AED {Number(item.itemPrice).toFixed(2)}</td>
                <td>{item.quantity}</td>
                <td>AED {(Number(item.itemPrice) * item.quantity).toFixed(2)}</td>
              </tr>
            ))}
          </tbody>
        </table>
        
        <div style={{ marginTop: '20px', maxWidth: '300px', marginLeft: 'auto', textAlign: 'right' }}>
          <div style={{ marginBottom: '10px' }}>
            Subtotal: AED {Number(order.subtotal).toFixed(2)}
          </div>
          {Number(order.discount) > 0 && (
            <div style={{ marginBottom: '10px', color: '#16a34a' }}>
              Discount: - AED {Number(order.discount).toFixed(2)}
            </div>
          )}
          <div style={{ fontWeight: 'bold', fontSize: '18px' }}>
            Total: AED {Number(order.total).toFixed(2)}
          </div>
        </div>
      </div>
    </div>
  );
};

export default OrderDetail;
