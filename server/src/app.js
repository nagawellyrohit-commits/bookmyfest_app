import express from 'express';
import cors from 'cors';
import authRoutes from './routes/authRoutes.js';
import eventRoutes from './routes/eventRoutes.js';
import registrationRoutes from './routes/registrationRoutes.js';
import attendanceRoutes from './routes/attendanceRoutes.js';
import certificateRoutes from './routes/certificateRoutes.js';
import adminRoutes from './routes/adminRoutes.js';

const app = express();

// Standard middleware
app.use(cors());
app.use(express.json());

// Root health API
app.get('/api/health', (req, res) => {
  res.status(200).json({ status: 'ok', message: 'CollegeConnect API is running smoothly' });
});

// Route registries
app.use('/api/auth', authRoutes);
app.use('/api/events', eventRoutes);
app.use('/api/events', registrationRoutes);
app.use('/api/events', attendanceRoutes);
app.use('/api/events', certificateRoutes);
app.use('/api/admin', adminRoutes);

// Catch-all 404 route
app.use((req, res) => {
  res.status(404).json({ message: 'Requested API endpoint not found' });
});

// Centralized error middleware
app.use((err, req, res, next) => {
  console.error('Unhandled Error:', err);
  const status = err.status || 500;
  res.status(status).json({
    success: false,
    message: err.message || 'Internal Server Error',
    error: process.env.NODE_ENV === 'development' ? err.stack : undefined
  });
});

export default app;
