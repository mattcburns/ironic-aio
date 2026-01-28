# Design 001: API Framework Setup

**Status:** To Be Implemented

## Overview

This design establishes the foundational architecture for the ironic-aio API sidecar. The key architectural decision is implementing a **service layer pattern** that allows both REST and MCP interfaces to share the same business logic, eliminating code duplication.

## Goals

1. Establish project structure that supports REST and MCP interfaces
2. Define the service layer pattern for shared business logic
3. Set up core dependencies with proper justification
4. Create configuration management
5. Implement basic health check endpoint as proof of concept

## Architecture

```
┌─────────────────┐     ┌─────────────────┐
│   REST API      │     │   MCP Server    │
│   (FastAPI)     │     │   (mcp lib)     │
└────────┬────────┘     └────────┬────────┘
         │                       │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │    Service Layer      │
         │  (Business Logic)     │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │   Ironic Client       │
         │  (OpenStack SDK)      │
         └───────────────────────┘
```

## Project Structure

```
api/
├── app.py                  # FastAPI application entry point
├── mcp_server.py           # MCP server entry point
├── config.py               # Configuration management
├── requirements.txt        # Python dependencies
├── README.md               # Documentation with dependency justifications
├── designs/                # Design documents
├── services/               # Business logic layer (shared)
│   ├── __init__.py
│   └── health.py           # Health check service (proof of concept)
├── routers/                # REST API route handlers
│   ├── __init__.py
│   └── health.py           # Health check routes
├── mcp_tools/              # MCP tool definitions
│   ├── __init__.py
│   └── health.py           # Health check MCP tools
├── schemas/                # Pydantic models for request/response
│   ├── __init__.py
│   └── health.py           # Health check schemas
└── tests/                  # Test directory
    ├── __init__.py
    ├── conftest.py         # Pytest fixtures
    ├── test_health_service.py
    ├── test_health_router.py
    └── test_health_mcp.py
```

## Dependencies

The following dependencies are required (justifications in README.md):

| Package | Version | Purpose |
|---------|---------|---------|
| fastapi | ^0.109 | REST API framework with automatic OpenAPI generation |
| uvicorn | ^0.27 | ASGI server to run FastAPI |
| pydantic | ^2.0 | Data validation and settings management |
| mcp | ^1.0 | Model Context Protocol server implementation |
| httpx | ^0.27 | Async HTTP client (used by MCP, also useful for Ironic) |
| pydantic-settings | ^2.0 | Environment-based configuration |
| pytest | ^8.0 | Testing framework |
| pytest-asyncio | ^0.23 | Async test support |

## Implementation Details

### 1. Configuration (config.py)

```python
# Environment-based configuration using pydantic-settings
class Settings(BaseSettings):
    app_name: str = "ironic-aio-api"
    debug: bool = False
    ironic_api_url: str = "http://localhost:6385"
    ironic_api_version: str = "1.82"

    model_config = SettingsConfigDict(env_prefix="IRONIC_AIO_")
```

### 2. Service Layer Pattern

Services contain all business logic and are framework-agnostic:

```python
# services/health.py
class HealthService:
    """Health check service - shared by REST and MCP."""

    async def check_health(self) -> HealthStatus:
        """Check the health of the API and its dependencies."""
        # Business logic here
        return HealthStatus(status="healthy", ...)
```

### 3. REST Router

Routers are thin wrappers that call services:

```python
# routers/health.py
router = APIRouter(prefix="/health", tags=["health"])

@router.get("", response_model=HealthResponse)
async def get_health(service: HealthService = Depends(get_health_service)):
    return await service.check_health()
```

### 4. MCP Tools

MCP tools are also thin wrappers calling the same services:

```python
# mcp_tools/health.py
@mcp_server.tool()
async def check_health() -> dict:
    """Check the health of the ironic-aio API."""
    service = get_health_service()
    result = await service.check_health()
    return result.model_dump()
```

### 5. Shared Schemas

Pydantic models are shared between REST and MCP:

```python
# schemas/health.py
class HealthStatus(BaseModel):
    status: Literal["healthy", "degraded", "unhealthy"]
    version: str
    timestamp: datetime
```

## OpenAPI Specification

The FastAPI application will auto-generate OpenAPI specs. Additional metadata:

- Title: "Ironic AIO API"
- Description: "Business process API for OpenStack Ironic operations"
- Version: "0.1.0"

## Testing Requirements

1. **Unit tests for services**: Test business logic in isolation
2. **Integration tests for REST**: Test endpoints using FastAPI TestClient
3. **Integration tests for MCP**: Test MCP tools respond correctly
4. **Shared fixtures**: Common test data in conftest.py

## Acceptance Criteria

- [ ] Project structure created as specified
- [ ] All dependencies installed and documented in README.md
- [ ] Configuration management working with environment variables
- [ ] Health check service implemented
- [ ] Health check REST endpoint returns valid response
- [ ] Health check MCP tool returns valid response
- [ ] OpenAPI spec accessible at `/docs` and `/openapi.json`
- [ ] All tests pass with >80% coverage
- [ ] Both `app.py` and `mcp_server.py` can start without errors

## Documentation Requirements

The `api/README.md` must include:

1. **Development Setup**: Virtual environment creation and dependency installation
2. **Running the API**: Commands to start REST API and MCP server
3. **Running Tests**: Include the following commands:
   ```bash
   # Run all tests
   pytest

   # Run with coverage (enforcing 80% minimum)
   pytest --cov=. --cov-report=term-missing --cov-fail-under=80

   # Run specific test file
   pytest tests/test_health_service.py

   # Run tests matching a pattern
   pytest -k "health"
   ```
4. **Dependency Justifications**: As required by AGENTS.md

**Note:** Once `api/README.md` is complete, update the root `AGENTS.md` to reference it for detailed development instructions (e.g., "See `api/README.md` for setup and testing commands").

## Future Designs

This design is intentionally minimal. Future designs will add:

- **002**: Ironic client integration and connection management
- **003**: Server discovery and listing business process
- **004**: Server provisioning workflow
- **005**: Server decommissioning workflow
