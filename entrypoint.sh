#!/bin/bash
set -e
service postgresql restart
service apache2 restart
sleep 30
service renderd restart
tail -f /dev/null