import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { getCatalog } from '../../api/catalog';
import { addItem, getCart } from '../../cart';
import LoadingSpinner from '../../components/LoadingSpinner';
import ErrorMessage from '../../components/ErrorMessage';

const Catalog = () => {
  const { storeId } = useParams();
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [cartCount, setCartCount] = useState(0);
  const storeName = sessionStorage.getItem('currentStoreName') || 'Store';
  const navigate = useNavigate();

  useEffect(() => {
    updateCartCount();
    fetchCatalog();
  }, [storeId]);

  const updateCartCount = () => {
    const cart = getCart();
    const count = cart.items.reduce((sum, i) => sum + i.quantity, 0);
    setCartCount(count);
  };

  const fetchCatalog = async () => {
    try {
      const res = await getCatalog(storeId);
      // Customer only sees available items
      setItems(res.data.filter(item => item.isAvailable));
      setLoading(false);
    } catch (err) {
      setError('Failed to load catalog');
      setLoading(false);
    }
  };

  const handleAddToCart = (item) => {
    const added = addItem(storeId, { itemId: item.id, name: item.name, price: item.price });
    if (added) {
      updateCartCount();
    }
  };

  if (loading) return <LoadingSpinner />;

  return (
    <div className="container">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
        <h2>{storeName} Catalog</h2>
        <button className="btn btn-primary" onClick={() => navigate('/cart')}>
          View Cart ({cartCount})
        </button>
      </div>
      
      <ErrorMessage message={error} />
      
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(250px, 1fr))', gap: '20px' }}>
        {items.map(item => (
          <div key={item.id} className="card" style={{ display: 'flex', flexDirection: 'column' }}>
            <h3>{item.name}</h3>
            {item.description && <p style={{ color: '#666', fontSize: '14px', flex: 1 }}>{item.description}</p>}
            <div style={{ marginTop: 'auto', paddingTop: '15px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontWeight: 'bold' }}>AED {Number(item.price).toFixed(2)}</span>
              <button className="btn btn-success" onClick={() => handleAddToCart(item)}>Add to Cart</button>
            </div>
          </div>
        ))}
        {items.length === 0 && <p>No items available right now.</p>}
      </div>
    </div>
  );
};

export default Catalog;
