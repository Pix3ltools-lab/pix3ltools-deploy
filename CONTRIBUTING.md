# Contributing to Pix3lTools Deploy

Thank you for your interest in contributing to Pix3lTools Deploy! This document provides guidelines and instructions for contributing.

## Code of Conduct

Be respectful, inclusive, and constructive in all interactions. We're building tools to help content creators succeed.

## How to Contribute

### Reporting Bugs

1. **Check existing issues** to avoid duplicates
2. **Use the issue template** with:
   - Clear description of the bug
   - Steps to reproduce
   - Expected vs actual behavior
   - Docker and OS version
   - Relevant container logs

### Suggesting Features

1. **Open an issue** with the `enhancement` label
2. **Describe the feature** and its use case
3. **Explain why** it would benefit users
4. **Consider alternatives** you've thought about

### Submitting Pull Requests

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/your-feature-name`
3. **Make your changes** following our conventions
4. **Test thoroughly** - ensure `docker compose up -d` works correctly
5. **Commit with clear messages**: Use conventional commits (feat:, fix:, docs:, etc.)
6. **Push to your fork**: `git push origin feature/your-feature-name`
7. **Open a Pull Request** with:
   - Clear title and description
   - Reference to related issues
   - What was tested and how

## Development Setup

### Prerequisites

- Docker and Docker Compose
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/Pix3ltools-lab/pix3ltools-deploy.git
cd pix3ltools-deploy

# Create environment file
cp .env.example .env
# Edit .env and set a strong JWT_SECRET (minimum 32 characters)

# Start the stack
docker compose up -d
```

Services will be available at:
- **Pix3lBoard**: http://localhost:3000
- **Pix3lWiki**: http://localhost:3001
- **sqld**: http://localhost:8080

## Project Structure

```
pix3ltools-deploy/
├── docker-compose.yml     # Service definitions
├── .env.example           # Environment template
├── .github/
│   └── workflows/         # CI/CD pipelines
├── README.md              # Documentation
├── LICENSE                # MIT License
└── CONTRIBUTING.md        # This file
```

## What Belongs Here

This repo manages **deployment and orchestration** of the Pix3lTools stack. Contributions should focus on:

- Docker Compose configuration
- CI/CD workflows (GitHub Actions)
- Deployment scripts and automation
- Documentation for setup and operations

For application-level changes, contribute to the individual repos:
- [pix3lboard](https://github.com/Pix3ltools-lab/pix3lboard) — Kanban board source
- [pix3lwiki](https://github.com/Pix3ltools-lab/pix3lwiki) — Wiki source

## Git Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `ci:` CI/CD changes
- `chore:` Maintenance tasks

Example:
```
feat: Add health checks to docker-compose
fix: Correct volume mount paths for sqld
docs: Update README with backup instructions
ci: Add workflow for automated image builds
```

## Testing Changes

Before submitting a PR, verify:

1. **Stack starts cleanly**: `docker compose up -d` with no errors
2. **All services healthy**: `docker compose ps` shows all services running
3. **Database init works**: DB initialization scripts complete successfully
4. **Services accessible**: Pix3lBoard on :3000, Pix3lWiki on :3001
5. **Data persistence**: Data survives `docker compose down` + `up -d`
6. **Clean shutdown**: `docker compose down` stops gracefully

## Questions?

- Open an issue with the `question` label
- Check existing discussions
- Review the README.md

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

**Thank you for contributing to Pix3lTools Deploy!**

Part of the [Pix3lTools](https://github.com/Pix3ltools-lab) suite.
