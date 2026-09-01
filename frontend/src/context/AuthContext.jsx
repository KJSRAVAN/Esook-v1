import React, { createContext, useContext, useState, useEffect } from 'react';
import * as authApi from '../api/auth';

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [token, setToken] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const savedToken = localStorage.getItem('esook_token');
    if (savedToken) {
      setToken(savedToken);
      authApi.getMe()
        .then(res => setUser(res.data.user || res.data))
        .catch(() => {
          localStorage.removeItem('esook_token');
          setToken(null);
        })
        .finally(() => setLoading(false));
    } else {
      setLoading(false);
    }
  }, []);

  const login = async (data) => {
    const res = await authApi.login(data);
    const { token, user } = res.data;
    localStorage.setItem('esook_token', token);
    setToken(token);
    setUser(user);
    return user;
  };
  
  const register = async (data) => {
    const res = await authApi.register(data);
    const { token, user } = res.data;
    localStorage.setItem('esook_token', token);
    setToken(token);
    setUser(user);
    return user;
  };

  const logout = () => {
    localStorage.removeItem('esook_token');
    setToken(null);
    setUser(null);
    window.location.href = '/';
  };

  return (
    <AuthContext.Provider value={{ user, token, isAuthenticated: !!token, loading, login, register, logout }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => useContext(AuthContext);
