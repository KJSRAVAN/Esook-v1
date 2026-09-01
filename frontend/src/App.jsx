import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import Navbar from './components/Navbar';
import ProtectedRoute from './components/ProtectedRoute';

import CustomerLogin from './pages/customer/CustomerLogin';
import StoreSelect from './pages/customer/StoreSelect';
import Catalog from './pages/customer/Catalog';
import Cart from './pages/customer/Cart';
import OrderList from './pages/customer/OrderList';
import OrderDetail from './pages/customer/OrderDetail';

import StaffLogin from './pages/staff/StaffLogin';
import OrderQueue from './pages/staff/OrderQueue';

import ManagerLogin from './pages/manager/ManagerLogin';
import CatalogManage from './pages/manager/CatalogManage';

import AdminLogin from './pages/admin/AdminLogin';
import AdminDashboard from './pages/admin/AdminDashboard';
import CreateManager from './pages/admin/CreateManager';

const RootRedirect = () => {
  const { isAuthenticated, user } = useAuth();
  if (isAuthenticated && user?.role === 'CUSTOMER') return <Navigate to="/stores" replace />;
  return <CustomerLogin />;
};

const AppRoutes = () => {
  return (
    <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      <Navbar />
      <div style={{ flex: 1 }}>
        <Routes>
          {/* Customer Public/Auth */}
          <Route path="/" element={<RootRedirect />} />
          
          {/* Customer Protected */}
          <Route path="/stores" element={<ProtectedRoute roles={['CUSTOMER']}><StoreSelect /></ProtectedRoute>} />
          <Route path="/store/:storeId" element={<ProtectedRoute roles={['CUSTOMER']}><Catalog /></ProtectedRoute>} />
          <Route path="/cart" element={<ProtectedRoute roles={['CUSTOMER']}><Cart /></ProtectedRoute>} />
          <Route path="/orders" element={<ProtectedRoute roles={['CUSTOMER']}><OrderList /></ProtectedRoute>} />
          <Route path="/orders/:orderId" element={<ProtectedRoute roles={['CUSTOMER']}><OrderDetail /></ProtectedRoute>} />
          
          {/* Staff Routes */}
          <Route path="/staff/login" element={<StaffLogin />} />
          <Route path="/staff/orders" element={<ProtectedRoute roles={['STAFF', 'MANAGER']}><OrderQueue /></ProtectedRoute>} />
          
          {/* Manager Routes */}
          <Route path="/manager/login" element={<ManagerLogin />} />
          <Route path="/manager/catalog" element={<ProtectedRoute roles={['MANAGER']}><CatalogManage /></ProtectedRoute>} />
          
          {/* Admin Routes */}
          <Route path="/admin/login" element={<AdminLogin />} />
          <Route path="/admin/dashboard" element={<ProtectedRoute roles={['SUPER_ADMIN']}><AdminDashboard /></ProtectedRoute>} />
          <Route path="/admin/managers" element={<ProtectedRoute roles={['SUPER_ADMIN']}><CreateManager /></ProtectedRoute>} />
        </Routes>
      </div>
    </div>
  );
};

const App = () => (
  <AuthProvider>
    <BrowserRouter>
      <AppRoutes />
    </BrowserRouter>
  </AuthProvider>
);

export default App;
