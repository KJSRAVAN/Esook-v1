const CART_KEY = 'esook_cart';

export const getCart = () => {
  const data = localStorage.getItem(CART_KEY);
  return data ? JSON.parse(data) : { storeId: null, items: [] };
};

export const saveCart = (cart) => {
  localStorage.setItem(CART_KEY, JSON.stringify(cart));
};

export const clearCart = () => {
  localStorage.removeItem(CART_KEY);
};

export const addItem = (storeId, item) => {
  let cart = getCart();
  
  if (cart.storeId && cart.storeId !== storeId) {
    if (!window.confirm('This will clear your cart from the current store. Continue?')) {
      return false;
    }
    cart = { storeId, items: [] };
  }
  
  cart.storeId = storeId;
  const existingItem = cart.items.find(i => i.itemId === item.itemId);
  
  if (existingItem) {
    existingItem.quantity += 1;
  } else {
    cart.items.push({ ...item, quantity: 1 });
  }
  
  saveCart(cart);
  return true;
};

export const removeItem = (itemId) => {
  let cart = getCart();
  cart.items = cart.items.filter(i => i.itemId !== itemId);
  if (cart.items.length === 0) {
    cart.storeId = null;
  }
  saveCart(cart);
};

export const updateQuantity = (itemId, qty) => {
  let cart = getCart();
  const item = cart.items.find(i => i.itemId === itemId);
  if (item) {
    item.quantity = qty;
    if (item.quantity <= 0) {
      removeItem(itemId);
      return;
    }
  }
  saveCart(cart);
};
