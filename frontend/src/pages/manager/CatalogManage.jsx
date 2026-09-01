import React, { useState, useEffect } from 'react';
import { getCatalog, addCatalogItem, updateCatalogItem } from '../../api/catalog';
import { useAuth } from '../../context/AuthContext';
import LoadingSpinner from '../../components/LoadingSpinner';
import ErrorMessage from '../../components/ErrorMessage';

const CatalogManage = () => {
  const { user } = useAuth();
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  
  const [showAddForm, setShowAddForm] = useState(false);
  const [newItem, setNewItem] = useState({ name: '', description: '', price: '' });
  
  const [editingId, setEditingId] = useState(null);
  const [editForm, setEditForm] = useState({ price: '', description: '' });

  useEffect(() => {
    if (user?.storeId) {
      fetchCatalog();
    }
  }, [user]);

  const fetchCatalog = async () => {
    try {
      const res = await getCatalog(user.storeId);
      setItems(res.data);
      setLoading(false);
    } catch (err) {
      setError('Failed to load catalog');
      setLoading(false);
    }
  };

  const handleAddItem = async (e) => {
    e.preventDefault();
    try {
      await addCatalogItem(user.storeId, { ...newItem, price: Number(newItem.price) });
      setShowAddForm(false);
      setNewItem({ name: '', description: '', price: '' });
      fetchCatalog();
    } catch (err) {
      alert('Failed to add item');
    }
  };

  const toggleAvailability = async (item) => {
    try {
      await updateCatalogItem(user.storeId, item.id, { isAvailable: !item.isAvailable });
      fetchCatalog();
    } catch (err) {
      alert('Failed to update availability');
    }
  };

  const startEdit = (item) => {
    setEditingId(item.id);
    setEditForm({ price: item.price, description: item.description || '' });
  };

  const saveEdit = async (id) => {
    try {
      await updateCatalogItem(user.storeId, id, { price: Number(editForm.price), description: editForm.description });
      setEditingId(null);
      fetchCatalog();
    } catch (err) {
      alert('Failed to update item');
    }
  };

  if (loading) return <LoadingSpinner />;

  return (
    <div className="container">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
        <h2>Manage Catalog</h2>
        <button className="btn btn-primary" onClick={() => setShowAddForm(!showAddForm)}>
          {showAddForm ? 'Cancel' : 'Add Item'}
        </button>
      </div>
      
      <ErrorMessage message={error} />
      
      {showAddForm && (
        <div className="card" style={{ marginBottom: '20px', background: '#f8fafc' }}>
          <h3>Add New Item</h3>
          <form onSubmit={handleAddItem} style={{ display: 'flex', gap: '15px', alignItems: 'flex-end' }}>
            <div className="form-group" style={{ margin: 0, flex: 2 }}>
              <label>Name</label>
              <input required className="input" type="text" value={newItem.name} onChange={e => setNewItem({...newItem, name: e.target.value})} />
            </div>
            <div className="form-group" style={{ margin: 0, flex: 3 }}>
              <label>Description</label>
              <input className="input" type="text" value={newItem.description} onChange={e => setNewItem({...newItem, description: e.target.value})} />
            </div>
            <div className="form-group" style={{ margin: 0, flex: 1 }}>
              <label>Price (AED)</label>
              <input required className="input" type="number" step="0.01" min="0" value={newItem.price} onChange={e => setNewItem({...newItem, price: e.target.value})} />
            </div>
            <button type="submit" className="btn btn-success" style={{ height: '37px' }}>Save</button>
          </form>
        </div>
      )}

      <div className="card">
        <table className="table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Description</th>
              <th>Price</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {items.map(item => (
              <tr key={item.id}>
                <td>{item.name}</td>
                <td>
                  {editingId === item.id ? (
                    <input className="input" type="text" value={editForm.description} onChange={e => setEditForm({...editForm, description: e.target.value})} />
                  ) : (
                    item.description
                  )}
                </td>
                <td>
                  {editingId === item.id ? (
                    <input className="input" type="number" step="0.01" value={editForm.price} onChange={e => setEditForm({...editForm, price: e.target.value})} style={{ width: '80px' }} />
                  ) : (
                    `AED ${Number(item.price).toFixed(2)}`
                  )}
                </td>
                <td>
                  <span style={{ color: item.isAvailable ? '#16a34a' : '#dc2626', fontWeight: 'bold' }}>
                    {item.isAvailable ? 'Available' : 'Unavailable'}
                  </span>
                </td>
                <td>
                  <div style={{ display: 'flex', gap: '8px' }}>
                    {editingId === item.id ? (
                      <>
                        <button className="btn btn-success" style={{ padding: '4px 8px', fontSize: '12px' }} onClick={() => saveEdit(item.id)}>Save</button>
                        <button className="btn btn-secondary" style={{ padding: '4px 8px', fontSize: '12px' }} onClick={() => setEditingId(null)}>Cancel</button>
                      </>
                    ) : (
                      <>
                        <button className="btn btn-primary" style={{ padding: '4px 8px', fontSize: '12px' }} onClick={() => startEdit(item)}>Edit</button>
                        <button 
                          className={`btn ${item.isAvailable ? 'btn-danger' : 'btn-success'}`} 
                          style={{ padding: '4px 8px', fontSize: '12px' }} 
                          onClick={() => toggleAvailability(item)}
                        >
                          {item.isAvailable ? 'Disable' : 'Enable'}
                        </button>
                      </>
                    )}
                  </div>
                </td>
              </tr>
            ))}
            {items.length === 0 && (
              <tr>
                <td colSpan="5" style={{ textAlign: 'center' }}>No items in catalog</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default CatalogManage;
