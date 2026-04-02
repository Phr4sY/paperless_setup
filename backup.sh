#!/bin/bash

# --- Configuration ---
EXPORT_DIR="/paperless/export"
CONFIG_PATH="/paperless/rclone.conf"
REMOTE_SYNC="onedrive:MyNASBackups/Paperless/Daily_Sync"
REMOTE_ARCHIVE="onedrive:MyNASBackups/Paperless/Weekly_Snapshots"
DAY_OF_WEEK=$(date +%u)
TIMESTAMP=$(date +%Y-W%W)
RETENTION_DAYS=365

# 1. Export from Paperless (This must stay sudo for Podman for Docker you can execute it as a normal user)
echo "--- Starting Paperless Export ---"
/usr/bin/sudo /usr/bin/podman exec paperless_webserver_1 document_exporter ../export

# 2. Fix permissions so the user can process the files (not needed if you use Docker instead of podman)
/usr/bin/sudo /usr/bin/chown -R admin_nas:users $EXPORT_DIR

# 3. DAILY DIFFERENTIAL SYNC
# This keeps a perfect 1:1 mirror of your current Paperless data
echo "--- Starting Daily Differential Sync ---"
/paperless/rclone sync $EXPORT_DIR $REMOTE_SYNC --config $CONFIG_PATH -v

# 4. WEEKLY SNAPSHOT (Runs every Sunday = 7)
if [ "$DAY_OF_WEEK" == "7" ]; then
	echo "--- Sunday detected! Creating Weekly Archive ---"

	# Create the compressed tarball
	# -c (create), -z (gzip), -f (file)
	/usr/bin/tar -czf /paperless/paperless_weekly_$TIMESTAMP.tar.gz -C $EXPORT_DIR .

	# Copy the archive to the 'Weekly_Snapshots' folder on OneDrive
	/paperless/rclone copy /paperless/paperless_weekly_$TIMESTAMP.tar.gz $REMOTE_ARCHIVE --config $CONFIG_PATH -v

	# Delete the local archive file to save NAS space
	/usr/bin/rm /paperless/paperless_weekly_$TIMESTAMP.tar.gz

	# 5. RETENTION CLEANUP (Delete snapshots older than 1 year on OneDrive)
	echo "--- Cleaning up Snapshots older than 1 year ---"
	/paperless/rclone delete $REMOTE_ARCHIVE --min-age ${RETENTION_DAYS}d --config $CONFIG_PATH -v
	echo "Weekly archive and 1-year cleanup complete."
fi

# 6. Final Cleanup: Clear the local export folder
# We clear it so next time we start with a fresh export
/usr/bin/rm -rf $EXPORT_DIR/*
echo "--- Backup Process Finished Successfully ---"
