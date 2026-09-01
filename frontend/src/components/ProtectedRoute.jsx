import React from 'react';
import { Navigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import LoadingSpinner from './LoadingSpinner';

const ProtectedRoute = ({ children, roles }) => {
  const { isAuthenticated, user, loading } = useAuth();

  if (loading) return <LoadingSpinner />;

  if (!isAuthenticated) {
    if (roles?.includes('STAFF')) return <Navigate to="/staff/login" replace />;
    if (roles?.includes('MANAGER')) return <Navigate to="/manager/login" replace />;
    if (roles?.includes('SUPER_ADMIN')) return <Navigate to="/admin/login" replace />;
    return <Navigate to="/" replace />;
  }

  if (roles && roles.length > 0 && !roles.includes(user?.role)) {
    return (
      <div className="container">
        <div className="alert-error">Access Denied. You do not have permission to view this page.</div>
      </div>
    );
  }

  return children;
};

export default ProtectedRoute;
