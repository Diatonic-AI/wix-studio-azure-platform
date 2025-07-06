import { ResourceManagementClient } from '@azure/arm-resources';
import { DefaultAzureCredential } from '@azure/identity';
import cors from 'cors';
import dotenv from 'dotenv';
import express from 'express';
import helmet from 'helmet';

dotenv.config();

const app = express();
const port = process.env.PORT || 3002;

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Azure credentials
const credential = new DefaultAzureCredential();
const subscriptionId = process.env.AZURE_SUBSCRIPTION_ID || '';

// Routes
app.get('/', (req: express.Request, res: express.Response) => {
  res.json({
    message: 'Wix Studio Agency - API Services',
    version: '1.0.0',
    status: 'healthy',
    services: [
      'Azure Resource Management',
      'Client Management',
      'Project Deployment',
      'Monitoring & Analytics'
    ]
  });
});

app.get('/health', (req: express.Request, res: express.Response) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    azure: {
      connected: !!subscriptionId,
      subscriptionId: subscriptionId ? `${subscriptionId.substring(0, 8)}...` : 'not-configured'
    }
  });
});

// Azure Resource Management
app.get('/api/azure/resources', async (req: express.Request, res: express.Response): Promise<void> => {
  try {
    if (!subscriptionId) {
      res.status(400).json({
        success: false,
        error: 'Azure subscription ID not configured'
      });
      return;
    }

    const resourceClient = new ResourceManagementClient(credential, subscriptionId);
    const resources = [];

    for await (const resource of resourceClient.resources.list()) {
      resources.push({
        id: resource.id,
        name: resource.name,
        type: resource.type,
        location: resource.location
      });
    }

    res.json({ success: true, resources, count: resources.length });
  } catch (error) {
    console.error('Error fetching Azure resources:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch Azure resources'
    });
  }
});

// Client Management
app.get('/api/clients', (req: express.Request, res: express.Response) => {
  // Mock data for now - replace with actual database
  const clients = [
    {
      id: 1,
      name: "Sample Client",
      status: "active",
      projects: 2,
      lastUpdated: new Date().toISOString()
    }
  ];

  res.json({ success: true, clients });
});

// Project Management
app.get('/api/projects', (req: express.Request, res: express.Response) => {
  // Mock data for now - replace with actual database
  const projects = [
    {
      id: 1,
      name: "Client Website",
      client: "Sample Client",
      status: "development",
      technology: "Wix Studio",
      deployment: "pending"
    }
  ];

  res.json({ success: true, projects });
});

// Error handling middleware
app.use((err: Error, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Something went wrong!' });
});

app.listen(port, () => {
  console.log(`🚀 API Services server running on port ${port}`);
  console.log(`📍 Health check: http://localhost:${port}/health`);
  console.log(`☁️  Azure subscription: ${subscriptionId ? 'configured' : 'not configured'}`);
});

export default app;
