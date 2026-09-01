import React, { useState, useEffect } from 'react';
import { getAdminStores, getAdminUsers, createManager } from '../../api/admin';
import LoadingSpinner from '../../components/LoadingSpinner';
import ErrorMessage from '../../components/ErrorMessage';

const CreateManager = () => {
  const [stores, setStores] = useState([]);
  const [managers, setManagers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  
  const [formData, setFormData] = useState({ name: '', email: '', password: '', storeId: '' });

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      const [storesRes, usersRes] = await Promise.all([getAdminStores(), getAdminUsers()]);
      setStores(storesRes.data);
      setManagers(usersRes.data.filter(u => u.role === 'MANAGER'));
      if (storesRes.data.length > 0) {
        setFormData(prev => ({ ...prev, storeId: storesRes.data[0].id }));
      }
      setLoading(false);
    } catch (err) {
      setError('Failed to load data');
      setLoading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setSuccess('');
    try {
      await createManager(formData);
      setSuccess('Manager created successfully');
      setFormData({ name: '', email: '', password: '', storeId: stores[0]?.id || '' });
      fetchData(); // refresh list
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to create manager');
    }
  };

  if (loading) return <LoadingSpinner />;

  return (
    <div className="container" style={{ maxWidth: '800px' }}>
      <h2>Manage Staff</h2>
      
      {error && <div className="alert-error">{error}</div>}
      {success && <div className="alert-success">{success}</div>}
      
      <div className="card" style={{ marginBottom: '30px' }}>
        <h3>Create New Manager</h3>
        <form onSubmit={handleSubmit} style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '15px' }}>
          <div className="form-group">
            <label>Name</label>
            <input required className="input" type="text" value={formData.name} onChange={e => setFormData({...formData, name: e.target.value})} />
          </div>
          <div className="form-group">
            <label>Email</label>
            <input required className="input" type="email" value={formData.email} onChange={e => setFormData({...formData, email: e.target.value})} />
          </div>
          <div className="form-group">
            <label>Password</label>
            <input required className="input" type="password" value={formData.password} onChange={e => setFormData({...formData, password: e.target.value})} />
          </div>
          <div className="form-group">
            <label>Assign to Store</label>
            <select required className="input" value={formData.storeId} onChange={e => setFormData({...formData, storeId: e.target.value})}>
              {stores.map(store => (
                <option key={store.id} value={store.id}>{store.name}</option>
              ))}
            </select>
          </div>
          <div style={{ gridColumn: 'span 2' }}>
            <button type="submit" className="btn btn-primary">Create Manager</button>
          </div>
        </form>
      </div>

      <h3>Existing Managers</h3>
      <div className="card">
        <table className="table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Email</th>
              <th>Store</th>
            </tr>
          </thead>
          <tbody>
            {managers.map(manager => (
              <tr key={manager.id}>
                <td>{manager.name}</td>
                <td>{manager.email}</td>
                <td>{manager.store?.name || 'Unassigned'}</td>
              </tr>
            ))}
            {managers.length === 0 && (
              <tr>
                <td colSpan="3" style={{ textAlign: 'center' }}>No managers found</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default CreateManager;
