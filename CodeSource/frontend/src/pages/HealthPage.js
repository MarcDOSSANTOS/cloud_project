import React, { useState, useEffect } from 'react';
import api from '../services/api';

function HealthPage() {
  const [services, setServices] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    checkHealth();
    const interval = setInterval(checkHealth, 30000); // Rafraîchir toutes les 30s
    return () => clearInterval(interval);
  }, []);

  const checkHealth = async () => {
    try {
      const response = await api.get('/health');
      setServices(response.data.services || []);
    } catch (err) {
      setServices([
        { name: 'API Gateway', status: 'down' },
        { name: 'User Service', status: 'unknown' },
        { name: 'Product Service', status: 'unknown' },
        { name: 'Order Service', status: 'unknown' },
        { name: 'PostgreSQL', status: 'unknown' },
        { name: 'Redis', status: 'unknown' },
        { name: 'RabbitMQ', status: 'unknown' },
      ]);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="loading">
        <div className="spinner"></div>
      </div>
    );
  }

  return (
    <div className="container">
      <h2><i className="fas fa-heartbeat"></i> État des Services</h2>
      <p style={{ color: '#666', marginBottom: '1.5rem' }}>
        Surveillance en temps réel de l'infrastructure TechShop
      </p>

      <div className="health-status">
        {services.map((service, idx) => (
          <div key={idx} className="service">
            <div>
              <strong>{service.name}</strong>
              {service.response_time && (
                <span style={{ color: '#666', marginLeft: '0.5rem', fontSize: '0.85rem' }}>
                  ({service.response_time}ms)
                </span>
              )}
            </div>
            <span className={`status-badge ${service.status === 'up' ? 'up' : 'down'}`}>
              {service.status === 'up' ? '● En ligne' : '● Hors ligne'}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}

export default HealthPage;
