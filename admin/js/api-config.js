/**
 * REST API & Native JWT Configuration for Admin Portal
 * Replaces Firebase SDK & Firestore calls with backend REST endpoints
 */
const API_BASE_URL = 'http://abuad-backend-elfz.onrender.com/api';

class ApiClientAdmin {
  static getAccessToken() {
    return localStorage.getItem('accessToken');
  }

  static getRefreshToken() {
    return localStorage.getItem('refreshToken');
  }

  static setTokens(accessToken, refreshToken, user) {
    if (accessToken) localStorage.setItem('accessToken', accessToken);
    if (refreshToken) localStorage.setItem('refreshToken', refreshToken);
    if (user) localStorage.setItem('currentUser', JSON.stringify(user));
  }

  static clearTokens() {
    localStorage.removeItem('accessToken');
    localStorage.removeItem('refreshToken');
    localStorage.removeItem('currentUser');
  }

  static getHeaders() {
    const token = this.getAccessToken();
    return {
      'Content-Type': 'application/json',
      ...(token ? { 'Authorization': `Bearer ${token}` } : {})
    };
  }

  static async fetch(endpoint, options = {}) {
    const headers = { ...this.getHeaders(), ...(options.headers || {}) };
    try {
      const response = await fetch(`${API_BASE_URL}${endpoint}`, {
        ...options,
        headers,
      });

      if (response.status === 401 && this.getRefreshToken()) {
        const refreshed = await this.refreshToken();
        if (refreshed) {
          const retryHeaders = { ...this.getHeaders(), ...(options.headers || {}) };
          return fetch(`${API_BASE_URL}${endpoint}`, { ...options, headers: retryHeaders });
        }
      }
      return response;
    } catch (err) {
      console.error('API Fetch Error:', err);
      throw err;
    }
  }

  static async refreshToken() {
    try {
      const refreshToken = this.getRefreshToken();
      if (!refreshToken) return false;

      const res = await fetch(`${API_BASE_URL}/auth/refresh`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refreshToken })
      });

      const data = await res.json();
      if (res.ok && data.success) {
        this.setTokens(data.data.accessToken, data.data.refreshToken);
        return true;
      }
    } catch (e) { }
    this.clearTokens();
    return false;
  }
}

// Global Auth State Mocking
window.auth = {
  currentUser: null,
  onAuthStateChangedListeners: [],

  onAuthStateChanged(callback) {
    this.onAuthStateChangedListeners.push(callback);
    const storedUser = localStorage.getItem('currentUser');
    if (storedUser) {
      try {
        this.currentUser = JSON.parse(storedUser);
        callback(this.currentUser);
      } catch (e) {
        callback(null);
      }
    } else {
      callback(null);
    }
  },

  async signInWithEmailAndPassword(email, password) {
    const res = await ApiClientAdmin.fetch('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ emailOrUsername: email, password }),
    });
    const data = await res.json();
    if (!res.ok || !data.success) {
      throw new Error(data.error || 'Authentication failed');
    }

    ApiClientAdmin.setTokens(data.data.accessToken, data.data.refreshToken, data.data.user);
    this.currentUser = data.data.user;
    this.onAuthStateChangedListeners.forEach(cb => cb(this.currentUser));
    return { user: this.currentUser };
  },

  async signOut() {
    try {
      await ApiClientAdmin.fetch('/auth/logout', { method: 'POST' });
    } catch (e) { }
    ApiClientAdmin.clearTokens();
    this.currentUser = null;
    this.onAuthStateChangedListeners.forEach(cb => cb(null));
  }
};

// Fluent Query Builder Mock for legacy admin controller queries
class QueryMock {
  constructor(collectionName) {
    this.collectionName = collectionName;
    this.queries = [];
  }

  where(field, op, val) {
    this.queries.push({ field, op, val });
    return this;
  }

  orderBy(field, direction = 'asc') {
    return this;
  }

  limit(count) {
    return this;
  }

  getEndpoint(name) {
    const map = {
      'users': '/users',
      'posts': '/posts',
      'marketplace_items': '/marketplace',
      'marketplace': '/marketplace',
      'events': '/events',
      'stories': '/stories',
      'reports': '/admin/reports',
      'audit_logs': '/admin/audit-logs',
      'verification_requests': '/admin/verification-requests',
      'groups': '/events',
      'announcements': '/admin/announcements',
      'resources': '/admin/resources',
      'system/config': '/admin/config',
      'system': '/admin/config'
    };
    return map[name] || `/${name}`;
  }

  async get() {
    try {
      const endpoint = this.getEndpoint(this.collectionName);
      const res = await ApiClientAdmin.fetch(endpoint);
      if (!res.ok) {
        return {
          empty: true,
          size: 0,
          docs: [],
          forEach() { },
          docChanges() { return []; }
        };
      }
      const json = await res.json();
      let items = Array.isArray(json.data) ? json.data : (json.data && typeof json.data === 'object' ? [json.data] : []);

      const docs = items.map(item => ({
        id: item.id || item.uid || item.key || 'doc',
        data: () => item
      }));

      return {
        empty: docs.length === 0,
        size: docs.length,
        docs: docs,
        forEach(callback) {
          docs.forEach(callback);
        },
        docChanges() {
          return docs.map(doc => ({ type: 'added', doc }));
        }
      };
    } catch (e) {
      return {
        empty: true,
        size: 0,
        docs: [],
        forEach() { },
        docChanges() { return []; }
      };
    }
  }

  onSnapshot(callback, errorCb) {
    this.get()
      .then(result => {
        if (typeof callback === 'function') callback(result);
      })
      .catch(err => {
        if (typeof errorCb === 'function') errorCb(err);
      });
    return () => { };
  }

  async add(data) {
    const endpoint = this.getEndpoint(this.collectionName);
    const res = await ApiClientAdmin.fetch(endpoint, {
      method: 'POST',
      body: JSON.stringify(data)
    });
    const json = await res.json();
    return { id: (json.data && json.data.id) ? json.data.id : Date.now().toString() };
  }

  doc(id) {
    let endpoint = this.getEndpoint(this.collectionName);
    if (!endpoint.endsWith(`/${id}`)) {
      endpoint = `${endpoint}/${id}`;
    }

    return {
      async get() {
        try {
          const res = await ApiClientAdmin.fetch(endpoint);
          if (!res.ok) return { exists: false, id: id, data: () => ({}) };
          const json = await res.json();
          const item = json.data || null;
          return {
            exists: !!item,
            id: id,
            data: () => item || {}
          };
        } catch (e) {
          return { exists: false, id: id, data: () => ({}) };
        }
      },
      async set(data, options) {
        await ApiClientAdmin.fetch(endpoint, {
          method: 'POST',
          body: JSON.stringify(data)
        });
      },
      async update(data) {
        await ApiClientAdmin.fetch(endpoint, {
          method: 'POST',
          body: JSON.stringify(data)
        });
      },
      async delete() {
        await ApiClientAdmin.fetch(endpoint, {
          method: 'DELETE'
        });
      },
      onSnapshot(callback, errorCb) {
        this.get()
          .then(snap => {
            if (typeof callback === 'function') callback(snap);
          })
          .catch(err => {
            if (typeof errorCb === 'function') errorCb(err);
          });
        return () => { };
      }
    };
  }
}

// Global Firestore Mock Object for Admin Portal
window.db = {
  collection(name) {
    return new QueryMock(name);
  },
  batch() {
    return {
      update(docRef, data) { },
      set(docRef, data) { },
      delete(docRef) { },
      async commit() { }
    };
  }
};
