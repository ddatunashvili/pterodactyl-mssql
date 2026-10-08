# Pterodactyl MSSQL egg

Microsoft SQL Server 2022 image and egg for Pterodactyl.

## 1. Build and publish the image

**GitHub Actions (recommended):** push this folder to a GitHub repo on `main`.
`.github/workflows/docker.yml` builds and pushes `ghcr.io/<owner>/pterodactyl-mssql:2022`.
Then go to GitHub > Packages > pterodactyl-mssql > Package settings and set visibility to **Public**
(or add registry credentials to Wings `config.yml` under `docker.registries`).

**Local:**
```powershell
docker login ghcr.io -u <github-user>   # password = PAT with write:packages
.\build.ps1 -Image ghcr.io/<owner>/pterodactyl-mssql:2022
```

## 2. Import the egg

1. Edit `egg-mssql.json`, replace `OWNER` in `docker_images` with your GitHub user/org (lowercase).
2. Panel > Admin > Nests > Import Egg > pick `egg-mssql.json`.
3. Create a server: memory >= 2048 MB, set `ACCEPT_EULA=Y` and an SA password.

Connect with `<node-ip>,<allocation-port>` user `sa`. Lines typed in the panel console run as T-SQL.

## Notes

- Wings must run containers with uid 988 (default). If `system.user.uid` in Wings differs,
  rebuild with `-Uid <uid>` / `--build-arg CONTAINER_UID=<uid>`.
- Data lives in `/home/container/mssql` (the server volume), so backups include databases.
  Prefer stopping the server or using `BACKUP DATABASE` before a panel backup.
- Image is linux/amd64 only (Microsoft does not ship arm64 SQL Server).
