#!/bin/bash

URL=$1    # Jenkins input step return URL
USER=$2   # Jenkins username
PASS=$3   # Jenkins API token

echo "=================================================================="
echo "Starting Testing..."
echo "=================================================================="

# The test suite repo is copied here in its entirety
cd /tmp/src

# Change "skiptests" to false in pom.xml
sed -i 's/<skipTests>true/<skipTests>false/g' pom.xml

# Run all tests in test suite and continue even if tests fail
mvn clean install --projects Hello --projects World || true

TESTCOUNT=$(ls */target/cucumber.json | wc -l)
echo "There were $TESTCOUNT tests run."

# Make directory for all Cucumber json files
mkdir reports

# For cucumber.json files, take it and move it to reports directory
# Change name of file to [count].json so they don't overwrite each other
for ((i = 1 ; i <= $TESTCOUNT ; i++)); do
  CUR=$(ls */target/cucumber.json | tail -n +$i | head -1)
  echo $CUR
  cp -f $CUR reports/$i.json
done

# Notify Jenkins pipeline that tests have finished
curl -X POST --user $USER:$PASS \
  $URL

# Give a little time to make sure oc rsync works
# Pod will scale down after this finishes
sleep 1m
