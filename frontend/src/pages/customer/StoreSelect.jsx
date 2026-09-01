import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { getAreas, getStores } from '../../api/stores';
import LoadingSpinner from '../../components/LoadingSpinner';
import ErrorMessage from '../../components/ErrorMessage';

const StoreSelect = () => {
  const [areas, setAreas] = useState([]);
  const [stores, setStores] = useState([]);
  const [selectedArea, setSelectedArea] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const navigate = useNavigate();

  useEffect(() => {
    fetchAreasAndStores();
  }, []);

  useEffect(() => {
    fetchStores(selectedArea);
  }, [selectedArea]);

  const fetchAreasAndStores = async () => {
    try {
      const [areasRes, storesRes] = await Promise.all([getAreas(), getStores()]);
      setAreas(areasRes.data);
      setStores(storesRes.data);
      setLoading(false);
    } catch (err) {
      setError('Failed to load stores');
      setLoading(false);
    }
  };

  const fetchStores = async (areaId) => {
    try {
      const res = await getStores(areaId);
      setStores(res.data);
    } catch (err) {
      setError('Failed to load stores');
    }
  };

  const selectStore = (store) => {
    sessionStorage.setItem('currentStoreName', store.name);
    navigate(`/store/${store.id}`);
  };

  if (loading) return <LoadingSpinner />;

  return (
    <div className="container">
      <h2>Select a Store</h2>
      <ErrorMessage message={error} />
      
      <div style={{ marginBottom: '20px', display: 'flex', gap: '10px' }}>
        <button 
          className={`btn ${!selectedArea ? 'btn-primary' : 'btn-secondary'}`} 
          onClick={() => setSelectedArea('')}
        >
          All Areas
        </button>
        {areas.map(area => (
          <button 
            key={area.id}
            className={`btn ${selectedArea === area.id ? 'btn-primary' : 'btn-secondary'}`}
            onClick={() => setSelectedArea(area.id)}
          >
            {area.name}
          </button>
        ))}
      </div>
      
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(250px, 1fr))', gap: '20px' }}>
        {stores.map(store => (
          <div key={store.id} className="card" style={{ cursor: 'pointer', transition: 'transform 0.2s' }} onClick={() => selectStore(store)}>
            <h3>{store.name}</h3>
            <p style={{ color: '#666' }}>{store.area?.name}</p>
          </div>
        ))}
        {stores.length === 0 && <p>No stores available in this area.</p>}
      </div>
    </div>
  );
};

export default StoreSelect;
