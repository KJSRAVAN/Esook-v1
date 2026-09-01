import React, { useState, useEffect } from 'react';
import { getStoreOrders, updateOrderStatus } from '../../api/orders';
import LoadingSpinner from '../../components/LoadingSpinner';
import ErrorMessage from '../../components/ErrorMessage';

const OrderQueue = () => {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    fetchOrders();
    const interval = setInterval(fetchOrders, 30000); // refresh every 30s
    return () => clearInterval(interval);
  }, []);

  const fetchOrders = async () => {
    try {
      const res = await getStoreOrders();
      setOrders(res.data);
      setLoading(false);
    } catch (err) {
      setError('Failed to load orders');
      setLoading(false);
    }
  };

  const handleStatusUpdate = async (orderId, newStatus) => {
    try {
      await updateOrderStatus(orderId, newStatus);
      fetchOrders();
    } catch (err) {
      alert('Failed to update status');
    }
  };

  if (loading && orders.length === 0) return <LoadingSpinner />;

  return (
    <div className="container" style={{ maxWidth: '1200px' }}>
      <h2>Order Queue</h2>
      <ErrorMessage message={error} />
      
      <div className="card">
        <table className="table">
          <thead>
            <tr>
              <th>ID</th>
              <th>Customer</th>
              <th>Summary</th>
              <th>Total</th>
              <th>Type</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {orders.map(order => (
              <tr key={order.id}>
                <td>#{order.id.slice(0, 8)}</td>
                <td>{order.customer?.name}</td>
                <td>{order.items?.length} items</td>
                <td>AED {Number(order.total).toFixed(2)}</td>
                <td>{order.fulfillment}</td>
                <td><span className={`badge badge-${order.status.toLowerCase().replace('_', '-')}`}>{order.status}</span></td>
                <td>
                  <div style={{ display: 'flex', gap: '8px' }}>
                    {order.status === 'PENDING_PAYMENT' && (
                      <>
                        <button className="btn btn-primary" style={{ padding: '4px 8px', fontSize: '12px' }} onClick={() => handleStatusUpdate(order.id, 'ACCEPTED')}>Accept</button>
                        <button className="btn btn-danger" style={{ padding: '4px 8px', fontSize: '12px' }} onClick={() => handleStatusUpdate(order.id, 'REJECTED')}>Reject</button>
                      </>
                    )}
                    {order.status === 'ACCEPTED' && (
                      <button className="btn btn-success" style={{ padding: '4px 8px', fontSize: '12px' }} onClick={() => handleStatusUpdate(order.id, 'READY')}>Mark Ready</button>
                    )}
                    {order.status === 'READY' && order.fulfillment === 'PICKUP' && (
                      <button className="btn btn-secondary" style={{ padding: '4px 8px', fontSize: '12px' }} onClick={() => handleStatusUpdate(order.id, 'DELIVERED')}>Delivered</button>
                    )}
                  </div>
                </td>
              </tr>
            ))}
            {orders.length === 0 && (
              <tr>
                <td colSpan="7" style={{ textAlign: 'center' }}>No orders found</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default OrderQueue;
