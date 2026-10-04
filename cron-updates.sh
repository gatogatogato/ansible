#!/bin/bash
# Kept for the existing cronjob, see cron-run.sh
exec "$(dirname "${BASH_SOURCE[0]}")/cron-run.sh" updates
