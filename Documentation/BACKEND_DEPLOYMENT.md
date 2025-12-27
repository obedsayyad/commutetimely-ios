# Backend Deployment Guide

Guide for deploying the CommuteTimely Flask server to production.

## Deployment Options

### 1. Railway (Recommended - Easiest)

**Pros:** Zero-config deployment, auto-scaling, free tier
**Cons:** Limited free tier

**Steps:**
1. Install Railway CLI:
```bash
npm install -g @railway/cli
```

2. Login and init:
```bash
railway login
cd server
railway init
```

3. Add environment variables:
```bash
railway variables set JWT_SECRET="your-production-secret"
railway variables set FIREBASE_CREDENTIALS=$(cat firebase-service-account.json | base64)
```

4. Deploy:
```bash
railway up
```

5. Get deployment URL:
```bash
railway domain
```

6. Update `Secrets.xcconfig`:
```
AUTH_SERVER_URL = https://your-app.railway.app
```

### 2. Fly.io

**Pros:** Global edge deployment, generous free tier
**Cons:** Requires Docker knowledge

**Steps:**
1. Install flyctl:
```bash
curl -L https://fly.io/install.sh | sh
```

2. Login and launch:
```bash
fly auth login
cd server
fly launch
```

3. Set secrets:
```bash
fly secrets set JWT_SECRET="your-production-secret"
```

4. Deploy:
```bash
fly deploy
```

### 3. Heroku

**Pros:** Mature platform, extensive add-ons
**Cons:** No free tier anymore

**Setup:**
```bash
heroku create commutetimely-api
heroku config:set JWT_SECRET="your-production-secret"
git subtree push --prefix server heroku main
```

### 4. Google Cloud Run

**Pros:** Auto-scaling, pay-per-use
**Cons:** More complex setup

**Steps:**
1. Build and push container:
```bash
cd server
gcloud builds submit --tag gcr.io/PROJECT_ID/commutetimely-server
```

2. Deploy:
```bash
gcloud run deploy commutetimely-server \
  --image gcr.io/PROJECT_ID/commutetimely-server \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated
```

## Production Configuration

### Environment Variables

Required:
- `JWT_SECRET` - Strong secret key for JWT signing (32+ characters)
- `FIREBASE_CREDENTIALS` - Base64 encoded service account JSON

Optional:
- `FLASK_ENV=production`
- `PORT=5000`

### Database Setup (Future)

For production, replace in-memory storage with PostgreSQL:

```python
# Example using SQLAlchemy
from sqlalchemy import create_engine
DATABASE_URL = os.environ.get('DATABASE_URL')
engine = create_engine(DATABASE_URL)
```

### CORS Configuration

Update allowed origins in `app.py`:
```python
CORS(app, origins=[
    "commutetimely://",  # iOS app
    "https://yourdomain.com"
])
```

### Security Hardening

1. **HTTPS Only:**
   - All production endpoints must use HTTPS
   - Update `AUTH_SERVER_URL` with `https://`

2. **Rate Limiting:**
```python
from flask_limiter import Limiter
limiter = Limiter(app, key_func=get_remote_address)

@app.route('/auth/email/signin')
@limiter.limit("5 per minute")
def signin():
    ...
```

3. **Input Validation:**
   - Already implemented for email/password
   - Add additional checks as needed

4. **Logging:**
```python
import logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
```

## Monitoring

### Health Checks

Endpoint: `GET /health`

Returns:
```json
{
  "status": "healthy",
  "timestamp": "2024-01-01T00:00:00Z",
  "service": "CommuteTimely Server",
  "version": "1.0.0"
}
```

### Logging

Monitor these events:
- Authentication successes/failures
- Token refresh attempts
- Cloud sync operations
- Error rates

### Alerts

Set up alerts for:
- Health check failures
- High error rates (>5%)
- Slow response times (>2s)
- Memory/CPU usage spikes

## Scaling

### Horizontal Scaling

All deployment platforms support auto-scaling. Configure based on:
- Request volume
- Response time targets
- Cost constraints

### Database Considerations

When adding persistent storage:
- Use connection pooling
- Implement caching (Redis)
- Index frequently queried fields

## Backup & Recovery

### User Data

Implement regular backups:
```bash
# Example for PostgreSQL
pg_dump $DATABASE_URL > backup-$(date +%Y%m%d).sql
```

### Firebase Service Account

- Keep secure backup of service account JSON
- Store in encrypted vault (1Password, AWS Secrets Manager)
- Rotate keys annually

## Cost Optimization

### Railway/Fly.io Free Tier Limits
- Monitor monthly usage
- Optimize cold starts
- Use caching where possible

### Tips:
1. Implement response caching
2. Batch similar operations
3. Use gzip compression
4. Minimize external API calls

## Troubleshooting

### Deployment Fails

**Check:**
- Requirements.txt up to date
- All environment variables set
- Docker build succeeds locally

### 502/504 Errors

**Causes:**
- Cold start timeouts
- Memory limits exceeded
- External dependency failures

**Solutions:**
- Increase timeout limits
- Add health check warming
- Implement retry logic

### Firebase Token Verification Fails

**Check:**
- Service account credentials are set
- Firebase project matches client config
- Network connectivity to Firebase

## CI/CD Pipeline

GitHub Actions already configured in `.github/workflows/test.yml`

For auto-deployment:
```yaml
- name: Deploy to Railway
  if: github.ref == 'refs/heads/main'
  run: |
    cd server
    railway up
  env:
    RAILWAY_TOKEN: ${{ secrets.RAILWAY_TOKEN }}
```

## Migration from Development to Production

1. **Update Secrets.xcconfig:**
   ```
   AUTH_SERVER_URL = https://your-production-url.com
   ```

2. **Rebuild iOS app:**
   ```bash
   xcodebuild clean build
   ```

3. **Test authentication:**
   - Sign in with all providers
   - Verify cloud sync works
   - Check analytics events

4. **Monitor for 24 hours:**
   - Watch error rates
   - Check response times
   - Review user feedback

## Support

For deployment issues:
- Railway: https://help.railway.app
- Fly.io: https://community.fly.io
- Heroku: https://help.heroku.com

