import React, { useState, useEffect } from 'react';
import { getAdminStores, getAdminOrders } from '../../api/admin';
import LoadingSpinner from '../../components/LoadingSpinner';
import ErrorMessage from '../../components/ErrorMessage';

const AdminDashboard = () => {
  const [stores, setStores] = useState([]);
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      const [storesRes, ordersRes] = await Promise.all([getAdminStores(), getAdminOrders()]);
      setStores(storesRes.data);
      setOrders(ordersRes.data);
      setLoading(false);
    } catch (err) {
      setError('Failed to load dashboard data');
      setLoading(false);
    }
  };

  if (loading) return <LoadingSpinner />;

  return (
    <div className="container">
      <h2>Admin Dashboard</h2>
      <ErrorMessage message={error} />
      
      <div style={{ display: 'flex', gap: '20px', marginBottom: '30px' }}>
        <div className="card" style={{ flex: 1, textAlign: 'center' }}>
          <h3>Total Stores</h3>
          <p style={{ fontSize: '32px', fontWeight: 'bold', margin: '10px 0', color: '#2563eb' }}>{stores.length}</p>
        </div>
        <div className="card" style={{ flex: 1, textAlign: 'center' }}>
          <h3>Total Orders</h3>
          <p style={{ fontSize: '32px', fontWeight: 'bold', margin: '10px 0', color: '#16a34a' }}>{orders.length}</p>
        </div>
      </div>
      
      <h3>Stores Overview</h3>
      <div className="card">
        <table className="table">
          <thead>
            <tr>
              <th>ID</th>
              <th>Name</th>
              <th>Area</th>
              <th>Staff Count</th>
            </tr>
          </thead>
          <tbody>
            {stores.map(store => (
              <tr key={store.id}>
                <td>{store.id.slice(0, 8)}</td>
                <td>{store.name}</td>
                <td>{store.area?.name || 'N/A'}</td>
                <td>{store.users?.length || 0}</td>
              </tr>
            ))}
            {stores.length === 0 && (
              <tr>
                <td colSpan="4" style={{ textAlign: 'center' }}>No stores found</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default AdminDashboard;
