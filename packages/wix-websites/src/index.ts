import cors from 'cors';
import dotenv from 'dotenv';
import express from 'express';
import helmet from 'helmet';

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Routes
app.get('/', (req: express.Request, res: express.Response) => {
  res.json({
    message: 'Wix Studio Agency - Client Websites API',
    version: '1.0.0',
    status: 'healthy'
  });
});

app.get('/health', (req: express.Request, res: express.Response) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Wix Integration Routes (placeholder for now)
app.get('/api/wix/products', async (req: express.Request, res: express.Response) => {
  try {
    // TODO: Implement Wix SDK integration
    res.json({
      success: true,
      products: [],
      message: 'Wix SDK integration will be implemented here'
    });
  } catch (error) {
    console.error('Error fetching products:', error);
    res.status(500).json({ success: false, error: 'Failed to fetch products' });
  }
});

app.get('/api/wix/collections', async (req: express.Request, res: express.Response) => {
  try {
    // TODO: Implement Wix SDK integration
    res.json({
      success: true,
      collections: [],
      message: 'Wix SDK integration will be implemented here'
    });
  } catch (error) {
    console.error('Error fetching collections:', error);
    res.status(500).json({ success: false, error: 'Failed to fetch collections' });
  }
});

// Error handling middleware
app.use((err: Error, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Something went wrong!' });
});

// Start server
app.listen(port, () => {
  console.log(`🚀 Wix Websites API server running on port ${port}`);
  console.log(`📍 Health check: http://localhost:${port}/health`);
});

export default app;
