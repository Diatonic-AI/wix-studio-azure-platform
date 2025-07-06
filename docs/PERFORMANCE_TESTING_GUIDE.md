# AI-Powered Performance Testing & Monitoring

This document outlines the performance testing and monitoring strategies integrated into the CI/CD pipeline.

## Performance Testing Strategy

### 1. Load Testing with Azure Load Testing

#### Configuration Files

```yaml
# load-test-config.yaml
version: v0.1
testId: wix-platform-load-test
displayName: "Wix Platform Load Test"
description: "Comprehensive load test for all services"

appComponents:
  api-services:
    resourceId: /subscriptions/{subscription}/resourceGroups/{rg}/providers/Microsoft.Web/sites/{api-service}
  wix-websites:
    resourceId: /subscriptions/{subscription}/resourceGroups/{rg}/providers/Microsoft.Web/sites/{wix-websites}
  internal-tools:
    resourceId: /subscriptions/{subscription}/resourceGroups/{rg}/providers/Microsoft.Web/sites/{internal-tools}
  microservices:
    resourceId: /subscriptions/{subscription}/resourceGroups/{rg}/providers/Microsoft.App/containerApps/{microservices}

testPlan: load-test.jmx
configurationFiles:
  - load-test-variables.csv
  - user-properties.properties

failureCriteria:
  - avg(response_time_ms) > 2000
  - percentage(error) > 5
  - avg(latency) > 1000

autoStop:
  autoStopDisabled: false
  errorRate: 90.0
  errorRateTimeWindowInSeconds: 60
```

#### JMeter Test Plan

```xml
<!-- load-test.jmx -->
<?xml version="1.0" encoding="UTF-8"?>
<jmeterTestPlan version="1.2">
  <hashTree>
    <TestPlan guiclass="TestPlanGui" testclass="TestPlan" testname="Wix Platform Load Test">
      <stringProp name="TestPlan.comments">Comprehensive load test for Wix Platform</stringProp>
      <boolProp name="TestPlan.functional_mode">false</boolProp>
      <boolProp name="TestPlan.tearDown_on_shutdown">true</boolProp>
      <boolProp name="TestPlan.serialize_threadgroups">false</boolProp>
      
      <elementProp name="TestPlan.arguments" elementType="Arguments" guiclass="ArgumentsPanel">
        <collectionProp name="Arguments.arguments">
          <elementProp name="API_HOST" elementType="Argument">
            <stringProp name="Argument.name">API_HOST</stringProp>
            <stringProp name="Argument.value">${__P(API_HOST,localhost:3001)}</stringProp>
          </elementProp>
          <elementProp name="WIX_HOST" elementType="Argument">
            <stringProp name="Argument.name">WIX_HOST</stringProp>
            <stringProp name="Argument.value">${__P(WIX_HOST,localhost:3002)}</stringProp>
          </elementProp>
          <elementProp name="USERS" elementType="Argument">
            <stringProp name="Argument.name">USERS</stringProp>
            <stringProp name="Argument.value">${__P(USERS,50)}</stringProp>
          </elementProp>
          <elementProp name="RAMP_TIME" elementType="Argument">
            <stringProp name="Argument.name">RAMP_TIME</stringProp>
            <stringProp name="Argument.value">${__P(RAMP_TIME,300)}</stringProp>
          </elementProp>
          <elementProp name="DURATION" elementType="Argument">
            <stringProp name="Argument.name">DURATION</stringProp>
            <stringProp name="Argument.value">${__P(DURATION,600)}</stringProp>
          </elementProp>
        </collectionProp>
      </elementProp>
    </TestPlan>
    
    <hashTree>
      <!-- Thread Groups for different scenarios -->
      
      <!-- API Services Load Test -->
      <ThreadGroup guiclass="ThreadGroupGui" testclass="ThreadGroup" testname="API Services Load">
        <stringProp name="ThreadGroup.on_sample_error">continue</stringProp>
        <elementProp name="ThreadGroup.main_controller" elementType="LoopController">
          <boolProp name="LoopController.continue_forever">false</boolProp>
          <stringProp name="LoopController.loops">-1</stringProp>
        </elementProp>
        <stringProp name="ThreadGroup.num_threads">${USERS}</stringProp>
        <stringProp name="ThreadGroup.ramp_time">${RAMP_TIME}</stringProp>
        <longProp name="ThreadGroup.start_time">1699875600000</longProp>
        <longProp name="ThreadGroup.end_time">1699875600000</longProp>
        <boolProp name="ThreadGroup.scheduler">true</boolProp>
        <stringProp name="ThreadGroup.duration">${DURATION}</stringProp>
        <stringProp name="ThreadGroup.delay"></stringProp>
        <boolProp name="ThreadGroup.same_user_on_next_iteration">true</boolProp>
      </ThreadGroup>
      
      <hashTree>
        <!-- HTTP Request Defaults -->
        <ConfigTestElement guiclass="HttpDefaultsGui" testclass="ConfigTestElement" testname="HTTP Request Defaults">
          <elementProp name="HTTPsampler.Arguments" elementType="Arguments">
            <collectionProp name="Arguments.arguments"/>
          </elementProp>
          <stringProp name="HTTPSampler.domain">${API_HOST}</stringProp>
          <stringProp name="HTTPSampler.port">443</stringProp>
          <stringProp name="HTTPSampler.protocol">https</stringProp>
          <stringProp name="HTTPSampler.contentEncoding"></stringProp>
          <stringProp name="HTTPSampler.path"></stringProp>
          <stringProp name="HTTPSampler.implementation">HttpClient4</stringProp>
          <stringProp name="HTTPSampler.connect_timeout">10000</stringProp>
          <stringProp name="HTTPSampler.response_timeout">30000</stringProp>
        </ConfigTestElement>
        
        <!-- Test Scenarios -->
        
        <!-- Health Check -->
        <HTTPSamplerProxy guiclass="HttpTestSampleGui" testclass="HTTPSamplerProxy" testname="Health Check">
          <elementProp name="HTTPsampler.Arguments" elementType="Arguments">
            <collectionProp name="Arguments.arguments"/>
          </elementProp>
          <stringProp name="HTTPSampler.domain"></stringProp>
          <stringProp name="HTTPSampler.port"></stringProp>
          <stringProp name="HTTPSampler.protocol"></stringProp>
          <stringProp name="HTTPSampler.contentEncoding"></stringProp>
          <stringProp name="HTTPSampler.path">/health</stringProp>
          <stringProp name="HTTPSampler.method">GET</stringProp>
          <boolProp name="HTTPSampler.follow_redirects">true</boolProp>
          <boolProp name="HTTPSampler.auto_redirects">false</boolProp>
          <boolProp name="HTTPSampler.use_keepalive">true</boolProp>
          <boolProp name="HTTPSampler.DO_MULTIPART_POST">false</boolProp>
          <stringProp name="HTTPSampler.embedded_url_re"></stringProp>
          <stringProp name="HTTPSampler.connect_timeout"></stringProp>
          <stringProp name="HTTPSampler.response_timeout"></stringProp>
        </HTTPSamplerProxy>
        
        <!-- Response Assertion -->
        <ResponseAssertion guiclass="AssertionGui" testclass="ResponseAssertion" testname="Health Check Assertion">
          <collectionProp name="Asserion.test_strings">
            <stringProp name="49586">200</stringProp>
          </collectionProp>
          <stringProp name="Assertion.custom_message"></stringProp>
          <stringProp name="Assertion.test_field">Assertion.response_code</stringProp>
          <boolProp name="Assertion.assume_success">false</boolProp>
          <intProp name="Assertion.test_type">1</intProp>
        </ResponseAssertion>
        
        <!-- Duration Assertion -->
        <DurationAssertion guiclass="DurationAssertionGui" testclass="DurationAssertion" testname="Response Time Assertion">
          <stringProp name="DurationAssertion.duration">2000</stringProp>
        </DurationAssertion>
        
        <!-- Think Time -->
        <UniformRandomTimer guiclass="UniformRandomTimerGui" testclass="UniformRandomTimer" testname="Think Time">
          <stringProp name="ConstantTimer.delay">1000</stringProp>
          <stringProp name="RandomTimer.range">2000</stringProp>
        </UniformRandomTimer>
      </hashTree>
    </hashTree>
  </hashTree>
</jmeterTestPlan>
```

### 2. Automated Performance Testing in CI/CD

```yaml
# Performance testing workflow step
- name: 🚀 Performance Testing
  if: github.ref == 'refs/heads/main'
  run: |
    # Install Azure Load Testing CLI
    az extension add --name load
    
    # Create load test
    az load test create \
      --test-id "wix-platform-perf-test" \
      --display-name "Wix Platform Performance Test" \
      --description "Automated performance test from CI/CD" \
      --load-test-resource ${{ secrets.AZURE_LOAD_TESTING_RESOURCE }} \
      --resource-group ${{ secrets.AZURE_RESOURCE_GROUP }}
    
    # Upload test files
    az load test file upload \
      --test-id "wix-platform-perf-test" \
      --load-test-resource ${{ secrets.AZURE_LOAD_TESTING_RESOURCE }} \
      --resource-group ${{ secrets.AZURE_RESOURCE_GROUP }} \
      --path "./tests/performance/load-test.jmx"
    
    # Run load test
    az load test run \
      --test-id "wix-platform-perf-test" \
      --load-test-resource ${{ secrets.AZURE_LOAD_TESTING_RESOURCE }} \
      --resource-group ${{ secrets.AZURE_RESOURCE_GROUP }} \
      --parameters API_HOST=${{ steps.deploy.outputs.api_url }} \
      --parameters WIX_HOST=${{ steps.deploy.outputs.wix_url }} \
      --parameters USERS=100 \
      --parameters RAMP_TIME=300 \
      --parameters DURATION=600
```

## Application Performance Monitoring

### 1. Azure Application Insights Integration

```typescript
// Application Insights configuration
import { ApplicationInsights } from '@azure/monitor-opentelemetry-node';

// Initialize Application Insights
ApplicationInsights.setup()
  .setDistributedTracingMode(ApplicationInsights.DistributedTracingModes.AI_AND_W3C)
  .enableWebInstrumentation(false)
  .start();

// Custom telemetry tracking
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { NodeSDK } from '@opentelemetry/sdk-node';
import { Resource } from '@opentelemetry/resources';
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions';

const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: process.env.SERVICE_NAME || 'wix-platform',
    [SemanticResourceAttributes.SERVICE_VERSION]: process.env.SERVICE_VERSION || '1.0.0',
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();

// Custom metrics tracking
export class PerformanceTracker {
  private static client = ApplicationInsights.defaultClient;
  
  static trackDependency(name: string, duration: number, success: boolean) {
    this.client.trackDependency({
      name,
      duration,
      success,
      dependencyTypeName: 'HTTP',
      target: name
    });
  }
  
  static trackCustomEvent(name: string, properties?: any, measurements?: any) {
    this.client.trackEvent({
      name,
      properties,
      measurements
    });
  }
  
  static trackPerformanceCounter(name: string, value: number) {
    this.client.trackMetric({
      name,
      value
    });
  }
}

// Performance middleware for Express
export function performanceMiddleware(req: Request, res: Response, next: NextFunction) {
  const startTime = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    
    PerformanceTracker.trackDependency(
      `${req.method} ${req.path}`,
      duration,
      res.statusCode < 400
    );
    
    PerformanceTracker.trackCustomEvent('HttpRequest', {
      method: req.method,
      path: req.path,
      statusCode: res.statusCode,
      userAgent: req.headers['user-agent']
    }, {
      duration,
      responseSize: res.get('content-length') || 0
    });
  });
  
  next();
}
```

### 2. Real User Monitoring (RUM)

```typescript
// Frontend performance monitoring
class FrontendPerformanceMonitor {
  private appInsights: ApplicationInsights;
  
  constructor(instrumentationKey: string) {
    this.appInsights = new ApplicationInsights({
      config: {
        instrumentationKey,
        enableAutoRouteTracking: true,
        enableRequestHeaderTracking: true,
        enableResponseHeaderTracking: true,
        enableAjaxErrorStatusText: true,
        enableAjaxPerfTracking: true,
        enableUnhandledPromiseRejectionTracking: true
      }
    });
    
    this.appInsights.loadAppInsights();
    this.initializePerformanceTracking();
  }
  
  private initializePerformanceTracking() {
    // Track Core Web Vitals
    this.trackWebVitals();
    
    // Track custom performance metrics
    this.trackCustomMetrics();
    
    // Track user interactions
    this.trackUserInteractions();
  }
  
  private trackWebVitals() {
    // First Contentful Paint
    new PerformanceObserver((list) => {
      for (const entry of list.getEntries()) {
        this.appInsights.trackMetric({
          name: 'FirstContentfulPaint',
          value: entry.startTime
        });
      }
    }).observe({ entryTypes: ['paint'] });
    
    // Largest Contentful Paint
    new PerformanceObserver((list) => {
      const entries = list.getEntries();
      const lastEntry = entries[entries.length - 1];
      this.appInsights.trackMetric({
        name: 'LargestContentfulPaint',
        value: lastEntry.startTime
      });
    }).observe({ entryTypes: ['largest-contentful-paint'] });
    
    // Cumulative Layout Shift
    let clsValue = 0;
    new PerformanceObserver((list) => {
      for (const entry of list.getEntries()) {
        if (!entry.hadRecentInput) {
          clsValue += entry.value;
        }
      }
      this.appInsights.trackMetric({
        name: 'CumulativeLayoutShift',
        value: clsValue
      });
    }).observe({ entryTypes: ['layout-shift'] });
  }
  
  private trackCustomMetrics() {
    // API response times
    const originalFetch = window.fetch;
    window.fetch = async (...args) => {
      const startTime = performance.now();
      try {
        const response = await originalFetch(...args);
        const duration = performance.now() - startTime;
        
        this.appInsights.trackDependency({
          name: args[0].toString(),
          duration,
          success: response.ok,
          dependencyTypeName: 'Fetch'
        });
        
        return response;
      } catch (error) {
        const duration = performance.now() - startTime;
        this.appInsights.trackDependency({
          name: args[0].toString(),
          duration,
          success: false,
          dependencyTypeName: 'Fetch'
        });
        throw error;
      }
    };
  }
  
  private trackUserInteractions() {
    // Track button clicks
    document.addEventListener('click', (event) => {
      const target = event.target as HTMLElement;
      if (target.tagName === 'BUTTON' || target.closest('button')) {
        this.appInsights.trackEvent({
          name: 'ButtonClick',
          properties: {
            buttonText: target.textContent?.trim(),
            buttonId: target.id,
            page: window.location.pathname
          }
        });
      }
    });
    
    // Track page views
    this.appInsights.trackPageView({
      name: document.title,
      uri: window.location.href
    });
  }
}
```

## Performance Alerting and Dashboards

### 1. Azure Monitor Alerts

```bicep
// Performance alert rules
resource performanceAlerts 'Microsoft.Insights/metricAlerts@2018-03-01' = [for alert in performanceAlertRules: {
  name: alert.name
  location: 'global'
  properties: {
    description: alert.description
    severity: alert.severity
    enabled: true
    scopes: [
      appServicePlan.id
      appService.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'Metric1'
          metricNamespace: alert.metricNamespace
          metricName: alert.metricName
          operator: alert.operator
          threshold: alert.threshold
          timeAggregation: alert.timeAggregation
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}]

var performanceAlertRules = [
  {
    name: 'high-response-time'
    description: 'Alert when average response time exceeds 2 seconds'
    severity: 2
    metricNamespace: 'Microsoft.Web/sites'
    metricName: 'HttpResponseTime'
    operator: 'GreaterThan'
    threshold: 2000
    timeAggregation: 'Average'
  }
  {
    name: 'high-error-rate'
    description: 'Alert when error rate exceeds 5%'
    severity: 1
    metricNamespace: 'Microsoft.Web/sites'
    metricName: 'Http5xx'
    operator: 'GreaterThan'
    threshold: 0.05
    timeAggregation: 'Average'
  }
  {
    name: 'high-cpu-usage'
    description: 'Alert when CPU usage exceeds 80%'
    severity: 2
    metricNamespace: 'Microsoft.Web/serverfarms'
    metricName: 'CpuPercentage'
    operator: 'GreaterThan'
    threshold: 80
    timeAggregation: 'Average'
  }
  {
    name: 'high-memory-usage'
    description: 'Alert when memory usage exceeds 85%'
    severity: 2
    metricNamespace: 'Microsoft.Web/serverfarms'
    metricName: 'MemoryPercentage'
    operator: 'GreaterThan'
    threshold: 85
    timeAggregation: 'Average'
  }
]
```

### 2. Custom Dashboard Configuration

```json
{
  "properties": {
    "lenses": {
      "0": {
        "order": 0,
        "parts": {
          "0": {
            "position": {
              "x": 0,
              "y": 0,
              "colSpan": 6,
              "rowSpan": 4
            },
            "metadata": {
              "inputs": [
                {
                  "name": "options",
                  "value": {
                    "chart": {
                      "metrics": [
                        {
                          "resourceMetadata": {
                            "id": "/subscriptions/{subscription-id}/resourceGroups/{rg}/providers/Microsoft.Web/sites/{app-name}"
                          },
                          "name": "HttpResponseTime",
                          "aggregationType": {
                            "type": "Average"
                          },
                          "namespace": "Microsoft.Web/sites",
                          "metricVisualization": {
                            "displayName": "Response Time"
                          }
                        }
                      ],
                      "title": "Average Response Time",
                      "titleKind": 1,
                      "visualization": {
                        "chartType": 2
                      },
                      "timespan": {
                        "relative": {
                          "duration": 86400000
                        }
                      }
                    }
                  }
                }
              ],
              "type": "Extension/HubsExtension/PartType/MonitorChartPart"
            }
          }
        }
      }
    }
  }
}
```

## Continuous Performance Optimization

### 1. Automated Performance Regression Detection

```typescript
// Performance regression detection
export class PerformanceRegressionDetector {
  private readonly REGRESSION_THRESHOLD = 0.15; // 15% regression threshold
  
  async detectRegressions(currentMetrics: PerformanceMetrics, baselineMetrics: PerformanceMetrics): Promise<RegressionReport> {
    const regressions: PerformanceRegression[] = [];
    
    // Check response time regression
    const responseTimeRegression = this.calculateRegression(
      currentMetrics.averageResponseTime,
      baselineMetrics.averageResponseTime
    );
    
    if (responseTimeRegression > this.REGRESSION_THRESHOLD) {
      regressions.push({
        metric: 'Response Time',
        currentValue: currentMetrics.averageResponseTime,
        baselineValue: baselineMetrics.averageResponseTime,
        regressionPercentage: responseTimeRegression,
        severity: this.getSeverity(responseTimeRegression)
      });
    }
    
    // Check throughput regression
    const throughputRegression = this.calculateRegression(
      baselineMetrics.throughput, // Inverted for throughput
      currentMetrics.throughput
    );
    
    if (throughputRegression > this.REGRESSION_THRESHOLD) {
      regressions.push({
        metric: 'Throughput',
        currentValue: currentMetrics.throughput,
        baselineValue: baselineMetrics.throughput,
        regressionPercentage: throughputRegression,
        severity: this.getSeverity(throughputRegression)
      });
    }
    
    return {
      hasRegressions: regressions.length > 0,
      regressions,
      summary: this.generateSummary(regressions)
    };
  }
  
  private calculateRegression(current: number, baseline: number): number {
    return (current - baseline) / baseline;
  }
  
  private getSeverity(regressionPercentage: number): 'Low' | 'Medium' | 'High' | 'Critical' {
    if (regressionPercentage > 0.5) return 'Critical';
    if (regressionPercentage > 0.3) return 'High';
    if (regressionPercentage > 0.2) return 'Medium';
    return 'Low';
  }
  
  private generateSummary(regressions: PerformanceRegression[]): string {
    if (regressions.length === 0) {
      return 'No performance regressions detected.';
    }
    
    const criticalCount = regressions.filter(r => r.severity === 'Critical').length;
    const highCount = regressions.filter(r => r.severity === 'High').length;
    
    return `Detected ${regressions.length} performance regression(s): ${criticalCount} critical, ${highCount} high severity.`;
  }
}
```

### 2. Performance Budget Enforcement

```json
{
  "performanceBudgets": {
    "api-services": {
      "responseTime": {
        "p50": 500,
        "p95": 1000,
        "p99": 2000
      },
      "throughput": {
        "min": 1000
      },
      "errorRate": {
        "max": 0.01
      }
    },
    "wix-websites": {
      "responseTime": {
        "p50": 800,
        "p95": 1500,
        "p99": 3000
      },
      "firstContentfulPaint": {
        "max": 1500
      },
      "largestContentfulPaint": {
        "max": 2500
      }
    },
    "internal-tools": {
      "responseTime": {
        "p50": 300,
        "p95": 800,
        "p99": 1500
      },
      "bundleSize": {
        "max": 2048
      }
    }
  }
}
```

This comprehensive performance testing and monitoring setup provides:

1. **Automated Load Testing** - Integrated with Azure Load Testing for CI/CD
2. **Real-time Monitoring** - Application Insights for backend and frontend
3. **Performance Alerting** - Automated alerts for regressions and issues
4. **Regression Detection** - AI-powered performance regression analysis
5. **Performance Budgets** - Enforced performance standards
6. **Custom Dashboards** - Visual monitoring and reporting

The system ensures that performance is continuously monitored and any degradations are caught early in the development cycle.
