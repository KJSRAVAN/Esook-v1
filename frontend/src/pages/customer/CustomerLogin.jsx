import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../../context/AuthContext';
import ErrorMessage from '../../components/ErrorMessage';

const CustomerLogin = () => {
  const [isLogin, setIsLogin] = useState(true);
  const [formData, setFormData] = useState({ name: '', email: '', phone: '', password: '' });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const { login, register } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      if (isLogin) {
        await login({ email: formData.email, password: formData.password });
      } else {
        await register(formData);
      }
      navigate('/stores');
    } catch (err) {
      setError(err.response?.data?.message || 'Authentication failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="container" style={{ maxWidth: '400px', marginTop: '50px' }}>
      <div className="card">
        <h2 style={{ textAlign: 'center' }}>{isLogin ? 'Customer Login' : 'Create Account'}</h2>
        <ErrorMessage message={error} />
        
        <form onSubmit={handleSubmit}>
          {!isLogin && (
            <>
              <div className="form-group">
                <label>Name</label>
                <input required className="input" type="text" value={formData.name} onChange={e => setFormData({...formData, name: e.target.value})} />
              </div>
              <div className="form-group">
                <label>Phone</label>
                <input className="input" type="text" value={formData.phone} onChange={e => setFormData({...formData, phone: e.target.value})} />
              </div>
            </>
          )}
          <div className="form-group">
            <label>Email</label>
            <input required className="input" type="email" value={formData.email} onChange={e => setFormData({...formData, email: e.target.value})} />
          </div>
          <div className="form-group">
            <label>Password</label>
            <input required className="input" type="password" value={formData.password} onChange={e => setFormData({...formData, password: e.target.value})} />
          </div>
          
          <button type="submit" className="btn btn-primary" style={{ width: '100%' }} disabled={loading}>
            {loading ? 'Loading...' : (isLogin ? 'Login' : 'Register')}
          </button>
        </form>
        
        <div style={{ marginTop: '16px', textAlign: 'center' }}>
          <button className="btn btn-secondary" style={{ background: 'transparent', color: '#2563eb', padding: 0 }} onClick={() => setIsLogin(!isLogin)}>
            {isLogin ? 'Need an account? Register' : 'Already have an account? Login'}
          </button>
        </div>
      </div>
      
      <div style={{ marginTop: '40px', textAlign: 'center', fontSize: '12px', color: '#666' }}>
        <p>Demo Links:</p>
        <Link to="/staff/login" style={{ marginRight: '10px' }}>Staff Login</Link>
        <Link to="/manager/login" style={{ marginRight: '10px' }}>Manager Login</Link>
        <Link to="/admin/login">Admin Login</Link>
      </div>
    </div>
  );
};

export default CustomerLogin;
