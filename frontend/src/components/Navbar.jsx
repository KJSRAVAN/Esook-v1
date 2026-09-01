import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

const Navbar = () => {
  const { user, logout, isAuthenticated } = useAuth();
  const location = useLocation();

  if (!isAuthenticated || location.pathname.includes('/login') || location.pathname === '/') return null;

  return (
    <nav className="navbar">
      <div style={{ fontWeight: 'bold', fontSize: '1.25rem' }}>
        {user?.role === 'CUSTOMER' && <Link to="/stores" style={{textDecoration:'none', color:'inherit'}}>Esook</Link>}
        {(user?.role === 'STAFF' || user?.role === 'MANAGER') && 'Esook Staff'}
        {user?.role === 'SUPER_ADMIN' && 'Esook Admin'}
      </div>
      
      <div style={{ display: 'flex', gap: '16px', alignItems: 'center' }}>
        {user?.role === 'CUSTOMER' && (
          <>
            <Link to="/stores">Stores</Link>
            <Link to="/orders">My Orders</Link>
            <Link to="/cart">Cart</Link>
          </>
        )}
        
        {(user?.role === 'STAFF' || user?.role === 'MANAGER') && (
          <Link to="/staff/orders">Orders</Link>
        )}
        
        {user?.role === 'MANAGER' && (
          <Link to="/manager/catalog">Catalog</Link>
        )}
        
        {user?.role === 'SUPER_ADMIN' && (
          <>
            <Link to="/admin/dashboard">Dashboard</Link>
            <Link to="/admin/managers">Managers</Link>
          </>
        )}
        
        <button onClick={logout} className="btn btn-secondary">Logout</button>
      </div>
    </nav>
  );
};

export default Navbar;
