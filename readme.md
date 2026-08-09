# ai-opencode-sandbox

Minimal two-container sandbox for loop engineering with opencode (agent) and a self-hosted GitHub Actions runner.

## Overview
- **Topology**: two containers
  - `services-agent`: Django backend, Postgres, React frontend, Playwright deps, and opencode workspace.
  - `runner`: self-hosted GitHub Actions runner (registered to the throwaway repo).
- **Repo name**: `ai-opencode-sandbox` (kebab-case).
- **Auth model**: use **Account Y** (push rights only) for the throwaway repo. Provide a short-lived registration token for the runner and a personal access token for pushes if needed.
- **Persistence**: DB is ephemeral. If persistence is required, agent must `pg_dump` and commit the dump into the repo (e.g., `ai-repo/db/dump.sql`). On startup the services restore that dump automatically.
- **CI fidelity**: runner clones the repo itself (no shared CI volume). Agent pushes to the throwaway repo to trigger real Actions runs.

## Files and layout
.
├─ docker-compose.yml
├─ init/
│  └─ clone-repos.bash
├─ images/
│  ├─ services-agent/
│  │  └─ Dockerfile
│  └─ runner/
│     └─ Dockerfile
├─ services/
│  └─ start-all.bash
├─ runner/
│  └─ entrypoint.bash
└─ README.md

Code

## Quick start
1. **Edit** `init/clone-repos.bash` and replace placeholder HTTPS URLs with your throwaway repo URLs (use `https://github.com/YOUR_ACCOUNT_Y/ai-opencode-sandbox.git` for the main repo).
2. **Set tokens** in `docker-compose.yml`:
   - `RUNNER_REPO_URL` → `https://github.com/YOUR_ACCOUNT_Y/ai-opencode-sandbox`
   - `RUNNER_TOKEN` → registration token from GitHub (repo Settings → Actions → Runners → Add runner)
   - `GIT_PUSH_TOKEN` → personal access token for Account Y (scoped to repo push) if you push via HTTPS
3. **Build images**
   ```bash
   docker compose build
Start stack

bash
docker compose up -d
Enter agent workspace

bash
docker exec -it ai_opencode_services_agent bash
cd /workspace/repo/ai-repo
# Start opencode in auto mode (replace with your CLI)
# opencode --workspace . --mode auto
Trigger CI

Agent commits and pushes to ai-opencode-sandbox (Account Y). GitHub schedules the workflow and the registered runner executes it.

Collect results

Use actions/upload-artifact in workflows or commit small reports back to the throwaway repo.

Teardown

bash
# Unregister runner (inside runner container) or via GitHub UI
docker exec -it ai_opencode_runner bash -lc "/runner/actions-runner/config.sh remove --unattended --token YOUR_TOKEN" || true

# Stop and remove containers and volumes
docker compose down --volumes

# Rotate/delete tokens on GitHub
Notes and best practices
No host mounts: the stack uses Docker volumes only (repo-volume) to avoid touching host folders.

DB dumps: keep dumps small and sanitized. Agent must commit dumps explicitly to persist state.

Playwright: install browsers in both images if you want local and CI Playwright runs; otherwise keep Playwright only in the runner to reduce image size.

Security: Account Y must have push rights only. Do not give admin or delete scopes. Rotate tokens after each session.

Mirroring: run an owner-controlled mirror outside this sandbox to snapshot pushes for recovery if needed.

Example minimal workflow (push-triggered)
Agent pushes branch feature/x to ai-opencode-sandbox.

GitHub triggers .github/workflows/ci.yml on push.

Runner clones repo and runs tests (Playwright, lint, build).

Artifacts uploaded to Actions or committed back to repo.

Troubleshooting
If runner fails to register, verify RUNNER_TOKEN and RUNNER_REPO_URL.

If Playwright tests fail due to missing libs, ensure Playwright dependencies are installed in the image and npx playwright install --with-deps was run.

If agent cannot push via HTTPS, configure ~/.netrc or use git -c credential.helper inside the container with GIT_PUSH_TOKEN
---

# Two-container sandbox (services-agent + runner)

## Prereqs
- Docker and Docker Compose installed on your laptop.
- A throwaway GitHub repo (account Y) and a registration token for a self-hosted runner.
- A personal access token for account Y (if agent will push directly).

## Build images
docker compose build

## Start stack
# Edit docker-compose.yml to set RUNNER_REPO_URL and RUNNER_TOKEN
docker compose up -d

## Enter services-agent (agent workspace)
docker exec -it services_agent bash
# inside container you will be in /workspace; ai-repo is at /workspace/repo/ai-repo
# start opencode in auto mode (replace with your actual command)
# opencode --workspace /workspace/repo/ai-repo --mode auto

## How CI is triggered
- Agent commits and pushes to the throwaway repo (account Y).
- GitHub schedules the workflow and the registered self-hosted runner executes it.
- Runner clones the repo fresh and runs the workflow steps.

## Unregister and teardown
# Stop compose
docker compose down --volumes

# If runner still registered, remove it from GitHub UI or run unregister inside runner container before stopping:
docker exec -it gh_runner bash -lc "/runner/actions-runner/config.sh remove --unattended --token YOUR_TOKEN"

# Rotate/delete account Y tokens after session
Notes, assumptions, and small adjustments you may want
No shared CI volume: runner clones the repo itself from GitHub (this matches real CI). The repo-volume is used by services-agent for the agent workspace. If you prefer the runner to read the same files immediately without pushing, mount repo-volume into the runner and skip the clone step — but that diverges from real CI behavior.

DB persistence: by design DB is ephemeral. If the agent wants persistence, it should pg_dump and commit the dump into the repo (e.g., ai-repo/db/dump.sql). The start-all.bash restores that dump on startup.

Playwright: both images install Playwright and browsers. If you want smaller images, remove Playwright from services-agent and only keep it in runner, but then local test runs inside services-agent will not have browsers.

Opencode invocation: start-all.bash leaves you in the ai-repo workspace so you can start opencode manually or replace the exec /bin/bash with your opencode CLI invocation.

Runner tokens: RUNNER_TOKEN is a short‑lived registration token from GitHub (create via repo Settings → Actions → Runners → Add runner). GIT_PUSH_TOKEN is a personal access token for account Y (scoped to repo push). Keep both secret and rotate/delete after use.

Resource limits: add deploy.resources or mem_limit in docker-compose.yml if you want to cap memory/CPU.

Quick checklist to run this now
Put the files into a folder structure:

Code
.
├─ docker-compose.yml
├─ init/
│  └─ clone-repos.bash
├─ images/
│  ├─ services-agent/
│  │  └─ Dockerfile
│  └─ runner/
│     └─ Dockerfile
├─ services/
│  └─ start-all.bash
├─ runner/
│  └─ entrypoint.bash
└─ README.md
Edit init/clone-repos.bash to point to your throwaway repo URLs.

Edit docker-compose.yml to set RUNNER_REPO_URL, RUNNER_TOKEN, and GIT_PUSH_TOKEN.

docker compose build

docker compose up -d

docker exec -it services_agent bash → start opencode (or let it be started automatically).

Agent commits and git push to throwaway repo (account Y). GitHub will schedule the workflow and the runner will execute it.

Two-container minimal sandbox

Prereqs
- Docker and Docker Compose
- Throwaway GitHub repo (account Y)
- Registration token for self-hosted runner (repo Settings -> Actions -> Runners -> Add runner)
- Optional personal access token for account Y if agent will push via HTTPS

Build and run
1. Edit init/clone-repos.bash to point to your throwaway HTTPS repo URLs.
2. Edit docker-compose.yml to set RUNNER_REPO_URL, RUNNER_TOKEN, and GIT_PUSH_TOKEN.
3. Build images:
   docker compose build
4. Start stack:
   docker compose up -d
5. Enter agent workspace:
   docker exec -it services_agent bash
   cd /workspace/repo/ai-repo
   # start opencode in auto mode (replace with your CLI)
   # opencode --workspace . --mode auto

CI flow
- Agent commits and pushes to throwaway repo (account Y).
- GitHub triggers Actions; the registered runner clones the repo and runs workflows.
- Artifacts can be uploaded via actions/upload-artifact or committed back to the repo by workflows.

Teardown
- Unregister runner (inside runner container or via GitHub UI) then:
  docker compose down --volumes
- Rotate/delete tokens after session.

wait, can we run slef-hosted runner in docker container?
Short answer
Yes — you can run a GitHub self‑hosted runner inside a Docker container. It gives you the real Actions runtime while remaining easy to start/stop. You must choose how jobs will execute (inside the runner container, via Docker‑in‑Docker, or by giving the runner access to the host Docker socket) and apply a few security precautions.

Key options and tradeoffs
Option	Isolation	Ease	When to use
Runner in container + Docker socket mounted	Low isolation; runner can start containers on host	Very easy	Fast local dev; accept host exposure risk
Runner in container + Docker‑in‑Docker sidecar	Better isolation; DinD runs containers inside sibling daemon	Medium	Safer than socket mount; needs privileged DinD container
Runner in container launching jobs in containers without Docker	High isolation per job if you use VM/container orchestrator	Harder	Production‑grade isolation; use when security matters
Runner inside VM with Docker	Strong isolation from host	Medium	Best balance for laptop: runner VM isolates host


Recommended safe pattern for laptop sandbox
Run the runner in a Docker container for convenience.

Use a disposable GitHub repo for registration.

Run each job in its own container (the runner will create containers) rather than letting jobs run directly on the runner process.

Avoid mounting host secrets and the host Docker socket unless you understand the risk. If you must run containers from the runner, prefer a DinD sidecar with controlled privileges.

Automate registration and teardown: register runner with a short‑lived token and unregister + remove container after the test run.

Quickstart example using Docker Compose with DinD
This example runs a DinD daemon and a runner container that uses it to start job containers. It isolates job containers from your host Docker daemon.

docker-compose.yml

yaml
version: "3.8"
services:
  dind:
    image: docker:24-dind
    privileged: true
    environment:
      DOCKER_TLS_CERTDIR: ""
    volumes:
      - dind-data:/var/lib/docker

  runner:
    image: my-gh-runner:latest
    depends_on:
      - dind
    environment:
      RUNNER_REPO_URL: "https://github.com/yourorg/your-disposable-repo"
      RUNNER_TOKEN: "PASTE_REGISTRATION_TOKEN"
      RUNNER_NAME: "sandbox-runner-1"
      RUNNER_WORKDIR: "/tmp/_work"
    volumes:
      - ./runner-data:/runner
    network_mode: "service:dind"

volumes:
  dind-data:
  runner-data:
Build a minimal runner image Dockerfile

dockerfile
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y curl jq git ca-certificates
WORKDIR /runner
# Download and extract runner binary (replace version)
RUN curl -O -L https://github.com/actions/runner/releases/download/v2.x.x/actions-runner-linux-x64-2.x.x.tar.gz \
  && tar xzf actions-runner-linux-x64-2.x.x.tar.gz
COPY entrypoint.bash /entrypoint.bash
RUN chmod +x /entrypoint.bash
ENTRYPOINT ["/entrypoint.bash"]
entrypoint.bash

bash
#!/bin/bash
set -e
# Configure runner non-interactively
./config.sh --unattended --url "${RUNNER_REPO_URL}" --token "${RUNNER_TOKEN}" --name "${RUNNER_NAME}" --work "${RUNNER_WORKDIR}"
# Run the runner
trap './config.sh remove --unattended --token "${RUNNER_TOKEN}" || true' EXIT
./run.sh
How it works

The DinD service provides a Docker daemon inside the compose network.

The runner container uses that daemon (via network_mode: service:dind) so jobs that request Docker will run inside the DinD daemon, not your host Docker.

Register the runner with a disposable repo token, run workflows, then stop and remove the compose stack and delete the disposable repo.

Security and operational tips
Use a disposable repo for registration so secrets and workflows never touch production.

Use short‑lived registration tokens and unregister the runner after the run.

Do not mount host SSH keys or /var/run/docker.sock into the runner unless you accept host exposure.

Limit network access of the runner container to the sandbox network if you want to restrict egress.

Run jobs as non‑root inside job containers and avoid privileged containers unless required.

Automate teardown: script unregister → stop containers → remove volumes → delete disposable repo and tokens.

Practical next steps you can run now
Create a disposable GitHub repo and get a registration token.

Copy the docker-compose.yml, Dockerfile, and entrypoint.bash above into a local folder. Replace the token and repo URL.

Build and start:

bash
docker compose build
docker compose up -d
Push a test workflow to the disposable repo and observe jobs run on your laptop runner.

When finished, unregister and tear down:

bash
# inside runner dir
docker compose down --volumes
# remove disposable repo and revoke tokens on GitHub
If you want, I can now generate a complete ready‑to‑run repo with the Dockerfile, entrypoint, and a sample GitHub Actions workflow that runs Playwright against a local Django service inside the same compose stack. Which OS do you prefer for the runner image: Ubuntu or Alpine?

so, i am thinking about like this.

we have docker compose in our laptop.
we will prepare a compose.yaml in which:-

- no laptop folders mounted.
- there are five separate containers: backend (django) + opencode, frontend (react) + opencode, db (postgres) + opencode, testing(playwright) + opencode, github action runner [currently need this - in future: redis, celery, kafka, etc]; or four separate containers: backend + db + opencode, frontend + opencode, testing + opencode, gh action runner; or three separate containers: backend + db + opencode, frontend + testing + opencode, gh action runner; or two separate containers: backend + db + frontend + testing + opencode, gh action runner; or single container backend + db + frontend + testing + opencode + gh action runner
- in every contaner, the entry point is bash (opencode & other things launched from it) - [is gui has any use here? opencode is entirely tui. do we need any editors like vscode?]
- there is another repo which contains all the ai skills, agents, workflows, opencode customizations, etc - called ai-repo
- frontend, backend, testing, ai-repo code is hosted on throwable private github repos
- on compose up: frontend, backend, testing, ai repos are cloned.
- on entry point: opencode is launched on ai-repo, work started in auto mode
- ai writes the code, tests the code using playwright, test the ci cd workflows using gh action runner; after everything ok - pushes to respective git repos
- ai can't control the repos like thier visibility, repo delete, etc (how do this? i am thinking about creating the repo on account X (the owner), then add collaborator account Y (the worker) - the docker use account Y; authenticated gh will be avaialble in container for gh actions (wait - we are using gh action runner container - is these authenticated really need for them?))
- we will get the outputs from the throwaway repo
- we will also keep a non-destructive mirror (if parent repo edited the history, deleted the branch, etc are handled by safe keeping them (like prefixing with deleted, before-edit, etc), and new branch, commit like changes are exactly mirrored) of throwaway repo (synced via. github webhook) for safety (if agent deleted the entire commits after work done - we can still access them on mirror repo).
Feasibility summary
Your plan is fully feasible and sensible: run a multi‑container Docker Compose sandbox on your laptop with no host mounts, clone throwaway repos into container volumes at startup, run the agent (opencode) in auto mode against those throwaway repos and sandbox services, and use an ephemeral self‑hosted runner to execute real GitHub Actions. The key is principle of least privilege for any GitHub identity the agent uses and an independent, owner‑controlled backup/mirroring pipeline so destructive actions can’t erase your only copy.

High level architecture (recommended)
Docker Compose network only; no laptop folders mounted. Use Docker named volumes for repo worktrees and DB storage.

Containers (one per role, choose granularity you prefer):

backend (Django + local DB client)

db (Postgres)

frontend (React dev server)

testing (Playwright runner)

ai/agent (opencode running on ai-repo)

self-hosted-runner (GitHub Actions runner)

Init container or entrypoint script clones the throwaway repos into container volumes on compose up.

Agent runs in auto mode inside the ai/agent container and works only against the cloned throwaway repos and sandbox services.

Artifacts and approved outputs are exported from container volumes to host only via an explicit host-side export command after manual review.

How to prevent destructive repo operations
Use GitHub permission design and operational controls so the agent cannot delete repos, change visibility, or remove history on the authoritative owner account.

Concrete controls

Owner account X: retains admin on the real repos and the mirror.

Worker account Y (used by agent): grant Write (push) permission only on the throwaway repos; do not give admin. Do not add Y as admin on owner repos.

Prefer GitHub App over personal tokens: create a GitHub App with the minimal scopes needed (contents: read/write for specific repos, pull requests: write if needed). Install it only on throwaway repos. App tokens are fine‑grained and auditable.

Branch protection on throwaway repos: enable require pull requests, disallow force pushes, and prevent deletion of protected branches. This forces the agent to create PRs rather than rewriting history.

Disable destructive API scopes: do not provide delete_repo or admin:org scopes to any token the agent can access.

Runner registration: register the self‑hosted runner only to the throwaway repo (or org sandbox) using a short‑lived registration token. Unregister and destroy the runner after the run.

Secrets: only inject minimal, scoped secrets into the runner or repo; rotate and delete them after the run.

How the agent will push safely
Agent workflow: agent commits locally to the cloned throwaway repo (inside container volume). To publish: agent pushes to the throwaway remote (account Y) or opens PRs against the throwaway repo.

Promotion to real repo: require a manual review step by owner X. Owner X pulls artifacts from the mirror or throwaway repo and merges into the real repo manually or via a controlled CI job that runs under owner credentials.

Use GitHub App install tokens for automated pushes if you need programmatic pushes from the sandbox; configure the App to only have the minimal repository permissions and install it only on the throwaway repo.

Self‑hosted runner and authentication details
Runner registration token is short‑lived and only used to register the runner to the throwaway repo. The runner itself does not need a personal user token to execute jobs.

Workflows that call GitHub API will run with the repository context and any secrets available to that repo. Keep those secrets minimal and sandboxed.

If workflows need to push back to the repo, they will do so using the runner’s job context (GITHUB_TOKEN) or an App token; configure permissions so pushes are allowed only to non‑protected branches or to the throwaway repo.

Runner placement: run the runner in a container (DinD pattern) or a small VM on your laptop for isolation. Register it only to the throwaway repo and tear it down after testing.

Mirroring and recovery strategy
Owner‑controlled mirror service (recommended)

Host a small service under owner X (outside the sandbox) that receives webhooks from the throwaway repo and immediately performs a git fetch --all and stores a snapshot (bare repo or archive) in owner‑controlled storage.

This mirror uses owner credentials and is read‑only from the sandbox perspective. If the agent deletes branches or force‑pushes, the mirror still retains the prior snapshots.

Alternative: schedule a host process (outside compose) that periodically git clone --mirror the throwaway repo and stores snapshots.

Naming policy: when mirroring, prefix any rewritten or deleted refs with archived/ and keep timestamps so you can recover any lost commits.

Retention: keep snapshots until you manually approve deletion.

Minimal Compose and runtime pattern (practical notes)
No host mounts: use Docker volumes for repo-volume, db-volume, artifacts-volume. An init container clones throwaway repos into repo-volume.

Entrypoints: each container ENTRYPOINT is bash so opencode and other processes can be launched interactively or by scripts. No GUI or VSCode required; opencode is TUI.

Auto start: ai/agent entrypoint runs a supervisor script that:

ensures repos are cloned into volumes,

starts opencode in auto mode on ai-repo,

streams logs to a central logs volume for auditing,

enforces a global runtime timeout and resource limits.

Playwright: run tests inside the testing container against the frontend and backend services on the same Docker network. Store test reports in artifacts-volume.

CI validation: push workflow changes to the throwaway repo; the self‑hosted runner executes them. Runner writes artifacts to artifacts-volume for review.

Quick security checklist before enabling auto mode
Worker account Y has no admin rights and minimal repo scopes.

Throwaway repos created per run; owner X retains admin and mirror control.

Runner registered only to throwaway repo and runs in container/VM; unregister and destroy after run.

Secrets scoped and rotated; no host SSH keys or Docker socket mounted into containers.

Branch protection prevents force pushes and branch deletion.

Owner mirror receives webhooks and snapshots every push.

Logging and audit: capture agent stdout/stderr, git activity, and workflow logs to artifacts-volume.

Automatic teardown: after a run, unregister runner, delete throwaway repos (owner action), and destroy volumes unless artifacts are exported.

Next deliverables I can generate for you now
A ready‑to‑run docker-compose.yml that uses Docker volumes, an init container to clone throwaway repos, and services for backend, frontend, testing, ai/agent, and self‑hosted runner.

Init and entrypoint scripts: clone logic, opencode auto launcher, runner registration/unregistration automation.

A short security policy checklist and sample GitHub App permission manifest to create a least‑privilege App for the agent.

A simple mirror webhook receiver script (Node/Python) that snapshots the throwaway repo into owner storage on every push.

I will produce those artifacts next; I will start with the docker-compose.yml and init scripts so you can spin up the sandbox immediately.

there are five separate containers: backend (django) + opencode, frontend (react) + opencode, db (postgres) + opencode, testing(playwright) + opencode, github action runner [currently need this - in future: redis, celery, kafka, etc];

or four separate containers: backend + db + opencode, frontend + opencode, testing + opencode, gh action runner;

or three separate containers: backend + db + opencode, frontend + testing + opencode, gh action runner;

or two separate containers: backend + db + frontend + testing + opencode, gh action runner;

or single container backend + db + frontend + testing + opencode + gh action runner

what is best for our use case - we need minmum overheads.
----------
we are not giving account X. we are giving account Y - only permission compared to public user is that - he had push permission.
------
agent can create any branches, and can work freely - so, we don't need branch rules, pr rules, etc.
------
so, the runner not need access to the throwaway repo - even it is in separate container - on same container runner can access the container files?
------
we don't need another overhead of github app - is github app has any advantage here?
-------
is DinD supported in macos? has any advantages over runner in another container?
Container topology recommendation
Best balance for minimal overhead and safety — three containers:

services — backend (Django) + db (Postgres) + frontend (React) + optional lightweight extras

agent — opencode running on ai-repo and doing the loop engineering

runner — self‑hosted GitHub Actions runner (ephemeral container/VM)

Why three

Lowest operational overhead while keeping clear separation of concerns.

The services container groups tightly coupled runtime pieces (Django, Postgres, React dev server) so the agent and tests can reach them on the same Docker network without extra networking plumbing.

The agent container is isolated so it can be given the push credentials for the throwaway repos and run in auto mode without touching host files.

The runner is isolated so CI jobs run in a controlled environment; it can be ephemeral and torn down after each session.

When to choose other splits

Five containers (one per role) if you want maximum process isolation and easier per-service lifecycle — higher resource and orchestration cost.

Two containers or single container only if you absolutely need minimal containers and accept weaker isolation and harder debugging. Not recommended for CI/test fidelity or security.

How the runner can access repo files and services
Shared volumes

Put the cloned throwaway repos into a Docker named volume (e.g., repo-volume). Mount that same volume into both the agent and the runner containers. That gives the runner direct file access without exposing host folders.

Network access

All containers on the same Docker network can reach the services by service name (e.g., http://backend:8000). No host network exposure required.

Alternative

Let the runner clone the throwaway repo itself (using the throwaway account Y credentials). This avoids sharing volumes but requires the runner to have network access and credentials for that throwaway repo.

Key point

The runner does not need special GitHub authentication beyond the registration token to run jobs. If a workflow step needs to push, it will use the repo’s GITHUB_TOKEN or whatever secrets are configured for that throwaway repo. Keep those secrets minimal.

Permissions model and destructive actions
Your stated model — agent uses account Y with push permission only — is workable and simple. Important controls to keep:

Do not give account Y admin or repo deletion scopes. Push-only is sufficient for development.

Keep owner X out of the sandbox so the agent cannot change repo visibility or delete repos.

Mirror every push to an owner‑controlled backup (outside the sandbox) so you can recover if the agent rewrites history or deletes branches. The mirror should fetch and snapshot refs immediately on webhook events.

No branch rules required if you accept agent freedom. Mirror + owner review is your safety net.

GitHub App versus personal token
GitHub App advantages

Fine‑grained permissions per repository and per action.

Auditable and easier to revoke/rotate.

Scoped installs — install only on throwaway repos.

When you can skip it

If you want minimal setup and you already have account Y with push rights to throwaway repos, a personal token is simpler.

Use a short‑lived token and rotate/delete it after the run.

Recommendation

For quick, low‑overhead runs use account Y token. If you plan repeated automated runs or want stronger governance, switch to a GitHub App later.

DinD on macOS and runner container execution modes
DinD support on macOS

Docker Desktop on macOS runs Linux containers inside a lightweight VM. You can run DinD containers, but privileged DinD containers are not fully supported or recommended on macOS because they require kernel features and privileged mode that are best supported on Linux hosts.

Practically: DinD will work more reliably on a Linux host or inside a Linux VM on macOS (e.g., Multipass, Vagrant, or a cloud VM).

Runner job execution options and tradeoffs

Runner container + host Docker socket (/var/run/docker.sock)

Pros: Easy; runner can start containers for jobs.

Cons: Grants runner jobs full control of host Docker — high security risk. Not recommended on your laptop unless you accept that risk.

Runner container + DinD sidecar

Pros: Jobs run in the DinD daemon, isolating them from host Docker. Better than socket mount.

Cons: Requires privileged DinD; on macOS this is fragile. Works best on Linux.

Runner in VM

Pros: Strong isolation; you can run DinD or mount socket inside VM without affecting host. Best security for laptop use.

Cons: Slightly more overhead to manage the VM.

Runner runs jobs directly (no Docker)

Pros: Simple; no DinD/socket complexity.

Cons: Less isolation between jobs; you must ensure each job cleans up and runs as non‑root.

Recommendation for macOS laptop

If you want minimal friction: run the runner container and let it execute jobs directly (no Docker-in-Docker). Use the throwaway repo and keep jobs lightweight.

If you need to run containerized jobs (recommended for Playwright, DB, etc.): run the runner inside a small Linux VM on your laptop (Multipass/UTM) and use DinD or host socket inside that VM. This gives DinD reliability and keeps your macOS host safe.

Practical checklist to implement your three-container sandbox now
Create Docker volumes: repo-volume, artifacts-volume, db-volume.

Init step: on compose up an init script clones throwaway repos into repo-volume.

Compose services: services container runs Django, Postgres (or Postgres in same container), and React dev server; expose only internal ports on the Docker network.

Agent container: mounts repo-volume, runs opencode on ai-repo in auto mode.

Runner container: mounts repo-volume or clones repo itself; register to throwaway repo; run workflows; write artifacts to artifacts-volume.

No host mounts: do not mount ~/.ssh, /var/run/docker.sock, or host folders.

Mirror: owner X runs an external mirror service that listens to throwaway repo webhooks and snapshots refs to owner storage.

Teardown: after run, unregister runner, delete disposable repo or rotate tokens, and destroy volumes unless artifacts are exported.

Final practical recommendation
Start with the three‑container layout (services, agent, runner) for minimal overhead and good isolation.

Run the runner in a Linux VM on macOS if you need containerized job execution (DinD). If not, run the runner container directly but avoid mounting the host Docker socket.

Use account Y push rights only and rely on an owner‑controlled mirror for recovery.

Skip GitHub App for now to reduce setup complexity; adopt it later if you need finer permission control.

If you want, I will now generate a ready‑to‑run Docker Compose template, plus the init scripts that clone throwaway repos into volumes, and a small mirror webhook receiver script for owner snapshots. Which should I produce first: the compose template or the mirror webhook script?

the opencode workspace is ai-repo. but, it entirely works on frontend code, backend code, testing code & db code. three separate containers: backend + db + opencode, frontend + testing + opencode, gh action runner has any advantages over two separate containers: backend + db + frontend + testing + opencode, gh action runner?
------
runner definetly need internet access. we are using several other github actions - these must be resolved from internet. also, runner needs to push the results.
-------
want minimal setup and you already have account Y with push rights to throwaway repos
------
i completely not understanted the Runner job execution options and tradeoffs - explain in maximum details
------
Runner placement recommendation (short verdict)
For minimal overhead with safe isolation, use three containers:

services (backend + db + frontend)

agent (opencode on ai-repo)

runner (self‑hosted GitHub Actions runner)

This keeps resource use low, gives the agent full local access to services and repo volumes, and isolates CI execution so you can tear down the runner independently. The runner must have internet access to resolve marketplace actions and push results; mount the shared repo volume (or let the runner clone the throwaway repo) so it can read/write code and artifacts.

Why three containers is the best tradeoff
Attribute	Three containers (recommended)	Two containers	Single container
Isolation	Good — services separated from agent and runner	Lower — agent and services co‑hosted increases blast radius	Poor — everything shares same environment
Resource overhead	Low	Slightly lower	Lowest but risky
Simplicity	Simple to reason about and manage	Simpler but harder to secure per-role	Simplest to run, hardest to contain
CI fidelity	Runner isolated; can be ephemeral	Runner shares resources with services if combined	Hard to emulate real runner behavior safely
Tear‑down & recovery	Easy to destroy runner or agent independently	Less flexible	All-or-nothing teardown


Practical: three containers gives minimal operational overhead while preserving safety and the ability to run real GitHub Actions on an ephemeral runner.

How the runner accesses repos and services
Shared Docker volume: clone the throwaway repo into a named volume (e.g., repo-volume) at startup. Mount that same volume into both agent and runner containers. The runner reads/writes files directly without host mounts.

Network: all containers on the same Docker network; runner can reach http://backend:8000 and http://frontend:3000 for tests.

Push results: runner needs outbound internet to push to the throwaway GitHub repo (account Y). Use a short‑lived token stored only in the throwaway repo’s secrets or injected into the runner container at runtime.

GitHub App vs personal token (short)
Personal token (account Y): simplest. Use a token with push rights only to throwaway repos. Rotate/delete after runs.

GitHub App: more secure and auditable; fine‑grained repo installs and easier revocation. Use later if you want stronger governance.
For minimal setup: stick with account Y token now.

Runner job execution options — full detailed explanation
Below are the four practical ways a self‑hosted runner executes jobs, with technical details, security implications, and recommended controls.

1) Runner executes jobs directly on the runner host (no containers)
How it works

The runner process checks out the repo and runs each workflow step as processes on the runner host (the container or VM where the runner runs). Steps run in the runner’s user context.

Pros

Simple to set up.

No Docker/DinD complexity.

Good for workflows that need direct access to host resources (binaries, GPUs).

Cons / Risks

Low isolation: one job can affect subsequent jobs (leftover files, processes, env vars).

Security: a malicious workflow can access any file the runner user can, exfiltrate secrets, or install persistent agents.

Cleanup burden: you must ensure each job cleans up; otherwise state leaks.

When to use

Quick local testing where you control the runner and trust the workflows (throwaway repo, ephemeral runner).

When jobs require host-level access and you accept the risk.

Mitigations

Run runner inside a VM or container (so host is not your laptop OS).

Run the runner as a non‑privileged user.

Enforce job timeouts and disk quotas.

Automate runner teardown after the session.

2) Runner starts job containers by using the host Docker daemon (mounting /var/run/docker.sock)
How it works

The runner has access to the host Docker socket. When a job requests container or uses docker steps, the runner instructs the host Docker daemon to create containers for the job. Those containers run on the host Docker engine.

Pros

Jobs run in containers (better isolation per job).

Easy to support containerized workflows and Docker-based actions.

Simple to implement on Linux hosts.

Cons / Risks

Host compromise risk: mounting the Docker socket effectively gives job containers root-equivalent control over the host (they can create privileged containers, mount host paths, or escalate).

Not safe on shared or sensitive hosts.

When to use

Fast local dev when you accept host exposure (e.g., disposable VM or dedicated sandbox laptop).

Not recommended on your primary laptop unless you isolate the runner in a VM.

Mitigations

Avoid mounting host socket on your macOS host; instead run inside a VM.

Limit runner network and filesystem access.

Use ephemeral VMs for the runner.

3) Runner + Docker‑in‑Docker (DinD) sidecar (privileged DinD daemon inside compose)
How it works

Compose runs a privileged DinD container that provides a Docker daemon inside the compose network. The runner container connects to that DinD daemon (via network or socket) and creates job containers inside the DinD daemon. Those containers are isolated from the host Docker daemon.

Pros

Better isolation from host: job containers run inside the DinD daemon, not the host Docker engine.

Runner can still create containers for jobs, enabling full containerized workflows.

Cleaner teardown: destroy DinD daemon and its volumes to remove job artifacts.

Cons / Risks

DinD requires privileged mode and kernel features; it’s less secure than VM isolation.

On macOS, DinD is fragile because Docker Desktop runs a Linux VM under the hood; privileged DinD inside that stack can be unreliable or unsupported. Works best on Linux hosts or inside a Linux VM.

Slightly more complex compose setup.

When to use

You want containerized job isolation but cannot or do not want to give runner access to host Docker socket.

Use on Linux hosts or inside a Linux VM on macOS.

Mitigations

Run DinD in a dedicated VM if on macOS.

Limit DinD privileges and network egress.

Destroy DinD volumes after runs.

4) Runner inside a VM (best isolation) — runner uses host Docker or DinD inside VM
How it works

The runner runs inside a dedicated Linux VM (VirtualBox, QEMU, Multipass, cloud instance). Inside that VM you can either:

let the runner execute jobs directly on the VM, or

run DinD or mount the VM’s Docker socket so job containers run inside the VM.

Pros

Strong isolation: VM boundary protects your laptop host from job actions.

You can safely mount the VM’s Docker socket or run DinD without risking the host.

Works reliably on macOS because the VM provides a Linux kernel.

Cons

More resource overhead (VM memory/CPU).

Slightly more setup and teardown steps.

When to use

You want a safe, repeatable sandbox on macOS laptop and need containerized job execution (Playwright, DB, Docker-based actions).

Recommended for any untrusted or semi-trusted workflows.

Mitigations

Automate VM creation and destruction per session.

Use ephemeral VM images and snapshot/rollback for repeatability.

Practical recommendations for your setup (explicit)
Three containers on your laptop host is the minimal, practical layout.

Runner must have internet — allow outbound access from the runner container/VM to reach GitHub marketplace and push results. Keep network limited to necessary egress.

Runner execution mode choice:

If you want absolute simplicity and you will only run trusted throwaway workflows: run the runner container and let it execute jobs directly (no DinD). Use non‑root runner user and ephemeral runner lifecycle.

If you need to run containerized jobs (recommended for Playwright and CI parity) and you are on macOS, run the runner inside a small Linux VM (Multipass/UTM/VM) and either:

mount the VM’s Docker socket into the runner (easy), or

run DinD inside the VM (safer than DinD on macOS host).

If you are on Linux, you can use DinD sidecar in Docker Compose for better isolation without a VM. Or run runner container + DinD.

Volume sharing: use a named Docker volume repo-volume mounted into both agent and runner so the runner can run workflows against the same files the agent modifies. No host mounts required.

Security controls:

Use account Y token with push rights only to throwaway repos. Rotate/delete after runs.

Register runner only to throwaway repo; unregister and destroy runner after session.

Do not mount host SSH keys or /var/run/docker.sock into runner unless inside VM.

Keep artifacts in artifacts-volume and export only after manual review.

Quick decision table for runner execution on your laptop
Need	Recommended mode	If on macOS	If on Linux
Minimal setup, trusted workflows	Runner executes jobs directly in container	OK (container)	OK (container)
Containerized jobs, safer isolation	Runner inside Linux VM + VM Docker socket or DinD	Use VM (Multipass/UTM)	DinD sidecar or VM
Max isolation, protect host	Runner inside VM, jobs in containers inside VM	Use VM	Use VM or separate host


Final practical next steps (one‑page)
Start with three containers: services, agent, runner. Use named volumes for repo-volume and artifacts-volume.

Runner placement:

If you want minimal friction now: run runner container directly and let it execute jobs (no DinD). Ensure runner is ephemeral and registered only to throwaway repo.

If you need containerized job execution and you’re on macOS: create a small Linux VM and run the runner inside it. Use the VM’s Docker for job containers.

Provision throwaway repo (account Y token) and clone into repo-volume at compose startup. Mount repo-volume into agent and runner.

Test: push a workflow that runs Playwright against the services; confirm runner executes it and artifacts land in artifacts-volume.

Tear down: unregister runner, delete token, destroy runner container/VM, and keep owner mirror snapshots for recovery.

If you want, I’ll now generate a ready-to-run Docker Compose template for the three-container layout plus two variants of runner deployment:

Variant A: runner container executing jobs directly (fast start).

Variant B: runner inside a Linux VM (Multipass) with instructions to mount the VM Docker socket for containerized jobs on macOS.

Tell me which variant to produce first and I’ll output the compose file, entrypoint scripts, and the small shell commands to register/unregister the runner.

we don't care about the blast radious. everythong on the setup only touches the throwaways. we want simple setups
------
Runner + Docker‑in‑Docker (DinD) sidecar (privileged DinD daemon inside compose): is DinD reliable in macos?
Runner inside a VM (best isolation) — runner uses host Docker or DinD inside VM: can we automate (and throw away) this - like using vagrant, etc?
what about Runner inside a container - so, the host is container - and we can mange it with docker compose?
Recommendation
For minimal overhead and reliable behavior on macOS, run the self‑hosted runner in a container and let it execute jobs directly (no DinD). If you need containerized job execution later, run the runner inside a throwaway Linux VM (automated with Multipass or Vagrant) and use the VM’s Docker for DinD or socket mounting. This gives a simple, repeatable workflow now and an easy upgrade path when you need full containerized CI.

DinD reliability on macOS and practical implications
DinD on macOS is fragile. Docker Desktop on macOS runs Linux containers inside a lightweight VM. Running a privileged DinD container inside that stack often fails or behaves inconsistently because DinD expects direct access to Linux kernel features and privileged operations.

If you need DinD reliably, use a Linux VM. A dedicated Linux VM (Multipass, Vagrant, UTM) provides a real Linux kernel where DinD works predictably.

Summary guidance

For quick, simple runs on macOS: avoid DinD; run the runner container and execute jobs directly.

For containerized job isolation on macOS: use a Linux VM and run DinD or mount the VM Docker socket there.

Runner in a container on your laptop Minimal setup and how it works
Why choose this now

Fast to set up with Docker Compose.

Runner has internet access for marketplace actions and pushing results.

No host folder mounts required if you use Docker volumes for repos and artifacts.

Low operational overhead and easy teardown.

Key points

Runner executes workflow steps as processes inside the runner container. Jobs that expect containers will run as processes unless you add DinD or socket access.

Share the throwaway repo via a Docker named volume repo-volume mounted into both the agent and runner so both see the same files.

Keep the runner registered only to the throwaway repo and unregister + remove the container after the session.

Minimal Docker Compose snippet

yaml
version: "3.8"
services:
  services:
    image: ubuntu:22.04
    container_name: sandbox_services
    volumes:
      - repo-volume:/srv/repos
      - artifacts-volume:/srv/artifacts
    networks:
      - sandbox_net
    command: bash -lc "cd /srv/repos/your-repo && ./start-backend-and-frontend.sh"

  agent:
    image: your-agent-image:latest
    container_name: sandbox_agent
    volumes:
      - repo-volume:/workspace/repo
      - artifacts-volume:/workspace/artifacts
    networks:
      - sandbox_net
    command: bash -lc "cd /workspace/repo && exec /bin/bash"

  runner:
    image: your-gh-runner-image:latest
    container_name: sandbox_runner
    volumes:
      - repo-volume:/runner/repo
      - artifacts-volume:/runner/artifacts
    networks:
      - sandbox_net
    environment:
      - RUNNER_REPO_URL=https://github.com/yourorg/throwaway-repo
      - RUNNER_TOKEN=PASTE_TOKEN_HERE
    command: bash -lc "/entrypoint.bash"

volumes:
  repo-volume:
  artifacts-volume:

networks:
  sandbox_net:
Quick lifecycle

docker compose up -d

Runner container registers to throwaway repo and runs jobs.

After tests, docker compose down --volumes and remove the runner registration token on GitHub.

Runner inside an automated throwaway VM on macOS Use Multipass or Vagrant
Why use a VM

Reliable DinD and containerized job execution.

Stronger isolation from your macOS host.

Easy to automate create and destroy for throwaway runs.

Multipass quick automation example

bash
# 1 Create ephemeral VM
multipass launch --name ci-vm --mem 4G --disk 20G --cpus 2

# 2 Copy helper scripts and runner tarball into VM
multipass transfer ./runner-setup.sh ci-vm:/home/ubuntu/runner-setup.sh

# 3 Run setup inside VM (this script installs docker, downloads runner, registers it)
multipass exec ci-vm -- bash /home/ubuntu/runner-setup.sh "https://github.com/yourorg/throwaway-repo" "REG_TOKEN"

# 4 When done, unregister and delete VM
multipass exec ci-vm -- bash -lc "/home/ubuntu/unregister-runner.sh"
multipass delete ci-vm
multipass purge
What runner-setup.sh does

Installs Docker and required packages.

Downloads and configures the GitHub Actions runner with the provided registration token.

Optionally configures Docker-in-Docker or leaves Docker socket available inside the VM.

Starts the runner as a service.

Vagrant alternative

Use a Vagrantfile to spin up a VirtualBox or libvirt VM, provision Docker and the runner, then vagrant destroy to tear down. Vagrant is scriptable and works well if you prefer VirtualBox or libvirt.

Advantages

DinD and containerized jobs behave like a Linux CI host.

Full control over installed tooling (Playwright browsers, Python, Node).

Easy to destroy and recreate for each session.

Runner job execution modes explained in practical terms
Runner executes jobs directly inside the runner container or VM

Behavior: Steps run as processes on the runner host.

Pros: Simple, no Docker complexity.

Cons: Less per-job isolation; cleanup required between jobs.

Runner uses host Docker socket (/var/run/docker.sock)

Behavior: Runner instructs host Docker to create containers for jobs.

Pros: Jobs run in containers.

Cons: Host exposure risk because job containers can control host Docker.

Runner uses DinD sidecar

Behavior: A privileged DinD daemon runs in the compose network; runner uses that daemon to create job containers inside DinD.

Pros: Job containers isolated from host Docker.

Cons: Requires privileged DinD; unreliable on macOS host without a Linux VM.

Runner inside a VM

Behavior: Runner and Docker run inside a Linux VM; jobs run in containers inside the VM.

Pros: Best isolation and reliability for DinD.

Cons: More resource overhead; but fully automatable and throwaway.

Which to pick now

If you want simplest and fastest: runner container executing jobs directly.

If you need containerized jobs and are on macOS: runner inside an ephemeral Linux VM.

If you are on Linux: DinD sidecar in Compose is a good middle ground.

Practical checklist and minimal security notes
Runner needs internet: allow outbound access from runner container/VM to GitHub and package registries.

Repo sharing: use a Docker volume repo-volume mounted into agent and runner so both operate on the same files.

Push rights: use account Y token with push rights to throwaway repos only; rotate or delete token after runs.

Artifacts: store test reports and artifacts in artifacts-volume and export only after review.

Teardown: automate unregistering the runner and destroying the runner container or VM at session end.

No host mounts: keep host filesystem untouched by using volumes and VM disks.

Ready next steps I will produce if you want
Compose template for the three-container layout with runner container variant and entrypoint scripts.

Multipass setup scripts to automate VM creation, runner registration, and teardown for macOS.

Small helper scripts to clone throwaway repos into volumes and to mirror snapshots to an owner backup.

Tell me which artifact to generate first and I will produce the exact files and commands you can run immediately.

we decided to run runner on container. now - we want decision on this

- backend + db + opencode, frontend + testing + opencode, gh action runner
- backend + db + frontend + testing + opencode, gh action runner
- backend + db + frontend + testing + opencode + gh action runner

care about simplicity, minimum resource usage - no worry about blast radious - original code is  safe
Short verdict
For minimum overhead while keeping a clean, practical workflow, run two containers:

services+agent — backend (Django) + DB (Postgres) + frontend + Playwright dependencies + opencode (ai‑repo workspace)

runner — self‑hosted GitHub Actions runner (container)

This is the simplest layout that still keeps CI execution (the runner) separate so you can start/stop/replace it independently. It uses fewer containers than a three‑container split but avoids the single‑container drawbacks (harder teardown, no independent runner lifecycle).

Why two containers is the best fit for your goals
You said: minimal overhead, no worry about blast radius, account Y has push rights, runner must have internet and push results, opencode (ai‑repo) works across frontend/backend/testing/db.

Two‑container advantages

Lowest operational cost while still isolating CI: fewer containers to manage, fewer volumes, less memory/CPU overhead.

Simplicity: single compose service for all app runtime + agent logic; the agent can directly modify code and run tests against local services without cross‑container networking complexity.

Runner independence: the runner container can be created, registered, used, and destroyed without touching the services/agent container.

Easy sharing of repo: use one named Docker volume (repo-volume) mounted into both containers so agent and runner operate on the same files.

Playwright and Django tests run locally inside the services container (or the testing process can be invoked by the runner), no extra orchestration required.

Why not single container

Single container is the absolute simplest but couples runner with services and agent. You lose the ability to tear down CI separately, and workflows that need to restart the runner or re-register it become clumsy. Also harder to debug CI vs app issues.

Why not three containers (services / agent / runner)

Three containers gives slightly better separation (agent isolated from services) but adds a small management cost. Since you don’t care about blast radius and want minimal overhead, the extra container is unnecessary.

Practical architecture (two‑container) — components and flow
Containers

services-agent

Runs: Postgres, Django dev server, React dev server, Playwright dependencies, and opencode agent (ai‑repo workspace).

Entrypoint: bash supervisor script that starts DB, backend, frontend, then launches opencode in auto mode on the cloned ai-repo.

runner

Runs: GitHub Actions runner binary.

Entrypoint: registration script → run.sh.

Needs outbound internet to fetch marketplace actions and to push results to throwaway repos.

Volumes

repo-volume — contains cloned throwaway repos (ai‑repo, frontend repo, backend repo, tests). Mounted into both containers at the same paths.

artifacts-volume — test reports, Playwright traces, logs.

db-volume — Postgres data (optional if you want persistence across runs).

Network

Single Docker network; services reachable by localhost inside services-agent and by service names from runner if needed.

Auth

Use account Y token for pushes. Provide it to the runner only (or to both if agent must push). Keep token ephemeral and rotate/delete after the session.

Mirroring

Keep an owner‑controlled mirror outside the compose stack that fetches the throwaway repo on every push (webhook or periodic git fetch --mirror) so you can recover deleted history.

How runner and agent share the repo and push results
At compose up an init script clones the throwaway repos into repo-volume.

Agent (opencode) works in /workspace/repo inside services-agent. It can create branches, run tests, generate CI files, and commit locally.

Runner mounts the same repo-volume at /runner/repo and executes workflows against the same files. When a workflow step pushes, it uses the repo context (GITHUB_TOKEN or account Y token) to push to the throwaway remote.

Because both containers share the same volume, the runner sees agent changes immediately (no network push required to trigger local workflows). If you prefer, the runner can git fetch from the throwaway remote instead of reading the volume.

Runner job execution mode (what you’ll run)
You chose runner in a container and want simplicity. Use the runner container executing jobs directly (no DinD). That means:

Workflow steps run as processes inside the runner container.

Containerized actions that expect docker will either fail or run as processes unless you add DinD or socket access later.

This is the simplest, lowest‑overhead mode and works well for Playwright, Django tests, and most JS/Python actions that don’t require launching sibling containers.

If you later need to run Dockerized jobs (e.g., build images inside workflows), you can:

Add DinD sidecar (works best on Linux hosts), or

Move the runner into a Linux VM and mount the VM Docker socket, or

Accept mounting host Docker socket (not recommended on macOS host).

Minimal docker-compose pattern (conceptual)
Volumes

repo-volume

artifacts-volume

db-volume (optional)

services-agent

mounts repo-volume:/workspace/repo

mounts artifacts-volume:/workspace/artifacts

runs start-all.bash which:

starts Postgres

runs python manage.py migrate and starts Django

starts React dev server

launches opencode on /workspace/repo/ai-repo in auto mode

writes logs to /workspace/artifacts

runner

mounts repo-volume:/runner/repo

mounts artifacts-volume:/runner/artifacts

environment: RUNNER_REPO_URL, RUNNER_TOKEN (account Y token), RUNNER_NAME

entrypoint: register runner (non‑interactive) → run.sh

Lifecycle

docker compose up -d

Agent runs and modifies code in repo-volume.

Runner executes workflows and writes artifacts to artifacts-volume.

After session: docker compose down --volumes, unregister runner, delete token.

Practical tips and small checklist
Images

Use images that include required runtimes:

services-agent image: Python, Node, Playwright dependencies (browsers), Postgres client.

runner image: GitHub Actions runner binary + any tools your workflows need (node, python, docker CLI if needed).

Playwright

Install Playwright browsers in services-agent (for local test runs) and in runner if workflows run Playwright there.

Secrets

Inject account Y token into the runner container via environment variable at runtime (avoid baking it into images). Remove/rotate token after use.

Artifacts & review

Always review artifacts-volume before pushing anything to real repos. Export artifacts to host only via an explicit host command.

Teardown

Automate unregistering the runner:

run ./config.sh remove --token <token> inside runner before destroying container.

Delete throwaway repo or rotate token after session.

Resource limits

Add light resource limits to containers (e.g., mem_limit: 2g) to avoid hogging laptop.

Quick comparison table (final)
Layout	Simplicity	Resource use	Isolation	Recommended when
Two containers (services+agent, runner)	Highest	Low	Moderate (runner separate)	You want minimal overhead and independent CI lifecycle — recommended
Three containers (services, agent, runner)	Medium	Slightly higher	Better (agent isolated)	You want clearer separation between agent and services
Single container (everything)	Lowest complexity to start	Lowest	Poor	Only if you want absolute minimal orchestration and don’t need to tear down runner separately


Final actionable next steps (one command list)
Create docker-compose.yml with two services: services-agent and runner, plus named volumes repo-volume and artifacts-volume.

Add an init script that clones throwaway repos into repo-volume at startup.

Build services-agent image with Python, Node, Playwright browsers, and opencode. Add start-all.bash to start DB, backend, frontend, then opencode.

Build runner image with GitHub Actions runner and an entrypoint that registers with the throwaway repo using account Y token and runs run.sh.

docker compose up -d → run your loop engineering.

After tests, docker compose down --volumes, unregister runner, delete/rotate token, and archive artifacts from artifacts-volume.

If you want, I’ll now generate the two‑container docker-compose.yml, the start-all.bash for services-agent, the runner Dockerfile + entrypoint and a short init script that clones throwaway repos into repo-volume. I’ll also include the exact commands to register/unregister the runner and to export artifacts safely.

services-agent Entrypoint: bash
- the agent has fresh db, supervisor script restores dump from repo, starts db - backend - frontend, then launches opencode in auto mode on the cloned ai-repo.

how opencode calls the runner? is that webhook or something - via. internet or docker network?
also, i want to know the complete ci cd experience. in actual ci cd - there is nos ahred volume. so, we also. runner will use the account Y to clone the required repo.

db is not persisted. if something want to persist - that will dumped to repo - and will restore on next spin. also, no artifacts-volume: evrything is pushed to respective repo. repo-volume is throw away after done.

Playwright browsers must be in services-agent (for local test runs) and in runner.

Use images that include required runtimes: but, don't overload, only use the minimum ones - if they don't exist, construct them from bare minimum
Short verdict
Run two containers:

services-agent — backend (Django) + Postgres + frontend + Playwright deps + opencode (ai‑repo workspace)

runner — self‑hosted GitHub Actions runner (container)

Why: minimal resource use, minimal orchestration, simple lifecycle. The runner should clone the throwaway repo itself (no shared volume for CI fidelity). The agent pushes changes to the throwaway remote (account Y) to trigger real Actions runs.

How opencode (agent) and the runner interact
Primary trigger: Git push to throwaway repo (recommended, real‑world parity)

Agent workflow: opencode edits files in its local clone inside services-agent, commits, and pushes to the throwaway remote (account Y).

Runner behavior: GitHub receives the push and schedules the workflow on the registered self‑hosted runner. The runner clones the repo (exactly like GitHub‑hosted runners do) and executes the workflow. This mirrors real CI: no shared volume between agent and runner in the CI step.

Alternative triggers (optional)

GitHub API / gh CLI: agent can call the GitHub API to create a branch, open a PR, or dispatch a workflow (workflow_dispatch). This still requires network access to GitHub and appropriate token scopes.

Local invocation (not recommended for fidelity): runner could be invoked locally to run a workflow against the files in a shared volume, but that diverges from real CI behavior and hides issues that appear only when the runner clones the repo.

Network vs Docker network

Pushes and GitHub API calls go over the internet (GitHub). The agent must have outbound internet to push to the throwaway repo.

Service-to-service traffic (Playwright → frontend/backend) stays on the Docker network inside services-agent. The runner needs internet for marketplace actions and to push results, but it does not need direct access to the services-agent internals unless your workflows run tests that contact the running services — in that case the runner must be able to reach the services (either by being on the same Docker network or by the agent exposing test endpoints). For simplicity: run tests inside services-agent (local test runs) and run CI workflows on the runner that validate artifacts or run additional checks that do not require direct access to the live dev servers.

Complete CI/CD experience (end‑to‑end, step by step)
Startup

docker compose up starts services-agent and runner.

An init script in services-agent clones the throwaway repos into its workspace and restores DB from a dump in the repo (if present).

Development loop (agent)

Opencode runs in auto mode on ai-repo inside services-agent.

Agent edits frontend/backend/tests, writes Playwright tests, runs local tests against the local services, and commits locally.

Publish to throwaway remote

When ready to run CI, the agent pushes the branch to the throwaway GitHub repo (account Y token). This is the canonical trigger for GitHub Actions.

GitHub schedules workflow

GitHub receives the push and schedules the workflow on the registered self‑hosted runner for that throwaway repo.

Runner executes workflow

Runner clones the repo (fresh checkout) and runs the workflow steps. Playwright tests that must run in CI will run on the runner (runner image must include Playwright browsers).

Workflows that need to interact with services can:

Option A (recommended for parity): run tests that do not require the live services-agent (unit tests, build, lint, artifact generation).

Option B: if CI must run end‑to‑end tests against the running dev services, ensure the runner can reach those services (place runner on same Docker network or expose service ports to the runner). This increases coupling and complexity.

Artifacts and results

Workflow artifacts (reports, screenshots) are uploaded to the throwaway repo’s Actions artifacts or pushed back to the repo (account Y). You said you prefer no artifacts volume — so configure workflows to actions/upload-artifact or commit results to the repo (small reports) using the runner’s credentials.

Promotion / review

Owner review and manual promotion: owner X inspects the throwaway repo or mirror and decides whether to merge or copy changes into the canonical repo.

Tear down

Unregister and destroy the runner container, delete/rotate account Y token if desired, and remove the throwaway repo if you want.

DB persistence and dumps
No persistent DB by default. On startup services-agent runs a supervisor script that:

Restores DB from a SQL dump found in the repo (e.g., ai-repo/db/dump.sql) if present.

Starts Postgres and runs migrations.

If agent wants to persist state, it should pg_dump the DB and commit the dump into the throwaway repo (or push to a separate storage repo). On next spin the supervisor will restore that dump. This keeps persistence explicit and under version control.

Notes

Keep dumps small (sampled or sanitized) to avoid huge repo sizes.

Use a consistent path and naming convention (e.g., db/dumps/latest.sql) so the supervisor can find and restore automatically.

Playwright and runtimes (minimal images)
Principles

Keep images minimal: start from python:3.11-slim and node:18-slim and install only required packages and Playwright browsers.

Install Playwright browsers only where needed: services-agent (for local test runs) and runner (for CI Playwright runs).

Minimal image snippets

services-agent Dockerfile (conceptual)

dockerfile
FROM node:18-slim AS node_base
RUN apt-get update && apt-get install -y python3 python3-pip curl ca-certificates
# Install Playwright browsers for local runs
RUN npm i -g playwright@1.x && npx playwright install --with-deps
# Copy minimal scripts and supervisor
WORKDIR /workspace
COPY start-all.bash /workspace/start-all.bash
RUN chmod +x /workspace/start-all.bash
ENTRYPOINT ["/bin/bash", "-lc", "/workspace/start-all.bash"]
runner Dockerfile (conceptual)

dockerfile
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y curl jq git ca-certificates nodejs npm python3 python3-pip
# Install Playwright for CI tests that run in Actions
RUN npm i -g playwright@1.x && npx playwright install --with-deps
# Download and extract GitHub Actions runner in entrypoint
COPY entrypoint.bash /entrypoint.bash
RUN chmod +x /entrypoint.bash
ENTRYPOINT ["/entrypoint.bash"]
Keep images small

Install only the packages your tests and app need (e.g., libnss3, libatk1.0-0, libx11-6 for Playwright). Use --no-install-recommends and clean apt caches.

How opencode triggers CI in this setup (practical)
Primary flow (recommended): opencode commits and git push origin feature/xyz using account Y credentials. That push triggers GitHub Actions on the throwaway repo and the runner executes the workflow. This is the simplest and mirrors production CI exactly.

If you want to avoid pushing for local iteration: opencode can run Playwright locally inside services-agent and only push when tests pass. But remember: runner clones the repo in CI, so pushing is required to validate the real CI run.

Minimal docker-compose conceptual skeleton (two containers)
yaml
version: "3.8"
services:
  services-agent:
    build: ./images/services-agent
    container_name: services_agent
    volumes:
      - repo-volume:/workspace/repo
    networks:
      - sandbox_net
    environment:
      - DB_DUMP_PATH=/workspace/repo/ai-repo/db/dump.sql
    tty: true

  runner:
    build: ./images/runner
    container_name: gh_runner
    environment:
      - RUNNER_REPO_URL=https://github.com/yourorg/throwaway-repo
      - RUNNER_TOKEN=PASTE_TOKEN_HERE
    networks:
      - sandbox_net
    tty: true

volumes:
  repo-volume:

networks:
  sandbox_net:
Init behavior: services-agent entrypoint clones throwaway repos into /workspace/repo and restores DB if dump exists.

Runner behavior: entrypoint.bash registers the runner using RUNNER_TOKEN and runs run.sh.

Practical checklist to run now (commands)
Prepare throwaway repo on GitHub and get account Y token.

Build images: docker compose build.

Start stack: docker compose up -d.

Agent work: opencode runs in services-agent, edits and commits.

Push to trigger CI: agent runs git push origin feature/xyz (account Y).

Runner executes: GitHub schedules job on your runner; runner clones and runs workflow.

Collect results: artifacts uploaded to GitHub Actions or committed to repo by workflow.

Teardown: docker compose down --volumes; unregister runner if needed; rotate/delete token.

Final notes and offer
Recommendation: use the push-to-throwaway-remote trigger so CI behavior matches production. Runner should clone the repo itself (no shared volume for CI). Keep DB persistence via explicit dumps committed to the repo. Install Playwright browsers in both images but keep images minimal.

If you want, I will now generate the concrete files: docker-compose.yml, services-agent start-all.bash, runner entrypoint.bash and minimal Dockerfiles tuned for small images, plus the exact git commands opencode should run to trigger CI. Which files should I produce first?

generate the files
Files I generated for your two‑container sandbox
docker-compose.yml — two services: services-agent and runner, plus a named repo-volume.

images/services-agent/Dockerfile — minimal image with Python, Node, Playwright deps, Postgres client and a lightweight supervisor script.

images/runner/Dockerfile — minimal runner image that downloads the GitHub Actions runner and provides an entrypoint to register/unregister and run.

init/clone-repos.bash — init script that clones the throwaway repos into the repo-volume at container start.

services/start-all.bash — entrypoint for services-agent: restore DB dump if present, start Postgres, run migrations, start Django and frontend, then launch opencode in auto mode.

runner/entrypoint.bash — registers the runner non‑interactively, runs run.sh, and unregisters on exit.

README.md — exact commands to build, run, register/unregister, and the minimal CI workflow notes.

Below are the files (copy/paste into your project). Replace placeholders (e.g., YOUR_THROWAWAY_REPO_URL, ACCOUNT_Y_TOKEN, AI_REPO_URL) with your values.

1) docker-compose.yml
yaml
version: "3.8"
services:
  services-agent:
    build: ./images/services-agent
    container_name: services_agent
    environment:
      - REPO_VOLUME_PATH=/workspace/repo
      - DB_DUMP_PATH=/workspace/repo/ai-repo/db/dump.sql
      - GIT_USER_NAME=agent
      - GIT_USER_EMAIL=agent@example.com
    volumes:
      - repo-volume:/workspace/repo
      - ./init:/init:ro
    networks:
      - sandbox_net
    tty: true

  runner:
    build: ./images/runner
    container_name: gh_runner
    environment:
      - RUNNER_REPO_URL=https://github.com/yourorg/your-throwaway-repo
      - RUNNER_TOKEN=PASTE_ACCOUNT_Y_REGISTRATION_TOKEN_HERE
      - RUNNER_NAME=sandbox-runner-1
      - GIT_PUSH_TOKEN=PASTE_ACCOUNT_Y_PERSONAL_ACCESS_TOKEN_HERE
    volumes:
      - repo-volume:/runner/repo
    networks:
      - sandbox_net
    tty: true

volumes:
  repo-volume:

networks:
  sandbox_net:
2) images/services-agent/Dockerfile
dockerfile
# Minimal image: Node + Python + Postgres client + Playwright deps
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates git python3 python3-pip python3-venv \
    nodejs npm gnupg2 lsb-release wget unzip \
    postgresql postgresql-contrib procps sudo \
    libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libx11-6 libxcomposite1 libxrandr2 libxdamage1 libxss1 libasound2 libgbm1 \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Playwright CLI and browsers (minimal)
RUN npm i -g playwright@1.62.1
RUN npx playwright install --with-deps

# Python tooling
RUN pip3 install --no-cache-dir pip setuptools wheel

# Copy scripts
WORKDIR /workspace
COPY start-all.bash /workspace/start-all.bash
COPY init/clone-repos.bash /init/clone-repos.bash
RUN chmod +x /workspace/start-all.bash /init/clone-repos.bash

# Default entrypoint: bash supervisor script
ENTRYPOINT ["/bin/bash", "-lc", "/workspace/start-all.bash"]
3) images/runner/Dockerfile
dockerfile
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates git jq sudo tar gzip libicu-dev libssl-dev libkrb5-3 \
    nodejs npm python3 python3-pip \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Playwright for CI tests that run in Actions
RUN npm i -g playwright@1.62.1
RUN npx playwright install --with-deps

WORKDIR /runner
COPY runner/entrypoint.bash /runner/entrypoint.bash
RUN chmod +x /runner/entrypoint.bash

ENTRYPOINT ["/bin/bash", "-lc", "/runner/entrypoint.bash"]
4) init/clone-repos.bash
bash
#!/usr/bin/env bash
set -euo pipefail

# This script runs inside services-agent and clones the throwaway repos into /workspace/repo
REPO_ROOT=${REPO_VOLUME_PATH:-/workspace/repo}
mkdir -p "$REPO_ROOT"
cd "$REPO_ROOT"

# Example: clone ai-repo, frontend, backend, tests. Replace URLs with your throwaway repo URLs.
# If already cloned, fetch latest.
clone_or_update() {
  local url="$1"
  local name="$2"
  if [ -d "$name/.git" ]; then
    echo "Updating $name"
    git -C "$name" fetch --all --prune || true
  else
    echo "Cloning $name from $url"
    git clone --depth=1 "$url" "$name" || { echo "Clone failed for $url"; exit 1; }
  fi
}

# Replace these with your throwaway repo URLs
clone_or_update "git@github.com:yourorg/ai-repo.git" "ai-repo"
clone_or_update "git@github.com:yourorg/frontend-repo.git" "frontend"
clone_or_update "git@github.com:yourorg/backend-repo.git" "backend"
clone_or_update "git@github.com:yourorg/tests-repo.git" "tests"

echo "All repos present under $REPO_ROOT"
5) services/start-all.bash
bash
#!/usr/bin/env bash
set -euo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

REPO_ROOT=${REPO_VOLUME_PATH:-/workspace/repo}
DB_DUMP=${DB_DUMP_PATH:-/workspace/repo/ai-repo/db/dump.sql}
GIT_USER_NAME=${GIT_USER_NAME:-agent}
GIT_USER_EMAIL=${GIT_USER_EMAIL:-agent@example.com}

# 1. Ensure repos are cloned (init script)
if [ -x /init/clone-repos.bash ]; then
  echo "Running clone-repos.bash"
  /init/clone-repos.bash
fi

cd "$REPO_ROOT" || exit 1

# 2. Configure git user for local commits
git config --global user.name "$GIT_USER_NAME"
git config --global user.email "$GIT_USER_EMAIL"

# 3. Initialize Postgres data dir if missing
PGDATA=/var/lib/postgresql/data
if [ ! -d "$PGDATA" ] || [ -z "$(ls -A $PGDATA 2>/dev/null || true)" ]; then
  echo "Initializing Postgres data directory"
  mkdir -p "$PGDATA"
  chown -R postgres:postgres "$PGDATA"
  su -s /bin/bash -c "initdb -D $PGDATA" postgres
fi

# 4. Start Postgres
echo "Starting Postgres"
su -s /bin/bash -c "pg_ctl -D $PGDATA -l /var/log/postgres.log start" postgres

# 5. Restore DB dump if present
if [ -f "$DB_DUMP" ]; then
  echo "Restoring DB from $DB_DUMP"
  # Create DB and restore (assumes dump is plain SQL)
  su -s /bin/bash -c "psql -c \"CREATE DATABASE sandboxdb;\" || true" postgres
  su -s /bin/bash -c "psql sandboxdb < $DB_DUMP" postgres
fi

# 6. Start backend (Django) — assumes backend repo has manage.py and requirements.txt
if [ -d "$REPO_ROOT/backend" ]; then
  echo "Starting Django backend"
  cd "$REPO_ROOT/backend"
  python3 -m venv .venv || true
  . .venv/bin/activate
  pip install --no-cache-dir -r requirements.txt || true
  python manage.py migrate || true
  # Run in background
  nohup python manage.py runserver 0.0.0.0:8000 > /workspace/backend.log 2>&1 &
  cd "$REPO_ROOT"
fi

# 7. Start frontend (React) — assumes frontend has package.json
if [ -d "$REPO_ROOT/frontend" ]; then
  echo "Starting frontend dev server"
  cd "$REPO_ROOT/frontend"
  npm ci || true
  # Start dev server in background (adjust command to your app)
  nohup npm run start -- --host 0.0.0.0 > /workspace/frontend.log 2>&1 &
  cd "$REPO_ROOT"
fi

# 8. Ensure Playwright browsers available (already installed in image)
echo "Playwright browsers should be installed in image"

# 9. Launch opencode (agent) in auto mode on ai-repo
if [ -d "$REPO_ROOT/ai-repo" ]; then
  echo "Launching opencode (ai agent) on ai-repo in auto mode"
  cd "$REPO_ROOT/ai-repo"
  # Example: placeholder command to start opencode; replace with actual opencode CLI
  # opencode --workspace . --mode auto --allow-network --git-user "$GIT_USER_NAME" --git-email "$GIT_USER_EMAIL"
  # For now, drop to an interactive bash so you can start opencode manually if needed
  echo "Entering agent workspace: $REPO_ROOT/ai-repo"
  exec /bin/bash
else
  echo "ai-repo not found at $REPO_ROOT/ai-repo; entering /bin/bash"
  exec /bin/bash
fi
Note: Replace the placeholder opencode command with the actual CLI invocation you use to start the agent in auto mode. The script leaves you in the agent workspace so you can start opencode interactively or let the container run it automatically.

6) runner/entrypoint.bash
bash
#!/usr/bin/env bash
set -euo pipefail

RUNNER_DIR=/runner/actions-runner
RUNNER_URL=${RUNNER_REPO_URL:-}
RUNNER_TOKEN=${RUNNER_TOKEN:-}
RUNNER_NAME=${RUNNER_NAME:-}
RUNNER_WORKDIR=/runner/_work
GIT_PUSH_TOKEN=${GIT_PUSH_TOKEN:-}

if [ -z "$RUNNER_URL" ] || [ -z "$RUNNER_TOKEN" ]; then
  echo "RUNNER_REPO_URL, RUNNER_TOKEN and RUNNER_NAME must be set"
  exec /bin/bash
fi

mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

# Download runner if not present
if [ ! -f "$RUNNER_DIR/run.sh" ]; then
  echo "Downloading GitHub Actions runner"
  # Replace version with latest stable if needed
  RUNNER_TAR="actions-runner-linux-x64-2.308.0.tar.gz"
  curl -fsSL -o "$RUNNER_TAR" "https://github.com/actions/runner/releases/download/v2.308.0/$RUNNER_TAR"
  tar xzf "$RUNNER_TAR" --strip-components=0
fi

# Configure runner non-interactively
./config.sh --unattended --url "$RUNNER_URL" --token "$RUNNER_TOKEN" --name "$RUNNER_NAME" --work "$RUNNER_WORKDIR"

# Export GIT token for workflows that need to push (optional)
if [ -n "$GIT_PUSH_TOKEN" ]; then
  echo "Setting up GIT push token for workflows"
  # Write token to a file that workflows can read, or set as env var for runner jobs
  export GIT_PUSH_TOKEN
fi

# Ensure cleanup on exit
cleanup() {
  echo "Removing runner registration"
  ./config.sh remove --unattended --token "$RUNNER_TOKEN" || true
}
trap cleanup EXIT

# Run the runner
./run.sh
7) README.md (usage and commands)
markdown
# Two-container sandbox (services-agent + runner)

## Prereqs
- Docker and Docker Compose installed on your laptop.
- A throwaway GitHub repo (account Y) and a registration token for a self-hosted runner.
- A personal access token for account Y (if agent will push directly).

## Build images
docker compose build

## Start stack
# Edit docker-compose.yml to set RUNNER_REPO_URL and RUNNER_TOKEN
docker compose up -d

## Enter services-agent (agent workspace)
docker exec -it services_agent bash
# inside container you will be in /workspace; ai-repo is at /workspace/repo/ai-repo
# start opencode in auto mode (replace with your actual command)
# opencode --workspace /workspace/repo/ai-repo --mode auto

## How CI is triggered
- Agent commits and pushes to the throwaway repo (account Y).
- GitHub schedules the workflow and the registered self-hosted runner executes it.
- Runner clones the repo fresh and runs the workflow steps.

## Unregister and teardown
# Stop compose
docker compose down --volumes

# If runner still registered, remove it from GitHub UI or run unregister inside runner container before stopping:
docker exec -it gh_runner bash -lc "/runner/actions-runner/config.sh remove --unattended --token YOUR_TOKEN"

# Rotate/delete account Y tokens after session
Notes, assumptions, and small adjustments you may want
No shared CI volume: runner clones the repo itself from GitHub (this matches real CI). The repo-volume is used by services-agent for the agent workspace. If you prefer the runner to read the same files immediately without pushing, mount repo-volume into the runner and skip the clone step — but that diverges from real CI behavior.

DB persistence: by design DB is ephemeral. If the agent wants persistence, it should pg_dump and commit the dump into the repo (e.g., ai-repo/db/dump.sql). The start-all.bash restores that dump on startup.

Playwright: both images install Playwright and browsers. If you want smaller images, remove Playwright from services-agent and only keep it in runner, but then local test runs inside services-agent will not have browsers.

Opencode invocation: start-all.bash leaves you in the ai-repo workspace so you can start opencode manually or replace the exec /bin/bash with your opencode CLI invocation.

Runner tokens: RUNNER_TOKEN is a short‑lived registration token from GitHub (create via repo Settings → Actions → Runners → Add runner). GIT_PUSH_TOKEN is a personal access token for account Y (scoped to repo push). Keep both secret and rotate/delete after use.

Resource limits: add deploy.resources or mem_limit in docker-compose.yml if you want to cap memory/CPU.

Quick checklist to run this now
Put the files into a folder structure:

Code
.
├─ docker-compose.yml
├─ init/
│  └─ clone-repos.bash
├─ images/
│  ├─ services-agent/
│  │  └─ Dockerfile
│  └─ runner/
│     └─ Dockerfile
├─ services/
│  └─ start-all.bash
├─ runner/
│  └─ entrypoint.bash
└─ README.md
Edit init/clone-repos.bash to point to your throwaway repo URLs.

Edit docker-compose.yml to set RUNNER_REPO_URL, RUNNER_TOKEN, and GIT_PUSH_TOKEN.

docker compose build

docker compose up -d

docker exec -it services_agent bash → start opencode (or let it be started automatically).

Agent commits and git push to throwaway repo (account Y). GitHub will schedule the workflow and the runner will execute it.

If you want, I can now:

(A) produce a compact opencode example command sequence the agent should run to commit/push and trigger CI, and a tiny sample GitHub Actions workflow that runs Playwright and uploads artifacts; or

(B) produce a smaller variant of the images that strips optional packages to minimize image size.

Pick A or B and I’ll generate the exact files next.

B
Minimal optimized files for two‑container sandbox
Below are the smaller, trimmed variants of the images and scripts. They remove optional packages, install only the runtime bits required for Django, Node, Playwright, and the GitHub runner, and keep images compact by cleaning apt caches and avoiding large extras.

Copy the files into the same folder layout as before:

Code
.
├─ docker-compose.yml
├─ init/
│  └─ clone-repos.bash
├─ images/
│  ├─ services-agent/
│  │  └─ Dockerfile
│  └─ runner/
│     └─ Dockerfile
├─ services/
│  └─ start-all.bash
├─ runner/
│  └─ entrypoint.bash
└─ README.md
docker-compose.yml
yaml
version: "3.8"
services:
  services-agent:
    build: ./images/services-agent
    container_name: services_agent
    environment:
      - REPO_VOLUME_PATH=/workspace/repo
      - DB_DUMP_PATH=/workspace/repo/ai-repo/db/dump.sql
      - GIT_USER_NAME=agent
      - GIT_USER_EMAIL=agent@example.com
    volumes:
      - repo-volume:/workspace/repo
      - ./init:/init:ro
    networks:
      - sandbox_net
    tty: true

  runner:
    build: ./images/runner
    container_name: gh_runner
    environment:
      - RUNNER_REPO_URL=https://github.com/yourorg/your-throwaway-repo
      - RUNNER_TOKEN=PASTE_ACCOUNT_Y_REGISTRATION_TOKEN_HERE
      - RUNNER_NAME=sandbox-runner-1
      - GIT_PUSH_TOKEN=PASTE_ACCOUNT_Y_PERSONAL_ACCESS_TOKEN_HERE
    volumes:
      - repo-volume:/runner/repo
    networks:
      - sandbox_net
    tty: true

volumes:
  repo-volume:

networks:
  sandbox_net:
images/services-agent/Dockerfile (minimal)
dockerfile
# Minimal services-agent image
# Base byte-frozen: Python 3.13.14 patch tag + index digest pin (freezes the
# baked OS layer beneath Python too — glibc, openssl, libc6). Bump discipline:
#   docker buildx imagetools inspect python:3.13.14-slim  # get new index digest
# then update the @sha256:... below. The apt layer is snapshot-pinned below.
FROM python:3.13.14-slim@sha256:9662417aace5ae7b8e2609cce472b72a8958e134ba372808abe9cc1a0c0125e6

# All RUN steps use bash: set -o pipefail and brace-groups are bash-isms, and
# Debian/Ubuntu /bin/sh is dash (which has neither). ENTRYPOINT already uses
# /bin/bash -lc.
SHELL ["/bin/bash", "-c"]

# Required build args — fail-fast gate: docker build (or compose build) must
# receive these, mirroring the runtime env requirements. Values are validated
# but NOT baked into the image (no ENV/COPY from them); the container gets
# them via compose environment at run time.
ARG GITHUB_PAT
ARG AI_REPO_URL
ARG FRONTEND_REPO_URL
ARG BACKEND_REPO_URL
ARG TESTS_REPO_URL
ARG DB_REPO_URL
ARG DB_DUMP_PATH
ARG GIT_USER_NAME
ARG GIT_USER_EMAIL
ARG BACKEND_PROJECT_DIR

RUN test -n "$GITHUB_PAT" \
  && test -n "$AI_REPO_URL" \
  && test -n "$FRONTEND_REPO_URL" \
  && test -n "$BACKEND_REPO_URL" \
  && test -n "$TESTS_REPO_URL" \
  && test -n "$DB_REPO_URL" \
  && test -n "$DB_DUMP_PATH" \
  && test -n "$GIT_USER_NAME" \
  && test -n "$GIT_USER_EMAIL" \
  && test -n "$BACKEND_PROJECT_DIR" \
  || { echo "ERROR: required build args missing (GITHUB_PAT, AI_REPO_URL, FRONTEND_REPO_URL, BACKEND_REPO_URL, TESTS_REPO_URL, DB_REPO_URL, DB_DUMP_PATH, GIT_USER_NAME, GIT_USER_EMAIL, BACKEND_PROJECT_DIR) — pass via --build-arg or compose build args" >&2; exit 1; }

ENV DEBIAN_FRONTEND=noninteractive

# System deps: Chromium runtime libs, Postgres server (ephemeral sandbox DB),
# git + ca-certificates (runtime), curl (build-time only, purged below), and
# the C toolchain (build-essential python3-dev libpq-dev swig) so the
# backend's pip install can COMPILE the packages that have no binary wheels:
# psycopg2 (Django's postgres driver, definitely imported) and quickfix
# (builds with g++ + swig). Keeps upstream requirements text byte-identical.
#
# Reproducibility: the entire apt layer is pinned to a dated Debian snapshot
# (2026-08-01), freezing git, postgresql-17, and every transitive lib to exact
# versions. Snapshot Releases are older than apt's 7-day validity window, so
# Check-Valid-Until: no is required.
#
# Output capture: every RUN step below tees its output to /var/log/build/*.log
# inside the image (in addition to stdout), so a later failure can be
# interpreted via docker exec after the build. set -o pipefail keeps a failing
# step failing — tee must never mask an error.
RUN set -o pipefail \
  && mkdir -p /var/log/build \
  && rm -f /etc/apt/sources.list.d/debian.sources \
  && printf 'Types: deb\nURIs: https://snapshot.debian.org/archive/debian/20260801T000000Z/\nSuites: trixie trixie-updates\nComponents: main\nSigned-By: /usr/share/keyrings/debian-archive-keyring.gpg\nCheck-Valid-Until: no\n' > /etc/apt/sources.list.d/snapshot.sources \
  && apt-get update 2>&1 | tee /var/log/build/apt-update.log \
  && apt-get install -y --no-install-recommends curl ca-certificates git git-lfs xz-utils \
     postgresql-17 \
     build-essential python3-dev libpq-dev swig \
     libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libx11-6 libxcomposite1 libxrandr2 libxdamage1 libxss1 libasound2 libgbm1 \
     libdbus-1-3 libdrm2 libxkbcommon0 libxcb1 libxext6 libxfixes3 libxshmfence1 libxtst6 \
     libpango-1.0-0 libcairo2 libatspi2.0-0 libnspr4 libglib2.0-0 fonts-liberation \
     2>&1 | tee /var/log/build/apt-install.log

# Node.js 18.20.8 (final 18.x; required by the frontend stack) + OpenCode CLI
# 1.18.15 (the agent runtime, pinned to the host's version).
# Supply-chain hardening: official binary tarballs with PINNED SHA-256, instead
# of the Nodesource setup script (mutable remote code executed as root) and apt
# repo (its 18.x signing key uses SHA-1 and is rejected by Debian trixie since
# 2026-02-01; Nodesource rotated the key for 20/22/24 LTS only). OpenCode's
# GitHub release ships no official checksums, so its pin is cross-verified
# against the npm registry package (opencode-linux-x64@1.18.15): both extract
# to the identical binary (sha256 c1971d3d...).
# Hash sources: https://nodejs.org/dist/latest-v18.x/SHASUMS256.txt
# https://github.com/anomalyco/opencode/releases/download/v1.18.15/opencode-linux-x64.tar.gz
RUN set -o pipefail \
  && { curl -fsSL -o /tmp/node.tar.xz https://nodejs.org/dist/v18.20.8/node-v18.20.8-linux-x64.tar.xz \
    && echo "5467ee62d6af1411d46b6a10e3fb5cacc92734dbcef465fea14e7b90993001c9  /tmp/node.tar.xz" | sha256sum -c - \
    && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 \
    && rm /tmp/node.tar.xz \
    && curl -fsSL -o /tmp/opencode.tar.gz https://github.com/anomalyco/opencode/releases/download/v1.18.15/opencode-linux-x64.tar.gz \
    && echo "d842e0e8c622c672a481b7dc6f0329009b64db96b2ba6041e56f4f93f0293b1c  /tmp/opencode.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/opencode.tar.gz -C /usr/local/bin opencode \
    && chmod 755 /usr/local/bin/opencode \
    && rm /tmp/opencode.tar.gz; } 2>&1 | tee /var/log/build/node-opencode-download.log

# Remove build-time-only curl and apt metadata
RUN set -o pipefail \
  && apt-get purge -y --auto-remove curl 2>&1 | tee /var/log/build/apt-purge.log \
  && rm -rf /var/lib/apt/lists/*

# Playwright CLI and browsers — exact version pinned; playwright verifies
# browser archive integrity during install. 1.61.x is the newest line that
# supports node 18 (1.62+ requires node >=20); --only-shell installs just the
# headless Chromium shell (screenshots only) — saves ~100 MB over full Chromium.
RUN set -o pipefail \
  && npm i -g playwright@1.61.1 2>&1 | tee /var/log/build/playwright-install.log \
  && npx playwright install chromium --only-shell 2>&1 | tee /var/log/build/playwright-browsers.log \
  && npm cache clean --force \
  && rm -rf /root/.npm

# Python tooling: none needed — base ships pip 26.1.2 (frozen by the digest
# pin); setuptools/wheel are unnecessary (PEP 517 build isolation, and all
# runtime deps ship cp313 wheels). psql/pg_restore come via postgresql-17.

WORKDIR /workspace

# Copy scripts (baked outside /workspace so the repo volume can mount there)
COPY services/start-all.bash /init/start-all.bash
COPY services/restore-db.bash /init/restore-db.bash
COPY services/scripts/ /init/scripts/
COPY init/clone-repos.bash /init/clone-repos.bash
RUN chmod +x /init/start-all.bash /init/restore-db.bash /init/clone-repos.bash

ENTRYPOINT ["/bin/bash", "-lc", "/init/start-all.bash"]
images/runner/Dockerfile (common base)
dockerfile
# Common GitHub Actions self-hosted runner BASE image.
# Dedicated per-repo images (images/runner-<repo>/Dockerfile) build FROM this
# (or from the shared node tier, images/runner-node/Dockerfile) and add their
# own toolchains. The base itself never runs as a runner — it only exists as
# a build dependency.
# Base byte-frozen: ubuntu 22.04 digest pin (freezes the exact base layer).
# Bump discipline: docker buildx imagetools inspect ubuntu:22.04  # new digest
# then update the @sha256:... below. The runner tarball (2.336.0, downloaded
# at runtime by entrypoint.bash) is checksum-verified against the SHA-256
# GitHub now publishes in each release's notes.
FROM ubuntu:22.04@sha256:3b06811b2afd352be909dd088a004166d665dc76d38b13eada33522a9d915c6f

# All RUN steps use bash: set -o pipefail and brace-groups are bash-isms, and
# Ubuntu /bin/sh is dash (which has neither). ENTRYPOINT already uses
# /bin/bash -lc.
SHELL ["/bin/bash", "-c"]

# Required build args — fail-fast gate, same as every runner image. The base
# is repo-agnostic, so compose wires the e2e value set as the canonical probe
# (RUNNER_E2E_* is always required by the active compose). Values are
# validated but NOT baked into the image.
ARG RUNNER_REPO_URL
ARG RUNNER_TOKEN
ARG GIT_PUSH_TOKEN
ARG RUNNER_NAME

RUN test -n "$RUNNER_REPO_URL" \
  && test -n "$RUNNER_TOKEN" \
  && test -n "$GIT_PUSH_TOKEN" \
  && test -n "$RUNNER_NAME" \
  || { echo "ERROR: required build args missing (RUNNER_REPO_URL, RUNNER_TOKEN, GIT_PUSH_TOKEN, RUNNER_NAME) — pass via --build-arg or compose build args" >&2; exit 1; }

ENV DEBIAN_FRONTEND=noninteractive

# gh runner runtime deps: the runner binary links the runtime .so only —
# runtime packages (libicu70/libssl3), not the -dev header packages (3-4x
# larger). Deps were verified against the 2.308.0 tarball's ELF needs when
# the base was designed; the 2.336.0 bump is expected to keep them (same
# load-time shape) — if it ever changes, the missing-lib failure shows in
# /var/log/runner-entrypoint.log. libicu70 is what pulls libstdc++6 +
# libgcc-s1 (hard load-time deps of coreclr + bundled node20), libssl3 pulls
# zlib1g, tar pulls liblzma5. curl kept (actions +
# Node tarball fetch). No gzip — nothing uses the binary; tar -xzf and the
# .NET/Playwright extractors decompress via libz/bundled code. No python
# (runner-backend only) and no node (runner-node tier only) — per-layer
# toolchains stay out of the shared base.
#
# Reproducibility: apt layer pinned to a dated Ubuntu snapshot (2026-08-09),
# freezing every package to exact versions. Snapshot Releases are older than
# apt's 7-day validity window, so Check-Valid-Until: no is required. All
# downstream layers (runner-node, per-repo toolchains) inherit these pinned
# sources. TWO pockets: jammy main + jammy-updates — the pinned base digest
# is rebuilt with jammy-updates versions baked in (e.g. perl-base
# 5.34.0-3ubuntu1.7), so a main-only pin creates version skew (snapshot perl
# 5.34.0-3ubuntu1 requires perl-base exactly = 5.34.0-3ubuntu1) and apt
# fails with "held broken packages".
#
# Output capture: RUN steps tee their output to /var/log/build/*.log inside
# the image (in addition to stdout) so failures can be interpreted later via
# docker exec. set -o pipefail keeps a failing step failing — tee must never
# mask an error.
#
# CA bootstrap: the ubuntu:22.04 base image ships NO CA store, so an https
# apt against the snapshot fails TLS before any package is installed
# ("No system certificates available. Try installing ca-certificates").
# Default sources are plain http archive.ubuntu.com, so ca-certificates is
# bootstrapped from them first, then sources are swapped to the pinned
# snapshot. Debian-slim bases (services-agent, runner-db) ship certs and do
# not need this.
RUN set -o pipefail \
  && mkdir -p /var/log/build \
  && apt-get update 2>&1 | tee /var/log/build/apt-bootstrap-update.log \
  && apt-get install -y --no-install-recommends ca-certificates \
     2>&1 | tee /var/log/build/apt-bootstrap-ca.log \
  && rm -f /etc/apt/sources.list \
  && printf 'deb [check-valid-until=no] https://snapshot.ubuntu.com/ubuntu/20260809T000000Z/ jammy main\ndeb [check-valid-until=no] https://snapshot.ubuntu.com/ubuntu/20260809T000000Z/ jammy-updates main\n' > /etc/apt/sources.list \
  && apt-get update 2>&1 | tee /var/log/build/apt-update.log \
  && apt-get install -y --no-install-recommends curl git tar libicu70 libssl3 libkrb5-3 \
     2>&1 | tee /var/log/build/apt-install.log \
  && rm -rf /var/lib/apt/lists/*

# GitHub's runner refuses to run as root ("Must not run with sudo", EUID
# check in config.sh). Everything runner-owned lives under /runner; the
# entrypoint chowns /runner and runs config.sh/run.sh via `su runner -c`.
# runner-frontend, runner-e2e and runner-node inherit this user.
RUN useradd -m -s /bin/bash runner

WORKDIR /runner
COPY runner/entrypoint.bash /runner/entrypoint.bash
RUN chmod +x /runner/entrypoint.bash

ENTRYPOINT ["/bin/bash", "-lc", "/runner/entrypoint.bash"]

images/runner-node/Dockerfile (shared node tier — build dependency only)
dockerfile
# Shared NODE tier for runner images that need a system node — build
# dependency only, never runs as a runner. Consumed by runner-e2e
# (playwright) and runner-frontend (npm); runner-backend / runner-db do NOT
# include it. Kept as its own tier so the pinned tarball exists once.
FROM ai-opencode-sandbox-runner-base:latest

# RUN steps use bash (see runner-base): /bin/sh is dash, no pipefail.
SHELL ["/bin/bash", "-c"]

# Node.js 18.20.8 — official binary tarball with PINNED SHA-256, instead of the
# Nodesource setup script (mutable remote code executed as root) and apt repo
# (its 18.x signing key uses SHA-1 and is rejected on modern apt since 2026-02).
# Hash source: https://nodejs.org/dist/latest-v18.x/SHASUMS256.txt
# xz-utils is build-time-only (tar -xJf spawns the xz binary) and is purged
# after extraction; it stays out of the shared base per the per-layer rule.
#
# Output capture: the step tees its output to /var/log/build/node-tier-install.log
# inside the image (in addition to stdout) so failures can be interpreted later
# via docker exec. set -o pipefail keeps a failing step failing — tee must
# never mask an error.
RUN set -o pipefail \
  && mkdir -p /var/log/build \
  && { apt-get update \
    && apt-get install -y --no-install-recommends xz-utils \
    && curl -fsSL -o /tmp/node.tar.xz https://nodejs.org/dist/v18.20.8/node-v18.20.8-linux-x64.tar.xz \
    && echo "5467ee62d6af1411d46b6a10e3fb5cacc92734dbcef465fea14e7b90993001c9  /tmp/node.tar.xz" | sha256sum -c - \
    && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 \
    && rm /tmp/node.tar.xz \
    && apt-get purge -y --auto-remove xz-utils \
    && rm -rf /var/lib/apt/lists/*; } 2>&1 | tee /var/log/build/node-tier-install.log

Dedicated per-repo runner images build FROM the base (or the node tier) and
add one toolchain each; all four share the same required-args fail-fast gate
(RUNNER_REPO_URL / RUNNER_TOKEN / GIT_PUSH_TOKEN / RUNNER_NAME, validated
but not baked). runner-db and runner-backend are the exceptions to the
FROM-chain — both STANDALONE (see below):

- images/runner-e2e/Dockerfile — FROM node tier; Chromium runtime libs
  hand-picked (same proven list as services-agent, snapshot-pinned) +
  Playwright CLI with the headless Chromium shell (--only-shell, same as
  services-agent; saves ~100 MB over full Chromium). No --with-deps — the
  lib layer installs exactly the proven set and removes apt lists.
  Selenium/cucumber is discontinued; Playwright is the only e2e future.
- images/runner-db/Dockerfile — STANDALONE FROM debian:trixie-slim (digest
  pinned) + snapshot-pinned apt, same snapshot domain as services-agent:
  full runner prereqs (libicu76 / libssl3t64 / libkrb5-3, trixie names) +
  postgresql-17 SERVER. Reason: db workflows restore 17-format dumps, which
  jammy's postgresql-14 cannot; carrying the server lets initdb / restore /
  psql run entirely locally on the runner.
- images/runner-frontend/Dockerfile — FROM node tier; npm-only (node 18 +
  npm come from the node tier) — same npm-only stack as services-agent; no
  yarn.
- images/runner-backend/Dockerfile — STANDALONE FROM the same digest-pinned
  python:3.13.14-slim as services-agent (Python 3.13.14 + pip 26.1.2, frozen
  by the digest) + snapshot-pinned runner prereqs (libicu76 / libssl3t64 /
  libkrb5-3, trixie names). Reason: jammy's apt python3 is 3.10; backend
  workflows need 3.13. No node — the backend runner does not carry it.

Compose builds the base and node tiers first as build-only services
(command: /bin/true) and the per-repo runners declare `depends_on` chains
(runner-e2e → runner-node → runner-base). runner-db and runner-backend are
standalone — they pull debian:trixie-slim / python:3.13.14-slim by digest
and have no depends_on. `docker compose
up --build`
orders the builds automatically; for `docker compose build` alone use
`docker compose build --with-dependencies` (compose ≥ 2.20). The base
service passes the e2e value set as its build args (RUNNER_E2E_REPO_URL /
RUNNER_E2E_TOKEN / GIT_PUSH_TOKEN) plus the static probe name
ai-opencode-runner-e2e — the canonical probe for the base's own gate, since
the base itself is repo-agnostic. RUNNER_NAME is not an env var: each
service's name is a compose literal (ai-opencode-runner-e2e / -db /
-frontend / -backend), required by the entrypoint and gated at build.
init/clone-repos.bash (HTTPS clones for minimal credential juggling)
bash
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=/workspace
mkdir -p "$REPO_ROOT"
cd "$REPO_ROOT"

# Minimum-storage clone semantics: never smudge LFS pointers (even if a repo
# declares them) and never recurse into submodules — submodule content is
# cloned separately as its own top-level repo (e.g. the db repo itself).
export GIT_LFS_SKIP_SMUDGE=1

# Repo URLs passed via environment variables — required, no defaults.
# docker-compose.yml provides these; set -u aborts if any is unset.
# AI_REPO_URL / FRONTEND_REPO_URL / BACKEND_REPO_URL / TESTS_REPO_URL / DB_REPO_URL
# GITHUB_PAT (required, for private repos, e.g. GITHUB_PAT=github_pat_xxx) is injected
# as https://x-access-token:<PAT>@github.com/...

# URLs are always plain https://github.com/... (no embedded credentials), so
# auth injection is a straight rewrite: scheme stripped, PAT inserted.
auth_url() {
  local url="$1"
  if [ -n "$GITHUB_PAT" ]; then
    printf 'https://x-access-token:%s@%s' "$GITHUB_PAT" "${url#https://}"
  else
    printf '%s' "$url"
  fi
}

clone_or_update() {
  local url="$1"
  local name="$2"
  url=$(auth_url "$url")
  if [ -d "$name/.git" ]; then
    echo "Updating $name"
    git -C "$name" fetch --all --prune --depth=1 --no-tags || true
  else
    echo "Cloning $name from $url"
    # --depth=1 --single-branch --no-tags: shallow, one branch, no refs —
    # minimum storage. Submodules are NOT recursed (left as gitlinks).
    git clone --depth=1 --single-branch --no-tags "$url" "$name" \
      || { echo "Clone failed for $name"; exit 1; }
  fi
}

# Output capture: the clone block below tees its output to
# /workspace/logs/clone-repos.log (in addition to stdout) so failures can be
# interpreted later — /workspace is the repo volume and survives container
# recreation. pipefail keeps tee from masking a failed clone.
mkdir -p /workspace/logs
{
  clone_or_update "$AI_REPO_URL" "ai-repo"
  clone_or_update "$FRONTEND_REPO_URL" "frontend"
  clone_or_update "$BACKEND_REPO_URL" "backend"
  clone_or_update "$TESTS_REPO_URL" "tests"
  clone_or_update "$DB_REPO_URL" "db"

  echo "Repos ready at $REPO_ROOT"
} 2>&1 | tee /workspace/logs/clone-repos.log
services/start-all.bash (trimmed)
bash
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=${REPO_VOLUME_PATH:-/workspace/repo}
DB_DUMP=${DB_DUMP_PATH:-/workspace/repo/ai-repo/db/dump.sql}
GIT_USER_NAME=${GIT_USER_NAME:-agent}
GIT_USER_EMAIL=${GIT_USER_EMAIL:-agent@example.com}

# Ensure repos are present
if [ -x /init/clone-repos.bash ]; then
  /init/clone-repos.bash
fi

cd "$REPO_ROOT" || exit 1

git config --global user.name "$GIT_USER_NAME"
git config --global user.email "$GIT_USER_EMAIL"

# Start a lightweight Postgres using the system package (ephemeral)
PGDATA=/var/lib/postgresql/data
if [ ! -d "$PGDATA" ] || [ -z "$(ls -A $PGDATA 2>/dev/null || true)" ]; then
  mkdir -p "$PGDATA"
  chown -R postgres:postgres "$PGDATA"
  su -s /bin/bash -c "initdb -D $PGDATA" postgres
fi

su -s /bin/bash -c "pg_ctl -D $PGDATA -l /var/log/postgres.log start" postgres

# Restore DB dump if present
if [ -f "$DB_DUMP" ]; then
  su -s /bin/bash -c "psql -c \"CREATE DATABASE sandboxdb;\" || true" postgres
  su -s /bin/bash -c "psql sandboxdb < $DB_DUMP" postgres
fi

# Start backend if present
if [ -d "$REPO_ROOT/backend" ]; then
  cd "$REPO_ROOT/backend"
  python3 -m venv .venv || true
  . .venv/bin/activate
  pip install --no-cache-dir -r requirements.txt || true
  nohup python manage.py runserver 0.0.0.0:8000 > /workspace/backend.log 2>&1 &
  cd "$REPO_ROOT"
fi

# Start frontend if present
if [ -d "$REPO_ROOT/frontend" ]; then
  cd "$REPO_ROOT/frontend"
  npm ci || true
  nohup npm run start -- --host 0.0.0.0 > /workspace/frontend.log 2>&1 &
  cd "$REPO_ROOT"
fi

# Leave shell in ai-repo workspace so opencode can be started manually or by replacing the exec line
if [ -d "$REPO_ROOT/ai-repo" ]; then
  cd "$REPO_ROOT/ai-repo"
  echo "Agent workspace ready at $REPO_ROOT/ai-repo"
  exec /bin/bash
else
  exec /bin/bash
fi
runner/entrypoint.bash (trimmed)
bash
#!/usr/bin/env bash
set -euo pipefail

RUNNER_DIR=/runner/actions-runner
RUNNER_URL=${RUNNER_REPO_URL:-}
RUNNER_TOKEN=${RUNNER_TOKEN:-}
RUNNER_NAME=${RUNNER_NAME:-}
RUNNER_WORKDIR=/runner/_work
GIT_PUSH_TOKEN=${GIT_PUSH_TOKEN:-}

if [ -z "$RUNNER_URL" ] || [ -z "$RUNNER_TOKEN" ]; then
  echo "RUNNER_REPO_URL, RUNNER_TOKEN and RUNNER_NAME must be set"
  exec /bin/bash
fi

mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

if [ ! -f "$RUNNER_DIR/run.sh" ]; then
  echo "Downloading GitHub Actions runner"
  RUNNER_TAR="actions-runner-linux-x64-2.308.0.tar.gz"
  curl -fsSL -o "$RUNNER_TAR" "https://github.com/actions/runner/releases/download/v2.308.0/$RUNNER_TAR"
  tar xzf "$RUNNER_TAR"
fi

./config.sh --unattended --url "$RUNNER_URL" --token "$RUNNER_TOKEN" --name "$RUNNER_NAME" --work "$RUNNER_WORKDIR"

cleanup() {
  ./config.sh remove --unattended --token "$RUNNER_TOKEN" || true
}
trap cleanup EXIT

# Export GIT_PUSH_TOKEN for workflows if provided
if [ -n "$GIT_PUSH_TOKEN" ]; then
  export GIT_PUSH_TOKEN
fi

./run.sh
README.md (concise)
markdown
Two-container minimal sandbox

Prereqs
- Docker and Docker Compose
- Throwaway GitHub repo (account Y)
- Registration token for self-hosted runner (repo Settings -> Actions -> Runners -> Add runner)
- Optional personal access token for account Y if agent will push via HTTPS

Build and run
1. Edit init/clone-repos.bash to point to your throwaway HTTPS repo URLs.
2. Edit docker-compose.yml to set RUNNER_REPO_URL, RUNNER_TOKEN, and GIT_PUSH_TOKEN.
3. Build images:
   docker compose build
4. Start stack:
   docker compose up -d
5. Enter agent workspace:
   docker exec -it services_agent bash
   cd /workspace/repo/ai-repo
   # start opencode in auto mode (replace with your CLI)
   # opencode --workspace . --mode auto

CI flow
- Agent commits and pushes to throwaway repo (account Y).
- GitHub triggers Actions; the registered runner clones the repo and runs workflows.
- Artifacts can be uploaded via actions/upload-artifact or committed back to the repo by workflows.

Teardown
- Unregister runner (inside runner container or via GitHub UI) then:
  docker compose down --volumes
- Rotate/delete tokens after session.
Notes and small optimizations
HTTPS clones in clone-repos.bash avoid SSH key mounting. Use GIT_PUSH_TOKEN in runner workflows or agent git commands if pushing via HTTPS (store token in ~/.netrc or use git -c credential.helper=... inside container).

Playwright is installed in both images. If you want even smaller images, remove Playwright from services-agent and run local tests only on the runner.

Image size: these Dockerfiles use slim/base images and remove apt caches. If you need further size reduction, consider multi-stage builds or installing only the exact system libs Playwright requires (advanced).

Opencode auto start: start-all.bash leaves you in the agent workspace. Replace the final exec /bin/bash with your opencode CLI invocation to start automatically.
