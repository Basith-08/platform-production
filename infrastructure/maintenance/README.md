# Platform maintenance

`cleanup-docker.sh` runs weekly and removes only unused Docker images older than
168 hours (`7 days`). It uses `docker image prune -a`, which does not remove
images referenced by containers, containers themselves, or any Docker volume.
The grace period keeps recent immutable Git commit-SHA images available for
rollback and troubleshooting.

The component is deployed by the same changed-component workflow as the other
`infrastructure/<component>` directories. Its crontab is merged with the
backup component's deploy-user crontab rather than replacing it.
